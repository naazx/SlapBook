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
    let model: AppModel

    init(grouped: Bool = false, motionEnabled: Bool = false) throws {
        defaults = try #require(UserDefaults(suiteName: name))
        defaults.set(true, forKey: "detectionEnabled")
        defaults.set(true, forKey: "shortcutEnabled")
        defaults.set(motionEnabled, forKey: "experimentalMotionEnabled")
        defaults.set(grouped, forKey: "multiTapEnabled")
        model = AppModel(defaults: defaults, workspaceCenter: workspace, applicationCenter: application,
                         audio: audio, motion: motion, shortcut: shortcut)
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
