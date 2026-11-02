import Foundation
import IOKit
import IOKit.hid

// Read-only diagnostic. Never writes a report, seizes a device, or requests elevation.
var iterator: io_iterator_t = 0
let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSPUHIDDevice"), &iterator)
print("Registry query:", result)
if result == KERN_SUCCESS {
    defer { IOObjectRelease(iterator) }
    var count = 0
    while case let service = IOIteratorNext(iterator), service != 0 {
        defer { IOObjectRelease(service) }
        func number(_ key: String) -> Int? {
            (IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber)?.intValue
        }
        guard number("PrimaryUsagePage") == 0xff00, number("PrimaryUsage") == 3 else { continue }
        count += 1
        print("Accelerometer registry entry found; report bytes:", number("MaxInputReportSize") ?? -1)
        guard let device = IOHIDDeviceCreate(kCFAllocatorDefault, service) else {
            print("IOHIDDeviceCreate failed (no accessible user client).")
            continue
        }
        let opened = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        print(String(format: "Nonexclusive IOHIDDeviceOpen: 0x%08x", UInt32(bitPattern: opened)))
        if opened == kIOReturnSuccess {
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
            buffer.initialize(repeating: 0, count: 64)
            defer { buffer.deinitialize(count: 64); buffer.deallocate() }
            let reports = UnsafeMutablePointer<Int>.allocate(capacity: 1)
            reports.initialize(to: 0)
            defer { reports.deinitialize(count: 1); reports.deallocate() }
            IOHIDDeviceRegisterInputReportCallback(device, buffer, 64, { context, result, _, _, _, _, length in
                guard result == kIOReturnSuccess, let context else { return }
                let reports = context.assumingMemoryBound(to: Int.self)
                reports.pointee += 1
                if reports.pointee == 1 { print("Received an actual input report; bytes:", length) }
            }, reports)
            IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            CFRunLoopRunInMode(.defaultMode, 2, false)
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            print("Actual input reports in 2 seconds:", reports.pointee)
        }
    }
    print("Matching registry entries:", count)
}
