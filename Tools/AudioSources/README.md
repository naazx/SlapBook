# Human vocal source recordings

These five files are the public HQ MP3 previews of sounds explicitly released
under **CC0 1.0** on their primary Freesound pages, verified 2 November 2026.
They are not original WAV master downloads. The original authors are credited
in `sources.json`, the bundled `AUDIO_LICENSE.txt`, and the app's Sound Credits.

The exact preview URLs were observed in each sound page's public embedded player.
No login, API key, or authentication bypass was used. `sources.json` records the
source page, author, license URL, preview URL, size and SHA-256 of every file.

`Tools/human_reactions.py` verifies the hashes, decodes with macOS `afconvert`,
trims dead air, adds fades, normalizes, and arranges the performances into six
non-explicit reaction patterns. This source directory is not bundled in the app;
the app contains only the resulting PCM reactions and their credit manifest.

Rebuild all sounds offline on macOS:

```sh
python3 Tools/generate_sound_pack.py
```
