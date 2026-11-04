"""Generates Farm Heist's own sounds as .wav files (44.1 kHz, 16-bit mono),
synthesised from scratch so there are no licences to worry about. The
building blocks are Tide Market's (its tools/sound_art), the sounds are the
farm's.

    python tools/sound_art/generate.py                 only sounds with no file yet
    python tools/sound_art/generate.py Siren Bonk      just these (re-upload them after)
    python tools/sound_art/generate.py --all           everything

Writes art/sounds/<Name>.wav. Upload each in Studio (Window > Asset Manager
> Import, or the Creator Dashboard), then paste its ID into
src/shared/Config/Sounds.luau next to the same name ("rbxassetid://...").

Loops (Rain, Birds, Crickets, FarmTheme) are seamless: textures crossfade
their tail onto the start, the music folds what rings past the end back in.
"""
import math
import os
import sys
import wave

import numpy as np

RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "sounds")
rng = np.random.default_rng(20261104)


# ---------------------------------------------------------------------------
# Building blocks (Tide Market's)


def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def env(seconds, attack=0.004, decay=0.2, sustain=0.0, release=None):
    """Attack, then exponential decay towards `sustain`."""
    t = t_axis(seconds)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = sustain + (1 - sustain) * np.exp(-np.maximum(t - attack, 0) / max(decay, 1e-4))
    e = a * d
    if release:
        e *= np.clip((seconds - t) / release, 0, 1)
    return e


def tone(freq, seconds, partials=((1, 1.0),)):
    t = t_axis(seconds)
    out = np.zeros_like(t)
    for ratio, amp in partials:
        out += amp * np.sin(2 * math.pi * freq * ratio * t)
    return out


def sweep(f0, f1, seconds, curve=1.0):
    """A sine gliding from f0 to f1 (curve > 1 lingers near f0)."""
    t = t_axis(seconds)
    f = f0 + (f1 - f0) * (t / seconds) ** curve
    return np.sin(2 * math.pi * np.cumsum(f) / RATE)


def noise(seconds):
    return rng.normal(0, 1, int(seconds * RATE))


def lowpass(x, cutoff):
    """One-pole low-pass; cutoff may be a number or an array (sweeps)."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    alpha = 1 - np.exp(-2 * math.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def band(x, lo, hi, soft=0.25):
    """Keeps lo–hi Hz (an FFT mask with soft edges): fast for long noise."""
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / RATE)
    mask = np.ones_like(freqs)
    if lo > 0:
        mask *= np.clip((freqs - lo * (1 - soft)) / (lo * soft + 1e-9), 0, 1)
    if hi < RATE / 2:
        mask *= np.clip((hi * (1 + soft) - freqs) / (hi * soft + 1e-9), 0, 1)
    return np.fft.irfft(spectrum * mask, len(x))


def place(total, clip, start):
    """Adds `clip` into `total` starting at `start` seconds."""
    i = int(start * RATE)
    if i < 0:
        clip, i = clip[-i:], 0
    end = min(len(total), i + len(clip))
    if end > i:
        total[i:end] += clip[: end - i]
    return total


def silence(seconds):
    return np.zeros(int(seconds * RATE))


def note(name):
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    letter, octave = name[0], int(name[-1])
    semis = names[letter] + (1 if "#" in name else 0) + (octave - 4) * 12
    return 440 * 2 ** (semis / 12)


def bell_tone(freq, seconds, brightness=1.0, decay=1.2):
    """A struck bell: inharmonic partials, the high ones dying fastest."""
    t = t_axis(seconds)
    partials = [(0.5, 0.35, 1.6), (1.0, 1.0, 1.0), (1.19, 0.45, 0.8), (1.5, 0.35, 0.6), (2.0, 0.5 * brightness, 0.45),
                (2.51, 0.25 * brightness, 0.3), (3.0, 0.15 * brightness, 0.22), (4.07, 0.1 * brightness, 0.15)]
    out = np.zeros_like(t)
    for ratio, amp, life in partials:
        out += amp * np.sin(2 * math.pi * freq * ratio * t) * np.exp(-t / (decay * life))
    return out * np.clip(t / 0.002, 0, 1)


def pluck(freq, seconds, brightness=0.5, decay=0.996):
    """Karplus-Strong plucked string: a burst of noise in a delay line one
    period long, smoothed and damped each pass (lower decay: a banjo's
    short twang)."""
    n = int(seconds * RATE)
    period = max(2, int(round(RATE / freq)))
    burst = lowpass(rng.uniform(-1, 1, period), 1500 + 6000 * brightness)
    out = np.zeros(n + 1)
    out[1:period + 1] = burst
    for start in range(period + 1, n + 1, period):
        end = min(n + 1, start + period)
        out[start:end] = decay * 0.5 * (out[start - period:end - period] + out[start - period - 1:end - period - 1])
    return out[1:] * np.clip(t_axis(seconds) / 0.003, 0, 1)


def crossfade_loop(x, seconds, overlap):
    """Folds the last `overlap` seconds over the start (equal power): a loop
    of `seconds` with no seam."""
    n, o = int(seconds * RATE), int(overlap * RATE)
    fade = np.linspace(0, 1, o)
    out = x[:n].copy()
    out[:o] = x[:o] * np.sqrt(fade) + x[n:n + o] * np.sqrt(1 - fade)
    return out


def fold_loop(x, seconds):
    """For music: whatever rings past the end is added back at the start."""
    n = int(seconds * RATE)
    out = x[:n].copy()
    rest = x[n:]
    out[:len(rest)] += rest[: len(out)]
    return out


def knock(freq, seconds=0.16, hard=1.0):
    """A wooden knock: a short body with a few partials and a click."""
    body = tone(freq, seconds, ((1, 1), (2.3, 0.4), (3.9, 0.15))) * env(seconds, 0.0008, 0.03 + 0.02 * hard)
    click = highpass(noise(seconds), 2500) * env(seconds, 0.0004, 0.004) * 0.35 * hard
    return body + click


def normalise(x, peak=0.85):
    m = np.max(np.abs(x))
    return x if m == 0 else x / m * peak


def fade_edges(x, start_ms=0.5, end_ms=6):
    a, z = int(start_ms / 1000 * RATE), int(end_ms / 1000 * RATE)
    if len(x) > a + z:
        x[:a] *= np.linspace(0, 1, a)
        x[-z:] *= np.linspace(1, 0, z)
    return x


def write(name, x, peak=0.85, loop=False):
    x = np.asarray(x, dtype=float)
    x = normalise(x if loop else fade_edges(x), peak)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    path = os.path.join(OUT_DIR, f"{name}.wav")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data)
    print(f"  {name}.wav  {len(x) / RATE:.2f}s")


# ---------------------------------------------------------------------------
# Interface


def error_buzz():
    """Something didn't work: two soft falling notes, not harsh."""
    out = silence(0.42)
    for i, n in enumerate(["E4", "C4"]):
        s, f = 0.2, note(n)
        t = t_axis(s)
        w = np.sign(np.sin(2 * math.pi * f * t)) * 0.5 + np.sin(2 * math.pi * f * t)
        place(out, lowpass(w, 1400) * env(s, 0.005, 0.07), i * 0.17)
    return out


# ---------------------------------------------------------------------------
# The field


def plant():
    """A seed pressed into soft soil: a low thud and a few crumbs."""
    s = 0.35
    out = band(noise(s), 40, 300, 0.1) * env(s, 0.003, 0.05) * 3.0
    out += tone(110, s, ((1, 1), (1.6, 0.3))) * env(s, 0.002, 0.04) * 0.5
    for _ in range(6):
        crumb = lowpass(highpass(noise(0.03), 900), 3000) * env(0.03, 0.0005, 0.006)
        place(out, crumb * rng.uniform(0.15, 0.4), rng.uniform(0.03, 0.2))
    return out


def water():
    """A watering can's pour: a splashy hiss that swells and stops, with
    drops plinking at the end."""
    s = 0.9
    t = t_axis(s)
    shape = np.clip(t / 0.08, 0, 1) * np.clip((0.62 - t) / 0.12, 0, 1)
    hiss = band(noise(s), 700, 6000) * shape * 0.45
    burble = band(noise(s), 200, 900) * shape * (0.6 + 0.4 * np.sin(2 * math.pi * 9 * t)) * 0.3
    out = hiss + burble
    for k in range(5):
        f = rng.uniform(1300, 2600)
        drop = sweep(f, f * 1.6, 0.06) * env(0.06, 0.001, 0.015)
        place(out, drop * rng.uniform(0.15, 0.3), 0.55 + k * rng.uniform(0.04, 0.07))
    return out


def harvest():
    """A ripe crop pulled up: a round pop, a leafy rustle and a sparkle."""
    out = silence(0.5)
    pop = sweep(820, 260, 0.07, 0.6) * env(0.07, 0.001, 0.03)
    place(out, pop * 0.9, 0.0)
    rustle = highpass(noise(0.16), 2200) * env(0.16, 0.004, 0.05) * 0.35
    place(out, rustle, 0.01)
    for i, n in enumerate(["E6", "B6"]):
        place(out, bell_tone(note(n), 0.3, 0.3, 0.12) * 0.18, 0.06 + i * 0.05)
    return out


def cash_register():
    """Paid (a truck back from the City, a big store sale): the drawer
    rattles open, coins, a ding."""
    out = silence(1.0)
    place(out, lowpass(highpass(noise(0.18), 900), 5000) * env(0.18, 0.002, 0.05) * 0.5, 0.0)
    for i in range(7):
        f = rng.uniform(2600, 4200)
        clink = tone(f, 0.25, ((1, 1), (1.47, 0.6), (2.09, 0.35))) * env(0.25, 0.0005, 0.045)
        place(out, clink * rng.uniform(0.2, 0.5), 0.05 + i * rng.uniform(0.03, 0.05))
    place(out, bell_tone(note("C6"), 0.8, 0.8, 0.4) * 0.9, 0.16)
    return out


def level_up():
    """A Farm Level: a bright brass arpeggio up a G chord, a bell on top."""
    s = 1.6
    out = silence(s)
    t = t_axis(0.9)
    for i, n in enumerate(["G4", "B4", "D5", "G5"]):
        f = note(n)
        saw = sum(np.sin(2 * math.pi * f * k * t) / k for k in range(1, 8))
        horn = lowpass(saw, 2400) * env(0.9, 0.02, 0.35 if i < 3 else 0.6, 0.15, 0.3)
        place(out, horn * (0.35 if i < 3 else 0.5), i * 0.11)
    place(out, bell_tone(note("G6"), 1.2, 0.6, 0.5) * 0.35, 0.33)
    return out


def tape():
    """Packing a crate: tape pulled off the roll in a quick rip."""
    s = 0.42
    t = t_axis(s)
    stick = 0.55 + 0.45 * np.sign(np.sin(2 * math.pi * (70 + 60 * t / s) * t))  # stick-slip
    rip = band(noise(s), 1200, 7000) * stick * env(s, 0.01, 0.25, 0, 0.08)
    return rip


def truck_horn():
    """A pickup's horn: two short honks (a truck leaving, "BEEP BEEP")."""
    out = silence(1.0)
    for start, length in ((0.0, 0.26), (0.38, 0.4)):
        t = t_axis(length)
        w = np.zeros_like(t)
        for f in (330, 415):
            w += sum(np.sin(2 * math.pi * f * k * t) / k for k in range(1, 9))
        honk = lowpass(w, 2000) * env(length, 0.015, 10, 1, 0.04)
        place(out, honk, start)
    return out


# ---------------------------------------------------------------------------
# Raids


def siren():
    """The theft alarm: a siren's chirp, up and down twice."""
    s = 1.5
    t = t_axis(s)
    f = 700 + 500 * (0.5 - 0.5 * np.cos(2 * math.pi * t / 0.75))
    phase = 2 * math.pi * np.cumsum(f) / RATE
    w = np.sin(phase) + 0.35 * np.sin(3 * phase) + 0.15 * np.sin(5 * phase)
    return lowpass(w, 3500) * env(s, 0.02, 10, 1, 0.12)


def bonk():
    """A bat on a head: a hollow wooden knock and a cartoon boing."""
    out = silence(0.55)
    place(out, knock(380, 0.2, 1.4), 0.0)
    t = t_axis(0.45)
    f = 650 * np.exp(-t / 0.12) + 240
    f = f * (1 + 0.04 * np.sin(2 * math.pi * 18 * t))  # the wobble
    boing = np.sin(2 * math.pi * np.cumsum(f) / RATE) * env(0.45, 0.004, 0.14)
    place(out, boing * 0.55, 0.015)
    return out


def whistle():
    """An arrest: a police whistle, short then long, the pea trilling."""
    out = silence(1.0)
    for start, length in ((0.0, 0.22), (0.32, 0.6)):
        t = t_axis(length)
        trill = 1 + 0.035 * np.sin(2 * math.pi * 32 * t)
        tonal = np.sin(2 * math.pi * np.cumsum(2900 * trill) / RATE) * (0.75 + 0.25 * np.sin(2 * math.pi * 32 * t))
        breath = band(noise(length), 2400, 4200) * 0.04
        place(out, (tonal + breath) * env(length, 0.01, 10, 1, 0.04), start)
    return out


def rustle():
    """Leaves shaking: a crop being pulled at by a thief."""
    s = 1.2
    out = band(noise(s), 1800, 8000) * 0.15
    grains = silence(s)
    for _ in range(40):
        g = band(noise(0.05), 2000, 7000) * np.hanning(int(0.05 * RATE))
        place(grains, g * rng.uniform(0.2, 0.7), rng.uniform(0, s - 0.06))
    return (out + grains) * env(s, 0.05, 10, 1, 0.25)


def alarm_bell():
    """The yard's alarm bell: an electric bell ringing hard."""
    s = 1.6
    out = silence(s + 0.5)
    strike = bell_tone(1400, 0.5, 1.0, 0.18)
    for k in range(int(s * 24)):
        place(out, strike * (0.7 + 0.3 * (k % 2)), k / 24)
    return out


def gavel():
    """SOLD: the gavel's knock on its block."""
    out = silence(0.5)
    place(out, knock(210, 0.3, 1.6) * 1.0, 0.0)
    place(out, band(noise(0.25), 40, 320, 0.1) * env(0.25, 0.001, 0.02) * 1.2, 0.0)  # (the block's thump, no hiss after)
    return out


# ---------------------------------------------------------------------------
# Ambience and music (loops)


def rain():
    """Steady rain: a soft hiss and hundreds of little drops."""
    total, loop = 13.0, 12.0
    hiss = band(noise(total), 1200, 9000) * 0.35
    drops = np.zeros(int(total * RATE))
    starts = rng.integers(0, len(drops) - 600, int(total * 260))
    grain_t = t_axis(600 / RATE)
    for start in starts:
        f = rng.uniform(2000, 6500)
        grain = np.sin(2 * math.pi * f * grain_t) * np.exp(-grain_t / rng.uniform(0.002, 0.006))
        drops[start:start + 600] += grain * rng.uniform(0.1, 1.0)
    return crossfade_loop(hiss + drops * 0.25, loop, total - loop)


def birds():
    """A farm by day: a breeze, and songbirds now and then, near and far."""
    total, loop = 17.0, 16.0
    out = band(noise(total), 120, 700) * 0.04  # (the breeze)
    species = [  # (lowest, highest Hz, chirp length, phrase length)
        (3200, 5200, 0.07, (3, 6)),
        (2400, 3600, 0.12, (2, 4)),
        (4200, 6800, 0.045, (4, 9)),
    ]
    cursor = 0.4
    while cursor < total - 1.5:
        lo, hi, length, phrase = species[rng.integers(0, len(species))]
        level = rng.uniform(0.25, 1.0)  # (near or far)
        at = cursor
        for _ in range(rng.integers(phrase[0], phrase[1] + 1)):
            f0 = rng.uniform(lo, hi)
            f1 = f0 * rng.uniform(0.75, 1.35)
            n = int(length * RATE)
            chirp = sweep(f0, f1, length, rng.uniform(0.5, 2.0))
            chirp *= np.sin(np.linspace(0, math.pi, n)) ** 2
            chirp *= 1 + 0.25 * np.sin(2 * math.pi * rng.uniform(25, 45) * t_axis(length))  # a warble
            place(out, chirp * level * 0.3, at)
            at += length + rng.uniform(0.04, 0.11)
        cursor = at + rng.uniform(0.8, 2.6)
    return crossfade_loop(out, loop, total - loop)


def crickets():
    """Night on the farm: a few crickets chirping in their own rhythms."""
    total, loop = 13.0, 12.0
    out = silence(total)
    t_chirp = t_axis(0.02)
    for _ in range(6):
        f = rng.uniform(3900, 5200)
        pulse = np.sin(2 * math.pi * f * t_chirp) * np.hanning(len(t_chirp))
        level = rng.uniform(0.25, 0.7)
        cursor = rng.uniform(0, 1.5)
        gap = rng.uniform(0.5, 1.1)
        while cursor < total - 0.2:
            for k in range(rng.integers(2, 4)):
                place(out, pulse * level, cursor + k * 0.035)
            cursor += gap * rng.uniform(0.85, 1.15)
    hush = band(noise(total), 200, 1500) * 0.02
    return crossfade_loop(out + hush, loop, total - loop)


def farm_theme():
    """The farm's tune (loop): a banjo rolling through G – C – G – D, a
    plucked bass on the beat, a brushed shaker on two and four, and a
    simple melody in G's pentatonic. 16 bars at 104 bpm (about 37 s)."""
    bpm = 104
    beat = 60 / bpm
    bars = 16
    loop = bars * 4 * beat
    out = silence(loop + 4)
    chords = {
        "G": ("G2", "D3", ["G3", "B3", "D4", "G4"]),
        "C": ("C3", "G2", ["C4", "E4", "G4", "C5"]),
        "D": ("D3", "A2", ["D4", "F#4", "A4", "D5"]),
    }
    progression = ["G", "G", "C", "G", "G", "G", "D", "D", "G", "G", "C", "C", "G", "D", "G", "G"]
    roll = [0, 2, 3, "drone", 1, 3, "drone", 2]  # a forward roll; the thumb's high G between
    for bar, name in enumerate(progression):
        root, fifth, tones = chords[name]
        start = bar * 4 * beat
        for b, bass in enumerate((root, fifth)):  # boom on 1 and 3
            place(out, pluck(note(bass), 1.4, 0.15, 0.995) * 0.6, start + b * 2 * beat)
        for step, which in enumerate(roll):
            f = note("G4") if which == "drone" else note(tones[which])
            at = start + step * beat / 2 + rng.uniform(-0.006, 0.006)
            level = 0.24 if which == "drone" else rng.uniform(0.27, 0.34)
            place(out, pluck(f, 1.2, 0.8, 0.993) * level, at)
        for b in (1, 3):  # the shaker
            shake = band(noise(0.09), 4000, 11000) * env(0.09, 0.01, 0.025) * 0.18
            place(out, shake, start + b * beat)
    melody = [  # (beat from the start, note)
        (0, "B4"), (1, "D5"), (2, "E5"), (3, "D5"),
        (4, "B4"), (5.5, "A4"), (6, "G4"),
        (8, "E5"), (9, "G5"), (10, "E5"), (11, "D5"),
        (12, "B4"), (14, "D5"),
        (16, "G5"), (17, "E5"), (18, "D5"), (19, "B4"),
        (20, "D5"), (21.5, "B4"), (22, "A4"),
        (24, "A4"), (25, "B4"), (26, "D5"), (27, "E5"),
        (28, "F#5"), (30, "E5"), (31, "D5"),
        (32, "B4"), (33, "D5"), (34, "G5"), (35, "D5"),
        (36, "E5"), (37.5, "D5"), (38, "B4"),
        (40, "C5"), (41, "E5"), (42, "G5"), (43, "E5"),
        (44, "D5"), (46, "C5"),
        (48, "B4"), (49, "D5"), (50, "E5"), (51, "G5"),
        (52, "E5"), (53, "F#5"), (54, "A5"), (55, "F#5"),
        (56, "G5"), (58, "D5"), (59, "B4"),
        (60, "G4"),
    ]
    for at_beat, name in melody:
        place(out, pluck(note(name), 2.0, 0.65, 0.996) * 0.42, at_beat * beat + 0.012)
    return fold_loop(out, loop)


# ---------------------------------------------------------------------------

SOUNDS = {
    "Error": (error_buzz, False),
    "Plant": (plant, False),
    "Water": (water, False),
    "Harvest": (harvest, False),
    "CashRegister": (cash_register, False),
    "LevelUp": (level_up, False),
    "Tape": (tape, False),
    "TruckHorn": (truck_horn, False),
    "Siren": (siren, False),
    "Bonk": (bonk, False),
    "Whistle": (whistle, False),
    "Rustle": (rustle, False),
    "AlarmBell": (alarm_bell, False),
    "Gavel": (gavel, False),
    "Rain": (rain, True),
    "Birds": (birds, True),
    "Crickets": (crickets, True),
    "FarmTheme": (farm_theme, True),
}


def main(argv):
    os.makedirs(OUT_DIR, exist_ok=True)
    names = [a for a in argv if not a.startswith("--")]
    every = "--all" in argv
    for name, (make, loop) in SOUNDS.items():
        path = os.path.join(OUT_DIR, f"{name}.wav")
        if names and name not in names:
            continue
        if not names and not every and os.path.exists(path):
            continue
        write(name, make(), 0.8 if loop else 0.85, loop)
    unknown = [n for n in names if n not in SOUNDS]
    if unknown:
        print("Not a sound here:", ", ".join(unknown))


if __name__ == "__main__":
    main(sys.argv[1:])
