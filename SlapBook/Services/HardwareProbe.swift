import Foundation
import IOKit
import IOKit.hid

struct HardwareReport: Sendable {
    let summary: String
    let detail: String
    let sensorPresent: Bool
}

/// Registry presence is deliberately separate from accessible, valid sensor readings.
enum HardwareProbe {
    static func inspect() -> HardwareReport {
        guard let service = accelerationService() else {
            return HardwareReport(
                summary: "Keyboard input available",
                detail: "No compatible SPU accelerometer entry was visible. macOS has no supported Core Motion chassis input. Use ⌥⌘S or the on-screen reaction buttons. Left/right location is unavailable.",
                sensorPresent: false
            )
        }
        defer { IOObjectRelease(service) }
        return HardwareReport(
            summary: "Experimental sensor entry found",
            detail: "An SPU accelerometer is listed, but registry presence does not prove access. The undocumented HID stream may be blocked by macOS. Keyboard input is always available. Left/right location is unavailable.",
            sensorPresent: true
        )
    }

    /// Caller owns the returned service reference. No sensor is opened by this query.
    static func accelerationService() -> io_service_t? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSPUHIDDevice"), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }
        while case let service = IOIteratorNext(iterator), service != 0 {
            let page = number("PrimaryUsagePage", service: service)
            let usage = number("PrimaryUsage", service: service)
            let size = number("MaxInputReportSize", service: service)
            if page == 0xff00, usage == 3, size == 22 {
                return service
            }
            IOObjectRelease(service)
        }
        return nil
    }

    /// Caller owns the matching driver reference. Search only below this device.
    static func accelerationDriver(for service: io_service_t) -> io_service_t? {
        var iterator: io_iterator_t = 0
        guard IORegistryEntryCreateIterator(service, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            if IOObjectConformsTo(entry, "AppleSPUHIDDriver") != 0,
               number("PrimaryUsagePage", service: entry) == 0xff00, number("PrimaryUsage", service: entry) == 3 {
                return entry
            }
            IOObjectRelease(entry)
        }
        return nil
    }

    private static func number(_ key: String, service: io_service_t) -> Int? {
        (IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber)?.intValue
    }
}
