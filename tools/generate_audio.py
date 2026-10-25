"""Generate the game's small, original PCM sound effects."""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RATE = 22050


def write_tone(name: str, notes: list[tuple[float, float, float]], duration: float) -> None:
    samples: list[int] = []
    count = int(RATE * duration)
    for index in range(count):
        t = index / RATE
        note = next((item for item in notes if item[0] <= t < item[1]), None)
        if note is None:
            value = 0.0
        else:
            start, end, frequency = note
            local = t - start
            span = end - start
            attack = min(1.0, local / 0.012)
            release = min(1.0, (span - local) / 0.045)
            envelope = max(0.0, min(attack, release))
            wobble = 1.0 + 0.015 * math.sin(2.0 * math.pi * 7.0 * local)
            value = 0.42 * envelope * math.sin(2.0 * math.pi * frequency * local * wobble)
            value += 0.12 * envelope * math.sin(2.0 * math.pi * frequency * 2.0 * local)
        samples.append(max(-32767, min(32767, int(value * 32767))))

    ROOT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(ROOT / name), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(b"".join(struct.pack("<h", sample) for sample in samples))


if __name__ == "__main__":
    write_tone("shot.wav", [(0.0, 0.12, 680.0), (0.12, 0.25, 480.0)], 0.27)
    write_tone("swish.wav", [(0.0, 0.11, 620.0), (0.10, 0.22, 840.0), (0.21, 0.38, 1040.0)], 0.40)
    write_tone("miss.wav", [(0.0, 0.15, 310.0), (0.16, 0.33, 245.0), (0.34, 0.54, 185.0)], 0.58)
    write_tone("horn.wav", [(0.0, 0.36, 390.0), (0.40, 0.78, 300.0), (0.84, 1.22, 220.0)], 1.26)
