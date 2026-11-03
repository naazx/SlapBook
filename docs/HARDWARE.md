# Hardware investigation

Investigated 2–3 November 2026 using Xcode 27.0, Swift 6.4, and the macOS 27 SDK. The host was a `Mac16,1` MacBook Pro with Apple M4 running macOS 27.0.1.

## Supported macOS interfaces

The installed `CoreMotion.framework/Headers/CMMotionManager.h` explicitly declares `CMMotionManager` `API_UNAVAILABLE(macos)` at lines 86–87. Importing Core Motion does not provide a supported Mac chassis accelerometer. Headphone motion describes the headphones, so SlapBook does not use it as evidence of a chassis tap. See [Apple's CMMotionManager documentation](https://developer.apple.com/documentation/coremotion/cmmotionmanager).

IOKit's HID functions are public, including [IOHIDDeviceOpen](https://developer.apple.com/documentation/iokit/1588670-iohiddeviceopen) and [input report callbacks](https://developer.apple.com/jp/documentation/iokit/1588666-iohiddeviceregisterinputreportca). They do not guarantee access to internal sensors or document the AppleSPU report protocol.

## Experimental sensor path

The original [apple-silicon-accelerometer research](https://github.com/olvvier/apple-silicon-accelerometer) identifies an undocumented `AppleSPUHIDDevice` accelerometer with vendor page `0xFF00`, usage `3`, and 22-byte reports. It describes signed little-endian axes at byte offsets 6, 10, and 14, scaled by 65,536. Its maintainer reports testing an M3 Pro and notes privileged access and compatibility limitations. This is not Apple-supported hardware capability documentation for the M4.

SlapBook opens the device nonexclusively and reports streaming after receiving three valid packets. It first waits 200 ms for existing reports. If there are none and the matched accelerometer driver reports an idle interval of zero, it requests an 8 ms interval and restores zero when the session closes. Other sensors and existing nonzero intervals are left alone. A report timeout or sleep closes the session. Wake retries if experimental input is still enabled. [AppleSPU driver activation reference](https://github.com/AbdullahFID/MacSlapApp/blob/main/Sources/MacSlapApp/AccelerometerReader.swift)

App Sandbox remains enabled. The app uses class exceptions for `IOHIDLibUserClient` to open the device and `AppleSPUHIDDriver` to set the interval. Activation runs under the ordinary user session without a privileged helper or Input Monitoring. [Apple's IOKit user-client exception documentation](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html)

Registry presence, device access, and live reports are separate states. The detector treats qualifying motion as a generic input with unknown location. Typing, desk bumps, and speaker vibration can also cross its sensitivity threshold. Try only gentle taps and use keyboard input if they fail to register.

## What was actually verified

The read-only diagnostic checks whether macOS exposes the device and permits opening it in the current execution context.

```sh
xcrun swift -module-cache-path /tmp/slapbook-hardware-module-cache Tools/hardware-probe.swift
```

The original restricted diagnostic and normally launched Release app found the 22-byte device but returned `kIOReturnNotPermitted` (`0xe00002e2`) when opening it. Signed, sandboxed probes then isolated the two access checks.

| Probe configuration | Observed result |
| --- | --- |
| App Sandbox alone | Opening the device returned `0xe00002e2`. |
| App Sandbox with `IOHIDLibUserClient` | Open succeeded with zero reports. macOS denied setting `ReportInterval` on the driver. |
| App Sandbox with both class exceptions | An 8 ms interval produced 133 real reports in one second. Restoring zero stopped the reports. |

A signed, sandboxed harness running SlapBook's production motion service received 237 valid samples over two seconds on `Mac16,1` (Apple M4, macOS 27.0.1). The read-only probe received zero reports after the service stopped. Physical tap recognition, left/right location, and audible tap-to-sound latency remain unverified. In an earlier GUI test, pressing the global shortcut in Finder generated a SlapBook input event.

## Reliable fallback

The app provides on-screen single/double/triple reaction buttons and a global `⌥⌘S` shortcut using `RegisterEventHotKey`. The shortcut receives only its registered combination and does not require a general keyboard monitor, Accessibility permission, or Input Monitoring. Registration failures are shown honestly; on-screen controls remain usable. Test Sound is independent of hardware. Keyboard and test events must be labeled as such and never counted as detected physical taps.
