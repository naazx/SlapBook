# Validation and continuation notes

Paused at the user's request on 2 November 2026. Source and the local app package
are saved; no commit, deployment, installation, or login-item registration was made.

## Verified

- Xcode 27.0 / Swift 6.4; native Swift 6 language mode, macOS 14 deployment target.
- Debug build and optimized Apple silicon Release build succeed on macOS 27.0.1.
- Final suite: **14 tests passed** (11 unit + 3 UI), zero failures.
- UI tests verify sound preview with detection off; importing, copying, playing and
  deleting a custom audio file; and global Option-Command-S delivery while Finder
  is the foreground app. UI tests now use disposable preferences.
- Unit tests verify gravity rejection, warm-up, sensitivity, debounce, invalid sensor
  data and sleep gaps, cooldown, persisted settings, all 36 bundled WAVs, decoding,
  corrupt/missing audio errors and shuffle behavior across refills.
- Native Release app opens and schedules a reaction with mascot animation.
- Release app Sandbox is enabled; normal build lacks Xcode's test-only exceptions.
- Physical sensor presence was observed, but opening it returned
  kIOReturnNotPermitted (0xe00002e2) both in the diagnostic and the normally launched
  Release app. No real chassis tap recognition or left/right detection is claimed.
  Experimental input was returned to off. Normal detection is enabled, volume 65%.
- Dark appearance visually inspected. Stats from normal development smoke checks
  were reset. No human recordings are bundled: all 36 clips are original CC0
  synthesized character effects, disclosed in the UI and audio documentation.
- Release code signature verified with codesign --verify --deep --strict; ZIP
  integrity verified with unzip -t.

## Artifacts

- `dist/SlapBook-Pro-macOS.zip`: 5 MB local ad hoc signed developer build, containing
  SlapBook.app. Not a notarized distribution release.
- `/tmp/SlapBookPro-release/Build/Products/Release/SlapBook.app`: unpackaged Release.
- `/tmp/slapbook-release.log`: successful final Release build log.
- `/tmp/slapbook-test.log`: successful final 14-test run.
- `/tmp/SlapBookPro-build/Logs/Test/Test-SlapBook-2026.11.02_15-10-56-+0200.xcresult`:
  final Xcode test report. Temporary paths may eventually be cleaned by macOS.

## Continue here

1. Finish native menu bar popover/close-window/reopen smoke checks. MenuBarExtra
   is implemented and compiles; this interaction has not yet been manually verified.
2. Visually inspect light appearance and any desired final UI adjustments.
3. Listen to the synthesized voices on the intended speakers/headphones; playback
   scheduling is verified, but audible latency and subjective audio quality are not
   measured. Import original human performances if human-recorded voices are wanted.
4. Test Launch at Login only after installing a signed build in Applications.
   Actual registration/status/error handling is implemented but registration was
   deliberately not enabled during development. Check real sleep/wake behavior.
5. Further physical motion testing needs accessible sensor reports. Do not suggest
   striking harder or promise that sensor access will become available.

The README contains exact Xcode and command-line run instructions. There are no
third-party dependencies. No extra GUI windows or services need to remain running.
