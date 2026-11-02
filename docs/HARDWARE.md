# Hardware investigation

Investigated 2 November 2026 using Xcode 27.0, Swift 6.4, and the installed macOS 27 SDK. The diagnostic host reports `Mac16,1` in the I/O registry.

## Supported macOS interfaces

The installed `CoreMotion.framework/Headers/CMMotionManager.h` explicitly declares `CMMotionManager` `API_UNAVAILABLE(macos)` at lines 86–87. Importing Core Motion does not provide a supported Mac chassis accelerometer. Headphone motion describes the headphones, so SlapBook does not use it as evidence of a chassis tap. See [Apple's CMMotionManager documentation](https://developer.apple.com/documentation/coremotion/cmmotionmanager).

IOKit's HID functions are public, including [IOHIDDeviceOpen](https://developer.apple.com/documentation/iokit/1588670-iohiddeviceopen) and [input report callbacks](https://developer.apple.com/jp/documentation/iokit/1588666-iohiddeviceregisterinputreportca). They do not guarantee access to internal sensors or document the AppleSPU report protocol.

## Experimental sensor path

The original [apple-silicon-accelerometer research](https://github.com/olvvier/apple-silicon-accelerometer) identifies an undocumented `AppleSPUHIDDevice` accelerometer with vendor page `0xFF00`, usage `3`, and 22-byte reports. It describes signed little-endian axes at byte offsets 6, 10, and 14, scaled by 65,536. Its maintainer reports testing an M3 Pro and notes privileged access and compatibility limitations. This is not Apple-supported hardware capability documentation for the M4.

SlapBook implements an independently written, explicitly opt-in reader for that layout, using public IOKit functions. It opens nonexclusively, validates packet length and plausible finite acceleration, and reports streaming only after actual valid reports. It makes no sensor writes, installs no privileged helper, requests no administrator access, and stops after three seconds without valid data. Sleep closes the session; wake retries only if the user still requested experimental input.

Registry presence is reported separately from access. An entry alone never enables the tap indicator. This version cannot establish left/right palm-rest location from a single accelerometer, so it provides generic input and no location statistics. Motion, typing, desk bumps, and speaker vibration may be indistinguishable from a tap. Sensitivity and debounce reduce noise; they cannot guarantee classification. Try only gentle touches; use keyboard input if these do not register.

## What was actually verified

Run the read-only diagnostic from the repository root:

```sh
xcrun swift -module-cache-path /tmp/slapbook-hardware-module-cache Tools/hardware-probe.swift
```

Observed in the agent's restricted execution context:

```text
Registry query: 0
Accelerometer registry entry found; report bytes: 22
Nonexclusive IOHIDDeviceOpen: 0xe00002e2
Matching registry entries: 1
```

The installed `IOReturn.h` identifies `0xe00002e2` as `kIOReturnNotPermitted`. **No real accelerometer samples or physical tap recognition were verified.** The access restriction may differ for a normally launched, signed application, so the application checks its own result instead of predicting access from the machine name.

The three hardware service source files compiled together in Swift 6 mode. A native command-line smoke check exercised the same app services: the experimental reader surfaced the denied access and stayed non-streaming. Shortcut handler installation succeeded, but global hotkey registration returned `eventInternalErr` (`-9868`) in that restricted command-line context. This is not evidence that the shortcut will register in every GUI session; the application exposes its actual registration result.

The signed native app was subsequently tested in the graphical session. Its global shortcut registered successfully, and an XCUITest activated Finder, pressed `⌥⌘S` there, reactivated SlapBook, and verified the actual global-shortcut input event. This passed. The restricted command-line hotkey result therefore does not describe the normal GUI app's behavior.

The optimized Release app was also launched normally, without Xcode's test-only entitlement exceptions. Enabling Detection and then Experimental chassis motion in its UI produced the same `0xe00002e2` access-denied status. The shortcut status in that app was ready. Experimental sensing was returned to off afterward. Thus sensor access was denied in both the restricted diagnostic and the actual sandboxed GUI application on this host.

## Reliable fallback

The app provides on-screen single/double/triple reaction buttons and a global `⌥⌘S` shortcut using `RegisterEventHotKey`. The shortcut receives only its registered combination and does not require a general keyboard monitor, Accessibility permission, or Input Monitoring. Registration failures are shown honestly; on-screen controls remain usable. Test Sound is independent of hardware. Keyboard and test events must be labeled as such and never counted as detected physical taps.
