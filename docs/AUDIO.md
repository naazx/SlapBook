# SlapBook Pro sound pack

The bundled pack has **36 reactions**: 30 original synthesized character effects
and **six edited CC0 human recordings** in Dramatic Moans. Every mode has
single/double/triple patterns and two variants per pattern. The app labels the
recorded and synthesized modes explicitly and provides a Sound Credits sheet.
No celebrity clones, Apple system speech output, commercial film clips, or
unlicensed meme recordings are included.

Dramatic Moans includes a long theatrical ah, a short surprised oh, two gasps,
and a sigh. Double/triple inputs select montages with two/three recorded reactions.
Runtime pitch (±140 cents) and rate (0.96–1.04×) variation remain optional. A shuffle
bag avoids immediate repeats when the candidate pool has at least two clips.

| Human source | Author | License |
| --- | --- | --- |
| [Ah! sound female](https://freesound.org/people/marythewitch/sounds/536839/) | marythewitch | CC0 1.0 |
| [Short Oh!](https://freesound.org/people/Airlane1979/sounds/798372/) | Airlane1979 | CC0 1.0 |
| [gasp.wav](https://freesound.org/people/iokera/sounds/414213/) | iokera | CC0 1.0 |
| [gasp HOH!.wav](https://freesound.org/people/Reitanna/sounds/242606/) | Reitanna | CC0 1.0 |
| [sigh](https://freesound.org/people/wjtaylor/sounds/265249/) | wjtaylor | CC0 1.0 |

The committed source files are the public HQ MP3 previews embedded on those
primary pages. These are compressed previews, not the original WAV masters;
resampling them to PCM does not restore information lost to compression. Exact
URLs, author names, licenses, byte sizes and SHA-256 hashes are recorded in
`Tools/AudioSources/sources.json` and the bundled sound manifest. All five source
pages and public preview links were verified on 2 November 2026. No authentication,
API key, or login bypass was used. CC0 permits these edits and redistribution.

Rebuild offline on macOS from the repository root:

```sh
python3 Tools/generate_sound_pack.py
```

The standard-library Python generator uses a fixed random seed for the 30
synthesized effects. It uses macOS `afconvert` to decode the committed MP3s, then
trims silence, adds short fades, normalizes and arranges the human performances.
The installed system decoder can affect exact decoded samples. Output is mono,
44.1 kHz, 16-bit PCM WAV, peaking around −2.4 dBFS. Source hashes are checked before
rendering; missing or altered sources fail explicitly. No network access is needed
to rebuild. `AUDIO_LICENSE.txt` contains the credits and CC0 dedication, while each
manifest clip identifies whether it is synthesized or recorded and lists its sources.

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
preloaded for responsive built-in playback.

When sleeping, playback stops and the prepared engine pauses. The next reaction
restarts it. An unavailable hardware output produces an explicit error.

Use the app's **Test Sound** with single, double, and triple selection to test
every reaction independently of any sensor or keyboard detection. Muting stops
the active sound immediately. The test respects mute and volume settings.
