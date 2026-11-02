"""Edit the committed CC0 human recordings into non-explicit reaction patterns."""

from array import array
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import wave


def recorded_reactions(rate, source_directory):
    records = json.loads((source_directory / "sources.json").read_text())["sources"]
    decoded = {}
    ids = {}
    with tempfile.TemporaryDirectory(prefix="slapbook-voices-") as temporary:
        for record in records:
            source = source_directory / record["file"]
            if hashlib.sha256(source.read_bytes()).hexdigest() != record["sha256"]:
                raise ValueError(f"Source hash mismatch: {source}")
            destination = Path(temporary) / (source.stem + ".wav")
            subprocess.run(["/usr/bin/afconvert", "-f", "WAVE", "-d", f"LEI16@{rate}",
                            "-c", "1", "--mix", str(source), str(destination)], check=True)
            with wave.open(str(destination), "rb") as handle:
                assert handle.getnchannels() == 1 and handle.getsampwidth() == 2
                assert handle.getframerate() == rate
                pcm = array("h", handle.readframes(handle.getnframes()))
            if sys.byteorder != "little":
                pcm.byteswap()
            samples = [value / 32768 for value in pcm]
            peak = max(map(abs, samples), default=0)
            if peak < 0.001:
                raise ValueError(f"Source is silent: {source}")
            # Remove dead air while preserving breath and the natural attack.
            audible = [n for n, value in enumerate(samples) if abs(value) > peak * 0.015]
            margin = round(rate * 0.025)
            samples = samples[max(0, audible[0] - margin):min(len(samples), audible[-1] + margin + 1)]
            mean = sum(samples) / len(samples)
            samples = [value - mean for value in samples]
            fade = min(round(rate * 0.01), len(samples) // 2)
            for n in range(fade):
                gain = n / fade
                samples[n] *= gain
                samples[-n - 1] *= gain
            decoded[source.stem] = samples
            ids[source.stem] = record["id"]

    patterns = {
        (1, 0): ("Theatrical ah", ["ah"]),
        (1, 1): ("Surprised oh", ["oh"]),
        (2, 0): ("Gasp, then aaah", ["gasp", "ah"]),
        (2, 1): ("Oh, the drama", ["oh", "sigh"]),
        (3, 0): ("Triple dramatic protest", ["hoh", "oh", "ah"]),
        (3, 1): ("Three stages of disbelief", ["gasp", "sigh", "hoh"]),
    }
    output = {}
    for key, (title, names) in patterns.items():
        samples = []
        for name in names:
            if samples:
                samples.extend([0.0] * round(rate * 0.11))
            samples.extend(decoded[name])
        peak = max(map(abs, samples))
        samples = [value * 0.76 / peak for value in samples]
        output[key] = (title, samples, [ids[name] for name in names])
    return output, records
