"""Cuts Farm Heist's stock sounds out of downloaded effects: trimmed, faded,
made mono and brought to about the loudness of the sounds they replace.
The downloads and what's made from them stay out of git (the repository is
public, and they aren't ours to hand out on their own): only this recipe is
kept here.

    python tools/sound_art/stock.py                    from your Downloads folder
    python tools/sound_art/stock.py --from <folder>    from another folder
    python tools/sound_art/stock.py DogAlert Siren     just these

Needs numpy and soundfile (`pip install soundfile`: it reads mp3). Writes
art/sounds/stock/<Name>.wav (44.1 kHz, 16-bit mono). Upload each to the
community, then paste its id next to the same name in
src/shared/Config/Sounds.luau.
"""
import os
import sys

import numpy as np
import soundfile

RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "sounds", "stock")

BONK = "freesound_community-bonk-sound-effect-36055.mp3"
KACHING = "modestas123123-cash-register-kaching-sound-effect-125042.mp3"
HIT_PLANT = "u_xjrmmgxfru-hit-plant-03-266292.mp3"
BELL_RING = "cartoon_music-shop-bell-ring-543931.mp3"
DOOR_BELL = "freesound_community-shop-door-bell-6405.mp3"
BONUS = "universfield-game-bonus-144751.mp3"
ALARM = "freesound_community-security-alarm-80493.mp3"
ALERTE = "alexis_gaming_cam-alerte-346112.mp3"
GAVEL = "intrepidmedia-gavel-of-justice-124029.mp3"
APPLAUSE = "driken5482-applause-cheer-236786.mp3"
YAY = "jesuschristisgod-children-saying-yay-praise-and-worship-jesus-299607.mp3"


def load(folder, name):
    """A file as mono floats at RATE."""
    x, rate = soundfile.read(os.path.join(folder, name), always_2d=True)
    mono = x.mean(axis=1)
    return resample(mono, RATE / rate)


def resample(x, ratio):
    """`ratio` times as many samples (played back at the same rate, a ratio
    over 1 is slower and lower)."""
    if ratio == 1:
        return x
    n = int(len(x) * ratio)
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)


def clip(x, start, end, fade_in=0.004, fade_out=0.08):
    """start to end (seconds), faded so nothing clicks."""
    y = x[int(start * RATE):int(end * RATE)].copy()
    a, b = int(fade_in * RATE), int(fade_out * RATE)
    y[:a] *= np.linspace(0, 1, a)
    y[-b:] *= np.linspace(1, 0, b) ** 2
    return y


def shaped(x, gain):
    """x through a filter: gain(frequencies in Hz) -> a gain for each."""
    spectrum = np.fft.rfft(x)
    return np.fft.irfft(spectrum * gain(np.fft.rfftfreq(len(x), 1 / RATE)), len(x))


def level(x, loudness, peak=0.92):
    """To `loudness` (the RMS of where there's sound), never over `peak`."""
    active = x[np.abs(x) > np.abs(x).max() * 0.05]
    k = loudness / np.sqrt((active ** 2).mean())
    return x * min(k, peak / np.abs(x).max())


def plant(source):
    """A seed pressed in: the first rustle of the hit, slowed and darkened
    into a soft pat, so it isn't the Harvest sound again."""
    y = resample(source[int(0.04 * RATE):int(0.3 * RATE)], 1.45)
    y = shaped(y, lambda f: 1 / (1 + (f / 1500) ** 4) + 0.04)
    b = int(0.1 * RATE)
    y[-b:] *= np.linspace(1, 0, b) ** 2
    y[:int(0.003 * RATE)] *= np.linspace(0, 1, int(0.003 * RATE))
    return y


def cheer(applause, yay):
    """You won the lot: the yay, sung by three (it again a little higher and a
    little lower, just behind it, so it's a crowd and not one voice), over
    the applause, which carries on after the yay and dies away."""
    seconds = 3.3
    out = np.zeros(int(seconds * RATE))
    voice = clip(yay, 0, 2.05, fade_in=0.01, fade_out=0.3)
    for ratio, delay, gain in ((1, 0, 1), (0.94, 0.05, 0.5), (1.06, 0.1, 0.45)):
        copy = resample(voice, ratio) * gain
        at = int(delay * RATE)
        out[at:at + len(copy)] += copy
    clap = clip(applause, 1.3, 1.3 + seconds, fade_in=0.04, fade_out=1.3)
    clap = shaped(clap, lambda f: 1 / (1 + (120 / np.maximum(f, 1)) ** 4))  # (no rumble)
    out[:len(clap)] += clap * 2
    return out


# name: (the file, or the files, how it's made from them, how loud)
RECIPES = {
    "Bonk": (BONK, lambda x: clip(x, 0.5, 1.2, fade_out=0.12), 0.2),
    "CashRegister": (KACHING, lambda x: clip(x, 0.5, 2.0, fade_out=0.3), 0.12),
    "Harvest": (HIT_PLANT, lambda x: clip(x, 0.03, 0.95, fade_out=0.2), 0.11),
    "Plant": (HIT_PLANT, plant, 0.14),
    "LevelUp": (BONUS, lambda x: clip(x, 0.14, 2.9, fade_out=0.8), 0.15),
    "ShopBell": (DOOR_BELL, lambda x: clip(x, 0.3, 2.3, fade_out=0.6), 0.1),  # (its first three rings)
    "CheckoutBell": (BELL_RING, lambda x: clip(x, 2.08, 3.7, fade_out=0.5), 0.11),  # (one ring of a counter bell)
    "Siren": (ALARM, lambda x: clip(x, 0, 3.1, fade_out=0.25), 0.35),  # (two of its bursts)
    "Gavel": (GAVEL, lambda x: clip(x, 1.37, 2.0, fade_out=0.2), 0.2),  # (its second strike: Goldie bangs once a call)
    "DogAlert": (ALERTE, lambda x: clip(x, 0.2, 1.0, fade_out=0.12), 0.2),
    "BidWon": ((APPLAUSE, YAY), cheer, 0.16),
}


def main(argv):
    folder = os.path.join(os.path.expanduser("~"), "Downloads")
    if "--from" in argv:
        at = argv.index("--from")
        folder = argv[at + 1]
        argv = argv[:at] + argv[at + 2:]
    os.makedirs(OUT_DIR, exist_ok=True)
    for name in argv or list(RECIPES):
        source, make, loudness = RECIPES[name]
        sources = source if isinstance(source, tuple) else (source,)
        y = level(make(*[load(folder, file) for file in sources]), loudness)
        soundfile.write(os.path.join(OUT_DIR, f"{name}.wav"), y, RATE, subtype="PCM_16")
        print(f"  {name}.wav  {len(y) / RATE:.2f} s  peak {np.abs(y).max():.2f}")


if __name__ == "__main__":
    main(sys.argv[1:])
