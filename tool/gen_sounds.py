"""Generates the game's sound effects into assets/sounds/.

The sounds are synthesised from scratch so the app ships no third-party
audio. Run from the repository root:

    python3 tool/gen_sounds.py
"""

import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')

random.seed(7)


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def mix(base, other, at=0.0, gain=1.0):
    """Adds [other] into [base] starting at [at] seconds, growing as needed."""
    start = int(at * RATE)
    end = start + len(other)
    if end > len(base):
        base.extend([0.0] * (end - len(base)))
    for i, v in enumerate(other):
        base[start + i] += v * gain
    return base


def env(n, attack, decay):
    """Fast attack, exponential decay envelope of [n] samples."""
    a = max(1, int(attack * RATE))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        else:
            out.append(math.exp(-(i - a) / (decay * RATE)))
    return out


def lowpass(samples, cutoff):
    rc = 1 / (2 * math.pi * cutoff)
    alpha = (1 / RATE) / (rc + 1 / RATE)
    out, y = [], 0.0
    for x in samples:
        y += alpha * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    rc = 1 / (2 * math.pi * cutoff)
    alpha = rc / (rc + 1 / RATE)
    out, y, prev = [], 0.0, 0.0
    for x in samples:
        y = alpha * (y + x - prev)
        prev = x
        out.append(y)
    return out


def noise(seconds):
    return [random.uniform(-1, 1) for _ in range(int(RATE * seconds))]


def tone(freq, seconds, partials=((1, 1.0),), glide=0.0):
    """Sum of sine partials; [glide] bends the pitch by that ratio over time."""
    n = int(RATE * seconds)
    out = []
    phases = [0.0] * len(partials)
    for i in range(n):
        f = freq * (1 + glide * i / n)
        v = 0.0
        for k, (mult, amp) in enumerate(partials):
            phases[k] += 2 * math.pi * f * mult / RATE
            v += amp * math.sin(phases[k])
        out.append(v)
    return out


def shape(samples, e):
    return [s * g for s, g in zip(samples, e)]


def wood(pitch=1.0, length=0.09):
    """A wooden piece knocking on a stone floor."""
    n = int(RATE * length)
    body = tone(380 * pitch, length, ((1, 1.0), (2.76, 0.5), (5.4, 0.25)))
    click = highpass(noise(length), 1800)
    e1 = env(n, 0.001, 0.018)
    e2 = env(n, 0.0005, 0.004)
    return [b * a + c * b2 * 0.6 for b, a, c, b2 in zip(body, e1, click, e2)]


def whoosh(seconds, lo=600, hi=2400):
    n = int(RATE * seconds)
    raw = noise(seconds)
    out, y = [], 0.0
    for i, x in enumerate(raw):
        t = i / n
        cutoff = lo + (hi - lo) * math.sin(math.pi * t)
        rc = 1 / (2 * math.pi * cutoff)
        alpha = (1 / RATE) / (rc + 1 / RATE)
        y += alpha * (x - y)
        out.append(y * math.sin(math.pi * t) ** 2)
    return out


def bell(freq, seconds=1.2):
    """A small temple bell: inharmonic partials, long ring."""
    n = int(RATE * seconds)
    partials = ((1, 1.0), (2.0, 0.6), (2.76, 0.4), (5.4, 0.2), (8.93, 0.1))
    return shape(tone(freq, seconds, partials), env(n, 0.002, 0.35))


def bleat(seconds=0.42):
    """A short goat cry: a buzzy voice with fast tremolo, bending down."""
    n = int(RATE * seconds)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        f = 520 - 140 * t
        phase += 2 * math.pi * f / RATE
        # Buzzy source: a few odd harmonics.
        v = math.sin(phase) + 0.45 * math.sin(3 * phase) + 0.25 * math.sin(5 * phase)
        trem = 0.55 + 0.45 * math.sin(2 * math.pi * 22 * i / RATE)
        amp = min(1, t * 25) * (1 - t) ** 1.4
        out.append(v * trem * amp)
    return lowpass(out, 2600)


def thud(seconds=0.25):
    n = int(RATE * seconds)
    body = tone(95, seconds, ((1, 1.0), (1.5, 0.3)), glide=-0.35)
    return shape(body, env(n, 0.002, 0.07))


def normalise(samples, peak=0.85):
    m = max(abs(s) for s in samples) or 1
    return [s / m * peak for s in samples]


def fade_tail(samples, seconds=0.02):
    n = int(RATE * seconds)
    for i in range(min(n, len(samples))):
        samples[-1 - i] *= i / n
    return samples


def save(name, samples, peak=0.85):
    samples = fade_tail(normalise(samples, peak))
    path = os.path.join(OUT, name)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(
            struct.pack('<h', int(max(-1, min(1, s)) * 32767)) for s in samples))
    print(f'{path}  {len(samples) / RATE:.2f}s')


def main():
    os.makedirs(OUT, exist_ok=True)

    # Picking up a piece: a light high tick.
    save('select.wav', wood(pitch=2.2, length=0.06), peak=0.5)

    # Placing a goat: a solid wooden knock.
    save('place.wav', wood(pitch=1.0, length=0.12))

    # Moving a piece: a short slide, then the knock.
    move = mix(whoosh(0.12, 400, 1500), [0.0], 0)
    move = [s * 0.35 for s in move]
    mix(move, wood(pitch=1.15, length=0.1), at=0.1)
    save('move.wav', move)

    # Capture: the tiger leaps, lands heavily, and the goat cries out.
    cap = [s * 0.5 for s in whoosh(0.26, 500, 3000)]
    mix(cap, thud(), at=0.22)
    mix(cap, wood(pitch=0.8, length=0.12), at=0.22, gain=0.8)
    mix(cap, bleat(), at=0.26, gain=0.55)
    save('capture.wav', cap, peak=0.95)

    # Invalid tap: two dull low knocks.
    bad = wood(pitch=0.55, length=0.07)
    mix(bad, wood(pitch=0.5, length=0.08), at=0.09)
    save('invalid.wav', lowpass(bad, 1400), peak=0.6)

    # Win: a rising run of temple bells.
    win = silence(0.05)
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        mix(win, bell(f, 1.3), at=0.12 * i, gain=0.8 if i < 3 else 1.0)
    save('win.wav', win)

    # Loss: slow falling low bells.
    lose = silence(0.05)
    for i, f in enumerate([392.0, 329.63, 261.63]):
        mix(lose, bell(f, 1.4), at=0.28 * i)
    save('lose.wav', lowpass(lose, 1800), peak=0.75)

    # Draw: two even bells.
    draw = bell(587.33, 1.2)
    mix(draw, bell(587.33, 1.2), at=0.3, gain=0.8)
    save('draw.wav', draw, peak=0.75)


if __name__ == '__main__':
    main()
