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


def bandpass(samples, freq, q):
    """A resonant band-pass filter (RBJ biquad), used to shape vowels."""
    w0 = 2 * math.pi * freq / RATE
    alpha = math.sin(w0) / (2 * q)
    a0 = 1 + alpha
    b0, b2 = alpha / a0, -alpha / a0
    a1, a2 = -2 * math.cos(w0) / a0, (1 - alpha) / a0
    out = []
    x1 = x2 = y1 = y2 = 0.0
    for x in samples:
        y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, x
        y2, y1 = y1, y
        out.append(y)
    return out


def formants(source, bands):
    """Passes a buzzy source through vocal-tract resonances."""
    out = [0.0] * len(source)
    for freq, q, gain in bands:
        for i, v in enumerate(bandpass(source, freq, q)):
            out[i] += v * gain
    return out


def voice(pitch, seconds, harmonics=14, rough=0.0, sub=0.0):
    """A glottal-style buzz whose pitch follows pitch(t) for t in 0..1.
    [rough] adds the irregular rasp of a big cat; [sub] a growl an octave down."""
    n = int(RATE * seconds)
    out, phase = [], 0.0
    jitter, rasp = 0.0, 1.0
    for i in range(n):
        t = i / n
        if rough:
            # Slowly wandering pitch and a ragged amplitude.
            jitter += (random.uniform(-1, 1) - jitter) * 0.02
            rasp += (random.uniform(1 - rough, 1 + rough) - rasp) * 0.08
        f = pitch(t) * (1 + jitter * 0.04 * rough)
        phase += 2 * math.pi * f / RATE
        v = 0.0
        for h in range(1, harmonics + 1):
            if f * h > RATE / 2.2:
                break
            v += math.sin(h * phase) / h
        if sub:
            v += sub * math.sin(phase / 2)
        out.append(v * rasp)
    return out


def bleat(seconds=0.55, base=430, scared=False):
    """A goat's "meh-eh-eh": a nasal voice that pulses quickly."""
    n = int(RATE * seconds)
    pulse = 26 if scared else 17

    def pitch(t):
        bend = 1 + 0.12 * math.sin(math.pi * t) - 0.18 * t
        return base * bend * (1 + 0.035 * math.sin(2 * math.pi * pulse * t * seconds))

    src = voice(pitch, seconds, harmonics=16)
    v = formants(src, [(700, 6, 1.0), (1750, 7, 0.7), (2600, 9, 0.35)])
    out = []
    for i, x in enumerate(v):
        t = i / n
        trem = 0.45 + 0.55 * abs(math.sin(math.pi * pulse * t * seconds))
        amp = min(1, t * 18) * (1 - t) ** 0.9
        out.append(x * trem * amp)
    breath = [x * 0.15 for x in highpass(noise(seconds), 2500)]
    return [a + b * min(1, i / n * 18) * (1 - i / n) for i, (a, b) in enumerate(zip(out, breath))]


def growl(seconds=0.6, base=85, rough=0.5):
    """A tiger's low warning rumble."""
    n = int(RATE * seconds)

    def pitch(t):
        return base * (1 + 0.15 * math.sin(math.pi * t))

    src = voice(pitch, seconds, harmonics=30, rough=rough, sub=0.5)
    v = formants(src, [(330, 3, 1.0), (850, 4, 0.6), (1900, 6, 0.25)])
    breath = bandpass(noise(seconds), 600, 1.2)
    out = []
    for i, (x, b) in enumerate(zip(v, breath)):
        t = i / n
        amp = min(1, t * 6) * (1 - t) ** 1.2
        out.append((x + b * 0.25) * amp)
    return out


def roar(seconds=1.5):
    """A full tiger roar: swells up, peaks, then falls away."""
    n = int(RATE * seconds)

    def pitch(t):
        return 95 + 85 * math.sin(math.pi * min(1, t / 0.75)) * (1 - 0.4 * t)

    src = voice(pitch, seconds, harmonics=40, rough=0.8, sub=0.35)
    v = formants(src, [(420, 2.5, 1.0), (1050, 3.5, 0.8), (2300, 5, 0.35)])
    breath = bandpass(noise(seconds), 900, 0.9)
    out = []
    for i, (x, b) in enumerate(zip(v, breath)):
        t = i / n
        amp = min(1, (t / 0.18) ** 1.5) * (1 - t) ** 1.6
        out.append((x + b * 0.4 * (0.5 + t)) * amp)
    return out


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

    # Placing a goat: a solid wooden knock.
    save('place.wav', wood(pitch=1.0, length=0.12))

    # Moving a piece: a short slide, then the knock.
    move = mix(whoosh(0.12, 400, 1500), [0.0], 0)
    move = [s * 0.35 for s in move]
    mix(move, wood(pitch=1.15, length=0.1), at=0.1)
    save('move.wav', move)

    # Capture: the tiger leaps and snarls as it lands, and the goat cries out.
    cap = [s * 0.5 for s in whoosh(0.26, 500, 3000)]
    mix(cap, thud(), at=0.22)
    mix(cap, wood(pitch=0.8, length=0.12), at=0.22, gain=0.8)
    mix(cap, growl(0.45, base=110, rough=0.9), at=0.18, gain=0.7)
    mix(cap, bleat(0.5, base=520, scared=True), at=0.28, gain=0.55)
    save('capture.wav', cap, peak=0.95)

    # Picking up a tiger: a short, low growl.
    save('growl.wav', growl(0.5), peak=0.7)

    # Picking up a goat: a soft, short bleat.
    save('bleat.wav', bleat(0.42), peak=0.55)

    # A goat realises a tiger can reach it: a quick, high, nervous cry.
    save('scared.wav', bleat(0.38, base=560, scared=True), peak=0.6)

    # Invalid tap: two dull low knocks.
    bad = wood(pitch=0.55, length=0.07)
    mix(bad, wood(pitch=0.5, length=0.08), at=0.09)
    save('invalid.wav', lowpass(bad, 1400), peak=0.6)

    # Tigers win: a roar over low bells.
    tw = silence(0.05)
    mix(tw, roar(), at=0.0)
    for i, f in enumerate([196.0, 261.63]):
        mix(tw, bell(f, 1.4), at=0.9 + 0.25 * i, gain=0.35)
    save('tigers_win.wav', tw, peak=0.95)

    # Goats win: the herd bleats happily over a rising run of temple bells.
    gw = silence(0.05)
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        mix(gw, bell(f, 1.3), at=0.12 * i, gain=0.55)
    for at, base in [(0.15, 430), (0.45, 500), (0.7, 460)]:
        mix(gw, bleat(0.45, base=base), at=at, gain=0.5)
    save('goats_win.wav', gw)

    # Draw: two even bells.
    draw = bell(587.33, 1.2)
    mix(draw, bell(587.33, 1.2), at=0.3, gain=0.8)
    save('draw.wav', draw, peak=0.75)


if __name__ == '__main__':
    main()
