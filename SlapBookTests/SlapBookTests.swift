import Foundation
import Testing
@testable import SlapBook

struct SlapBookTests {
    @Test func detectorRejectsGravityAndDebouncesRinging() {
        var detector = TapDetector()
        for n in 0..<100 {
            verify(!detector.process(x: 0, y: 0, z: 1, at: Double(n) / 100, sensitivity: 0.5))
        }
        verify(detector.process(x: 0.3, y: 0, z: 1, at: 1, sensitivity: 0.5))
        for n in 1...10 {
            verify(!detector.process(x: n % 2 == 0 ? 0.3 : 0, y: 0, z: 1, at: 1 + Double(n) / 100, sensitivity: 0.5))
        }
        for n in 11..<50 { _ = detector.process(x: 0, y: 0, z: 1, at: 1 + Double(n) / 100, sensitivity: 0.5) }
        verify(detector.process(x: -0.3, y: 0, z: 1, at: 1.5, sensitivity: 0.5))
    }

    @Test func sensitivityActuallyChangesThreshold() {
        var sensitive = TapDetector(), conservative = TapDetector()
        for n in 0..<100 {
            _ = sensitive.process(x: 0, y: 0, z: 1, at: Double(n) / 100, sensitivity: 1)
            _ = conservative.process(x: 0, y: 0, z: 1, at: Double(n) / 100, sensitivity: 0)
        }
        verify(sensitive.process(x: 0.06, y: 0, z: 1, at: 1, sensitivity: 1))
        verify(!conservative.process(x: 0.06, y: 0, z: 1, at: 1, sensitivity: 0))
    }

    @Test func detectorRejectsInvalidDataAndRewarmsAfterSleep() {
        var detector = TapDetector()
        verify(!detector.process(x: .nan, y: 0, z: 1, at: 0, sensitivity: 0.5))
        for n in 0..<100 { _ = detector.process(x: 0, y: 0, z: 1, at: Double(n) / 100, sensitivity: 0.5) }
        verify(!detector.process(x: 1000, y: 0, z: 1, at: 1, sensitivity: 1))
        verify(!detector.process(x: 0.3, y: 0, z: 1, at: 100, sensitivity: 1))
        verify(!detector.process(x: 0.3, y: 0, z: 1, at: 0, sensitivity: 1))
    }

    @Test func cooldownUsesMonotonicTimeAndBoundary() {
        var gate = ReactionGate()
        verify(gate.accept(at: 1, cooldown: 0.7))
        verify(!gate.accept(at: 1.69, cooldown: 0.7))
        verify(gate.accept(at: 1.71, cooldown: 0.7))
        verify(!gate.accept(at: .nan, cooldown: 0.7))
        gate.reset()
        verify(gate.accept(at: 1.72, cooldown: 3))
    }

    @MainActor @Test func settingsRoundTripAndClampPersistedInput() throws {
        let name = "SlapBookTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(99, forKey: "volume")
        defaults.set(-1, forKey: "cooldown")
        defaults.set("unknownMode", forKey: "mode")
        let settings = SettingsStore(defaults: defaults)
        verify(settings.volume == 1)
        verify(settings.cooldown == 0.2)
        verify(settings.mode == .dramaticMoans)
        verify(!settings.experimentalMotionEnabled)
        settings.mode = .chaos
        settings.muted = true
        settings.sensitivity = 0.8
        let restored = SettingsStore(defaults: defaults)
        verify(restored.mode == .chaos)
        verify(restored.muted)
        verify(restored.sensitivity == 0.8)
    }
}

private func verify(_ value: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(value, sourceLocation: sourceLocation)
}
