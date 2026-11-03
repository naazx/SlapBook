import Foundation
import Observation

@Observable @MainActor
final class SettingsStore {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var onChange: (() -> Void)?

    var detectionEnabled: Bool { didSet { persist() } }
    var sensitivity: Double { didSet { persist() } }
    var volume: Double { didSet { persist() } }
    var cooldown: Double { didSet { persist() } }
    var mode: SoundMode { didSet { persist() } }
    var muted: Bool { didSet { persist() } }
    var pitchVariation: Bool { didSet { persist() } }
    var multiTapEnabled: Bool { didSet { persist() } }
    var experimentalMotionEnabled: Bool { didSet { persist() } }
    var shortcutEnabled: Bool { didSet { persist() } }
    var openWindowAtLaunch: Bool { didSet { persist() } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            "detectionEnabled": true, "sensitivity": 0.5, "volume": 0.65,
            "cooldown": 0.7, "mode": SoundMode.dramaticMoans.rawValue,
            "muted": false, "pitchVariation": true, "multiTapEnabled": false,
            "experimentalMotionEnabled": false, "shortcutEnabled": true,
            "openWindowAtLaunch": true
        ])
        detectionEnabled = defaults.bool(forKey: "detectionEnabled")
        sensitivity = Self.clamp(defaults.double(forKey: "sensitivity"), 0...1)
        volume = Self.clamp(defaults.double(forKey: "volume"), 0...1)
        cooldown = Self.clamp(defaults.double(forKey: "cooldown"), 0.2...3)
        mode = SoundMode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .dramaticMoans
        muted = defaults.bool(forKey: "muted")
        pitchVariation = defaults.bool(forKey: "pitchVariation")
        multiTapEnabled = defaults.bool(forKey: "multiTapEnabled")
        experimentalMotionEnabled = defaults.bool(forKey: "experimentalMotionEnabled")
        shortcutEnabled = defaults.bool(forKey: "shortcutEnabled")
        openWindowAtLaunch = defaults.bool(forKey: "openWindowAtLaunch")
    }

    private static func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : range.lowerBound
    }

    private func persist() {
        defaults.set(detectionEnabled, forKey: "detectionEnabled")
        defaults.set(sensitivity, forKey: "sensitivity")
        defaults.set(volume, forKey: "volume")
        defaults.set(cooldown, forKey: "cooldown")
        defaults.set(mode.rawValue, forKey: "mode")
        defaults.set(muted, forKey: "muted")
        defaults.set(pitchVariation, forKey: "pitchVariation")
        defaults.set(multiTapEnabled, forKey: "multiTapEnabled")
        defaults.set(experimentalMotionEnabled, forKey: "experimentalMotionEnabled")
        defaults.set(shortcutEnabled, forKey: "shortcutEnabled")
        defaults.set(openWindowAtLaunch, forKey: "openWindowAtLaunch")
        onChange?()
    }
}
