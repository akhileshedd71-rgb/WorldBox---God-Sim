#!/usr/bin/env python3
"""Generate Verdant's original gentle synth motifs (standard library only)."""
from pathlib import Path
import math
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / 'assets/audio'
ROOT.mkdir(parents=True, exist_ok=True)
RATE = 22050

def write(name, seconds, voice):
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as wav:
        wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        wav.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, voice(n / RATE))) * 32767)) for n in range(int(RATE * seconds))))

def note(t, frequency, length):
    if not 0 <= t < length:
        return 0
    envelope = math.sin(math.pi * t / length) ** 2
    return envelope * (math.sin(math.tau * frequency * t) + 0.18 * math.sin(math.tau * frequency * 2 * t))

def meadow(t):
    # Eight original, slowly overlapping pentatonic notes; a silent loop seam.
    notes = [261.6256, 329.6276, 391.9954, 440.0, 391.9954, 329.6276, 293.6648, 261.6256]
    return sum(0.11 * note(t - index * 1.5, f, 3.5) for index, f in enumerate(notes))

write('meadow', 16, meadow)
write('touch', 0.09, lambda t: 0.16 * note(t, 659.255, 0.09))
write('paint', 0.16, lambda t: 0.11 * note(t, 329.627, 0.16))
write('save', 0.5, lambda t: 0.13 * note(t, 523.251, 0.3) + 0.11 * note(t - 0.16, 783.991, 0.34))
print('Generated four original audio assets.')
