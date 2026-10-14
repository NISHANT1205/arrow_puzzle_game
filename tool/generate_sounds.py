"""Generate original short PCM game effects. No third-party audio assets."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path('assets/audio')
OUT.mkdir(parents=True, exist_ok=True)

def write(name, notes, length):
    samples = [0.0] * round(RATE * length)
    for start, duration, freq, end_freq, gain in notes:
        for j in range(round(duration * RATE)):
            index = round(start * RATE) + j
            if index >= len(samples): break
            t = j / RATE
            phase = 2 * math.pi * (freq * t + (end_freq - freq) * t*t / (2 * duration))
            envelope = min(1, t / .004) * (1 - t / duration) ** 2
            samples[index] += gain * envelope * (math.sin(phase) + .12 * math.sin(phase * 2))
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as wav:
        wav.setparams((1, 2, RATE, len(samples), 'NONE', 'not compressed'))
        wav.writeframes(b''.join(struct.pack('<h', round(max(-.9,min(.9,s)) * 32767)) for s in samples))

# A rounded, descending bubble pop instead of an electronic click.
write('ui', [(0,.085,460,170,.34)], .095)

# Airy swish: deterministic band-limited noise with a smooth attack/release.
rng = random.Random(1205)
length = .14
samples = []
fast = slow = 0.0
for i in range(round(RATE * length)):
    u = i / (RATE * length)
    noise = rng.uniform(-1, 1)
    fast += (.12 + .22 * u) * (noise - fast)
    slow += .035 * (noise - slow)
    envelope = math.sin(math.pi * u) ** 2
    samples.append((fast - slow) * envelope)
peak = max(abs(s) for s in samples)
with wave.open(str(OUT / 'slide.wav'), 'wb') as wav:
    wav.setparams((1, 2, RATE, len(samples), 'NONE', 'not compressed'))
    wav.writeframes(b''.join(struct.pack('<h', round(s / peak * .32 * 32767)) for s in samples))
write('blocked', [(0,.15,190,85,.4),(0,.09,320,150,.16)], .17)
write('hint', [(0,.14,660,660,.27),(.09,.18,990,990,.26)], .29)
write('win', [(i*.115,.25,f,f,.27) for i,f in enumerate([523.25,659.25,783.99,1046.5])], .64)
write('lose', [(i*.12,.22,f,f,.29) for i,f in enumerate([392,311.13,246.94])], .48)
write('revive', [(i*.09,.19,f,f,.25) for i,f in enumerate([440,659.25,880])], .4)
