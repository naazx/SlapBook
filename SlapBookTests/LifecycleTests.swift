import AppKit
import Foundation
import ServiceManagement
import Testing
@testable import SlapBook

@MainActor
struct LifecycleTests {
    @Test func sleepCancelsGroupedReactionAndWakeStartsInputsOnce() async throws {
        let fixture = try Fixture(grouped: true, motionEnabled: true)
        defer { fixture.cleanup() }
        let model = fixture.model
        #expect(fixture.motion.starts == 1)
        #expect(fixture.shortcut.starts == 1)
        model.triggerManualTap()
        fixture.workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        fixture.workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        model.triggerManualTap()
        model.testSound()
        #expect(model.tapCount == 1)
        #expect(fixture.audio.suspends == 1)
        #expect(fixture.motion.stops == 1)
        #expect(fixture.shortcut.stops == 1)
        #expect(fixture.audio.played.isEmpty)

        fixture.workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        fixture.workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        #expect(fixture.motion.starts == 2)
        #expect(fixture.shortcut.starts == 2)
        // The first input after wake must not be swallowed by the old debounce,
        // nor combined with the canceled pre-sleep group.
        model.triggerManualTap()
        #expect(model.tapCount == 2)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while fixture.audio.played.isEmpty && clock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(fixture.audio.played == [1])
    }

    @Test func preferenceChangesWhileSleepingWaitForWake() throws {
        let fixture = try Fixture(motionEnabled: true)
        defer { fixture.cleanup() }
        fixture.workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        fixture.model.settings.detectionEnabled = false
        fixture.model.settings.detectionEnabled = true
        fixture.model.settings.volume = 0.3
        fixture.model.refreshHardware()
        #expect(fixture.motion.starts == 1)
        #expect(fixture.shortcut.starts == 1)
        fixture.workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        #expect(fixture.motion.starts == 2)
        #expect(fixture.shortcut.starts == 2)
    }

    @Test func wakeResetsCooldownAndShutdownIsFinal() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        fixture.model.settings.cooldown = 3
        fixture.model.triggerManualTap()
        #expect(fixture.audio.played == [1])
        fixture.workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
        fixture.workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        fixture.model.triggerManualTap()
        #expect(fixture.audio.played == [1, 1])
        fixture.model.shutdown()
        fixture.model.shutdown()
        let starts = fixture.shortcut.starts
        fixture.model.settings.detectionEnabled = false
        fixture.model.settings.detectionEnabled = true
        fixture.workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
        fixture.model.triggerManualTap()
        fixture.model.testSound()
        fixture.model.setLaunchAtLogin(true)
        #expect(fixture.shortcut.starts == starts)
        #expect(fixture.audio.played == [1, 1])
        #expect(fixture.model.tapCount == 2)
        #expect(fixture.login.registrations == 0)
    }

    @Test func pendingLoginApprovalCanBeCanceledWithoutRegisteringAgain() throws {
        let fixture = try Fixture(loginStatus: .requiresApproval)
        defer { fixture.cleanup() }
        #expect(fixture.model.launchAtLogin)
        #expect(fixture.model.loginNeedsApproval)
        #expect(fixture.model.loginStatus.contains("will not launch"))
        fixture.model.setLaunchAtLogin(true)
        #expect(fixture.login.registrations == 0)
        fixture.model.setLaunchAtLogin(false)
        #expect(fixture.login.unregistrations == 1)
        #expect(!fixture.model.launchAtLogin)
        #expect(!fixture.model.loginNeedsApproval)
    }

    @Test func activationRefreshesLoginStateAndRegistrationErrorsAreVisible() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        fixture.login.status = .enabled
        fixture.application.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        #expect(fixture.model.launchAtLogin)
        fixture.login.status = .notRegistered
        fixture.application.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        #expect(!fixture.model.launchAtLogin)
        fixture.login.registrationError = TestError.denied
        fixture.model.setLaunchAtLogin(true)
        #expect(fixture.model.statusMessage?.contains("Test registration denied") == true)
        #expect(!fixture.model.launchAtLogin)
        fixture.model.openLoginItemSettings()
        #expect(fixture.login.settingsOpens == 1)
    }

    @Test func selectedCustomPackRestoresAndOnlyItsAudioIsPrewarmed() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let sounds = [
            CustomSound(id: UUID(), name: "Ah", pack: "One", tapCount: 0, filename: "one.wav"),
            CustomSound(id: UUID(), name: "Oh", pack: "Two", tapCount: 0, filename: "two.wav")
        ]
        fixture.model.customSounds = sounds
        fixture.model.selectedCustomPack = "Two"
        #expect(fixture.audio.warmed.last == [sounds[1].url])
        fixture.model.settings.volume = 0.5
        let warmCount = fixture.audio.warmed.count
        fixture.model.settings.volume = 0.4
        #expect(fixture.audio.warmed.count == warmCount)
        fixture.defaults.set(try JSONEncoder().encode(sounds), forKey: "customSounds")
        let restoredAudio = FakeAudio()
        let restored = AppModel(defaults: fixture.defaults, workspaceCenter: NotificationCenter(),
                                applicationCenter: NotificationCenter(), audio: restoredAudio,
                                motion: FakeMotion(), shortcut: FakeShortcut(), loginItem: FakeLogin())
        defer { restored.shutdown() }
        #expect(restored.selectedCustomPack == "Two")
        #expect(restoredAudio.warmed == [[sounds[1].url]])
    }
    @Test func customModeIsOfferedOnlyWhileSoundsExist() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let model = fixture.model
        #expect(!model.availableModes.contains(.custom))
        model.settings.mode = .custom
        #expect(model.settings.mode == .dramaticMoans)
        let sound = CustomSound(id: UUID(), name: "Ah", pack: "One", tapCount: 0,
                                filename: UUID().uuidString + ".wav")
        model.customSounds = [sound]
        #expect(model.availableModes.contains(.custom))
        model.settings.mode = .custom
        #expect(model.settings.mode == .custom)
        model.removeSound(sound)
        #expect(model.settings.mode == .dramaticMoans)
        #expect(!model.availableModes.contains(.custom))
        fixture.defaults.set(SoundMode.custom.rawValue, forKey: "mode")
        let restored = AppModel(defaults: fixture.defaults, workspaceCenter: NotificationCenter(),
                                applicationCenter: NotificationCenter(), audio: FakeAudio(),
                                motion: FakeMotion(), shortcut: FakeShortcut(), loginItem: FakeLogin())
        defer { restored.shutdown() }
        #expect(restored.settings.mode == .dramaticMoans)
    }
    @Test func combinedLibraryNameIsReservedBeforeOpeningAFilePanel() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        fixture.model.customPackName = " All sounds "
        fixture.model.importSounds()
        #expect(fixture.model.statusMessage?.contains("reserved") == true)
        #expect(fixture.model.customSounds.isEmpty)
        #expect(fixture.model.customPacks == ["All sounds"])
    }
}

@MainActor
private final class Fixture {
    let name = "SlapBook.LifecycleTests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let workspace = NotificationCenter()
    let application = NotificationCenter()
    let audio = FakeAudio()
    let motion = FakeMotion()
    let shortcut = FakeShortcut()
    let login = FakeLogin()
    let model: AppModel

    init(grouped: Bool = false, motionEnabled: Bool = false, loginStatus: SMAppService.Status = .notRegistered) throws {
        defaults = try #require(UserDefaults(suiteName: name))
        defaults.set(true, forKey: "detectionEnabled")
        defaults.set(true, forKey: "shortcutEnabled")
        defaults.set(motionEnabled, forKey: "experimentalMotionEnabled")
        defaults.set(grouped, forKey: "multiTapEnabled")
        login.status = loginStatus
        model = AppModel(defaults: defaults, workspaceCenter: workspace, applicationCenter: application,
                         audio: audio, motion: motion, shortcut: shortcut, loginItem: login)
    }

    func cleanup() {
        model.shutdown()
        defaults.removePersistentDomain(forName: name)
    }
}

@MainActor
private final class FakeAudio: ReactionAudioService {
    var played: [Int] = []
    var suspends = 0
    var warmed: [[URL]] = []
    func prepare() throws { }
    func play(mode: SoundMode, tapCount: Int, volume: Double, pitchVariation: Bool, customURLs: [URL]) throws -> String {
        played.append(tapCount)
        return "Test reaction"
    }
    func setOutput(volume: Double, muted: Bool) { }
    func stop() { }
    func suspend() { suspends += 1 }
    func validate(url: URL) throws { }
    func preloadCustom(urls: [URL]) throws { warmed.append(urls) }
    func clearCustomCache() { }
}

@MainActor
private final class FakeMotion: MotionInputService {
    var onSample: ((Double, Double, Double) -> Void)?
    var onStatus: ((String, Bool) -> Void)?
    var starts = 0
    var stops = 0
    func start() { starts += 1 }
    func stop() { stops += 1 }
}

@MainActor
private final class FakeShortcut: ShortcutInputService {
    var onTrigger: (() -> Void)?
    var status = "Shortcut is off"
    var starts = 0
    var stops = 0
    func start() { starts += 1; status = "Test shortcut ready" }
    func stop() { stops += 1; status = "Shortcut is off" }
}

@MainActor
private final class FakeLogin: LoginItemService {
    var status: SMAppService.Status = .notRegistered
    var registrations = 0
    var unregistrations = 0
    var settingsOpens = 0
    var registrationError: (any Error)?
    func register() throws {
        registrations += 1
        if let registrationError { throw registrationError }
        status = .enabled
    }
    func unregister() throws { unregistrations += 1; status = .notRegistered }
    func openSettings() { settingsOpens += 1 }
}

private enum TestError: LocalizedError {
    case denied
    var errorDescription: String? { "Test registration denied" }
}
