# SlapBook Pro sound pack

The bundled pack consists of **36 original synthesized character reactions**:
six modes × single/double/triple patterns × two variants per pattern. These are
expressive formant-synthesized effects, **not recordings of human performers**.
The app should use that description wherever it introduces the stock pack.
No commercial recordings, memes, Apple system-voice output, or voice clones are
included. Secret Mode is original silliness rather than copyrighted meme audio.

`Dramatic Moans` contains non-explicit theatrical aaah and oooh vowels. Other
packs include high squeaks, chopped giggles, rising exclamations, falling sighs,
wobbles, and cartoon squawks. Double/triple inputs select independently rendered
two/three-syllable reactions. Runtime pitch (±140 cents) and rate (0.96–1.04×)
variation are optional. A shuffle bag avoids immediate repeats whenever the
candidate pool contains at least two clips.

Rebuild reproducibly from the repository root:

```sh
python3 Tools/generate_sound_pack.py
```

The generator uses only Python's standard library and a deterministic random
seed. It synthesizes a glottal oscillator, breath noise, broad vowel resonators,
pitch contours, attack/release fades, and soft saturation. Output is mono,
44.1 kHz, 16-bit PCM WAV. Each clip peaks at approximately −2.4 dBFS. No network
service or download is involved. `sound_manifest.json` lists every clip and
duration; `AUDIO_LICENSE.txt` dedicates the audio to CC0-1.0.

`AudioEngine` predecodes the stock pack to PCM, prepares and starts an
`AVAudioEngine`, then schedules buffers through an `AVAudioPlayerNode` and
`AVAudioUnitTimePitch`. Playback replaces the preceding reaction instead of
layering. This minimizes application-side loading delays; end-to-end audible
latency still depends on the output route and has not been measured. Bluetooth
headphones can add noticeable latency.

Custom audio must actually decode with AVFoundation, be nonempty, at most 25 MB,
at most 30 seconds, and have 1–8 channels. Supported common formats include WAV,
AIFF, CAF, MP3, and M4A, subject to codecs installed on macOS. Files are decoded
before acceptance and converted to the playback format. An unsupported, corrupt,
or missing clip produces a visible error; it is never silently replaced by a
placeholder. Imported sounds are local and are not uploaded.

Custom decoded PCM uses a 32 MiB least-recently-used cache, independent of the
number of imported files. Prewarming stops at that limit. Conversion reads at
most 8,192 native frames per input chunk, so a high-sample-rate multichannel
import does not allocate its entire uncompressed source. Stock PCM remains
preloaded (about 9 MiB) for immediate built-in playback.

Use the app's **Test Sound** with single, double, and triple selection to test
every reaction independently of any sensor or keyboard detection. Muting stops
the active sound immediately. The test respects mute and volume settings.
