import Foundation

/// Operates on real acceleration only. Never estimates left/right impact location.
struct TapDetector {
    private var gravity: SIMD3<Double>?
    private var lastSample: TimeInterval?
    private var lastTap: TimeInterval = -.infinity
    private var sampleCount = 0
    private var armed = true

    /// High-pass residual with hysteresis and a 120 ms mechanical debounce.
    mutating func process(x: Double, y: Double, z: Double, at time: TimeInterval, sensitivity: Double) -> Bool {
        let sample = SIMD3(x, y, z)
        guard x.isFinite, y.isFinite, z.isFinite, time.isFinite,
              abs(x) < 16, abs(y) < 16, abs(z) < 16 else { return false }
        guard let baseline = gravity, let previousTime = lastSample,
              time >= previousTime, time - previousTime < 0.5 else {
            gravity = sample; lastSample = time; sampleCount = 0; armed = true
            return false
        }
        lastSample = time
        let dt = max(0.0001, time - previousTime)
        let alpha = 1 - exp(-dt / 0.08)
        gravity = baseline + (sample - baseline) * alpha
        sampleCount += 1
        let delta = sample - baseline
        let magnitude = sqrt(delta.x * delta.x + delta.y * delta.y + delta.z * delta.z)
        let threshold = 0.18 - min(1, max(0, sensitivity)) * 0.165
        if magnitude < threshold * 0.4 { armed = true }
        guard sampleCount > 20, armed, magnitude > threshold, time - lastTap >= 0.12 else { return false }
        armed = false
        lastTap = time
        return true
    }

    mutating func reset() { self = TapDetector() }
}

struct ReactionGate {
    private(set) var lastReaction: TimeInterval = -.infinity
    mutating func accept(at time: TimeInterval, cooldown: TimeInterval) -> Bool {
        guard time.isFinite, time - lastReaction >= max(0.12, cooldown) else { return false }
        lastReaction = time
        return true
    }
    mutating func reset() { lastReaction = -.infinity }
}
