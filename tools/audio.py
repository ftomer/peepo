#!/usr/bin/env python3
"""Peepo's sound: one music track per level, and every effect the game plays.

    tools/audio.sh sfx                   # synthesize the effects, offline, free
    tools/audio.sh music [<id> ...]      # generate the tracks, costs money
    tools/audio.sh music --reprocess     # redo the post-process, no new calls

Two halves, because the two problems are nothing alike.

Music is generated: Lyria 3 Pro through the Gemini API, one prompt per level in
tools/audio_prompts.json. Model output carries no copyright claim from Google
and may ship commercially, which is the whole reason it is used here - a
children's app cannot afford a sample with a licence attached to it. The raw
response is kept in tools/audio/ so the post-process can be re-run, and re-run
again, without paying for the track twice.

Effects are synthesized: a few sine partials and an envelope, written straight
to a wav. Nothing is sampled and nothing is downloaded, so there is no
provenance to document and no licence to honour. It also buys control that a
sound pack cannot: the miss cue for a game aimed at three year olds has to be
audibly *not* a buzzer, and here that is one line saying which frequency and
how quiet.

Everything both halves write is a build artefact of this file. Delete
assets/audio/ and one `sfx` plus one `music --reprocess` puts it all back.
"""
import argparse
import base64
import json
import math
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
PROMPTS = ROOT / "tools" / "audio_prompts.json"
# Raw model output, kept out of the app bundle. Re-processing reads from here.
RAW = ROOT / "tools" / "audio"
MUSIC = ROOT / "assets" / "audio" / "music"
SFX = ROOT / "assets" / "audio" / "sfx"

RATE = 44100

# Lyria 3 Pro rather than Clip: Clip is fixed at thirty seconds, and thirty
# seconds is what a level sounds like to a four year old who has been on it for
# ten minutes.
MODEL = "lyria-3-pro-preview"

# How much of the tail is folded back over the head to close the loop. Long
# enough to cover a phrase ending that does not quite meet the beginning, short
# enough that it is not audible as a fade.
LOOP_FADE = 3.0

# Background music sits under a game, so it is mixed quiet and flat: an RMS
# target rather than a peak one, because peak normalising makes a sparse track
# far louder than a busy one at the same number.
MUSIC_RMS_DBFS = -20.0
MUSIC_PEAK_DBFS = -1.0

# Mono at 96k: the scenes are looked at, not listened to in stereo, and four
# tracks at this setting cost about the same bundle space as one backdrop.
MUSIC_BITRATE = "96k"


# ---------------------------------------------------------------- synthesis --


def silence(duration):
    return np.zeros(int(RATE * duration), dtype=np.float64)


def mix(into, part, at):
    """Adds [part] into [into] at [at] seconds, growing the buffer if needed."""
    start = int(RATE * at)
    end = start + len(part)
    if end > len(into):
        into = np.concatenate([into, np.zeros(end - len(into))])
    into[start:end] += part
    return into


def decay(n, seconds, attack=0.004):
    """A struck envelope: near-instant on, exponential off.

    The attack is not zero because a waveform that starts at full amplitude
    clicks, and a click on a reward sound is the one thing a child's ear picks
    out of it.
    """
    t = np.arange(n) / RATE
    env = np.exp(-t / (seconds / 5.0))
    rise = int(RATE * attack)
    if rise:
        env[:rise] *= np.linspace(0.0, 1.0, rise)
    return env


def bell(freq, duration, gain=1.0, attack=0.004):
    """One struck bell note.

    Three partials, the upper two pushed very slightly sharp. Exact multiples
    sound like an organ; a few cents of stretch is what reads as struck metal.
    Each partial decays faster than the one below it, which is the other half
    of the impression - a real bell loses its brightness first.
    """
    n = int(RATE * duration)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for ratio, weight, shorten in ((1.0, 1.0, 1.0), (2.01, 0.42, 0.55), (3.01, 0.18, 0.32)):
        out += weight * np.sin(2 * math.pi * freq * ratio * t) * decay(
            n, duration * shorten, attack
        )
    return out * gain / 1.6


def note(semitones, octave=0):
    """Equal-tempered frequency, counted in semitones from middle C."""
    return 261.625565 * 2 ** (octave + semitones / 12.0)


def noise(duration, seed):
    # Seeded, so a rebuild of the effects produces the same bytes as last time
    # and git sees no change unless the recipe changed.
    return np.random.default_rng(seed).standard_normal(int(RATE * duration))


def bandpass(signal, centre, q=2.0):
    """State-variable band-pass, [centre] given per sample so it can sweep.

    A plain loop: the filter is recursive, so there is nothing to vectorise,
    and a second of audio is fifty thousand cheap iterations.
    """
    centre = np.broadcast_to(np.asarray(centre, dtype=np.float64), signal.shape)
    f = 2.0 * np.sin(np.pi * np.clip(centre, 20.0, RATE * 0.45) / RATE)
    damp = 1.0 / q
    low = band = 0.0
    out = np.empty_like(signal)
    for i, x in enumerate(signal):
        high = x - low - damp * band
        band += f[i] * high
        low += f[i] * band
        out[i] = band
    return out


def fade_edges(signal, seconds=0.006):
    """Takes the click off both ends of a finished effect."""
    n = min(int(RATE * seconds), len(signal) // 2)
    if n:
        signal[:n] *= np.linspace(0.0, 1.0, n)
        signal[-n:] *= np.linspace(1.0, 0.0, n)
    return signal


def write_wav(path, signal, peak_dbfs):
    """Writes 16-bit mono at [peak_dbfs], the effect's place in the mix.

    Loudness is set here rather than in the game because the levels are
    relative to each other: a miss must be quieter than a find no matter what
    the device volume is, and that is a property of the files, not of the
    player.
    """
    signal = fade_edges(np.asarray(signal, dtype=np.float64).copy())
    peak = np.max(np.abs(signal))
    if peak > 0:
        signal *= (10 ** (peak_dbfs / 20.0)) / peak
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes((signal * 32767).astype("<i2").tobytes())
    return path


# ------------------------------------------------------------------ effects --
#
# One function per cue. The dB figure passed to write_wav is the cue's rank in
# the mix, and the ranking is deliberate: finishing a level is the loudest
# thing the game does, missing is the quietest.


def sfx_found():
    """A find: a major arpeggio up, one bell per note, quick enough to read as
    a single event rather than a tune."""
    out = silence(1.0)
    for i, semi in enumerate((0, 4, 7, 12)):
        out = mix(out, bell(note(semi, 1), 0.7, gain=0.85 ** i), 0.055 * i)
    return write_wav(SFX / "found.wav", out, -6.0)


def sfx_miss():
    """A tap on nothing.

    Wood, not a buzzer. Low, short, and the quietest cue in the game: the
    player is three and guessing is how they play, so this may register as
    "not there" and must never register as "wrong".
    """
    out = silence(0.22)
    out = mix(out, bell(note(-5), 0.16, attack=0.002) * 0.8, 0.0)
    knock = bandpass(noise(0.05, seed=11), centre=420.0, q=1.1)
    out = mix(out, knock * decay(len(knock), 0.05, attack=0.001) * 0.25, 0.0)
    return write_wav(SFX / "miss.wav", out, -20.0)


def sfx_hint():
    """A hint arriving: a shimmer high above the music, so it is heard as the
    game speaking rather than as part of the track."""
    out = silence(0.9)
    for i, semi in enumerate((4, 11, 16)):
        out = mix(out, bell(note(semi, 2), 0.55, gain=0.8 ** i), 0.045 * i)
    return write_wav(SFX / "hint.wav", out, -11.0)


def sfx_complete():
    """The level finished: the one moment the game is allowed to be loud.

    A swell underneath, an arpeggio over two octaves, then a scatter of high
    bells that carries on under the card while it rises.
    """
    out = silence(2.6)
    swell = np.sin(2 * math.pi * note(0, -1) * np.arange(int(RATE * 2.2)) / RATE)
    grow = np.linspace(0.0, 1.0, len(swell)) ** 0.6
    out = mix(out, swell * grow * np.linspace(1.0, 0.25, len(swell)) * 0.35, 0.0)
    for i, semi in enumerate((0, 4, 7, 12, 16, 19, 24)):
        out = mix(out, bell(note(semi, 1), 1.2, gain=0.92 ** i), 0.09 * i)
    sparkle = np.random.default_rng(7)
    for i in range(14):
        semi = int(sparkle.choice((0, 4, 7, 12, 16)))
        out = mix(
            out,
            bell(note(semi, 2), 0.5, gain=0.22),
            0.75 + 0.09 * i + sparkle.random() * 0.05,
        )
    return write_wav(SFX / "complete.wav", out, -3.0)


def sfx_stars():
    """One ping per star as it lands, rising, so three stars sound like more
    than two without anybody counting."""
    written = []
    for i, semi in enumerate((0, 4, 7)):
        out = bell(note(semi, 2), 0.5, gain=1.0)
        written.append(write_wav(SFX / f"star_{i + 1}.wav", out, -8.0))
    return written


def sfx_reveal():
    """The smoke clearing off a level.

    Noise through a band-pass that sweeps up and opens out, which is a whoosh,
    and one soft bell where the room appears.
    """
    duration = 1.5
    raw = noise(duration, seed=3)
    t = np.linspace(0.0, 1.0, len(raw))
    swept = bandpass(raw, centre=300.0 + 2600.0 * np.sin(t * math.pi) ** 0.7, q=1.6)
    shape = np.sin(t * math.pi) ** 1.4
    out = swept * shape * 0.9
    out = mix(out, bell(note(7, 1), 0.9, gain=0.5), 0.95)
    return write_wav(SFX / "reveal.wav", out, -13.0)


def sfx_tap():
    """A button. Short enough that a child mashing the level list does not
    build a drone out of it."""
    out = silence(0.12)
    out = mix(out, bell(note(9, 1), 0.07, attack=0.002), 0.0)
    return write_wav(SFX / "tap.wav", out, -16.0)


EFFECTS = (sfx_found, sfx_miss, sfx_hint, sfx_complete, sfx_stars, sfx_reveal, sfx_tap)


def build_sfx():
    written = []
    for make in EFFECTS:
        result = make()
        written.extend(result if isinstance(result, list) else [result])
    for path in written:
        print(f"{path.relative_to(ROOT)}  {path.stat().st_size / 1024:.1f} KB")
    return written


# -------------------------------------------------------------------- music --


def prompts():
    data = json.loads(PROMPTS.read_text())
    # Keys starting with an underscore are the notes at the top of the file.
    return {k: v for k, v in data.items() if not k.startswith("_")}


def generate(track, prompt):
    """Asks Lyria for one track and keeps the bytes exactly as they arrived."""
    from google import genai

    client = genai.Client()
    interaction = client.interactions.create(model=MODEL, input=prompt)
    audio = interaction.output_audio
    if audio is None:
        raise SystemExit(f"{track}: the model returned no audio")
    RAW.mkdir(parents=True, exist_ok=True)
    path = RAW / f"{track}.raw.mp3"
    path.write_bytes(base64.b64decode(audio.data))
    return path


def decode(path):
    """mp3 in, mono float samples out."""
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path),
         "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
        check=True, stdout=subprocess.PIPE,
    ).stdout
    return np.frombuffer(raw, dtype="<f4").astype(np.float64)


def encode(signal, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y",
         "-f", "f32le", "-ar", str(RATE), "-ac", "1", "-i", "-",
         "-c:a", "libmp3lame", "-b:a", MUSIC_BITRATE, str(path)],
        check=True, input=signal.astype("<f4").tobytes(),
    )
    return path


def trim(signal, floor_dbfs=-50.0):
    """Drops the silence the model leaves at either end.

    It has to go before the loop is closed: a track that ends in half a second
    of nothing would crossfade that nothing over its own opening bar.
    """
    loud = np.abs(signal) > 10 ** (floor_dbfs / 20.0)
    if not loud.any():
        return signal
    first, last = np.argmax(loud), len(loud) - np.argmax(loud[::-1])
    return signal[first:last]


def close_loop(signal, seconds=LOOP_FADE):
    """Folds the tail back over the head so the track can repeat forever.

    Equal-power rather than linear: two uncorrelated pieces of music summed
    with a straight fade dip in the middle, and the dip is exactly where the
    seam is, which is the one place it must not be heard.
    """
    n = int(RATE * seconds)
    if len(signal) <= n * 2:
        return signal
    head, body, tail = signal[:n], signal[n:-n], signal[-n:]
    t = np.linspace(0.0, 1.0, n)
    seam = head * np.sqrt(t) + tail * np.sqrt(1.0 - t)
    return np.concatenate([seam, body])


def level_out(signal):
    """RMS to the target, then held under the ceiling if that pushed it over."""
    rms = np.sqrt(np.mean(signal ** 2))
    if rms > 0:
        signal = signal * (10 ** (MUSIC_RMS_DBFS / 20.0)) / rms
    peak = np.max(np.abs(signal))
    ceiling = 10 ** (MUSIC_PEAK_DBFS / 20.0)
    if peak > ceiling:
        signal = signal * ceiling / peak
    return signal


def process(track):
    """Raw model output in tools/audio/ to a loopable track in assets/."""
    raw = RAW / f"{track}.raw.mp3"
    if not raw.exists():
        raise SystemExit(f"{track}: no {raw.relative_to(ROOT)} to process")
    out = encode(level_out(close_loop(trim(decode(raw)))), MUSIC / f"{track}.mp3")
    seconds = len(decode(out)) / RATE
    print(
        f"{out.relative_to(ROOT)}  {out.stat().st_size / 1024:.0f} KB  "
        f"{int(seconds) // 60}:{int(seconds) % 60:02d}"
    )
    return out


def build_music(tracks, reprocess):
    catalog = prompts()
    tracks = tracks or list(catalog)
    unknown = [t for t in tracks if t not in catalog]
    if unknown:
        raise SystemExit(
            f"no prompt for {', '.join(unknown)} - add one to "
            f"{PROMPTS.relative_to(ROOT)}"
        )
    for track in tracks:
        if not reprocess:
            print(f"{track}: asking {MODEL} ...", file=sys.stderr)
            generate(track, catalog[track])
        process(track)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("sfx", help="synthesize every sound effect")
    music = sub.add_parser("music", help="generate and post-process the tracks")
    music.add_argument("tracks", nargs="*", help="track ids, default every one")
    music.add_argument(
        "--reprocess",
        action="store_true",
        help="re-run the post-process on the kept model output, calling nothing",
    )
    args = parser.parse_args()
    if args.command == "sfx":
        build_sfx()
    else:
        build_music(args.tracks, args.reprocess)


if __name__ == "__main__":
    main()
