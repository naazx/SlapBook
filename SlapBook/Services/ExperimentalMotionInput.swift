import AppKit
import Foundation
import IOKit
import IOKit.hid

/// Uses public IOKit calls with an *undocumented* AppleSPU report layout.
/// Never enabled automatically, never asks for elevated privileges, never invents samples.
@MainActor
final class ExperimentalMotionInput {
    var onSample: ((Double, Double, Double) -> Void)?
    var onStatus: ((String, Bool) -> Void)?

    private var device: IOHIDDevice?
    private var buffer: UnsafeMutablePointer<UInt8>?
    private var watchdog: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var requested = false
    private var validReports = 0
    private var lastReport: TimeInterval = 0
    private var streaming = false

    init() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.requested else { return }
                self.closeSession()
                self.onStatus?("Sensor paused while this Mac sleeps.", false)
            }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.requested else { return }
                self.start()
            }
        })
    }

    isolated deinit {
        closeSession()
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
    }

    func start() {
        closeSession()
        requested = true
        guard let service = HardwareProbe.accelerationService() else {
            onStatus?("No compatible sensor visible. Use keyboard input.", false)
            return
        }
        defer { IOObjectRelease(service) }
        guard let candidate = IOHIDDeviceCreate(kCFAllocatorDefault, service) else {
            onStatus?("macOS did not expose a sensor user client. Use keyboard input.", false)
            return
        }
        let result = IOHIDDeviceOpen(candidate, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            let code = String(format: "0x%08x", UInt32(bitPattern: result))
            onStatus?("Sensor access unavailable (\(code)). Use ⌥⌘S. No administrator access is requested.", false)
            return
        }
        device = candidate
        let storage = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        storage.initialize(repeating: 0, count: 64)
        buffer = storage
        validReports = 0
        streaming = false
        lastReport = ProcessInfo.processInfo.systemUptime
        IOHIDDeviceRegisterInputReportCallback(candidate, storage, 64, { context, result, _, type, _, report, length in
            guard result == kIOReturnSuccess, type == kIOHIDReportTypeInput,
                  let context, length == 22 else { return }
            // This callback is scheduled only on the main run loop below.
            MainActor.assumeIsolated {
                let owner = Unmanaged<ExperimentalMotionInput>.fromOpaque(context).takeUnretainedValue()
                owner.receive(report, length: length)
            }
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(candidate, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        onStatus?("Waiting for real sensor reports…", false)
        watchdog = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard let self, self.device != nil else { return }
                if ProcessInfo.processInfo.systemUptime - self.lastReport > 3 {
                    self.closeSession()
                    self.onStatus?("No valid sensor reports received. Keyboard input remains available.", false)
                    return
                }
            }
        }
    }

    func stop() {
        requested = false
        closeSession()
        onStatus?("Experimental sensor is off. Keyboard input is available.", false)
    }

    private func closeSession() {
        watchdog?.cancel()
        watchdog = nil
        if let device {
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        device = nil
        buffer?.deinitialize(count: 64)
        buffer?.deallocate()
        buffer = nil
        validReports = 0
        streaming = false
    }

    private func receive(_ bytes: UnsafeMutablePointer<UInt8>, length: Int) {
        guard device != nil, requested, length == 22 else { return }
        func axis(_ offset: Int) -> Double {
            let raw = UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 |
                UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
            return Double(Int32(bitPattern: raw)) / 65536.0
        }
        let x = axis(6), y = axis(10), z = axis(14)
        let magnitude = sqrt(x * x + y * y + z * z)
        // A flat, stationary laptop normally includes gravity (~1 g). Reject
        // zero, unbounded, or nonfinite reports instead of treating them as taps.
        guard x.isFinite, y.isFinite, z.isFinite, magnitude > 0.1, magnitude < 16 else { return }
        validReports = min(3, validReports + 1)
        lastReport = ProcessInfo.processInfo.systemUptime
        guard validReports >= 3 else { return }
        if !streaming {
            streaming = true
            onStatus?("Receiving experimental motion data. Generic taps only; location is unavailable.", true)
        }
        onSample?(x, y, z)
    }
}
