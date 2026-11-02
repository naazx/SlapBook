#!/usr/bin/env python3
"""Rebuild SlapBook's original synthesized character voices (Python stdlib only).

These are intentionally absurd formant-synthesized voices, NOT human recordings,
licensed samples, or imitations of an identifiable person. No speech service,
system voice, training data, network, or third-party asset is used.
"""

import json
import math
from pathlib import Path
import random
import struct
import wave

RATE = 44100
ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "SlapBook" / "Audio" / "Resources"

PACKS = {
    "shy": ("Tiny squeak", "Awkward giggle", 285, 0.38),
    "anime": ("Dramatic aaah", "Heroic gasp", 235, 0.70),
    "drama": ("Theatrical sigh", "Absolutely scandalous", 145, 1.15),
    "chaos": ("Cartoon wobble", "Ridiculous squawk", 195, 0.80),
    "secret": ("Forbidden ooo", "Tiny existential crisis", 105, 0.95),
    "dramaticMoans": ("Grand aaah", "Operatic oooh", 175, 1.45),
}


class Resonator:
    def __init__(self, frequency, bandwidth):
        radius = math.exp(-math.pi * bandwidth / RATE)
        self.a = 2 * radius * math.cos(2 * math.pi * frequency / RATE)
        self.b = -(radius * radius)
        self.gain = 1 - radius
        self.y1 = self.y2 = 0.0

    def sample(self, value):
        result = self.gain * value + self.a * self.y1 + self.b * self.y2
        self.y2, self.y1 = self.y1, result
        return result


def syllable(duration, pitch, vowel, style, seed, variant):
    rng = random.Random(seed)
    count = round(duration * RATE)
    # Broad, recognizable vowels, not a reconstruction of a particular speaker.
    frequencies = {"ah": (760, 1180, 2700), "oh": (480, 880, 2500),
                   "ee": (340, 2100, 3000)}[vowel]
    filters = [Resonator(f, b) for f, b in zip(frequencies, (95, 130, 180))]
    phase = 0.0
    output = []
    previous = 0.0
    for index in range(count):
        t = index / RATE
        u = index / max(count - 1, 1)
        wobble = 1 + 0.035 * math.sin(2 * math.pi * 5.3 * t)
        contour = 1.0 + 0.38 * math.sin(math.pi * u) - 0.27 * u
        if style == "shy":
            contour = 1.12 - 0.24 * u
        elif style == "anime":
            contour = 0.85 + 0.50 * math.sin(math.pi * u * 0.85)
        elif style == "chaos":
            contour = 1 + 0.25 * math.sin(2 * math.pi * 4 * t) + 0.12 * math.sin(2 * math.pi * 9 * t)
        elif style == "secret":
            contour = 0.9 + 0.3 * math.sin(2 * math.pi * 2.5 * t)
        phase = (phase + pitch * contour * wobble / RATE) % 1.0
        # A soft, asymmetric glottal source gives the vowel its voiced character.
        glottal = math.sin(2 * math.pi * phase) + 0.48 * math.sin(4 * math.pi * phase)
        glottal += 0.19 * math.sin(6 * math.pi * phase) + 0.10 * math.sin(8 * math.pi * phase)
        # A quiet broadband buzz excites upper vowel resonances. The resonators
        # and output smoothing keep its bright edge softer than a raw saw wave.
        glottal += 0.22 * (2 * phase - 1)
        aspiration = rng.uniform(-1, 1)
        breath = 0.075 + 0.25 * math.exp(-u * 18) + 0.15 * u * u
        source = glottal * 0.68 + aspiration * breath
        resonant = sum(f.sample(source) * weight for f, weight in zip(filters, (1.0, 0.65, 0.3)))
        voiced = resonant * 3.0 + glottal * 0.09
        attack = min(1, t / (0.032 if style != "anime" else 0.014))
        release = min(1, (duration - t) / 0.11)
        envelope = math.sin(attack * math.pi / 2) ** 2 * math.sin(max(0, release) * math.pi / 2) ** 2
        envelope *= (1 - 0.32 * u)
        if style == "shy" and variant == 1:
            envelope *= 0.28 + 0.72 * (0.5 + 0.5 * math.sin(2 * math.pi * 7.5 * t)) ** 2
        # Gentle low-pass + saturation, then peak normalization at clip level.
        previous += 0.65 * (voiced - previous)
        output.append(math.tanh(previous * 1.2) * envelope)
    return output


def render(mode, tap_count, variant, pitch, duration, seed):
    rng = random.Random(seed)
    count = tap_count
    segments = []
    for n in range(count):
        vowel = ("oh" if variant else "ah")
        if mode == "shy":
            vowel = "ee" if not variant else "ah"
        segment_duration = duration / (1 + 0.25 * (count - 1))
        samples = syllable(segment_duration, pitch * (1 + n * 0.10) * rng.uniform(0.96, 1.04),
                           vowel, mode, seed + n * 101, variant)
        segments.extend(samples)
        if n < count - 1:
            segments.extend([0.0] * round(RATE * (0.075 if mode != "drama" else 0.12)))
    peak = max(abs(s) for s in segments) or 1.0
    return [s * (0.76 / peak) for s in segments]


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    entries = []
    for mode_index, (mode, (first, second, pitch, duration)) in enumerate(PACKS.items()):
        for tap_count in (1, 2, 3):
            for variant, title in enumerate((first, second)):
                stem = f"sb_{mode}_{tap_count}_{variant + 1}"
                samples = render(mode, tap_count, variant, pitch, duration,
                                 1801 + mode_index * 1000 + tap_count * 10 + variant)
                pcm = b"".join(struct.pack("<h", round(max(-1, min(1, s)) * 32767)) for s in samples)
                with wave.open(str(DEST / f"{stem}.wav"), "wb") as handle:
                    handle.setnchannels(1)
                    handle.setsampwidth(2)
                    handle.setframerate(RATE)
                    handle.writeframes(pcm)
                entries.append({"id": stem, "mode": mode, "tapCount": tap_count,
                                "title": title, "file": f"{stem}.wav",
                                "duration": round(len(samples) / RATE, 3)})
    manifest = {"version": 1, "provenance": "Original formant-synthesized character voices; not human recordings.",
                "license": "CC0-1.0", "sampleRate": RATE, "clips": entries}
    (DEST / "sound_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Created {len(entries)} original synthesized vocal reactions in {DEST}")


if __name__ == "__main__":
    main()
