"""Generate the original procedural gameplay sounds shipped with the resource."""

from __future__ import annotations

import argparse
import math
import random
import struct
import subprocess
import tempfile
import wave
from pathlib import Path

RATE = 48_000
RNG = random.Random(0x5F504A)


def envelope(index: int, length: int, attack: float = 0.04, release: float = 0.12) -> float:
    at = max(1, int(length * attack))
    rt = max(1, int(length * release))
    return min(1.0, index / at, (length - index - 1) / rt)


def noise(length: int) -> list[float]:
    return [RNG.uniform(-1.0, 1.0) for _ in range(length)]


def lowpass(values: list[float], amount: float) -> list[float]:
    output, state = [], 0.0
    for value in values:
        state += (value - state) * amount
        output.append(state)
    return output


def add_impact(values: list[float], at_seconds: float, strength: float, decay: float, tone: float = 110.0) -> None:
    start = int(at_seconds * RATE)
    length = int(decay * RATE)
    for offset in range(max(0, min(length, len(values) - start))):
        phase = offset / RATE
        falloff = math.exp(-7.0 * phase / max(decay, 0.001))
        values[start + offset] += strength * falloff * (math.sin(2 * math.pi * tone * phase) + RNG.uniform(-0.4, 0.4))


def soil_scrape(seconds: float) -> list[float]:
    length = int(seconds * RATE)
    rough = lowpass(noise(length), 0.075)
    values = [rough[i] * (0.55 + 0.25 * math.sin(2 * math.pi * 2.2 * i / RATE)) * envelope(i, length) for i in range(length)]
    add_impact(values, 0.46, 0.45, 0.13, 92.0)
    add_impact(values, 1.28, 0.34, 0.11, 108.0)
    return values


def water_pour(seconds: float) -> list[float]:
    length = int(seconds * RATE)
    fine = noise(length)
    smooth = lowpass(fine, 0.18)
    values = []
    for i in range(length):
        flow = 0.68 + 0.12 * math.sin(2 * math.pi * 3.1 * i / RATE)
        bubble = 0.05 * math.sin(2 * math.pi * (155 + 18 * math.sin(i / RATE * 1.7)) * i / RATE)
        values.append((smooth[i] * flow + bubble) * envelope(i, length, 0.10, 0.15))
    return values


def granules(seconds: float) -> list[float]:
    length = int(seconds * RATE)
    values = [0.0] * length
    for _ in range(92):
        at = RNG.uniform(0.08, seconds - 0.12)
        add_impact(values, at, RNG.uniform(0.035, 0.11), RNG.uniform(0.012, 0.035), RNG.uniform(900, 2600))
    bed = lowpass(noise(length), 0.12)
    return [(values[i] + bed[i] * 0.10) * envelope(i, length, 0.05, 0.18) for i in range(length)]


def spray(seconds: float) -> list[float]:
    length = int(seconds * RATE)
    hiss = lowpass(noise(length), 0.32)
    values = []
    for i in range(length):
        t = i / RATE
        pulse = 0.48 + 0.32 * max(0.0, math.sin(2 * math.pi * 4.0 * t))
        values.append(hiss[i] * pulse * envelope(i, length, 0.07, 0.12))
    add_impact(values, 0.04, 0.22, 0.06, 180.0)
    return values


def crop_pick(seconds: float) -> list[float]:
    length = int(seconds * RATE)
    rustle = lowpass(noise(length), 0.10)
    values = [rustle[i] * (0.22 + 0.18 * math.sin(2 * math.pi * 6.0 * i / RATE)) * envelope(i, length) for i in range(length)]
    add_impact(values, 0.56, 0.48, 0.055, 410.0)
    add_impact(values, 0.74, 0.20, 0.09, 125.0)
    return values


def normalize(values: list[float], peak: float = 0.82) -> list[float]:
    maximum = max(abs(value) for value in values) or 1.0
    scale = peak / maximum
    return [max(-1.0, min(1.0, value * scale)) for value in values]


def write_wav(path: Path, values: list[float]) -> None:
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(b"".join(struct.pack("<h", int(value * 32767)) for value in normalize(values)))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ffmpeg", required=True, type=Path)
    parser.add_argument("--output", default=Path(__file__).parents[1] / "nui-shell" / "audio", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    sounds = {
        "soil_scrape": soil_scrape(2.2),
        "water_pour": water_pour(1.9),
        "granules": granules(1.5),
        "spray": spray(1.6),
        "crop_pick": crop_pick(1.25),
    }
    with tempfile.TemporaryDirectory(prefix="sfpj-audio-") as directory:
        temp = Path(directory)
        for name, values in sounds.items():
            source = temp / f"{name}.wav"
            target = args.output / f"{name}.ogg"
            write_wav(source, values)
            subprocess.run([
                str(args.ffmpeg), "-hide_banner", "-loglevel", "error", "-y", "-i", str(source),
                "-af", "acompressor=threshold=0.02:ratio=8:attack=2:release=80:makeup=12,"
                    "loudnorm=I=-16:TP=-1.5:LRA=7",
                "-ac", "1", "-ar", str(RATE), "-c:a", "libvorbis", "-q:a", "4", str(target),
            ], check=True)
            print(f"{target.name}: {target.stat().st_size} bytes")


if __name__ == "__main__":
    main()
