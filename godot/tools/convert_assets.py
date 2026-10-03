#!/usr/bin/env python3
"""Convert the original Pythonista MapMan assets and level data for the Godot port.

Run from the repository root:

    python3 godot/tools/convert_assets.py

It copies the 3x (highest resolution) images into godot/assets, converts the
.caf audio to .ogg (needs ffmpeg), synthesises placeholder sound effects for the
Pythonista built-in sounds the original used, and writes the level data to
godot/data/*.json.
"""

import json
import math
import os
import re
import shutil
import struct
import subprocess
import sys
import wave

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SRC = os.path.join(ROOT, 'Script')
DST = os.path.join(ROOT, 'godot')

IMAGE_DIRS = {
    'Tiles': 'assets/tiles',
    'Effects': 'assets/effects',
    'Man/Idle': 'assets/man/idle',
    'Man/Frames': 'assets/man/frames',
    'Man/Death': 'assets/man/death',
    'Woman/Idle': 'assets/woman/idle',
    'Woman/Frames': 'assets/woman/frames',
    'Vortex': 'assets/vortex',
    'Hearts': 'assets/hearts',
    'Star': 'assets/star',
    'Heart': 'assets/heart',
    'CheckPoint': 'assets/checkpoint',
    'Menu': 'assets/menu',
    'Buttons': 'assets/buttons',
}

MUSIC = {
    'Brexit of Champions (opening).caf': 'menu.ogg',
    'Paris Breakup (end screen).caf': 'game_over.ogg',
    'A Boy named Crystal (mid game).caf': 'game_1.ogg',
    'A trace of empathy (mid game).caf': 'game_2.ogg',
    'Phishing for compliments (mid game).caf': 'game_3.ogg',
    'Questionable Thoughts (mid game).caf': 'game_4.ogg',
    'TOlerate INtolerence (mid game).caf': 'game_5.ogg',
    'Calling it a day (completion scoring).caf': 'completion.ogg',
}


def copy_images():
    for src_dir, dst_dir in IMAGE_DIRS.items():
        src = os.path.join(SRC, src_dir)
        dst = os.path.join(DST, dst_dir)
        os.makedirs(dst, exist_ok=True)
        for name in sorted(os.listdir(src)):
            if name.startswith('3x_') and name.endswith('.png'):
                shutil.copyfile(os.path.join(src, name), os.path.join(dst, name[3:]))
    gdst = os.path.join(DST, 'assets', 'background')
    os.makedirs(gdst, exist_ok=True)
    shutil.copyfile(os.path.join(SRC, 'Gradients', 'MapMan-background-TRANSPARENCY.png'),
                    os.path.join(gdst, 'gradient.png'))


def ffmpeg(src, dst, quality):
    subprocess.check_call(['ffmpeg', '-y', '-loglevel', 'error', '-i', src,
                           '-c:a', 'libvorbis', '-q:a', str(quality), dst])


def convert_audio():
    sfx = os.path.join(DST, 'assets', 'sfx')
    music = os.path.join(DST, 'assets', 'music')
    os.makedirs(sfx, exist_ok=True)
    os.makedirs(music, exist_ok=True)
    for name in ['checkpoint', 'clock', 'love', 'pop']:
        ffmpeg(os.path.join(SRC, 'SoundEffects', name + '.caf'), os.path.join(sfx, name + '.ogg'), 5)
    for src_name, dst_name in MUSIC.items():
        ffmpeg(os.path.join(SRC, 'GameMusic', src_name), os.path.join(music, dst_name), 3)


# --- Placeholder effects for the Pythonista built-in sounds -----------------

RATE = 22050


def write_wav(path, samples):
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b''.join(struct.pack('<h', int(max(-1.0, min(1.0, s)) * 32000)) for s in samples)
        w.writeframes(frames)


def tone(freq_fn, duration, env_fn, wave_fn=math.sin, volume=0.5):
    out = []
    phase = 0.0
    n = int(duration * RATE)
    for i in range(n):
        t = i / RATE
        phase += 2 * math.pi * freq_fn(t) / RATE
        out.append(volume * env_fn(t / duration) * wave_fn(phase))
    return out


def decay(k):
    return lambda p: math.exp(-k * p)


def square(phase):
    return 1.0 if math.sin(phase) >= 0 else -1.0


def noise_burst(duration, k, volume, seed=1):
    import random
    rnd = random.Random(seed)
    n = int(duration * RATE)
    out = []
    last = 0.0
    for i in range(n):
        p = i / n
        last = 0.6 * last + 0.4 * rnd.uniform(-1, 1)
        out.append(volume * math.exp(-k * p) * last)
    return out


def synth_effects():
    sfx = os.path.join(DST, 'assets', 'sfx')
    os.makedirs(sfx, exist_ok=True)
    effects = {
        # reverse tile: springy boing
        'reverse': tone(lambda t: 220 + 180 * math.sin(t * 40), 0.4, decay(5)),
        # vanish / hide tiles: rising sweep
        'vanish': tone(lambda t: 300 + 1500 * t, 0.45, lambda p: math.sin(math.pi * p), volume=0.35),
        # bonus points: two quick coin pings
        'points': tone(lambda t: 1320 if t < 0.07 else 1760, 0.25, decay(6), volume=0.35),
        # extra life: bleep
        'life': tone(lambda t: 880, 0.18, lambda p: 1.0 if p < 0.85 else (1 - p) / 0.15, square, 0.2),
        # sticky tile: low buzz
        'sticky': tone(lambda t: 110, 0.3, lambda p: 1.0 if p < 0.8 else (1 - p) / 0.2, square, 0.25),
        # level end: door thud
        'end_level': [a + b for a, b in zip(tone(lambda t: 90 - 40 * t, 0.35, decay(8), volume=0.7),
                                            noise_burst(0.35, 14, 0.4))],
        # footstep
        'step': noise_burst(0.07, 9, 0.6),
        # score counting ding
        'star': tone(lambda t: 2093, 0.2, decay(10), volume=0.25),
    }
    for name, samples in effects.items():
        write_wav(os.path.join(sfx, name + '.wav'), samples)


# --- Level data ---------------------------------------------------------------

def load_python2_module(path):
    src = open(path).read()
    src = re.sub(r'^(\s*)print (.*)$', r'\1print(\2)', src, flags=re.M)
    namespace = {}
    exec(compile(src, path, 'exec'), namespace)
    return namespace


def level_rows(level_str):
    # The original drops the first line (the newline after the opening quotes).
    return level_str.splitlines()[1:]


def loading_rows(loading_str, rows):
    if loading_str is None:
        return None
    lines = loading_str.splitlines()
    # Align from the bottom, exactly as Map.load_level does.
    return [lines[len(lines) - len(rows) + i] for i in range(len(rows))]


def convert_levels():
    data_dir = os.path.join(DST, 'data')
    os.makedirs(data_dir, exist_ok=True)

    g = load_python2_module(os.path.join(SRC, 'game_levels.py'))
    levels = []
    for number in sorted(g['levels']):
        rows = level_rows(g['levels'][number])
        levels.append({
            'number': number,
            'rows': rows,
            'loading': loading_rows(g['loadings'].get(number), rows),
            'delay': g['delays'].get(number, g['DEFAULT_DELAY']),
            'x_hides': g['x_hides'].get(number, g['DEFAULT_X_HIDES']),
            'checkpoint': number in g['check_points'],
            'message': g['level_messages'].get(number, ''),
        })
    with open(os.path.join(data_dir, 'levels.json'), 'w') as f:
        json.dump({'check_points': g['check_points'], 'levels': levels}, f, indent=1)

    t = load_python2_module(os.path.join(SRC, 'tutorial.py'))
    tutorial = []
    for number in sorted(t['levels']):
        tutorial.append({
            'number': number,
            'rows': level_rows(t['levels'][number]),
            'loading': None,
            'delay': g['DEFAULT_DELAY'],
            'x_hides': g['DEFAULT_X_HIDES'],
            'checkpoint': number in t['checkpoints'],
            'description': t['descriptions'][number],
        })
    with open(os.path.join(data_dir, 'tutorial.json'), 'w') as f:
        json.dump({'levels': tutorial}, f, indent=1)

    # The bonus map after the last level, where MapWoman waits by the vortex.
    rows = level_rows(g['completion'])
    completion = {
        'rows': rows,
        'loading': loading_rows(g['completion_loading'], rows),
        'delay': g['DEFAULT_DELAY'],
        'x_hides': 0,
        'checkpoint': False,
    }
    with open(os.path.join(data_dir, 'completion.json'), 'w') as f:
        json.dump(completion, f, indent=1)

    print('levels: {0}, tutorial: {1}'.format(len(levels), len(tutorial)))


if __name__ == '__main__':
    steps = sys.argv[1:] or ['images', 'audio', 'effects', 'levels']
    if 'images' in steps:
        copy_images()
    if 'audio' in steps:
        convert_audio()
    if 'effects' in steps:
        synth_effects()
    if 'levels' in steps:
        convert_levels()
