import AppKit
import Foundation
import Observation
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
protocol ReactionAudioService: AnyObject {
    func prepare() throws
    func play(mode: SoundMode, tapCount: Int, volume: Double, pitchVariation: Bool, customURLs: [URL]) throws -> String
    func setOutput(volume: Double, muted: Bool)
    func stop()
    func suspend()
    func validate(url: URL) throws
    func preloadCustom(urls: [URL]) throws
    func clearCustomCache()
}

@MainActor
protocol MotionInputService: AnyObject {
    var onSample: ((Double, Double, Double) -> Void)? { get set }
    var onStatus: ((String, Bool) -> Void)? { get set }
    func start()
    func stop()
}

@MainActor
protocol ShortcutInputService: AnyObject {
    var onTrigger: (() -> Void)? { get set }
    var status: String { get }
    func start()
    func stop()
}

extension AudioEngine: ReactionAudioService { }
extension ExperimentalMotionInput: MotionInputService { }
extension GlobalShortcut: ShortcutInputService { }

@Observable @MainActor
final class AppModel {
    var settings: SettingsStore
    var hardware: HardwareReport
    var motionStatus = "Experimental motion input is off."
    var motionStreaming = false
    var shortcutStatus = "Shortcut is off."
    var lastReaction = "Emotionally available. Technically fragile."
    var lastInput = "Waiting for a button or shortcut"
    var reactionID = 0
    var tapCount: Int
    var reactionCount: Int
    var secretUnlocked: Bool
    var statusMessage: String?
    var customSounds: [CustomSound] = []
    var customPackName = "My Sound Pack"
    var selectedCustomPack = "All sounds"
    var launchAtLogin = false
    var loginStatus = ""

    @ObservationIgnored private let audio: any ReactionAudioService
    @ObservationIgnored private let motion: any MotionInputService
    @ObservationIgnored private let shortcut: any ShortcutInputService
    @ObservationIgnored private var detector = TapDetector()
    @ObservationIgnored private var gate = ReactionGate()
    @ObservationIgnored private var groupTask: Task<Void, Never>?
    @ObservationIgnored private var groupCount = 0
    @ObservationIgnored private var currentMotionEnabled = false
    @ObservationIgnored private var currentShortcutEnabled = false
    @ObservationIgnored private var currentGroupingEnabled = false
    @ObservationIgnored private var lastManualInput: TimeInterval = -.infinity
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let workspaceCenter: NotificationCenter
    @ObservationIgnored private let applicationCenter: NotificationCenter
    @ObservationIgnored private var workspaceObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var applicationObserver: NSObjectProtocol?
    @ObservationIgnored private var sleeping = false
    @ObservationIgnored private var isShutdown = false

    var customPacks: [String] { ["All sounds"] + Set(customSounds.map(\.pack)).sorted() }

    init(defaults: UserDefaults = .standard,
         workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
         applicationCenter: NotificationCenter = .default,
         audio: any ReactionAudioService = AudioEngine(),
         motion: any MotionInputService = ExperimentalMotionInput(),
         shortcut: any ShortcutInputService = GlobalShortcut()) {
        self.defaults = defaults
        self.workspaceCenter = workspaceCenter
        self.applicationCenter = applicationCenter
        self.audio = audio
        self.motion = motion
        self.shortcut = shortcut
        settings = SettingsStore(defaults: defaults)
        hardware = HardwareProbe.inspect()
        tapCount = defaults.integer(forKey: "tapCount")
        reactionCount = defaults.integer(forKey: "reactionCount")
        secretUnlocked = defaults.bool(forKey: "secretUnlocked")
        if let data = defaults.data(forKey: "customSounds") {
            do {
                customSounds = try JSONDecoder().decode([CustomSound].self, from: data)
                // Filenames are generated UUIDs; reject metadata path traversal.
                    .filter { !$0.filename.contains("/") && !$0.filename.contains("..") }
            } catch { statusMessage = "Could not restore custom sound library: \(error.localizedDescription)" }
        }
        if settings.mode == .secret && !secretUnlocked { settings.mode = .dramaticMoans }
        do { try audio.prepare() }
        catch { statusMessage = error.localizedDescription }
        motion.onSample = { [weak self] x, y, z in
            guard let self, self.settings.detectionEnabled, !self.sleeping, !self.isShutdown else { return }
            let now = ProcessInfo.processInfo.systemUptime
            if self.detector.process(x: x, y: y, z: z, at: now, sensitivity: self.settings.sensitivity) {
                self.receiveInput(source: "Experimental chassis motion · location unknown")
            }
        }
        motion.onStatus = { [weak self] status, streaming in
            self?.motionStatus = status
            self?.motionStreaming = streaming
        }
        shortcut.onTrigger = { [weak self] in self?.triggerManualTap(source: "Global shortcut ⌥⌘S") }
        settings.onChange = { [weak self] in self?.settingsChanged() }
        updateLoginStatus()
        observeLifecycle()
        settingsChanged()
    }

    func refreshHardware() {
        guard !isShutdown else { return }
        hardware = HardwareProbe.inspect()
        if currentMotionEnabled && !sleeping { motion.stop(); detector.reset(); motion.start() }
        updateLoginStatus()
    }

    private func settingsChanged() {
        guard !isShutdown else { return }
        audio.setOutput(volume: settings.volume, muted: settings.muted)
        if !settings.detectionEnabled || sleeping || currentGroupingEnabled != settings.multiTapEnabled {
            cancelPendingGroup()
        }
        currentGroupingEnabled = settings.multiTapEnabled
        if settings.mode == .secret && !secretUnlocked { settings.mode = .dramaticMoans; return }
        let wantsMotion = settings.detectionEnabled && settings.experimentalMotionEnabled && !sleeping
        if currentMotionEnabled != wantsMotion {
            currentMotionEnabled = wantsMotion
            detector.reset()
            if wantsMotion { motion.start() } else { motion.stop(); motionStreaming = false }
        }
        let wantsShortcut = settings.detectionEnabled && settings.shortcutEnabled && !sleeping
        if currentShortcutEnabled != wantsShortcut {
            currentShortcutEnabled = wantsShortcut
            if wantsShortcut { shortcut.start() } else { shortcut.stop() }
        }
        shortcutStatus = shortcut.status
    }

    func triggerManualTap(source: String = "On-screen tap button") {
        guard settings.detectionEnabled, !sleeping, !isShutdown else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastManualInput >= 0.12 else { return }
        lastManualInput = now
        receiveInput(source: source)
    }

    private func receiveInput(source: String) {
        guard settings.detectionEnabled, !sleeping, !isShutdown else { return }
        tapCount += 1
        defaults.set(tapCount, forKey: "tapCount")
        lastInput = source
        if settings.multiTapEnabled {
            groupCount = min(3, groupCount + 1)
            groupTask?.cancel()
            if groupCount == 3 { flushGroup(); return }
            groupTask = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                self?.flushGroup()
            }
        } else { react(taps: 1, isTest: false) }
    }

    private func flushGroup() {
        groupTask?.cancel(); groupTask = nil
        let count = groupCount
        groupCount = 0
        guard settings.detectionEnabled, !sleeping, !isShutdown, count > 0 else { return }
        react(taps: count, isTest: false)
    }

    /// Hardware independent; deliberately bypasses input enable and cooldown.
    func testSound(tapCount: Int = 1) { react(taps: min(3, max(1, tapCount)), isTest: true) }

    private func react(taps: Int, isTest: Bool) {
        guard !sleeping, !isShutdown else { return }
        guard !settings.muted, settings.volume > 0 else {
            if isTest { statusMessage = "Sound is muted or volume is zero. Raise the volume to hear your Mac's feelings." }
            return
        }
        var nextGate = gate
        guard isTest || nextGate.accept(at: ProcessInfo.processInfo.systemUptime, cooldown: settings.cooldown) else { return }
        let matching = customSounds.filter {
            (selectedCustomPack == "All sounds" || $0.pack == selectedCustomPack) && ($0.tapCount == 0 || $0.tapCount == taps)
        }
        do {
            let title = try audio.play(mode: settings.mode, tapCount: taps, volume: settings.volume,
                                       pitchVariation: settings.pitchVariation, customURLs: matching.map(\.url))
            if !isTest { gate = nextGate }
            lastReaction = settings.mode == .custom
                ? (matching.first { $0.url.deletingPathExtension().lastPathComponent == title }?.name ?? title)
                : title
            if isTest { lastInput = "Sound preview · \(taps)-tap reaction" }
            reactionID += 1
            reactionCount += 1
            defaults.set(reactionCount, forKey: "reactionCount")
            statusMessage = nil
        } catch { statusMessage = error.localizedDescription }
    }

    func stopPlayback() { audio.stop() }

    func importSounds() {
        let panel = NSOpenPanel()
        panel.title = "Give your Mac a new vocabulary"
        panel.message = "Import audio you own or have permission to use. Up to 30 seconds / 25 MB each. Files are copied into the app's library."
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        let trimmed = customPackName.trimmingCharacters(in: .whitespacesAndNewlines)
        let pack = String((trimmed.isEmpty ? "My Sound Pack" : trimmed).prefix(64))
        var errors: [String] = []
        var imported = 0
        do { try FileManager.default.createDirectory(at: CustomSound.directory, withIntermediateDirectories: true) }
        catch { statusMessage = error.localizedDescription; return }
        for source in panel.urls {
            guard customSounds.count < 100 else { errors.append("Library limit is 100 sounds."); break }
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            var destination: URL?
            do {
                try audio.validate(url: source)
                let id = UUID()
                let filename = id.uuidString + "." + source.pathExtension.lowercased()
                let url = CustomSound.directory.appendingPathComponent(filename)
                destination = url
                try FileManager.default.copyItem(at: source, to: url)
                customSounds.append(CustomSound(id: id, name: source.deletingPathExtension().lastPathComponent,
                                                pack: pack, tapCount: 0, filename: filename))
                imported += 1
            } catch {
                if let destination { try? FileManager.default.removeItem(at: destination) }
                errors.append("\(source.lastPathComponent): \(error.localizedDescription)")
            }
        }
        persistLibrary()
        if imported > 0 { selectedCustomPack = pack; settings.mode = .custom }
        statusMessage = errors.isEmpty ? "Imported \(imported) sound\(imported == 1 ? "" : "s") into \(pack)." : errors.joined(separator: "\n")
    }

    func setSoundTapCount(_ sound: CustomSound, count: Int) {
        guard let index = customSounds.firstIndex(where: { $0.id == sound.id }) else { return }
        customSounds[index].tapCount = min(3, max(0, count))
        persistLibrary()
    }

    func removeSound(_ sound: CustomSound) {
        do {
            if FileManager.default.fileExists(atPath: sound.url.path) { try FileManager.default.removeItem(at: sound.url) }
            customSounds.removeAll { $0.id == sound.id }
            audio.clearCustomCache()
            if !customPacks.contains(selectedCustomPack) { selectedCustomPack = "All sounds" }
            persistLibrary()
        } catch { statusMessage = "Could not remove sound: \(error.localizedDescription)" }
    }

    private func persistLibrary() {
        do { defaults.set(try JSONEncoder().encode(customSounds), forKey: "customSounds") }
        catch { statusMessage = "Could not save sound library: \(error.localizedDescription)" }
    }

    func unlockSecret() {
        secretUnlocked = true
        defaults.set(true, forKey: "secretUnlocked")
        settings.mode = .secret
        lastReaction = "You found the forbidden feelings."
        reactionID += 1
    }

    func resetStatistics() {
        tapCount = 0; reactionCount = 0
        defaults.set(0, forKey: "tapCount"); defaults.set(0, forKey: "reactionCount")
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard !isShutdown else { return }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { statusMessage = "Launch at Login: \(error.localizedDescription)" }
        updateLoginStatus()
    }

    private func updateLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled
        switch status {
        case .enabled: loginStatus = "Enabled in macOS Login Items."
        case .requiresApproval: loginStatus = "Approve SlapBook Pro in System Settings → General → Login Items."
        case .notRegistered: loginStatus = "Off. Install the app in Applications before enabling."
        case .notFound: loginStatus = "Install a signed app in Applications to use Launch at Login."
        @unknown default: loginStatus = "Login item status is unavailable."
        }
    }

    private func cancelPendingGroup() {
        groupTask?.cancel()
        groupTask = nil
        groupCount = 0
    }

    private func suspendForSleep() {
        guard !isShutdown, !sleeping else { return }
        let hadMotion = currentMotionEnabled
        sleeping = true
        cancelPendingGroup()
        audio.suspend()
        settingsChanged()
        if hadMotion { motionStatus = "Sensor paused while this Mac sleeps." }
    }

    private func resumeAfterWake() {
        guard !isShutdown, sleeping else { return }
        sleeping = false
        lastManualInput = -.infinity
        detector.reset()
        gate.reset()
        hardware = HardwareProbe.inspect()
        updateLoginStatus()
        settingsChanged()
    }

    private func observeLifecycle() {
        workspaceObservers.append(workspaceCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.suspendForSleep() }
        })
        workspaceObservers.append(workspaceCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.resumeAfterWake() }
        })
        applicationObserver = applicationCenter.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateLoginStatus() }
        }
    }

    func shutdown() {
        guard !isShutdown else { return }
        isShutdown = true
        cancelPendingGroup()
        settings.onChange = nil
        motion.stop(); shortcut.stop(); audio.stop()
        currentMotionEnabled = false
        currentShortcutEnabled = false
        motionStreaming = false
        shortcutStatus = shortcut.status
        motion.onSample = nil
        motion.onStatus = nil
        shortcut.onTrigger = nil
        workspaceObservers.forEach { workspaceCenter.removeObserver($0) }
        workspaceObservers.removeAll()
        if let applicationObserver { applicationCenter.removeObserver(applicationObserver) }
        applicationObserver = nil
    }
}
