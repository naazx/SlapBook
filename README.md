# SlapBook Pro

**Your Mac has feelings. Unfortunately.**

A native Swift 6 / SwiftUI macOS menu bar app with an animated laptop mascot,
AVFoundation reaction playback, a global shortcut, and honest hardware diagnostics.
No third-party dependencies, network service, microphone capture, or administrator helper.

## Run in Xcode

1. Open `SlapBook.xcodeproj` in **Xcode 27 or later** (the project was created by Xcode 27).
2. Select the **SlapBook** scheme and **My Mac** destination.
3. Under **Signing & Capabilities**, select your development team, or choose
   **Sign to Run Locally** for local development. The bundle identifier is
   `com.nazardydyn.SlapBook`; change it for distribution if needed.
4. Press **⌘R**. The Playground window opens and a laptop icon appears in the menu bar.
5. Click **Test Sound**. This works with detection off and bypasses its cooldown.
   Single / Double / Triple buttons audition the separately authored reactions.
   Sound testing respects mute and volume. Use Settings → Stop Playback to stop a clip.
6. Close the window to keep the menu bar app running. Use **Open SlapBook…** in the
   menu bar, or open the app again from Finder or Spotlight, to bring it back, and
   **Quit** to exit. The app intentionally has no Dock icon. To start quietly in the
   menu bar (for example at login), turn off **Open this window when SlapBook starts**
   in Settings & About.

The deployment target is **macOS 14**. Runtime verification is performed on the
available macOS 27.0.1 host; older OS versions have not been tested. Swift language
mode is 6. The Xcode 27 SDK-specific audio methods have availability-gated fallbacks.

Command-line build and tests (local signing):

```sh
xcodebuild -project SlapBook.xcodeproj -scheme SlapBook \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/SlapBookPro-build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build

xcodebuild -project SlapBook.xcodeproj -scheme SlapBook \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/SlapBookPro-build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= test
```

The temporary build path avoids Finder/file-provider attributes on Desktop that can
cause codesign to reject a bundle. Xcode’s normal default DerivedData path is also
suitable. If a bundle fails signing with “resource fork, Finder information, or
similar detritus,” clean the build folder or move DerivedData off Desktop.

The shared SlapBook scheme runs unit tests only, including when you press **⌘U**.
The UI test target is excluded from the default test action. The application
itself needs no Accessibility or Input Monitoring permission for its shortcut.

## Input and hardware compatibility

**The default input is an explicitly labeled keyboard/button alternative.**
Press **⌥⌘S** anywhere when detection and the shortcut are enabled, or use
**Send an input** in the Playground. Registration failures (such as a conflicting
shortcut) are shown in Detection. The fixed combination uses `RegisterEventHotKey`,
so it does not record general keystrokes. Test Sound always remains independent.

On the available host, model `Mac16,1`, the registry exposes an SPU accelerometer
with vendor page `0xFF00`, usage `3`, and 22-byte input reports. The diagnostic
attempt to open it returned **`kIOReturnNotPermitted` (`0xe00002e2`)** in the restricted
execution context. **No actual chassis taps or left/right locations were verified.**
The normally launched, sandboxed Release app also returned that access-denied
status when its experimental option was tested.

`CMMotionManager` is unavailable on native macOS in the installed SDK. Experimental
AppleSPU reading uses public IOKit HID calls but an **undocumented device protocol**;
it is not a supported Apple motion API. It is disabled by default. If you explicitly
enable it, the app only reports streaming after receiving plausible real packets.
Denied access, missing devices, or a 3-second report timeout leave the supported
input alternative available. No fabricated samples, private frameworks, root
processes, or permission bypasses are used. App Sandbox stays enabled.

If a device permits streaming, the generic detector uses a gravity-removing filter,
a sensitivity threshold, hysteresis, a warm-up period, and 120 ms mechanical debounce.
It cannot reliably distinguish typing, desk movement, or sound-induced vibration
from intentional taps. Its thresholds have algorithmic tests, **not physical M4
calibration**. Left/right statistics are omitted because location is not established.
Use only gentle taps; never increase force to get a response.

Detection off disables automatic input reactions; sound previews remain available.
Cooldown is adjustable from 0.2–3 seconds. Optional rhythm grouping waits 250 ms after
the latest input (or fires on the third) to select a double/triple reaction, trading
some responsiveness for pattern recognition. Default single reactions are immediate
at the application layer; audible end-to-end latency has not been measured.
Input counts include shortcut and on-screen events, including events suppressed by
cooldown or mute. Sound previews increase reactions played, not inputs received.

See [the hardware investigation](docs/HARDWARE.md) for sources and the reproducible
read-only diagnostic (`swift Tools/hardware-probe.swift`).

## Sounds and custom packs

Six built-in personalities contain **36 reaction clips**:
Shy, Anime, Drama Queen, Chaos, Dramatic Moans, and unlockable Secret Mode. Secret
Mode is unlocked by clicking its card in Sound Library. **Dramatic Moans contains
six edits of real CC0 human recordings**: a long ah, a surprised oh, gasps and a
sigh, arranged for single/double/triple inputs. The other 30 reactions are original
synthesized vowel, giggle, squeak and cartoon effects. No licensed meme clips or
celebrity voices are bundled. Each mode includes
single, double and triple variants, a shuffle bag, optional pitch/rate variation,
volume, and immediate mute. All clips are predecoded to PCM for responsive playback.

All bundled audio is **CC0-1.0**. The five human source recordings, exact public
preview URLs, authors, licenses and hashes are committed alongside the generator
and clip manifest. Sound Credits in Settings lists the performers and links to
their primary source pages. The human sources are compressed HQ MP3 previews,
not original WAV masters. Regeneration uses Python’s standard library and macOS
`afconvert`; the installed decoder may affect exact output samples. There
are no remote asset dependencies and no silent substitutions if an asset is missing.
See [audio provenance and implementation](docs/AUDIO.md). Regenerate with:

```sh
python3 Tools/generate_sound_pack.py
```

To use real human performances or other audio you have rights to use:

1. In **Sound Library**, enter a pack name and choose **Import Sounds…**.
2. Select WAV, AIFF, CAF, M4A, MP3 or another AVFoundation-decodable file.
   Each file must be nonempty, no longer than 30 seconds, and no larger than 25 MB.
   Up to 100 files are stored. Corrupt/unsupported files produce visible errors.
3. Imported files are copied into the app's Application Support directory; moving
   the source file afterward is safe. No persistent external file permissions are needed.
4. Select the active pack (remembered across launches), choose **Use Custom Mode**
   (offered only while the library has sounds; removing the last one switches back
   to Dramatic Moans), and optionally assign each
   file to Single, Double, Triple, or Any rhythm. A gesture without matching clips
   produces an error instead of playing an unrelated fallback.
5. Use the test buttons to audition. The trash button removes that imported copy.

Settings, unlock state, counters and library metadata use UserDefaults. Audio is
stored locally under `Application Support/SlapBookPro/CustomSounds` inside the app's
sandbox container. Imports are never uploaded. Launch at Login uses `SMAppService`;
install a signed build in `/Applications` before enabling it. macOS may require
approval in System Settings → General → Login Items. Pending registration remains
cancelable, and a review button opens the relevant settings. Status refreshes when
the app becomes active. Registration failures are shown explicitly.

## Architecture and verification

- `Models/SettingsStore.swift`: persisted preferences, change notifications.
- `Models/AppModel.swift`: main-actor MVVM coordination, rhythm grouping, library,
  cooldown, lifecycle and login item status.
- `Models/TapProcessing.swift`: deterministic motion filter and reaction gate.
- `Services/`: read-only hardware inventory, experimental sensor, global shortcut.
- `Audio/AudioEngine.swift`: AVAudioEngine, decoded buffers, variation and shuffle.
- `ContentView.swift` and `Views/`: native settings pages, mascot and menu popover.

Unit tests cover detector warm-up, gravity rejection, debounce, sensitivity,
invalid data, sleep gaps, cooldown, settings persistence, audio integrity and imports.
Lifecycle and login-item tests use isolated services and notification centers.
They do not sleep the computer or change real Login Items. Build/test results
and remaining manual checks are recorded in [docs/VALIDATION.md](docs/VALIDATION.md).
The default test scheme excludes UI automation.

A locally signed universal (Apple silicon and Intel) build is packaged in
`dist/SlapBook-Pro-macOS.zip`. Unzip it and open `SlapBook.app` to try the app
immediately. This is a local developer build, not a notarized distribution release.

## Release builds

`Tools/release.sh` rebuilds that zip: a universal Release app, built off Desktop,
with its signature and App Sandbox verified. Without arguments it signs ad hoc,
so the result opens only on this Mac. To distribute to other Macs you need a paid
Apple Developer account and a **Developer ID Application** certificate:

```sh
xcrun notarytool store-credentials slapbook
DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=slapbook Tools/release.sh
```

The first command stores notarization credentials in your keychain once. The second
signs with a secure timestamp, submits to Apple's notary service, staples the ticket
and checks Gatekeeper before repackaging the zip.
