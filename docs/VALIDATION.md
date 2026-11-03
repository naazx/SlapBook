# Validation and handoff

Updated 3 November 2026. Earlier work merged through PRs #1 and #2; the completion
pass below is on `codex/post-merge-polish`. No installation, login-item
registration, or distribution deployment was performed.

## Chassis motion follow-up

- A signed, sandboxed harness running the production motion service received 237
  valid samples over two seconds on MacBook Pro M4 (`Mac16,1`, macOS 27.0.1).
  The read-only probe received zero reports after the service stopped.
- The shared Xcode scheme passed all 21 unit tests, including the regression test
  for automatic input during playback.
- A physical tap-to-sound check and sensitivity calibration still require manual
  testing. See [the hardware investigation](HARDWARE.md) for the permission checks.

## Post-merge polish build

- Xcode 27.0 / Swift 6.4, Swift 6 language mode, macOS 14 deployment target.
- Debug test build and optimized Apple silicon Release build succeed on macOS 27.0.1.
- **20 unit tests passed**, zero failures. The shared SlapBook scheme runs only
  SlapBookTests, including through ⌘U. UI automation is excluded at the user's request.
- Tests cover gravity rejection, warm-up, sensitivity, debounce, invalid data,
  sleep gaps, cooldown, settings persistence, all 36 bundled WAVs, format conversion,
  corrupt/missing audio errors, shuffle behavior, and human-recording provenance.
- Isolated lifecycle tests verify canceling pending groups on sleep, suspending
  audio/inputs, blocking input while asleep, resetting cooldown/debounce, one input
  restart on wake, and no restart after shutdown. The computer was not put to sleep.
- Login-service fakes verify pending approval can be canceled, duplicate registration
  is avoided, activation refreshes status, and failures are visible. Real Login Items
  were not changed. Approval status is distinct from actually running at login.
- Custom pack selection restores across launches and prewarms only its selected
  sounds in the bounded cache. Unrelated slider changes do not re-decode audio.
- Audio output format is checked before graph setup/restart; unavailable output
  produces an error. Physical device removal and output-route changes were not tested.
- Release code signature passes `codesign --verify --deep --strict`; ZIP integrity
  passes `unzip -t`. The app remains sandboxed.

## Sounds

The app bundles 30 original synthesized character reactions and **six CC0 human
vocal edits** in Dramatic Moans. Its long ah, short oh, gasps and sigh are arranged
into single/double/triple reactions. Five public Freesound HQ MP3 previews were
verified against their primary CC0 pages and committed with author credits, source
URLs and SHA-256 hashes. These are compressed preview sources, not WAV masters.

`Tools/generate_sound_pack.py` rebuilt the pack offline using the committed sources,
Python's standard library and macOS afconvert. Tests decode every resulting WAV,
check 44.1 kHz mono PCM, peak levels and click-prevention fades, and verify the six
recorded reactions have complete source metadata. Sound Credits is available in
Settings. Audible latency and subjective quality have not been measured/listened
through a monitoring system during this pass; Test Sound remains available.

## Hardware and UI limits

The host's SPU accelerometer entry was observed, but opening it returned
`kIOReturnNotPermitted` (`0xe00002e2`) in both a read-only diagnostic and a normally
launched Release GUI build. No real chassis tap recognition or left/right location
is claimed. The explicitly labeled keyboard/button alternative remains the intended
working input. See HARDWARE.md for the investigation and exact protocol caveats.

The initial version previously passed three UI tests (preview with detection off,
custom import/playback, and a shortcut from Finder). During this polish pass,
experimental UI checks encountered automation focus/selector issues and are not
used as current behavioral evidence. Further UI tests were stopped at the user's
request; their new uncommitted changes were removed and the legacy target is excluded
from the shared scheme. Menu-bar close/reopen, light appearance and real sleep/wake
integration remain manual verification items. No actual login/logout cycle was run.

## Light and dark rendering pass

A temporary unit test rendered the Playground, Sound Library, Detection and
Settings pages, the menu bar popover and Sound Credits offscreen in both Aqua
and Dark Aqua (not committed). Two layout defects were found and fixed:
Sound Credits truncated its two paragraphs with an ellipsis, and the selected
"Settings & About" sidebar item wrapped onto two lines. All other surfaces kept
readable contrast in both appearances. This is offscreen rendering, not a live
window or menu-bar interaction; close/reopen and real sleep/wake stay manual.

A launched Debug build ran as a UIElement (no Dock icon), settled at 0% CPU and
about 100 MB resident, and logged no SlapBook errors; only system App Intents
registration noise appeared. Route changes were reviewed in code, not with
hardware: every reaction calls `prepare()`, which rechecks the output format and
restarts a stopped engine, so a device switch is picked up on the next reaction.

## Completion pass (3 November 2026)

- Custom mode is offered only while imported sounds exist. Removing the last
  sound, or restoring a saved Custom mode with an empty library, falls back to
  Dramatic Moans instead of answering every input with an error. Unit tested.
- The window no longer has to open at every launch: "Open this window when
  SlapBook starts" (default on) lets it start in the menu bar only. Opening the
  app again from Finder or Spotlight now shows the window; previously, with no
  Dock icon, nothing visible happened once the window was closed. Verified on
  the launched app by counting its on-screen windows: one at a default launch,
  none with the setting off, one after reopening. The macOS 14 fallback (closing
  the window after launch) compiles but was not run on macOS 14.
- `Tools/release.sh` builds a universal arm64/x86_64 Release app and packages
  the zip. The ad hoc path was run end to end and the unzipped app launched.
  The Developer ID and notarization path was only syntax- and argument-checked:
  this Mac has no Developer ID certificate.
- The copyright string no longer claims all audio is synthesized, and the app
  declares the Entertainment category.
- 20 unit tests pass.

## Focused implementation commits

- `69a418d` — unavailable audio outputs and prepared-engine suspension.
- `e49247a` — centralized sleep/wake and shutdown handling.
- `60b612c` — pending launch-at-login approval and status refresh.
- `25e1665` — remembered/prewarmed custom packs and reserved-name validation.
- `4f8f916` — unit-only shared Xcode scheme.
- `7c9c72c` — accessible muted menu bar symbol.
- `b99ca8c` — credited human vocal reactions, generator, sources and provenance tests.

## Saved artifacts

- `dist/SlapBook-Pro-macOS.zip`: universal ad hoc signed developer build from
  `Tools/release.sh`, containing SlapBook.app. Not a notarized distribution release.
- `/tmp/SlapBookPro-release/Build/Products/Release/SlapBook.app`: Release app.
- `/tmp/slapbook-final-release.log`: final successful Release build log.
- `/tmp/slapbook-human-test.log`: final 19-unit-test run, no UI automation.
- `/tmp/SlapBookPro-build/Logs/Test/Test-SlapBook-2026.11.02_21-57-51-+0200.xcresult`:
  final unit-test report. Temporary paths may eventually be cleaned by macOS.

Use the README for exact Xcode/run/build instructions. No background build or test
process needs to remain running. Real Launch at Login verification requires an
installed signed build and the user's macOS approval when requested by the OS.
