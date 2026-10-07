#!/usr/bin/env python3
"""Per-level difficulty numbers for MapMan, from data/levels.json.

    python3 godot/tools/level_report.py            # table of every level
    python3 godot/tools/level_report.py --json     # same data as JSON
    python3 godot/tools/level_report.py 35 43      # just these levels
    python3 godot/tools/level_report.py --rev-b    # data/levels_b.json instead
    python3 godot/tools/level_report.py --file p   # any levels file

For each level it finds the shortest safe route (never touching a death
tile, avoiding time-loss tiles when it can) and estimates how much of the
20-second clock that route uses. "slack" below zero means the level can only
be finished by picking up extra-time tiles or moving at full tilt the whole way.
Used by the level-analyst subagent; needs only the Python standard library.
"""

import json
import os
import sys
from collections import Counter, deque

HERE = os.path.dirname(os.path.abspath(__file__))
LEVELS = os.path.join(HERE, '..', 'data', 'levels.json')
LEVELS_B = os.path.join(HERE, '..', 'data', 'levels_b.json')

CLOCK = 20.0
FAST_STEP = 7.0 / 60.0      # seconds per tile at a firm tilt (main.gd STOP_TIME / 2)
TIME_TILE = 5.0
SPIKE_WAIT = 1.0            # seconds a spike tile on the route costs, waiting for a gap
SPIKES = set('^%')
ENDS = set('nsewNSEW')
DEATH = set('d!')
EMPTY = set(' -')


def grid(level):
    cells = {}
    for y, row in enumerate(level['rows']):
        for x, ch in enumerate(row):
            if ch not in EMPTY:
                cells[(x, y)] = ch
    return cells


def shortest(cells, start, avoid):
    prev = {start: None}
    queue = deque([start])
    while queue:
        cur = queue.popleft()
        if cells[cur] in ENDS:
            path = []
            while cur is not None:
                path.append(cur)
                cur = prev[cur]
            return path[::-1]
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            visited = slide(cells, cur, d)
            if not visited or any(cells[v] in avoid for v in visited):
                continue
            nxt = visited[-1]
            if nxt not in prev:
                prev[nxt] = cur
                queue.append(nxt)
    return None


def slide(cells, cur, d):
    """The tiles a step from cur in direction d visits: one, or more across
    ice ('j'), where MapMan slides on until a tile that isn't ice stops him."""
    visited = []
    x, y = cur
    while True:
        nxt = (x + d[0], y + d[1])
        if nxt not in cells or cells[nxt] in ' -':
            break
        visited.append(nxt)
        x, y = nxt
        if cells[nxt] != 'j':
            break
    return visited


def crossed(path):
    """Every tile the route passes over, the ones slid across on ice included
    (path holds only where each move lands)."""
    out = []
    for a, b in zip(path, path[1:]):
        d = ((b[0] > a[0]) - (b[0] < a[0]), (b[1] > a[1]) - (b[1] < a[1]))
        p = a
        while p != b:
            p = (p[0] + d[0], p[1] + d[1])
            out.append(p)
    return out


def analyse(level):
    cells = grid(level)
    start = next(k for k, v in cells.items() if v.lower() == 'b')
    path = shortest(cells, start, DEATH | {'t'}) or shortest(cells, start, DEATH)
    counts = Counter(cells.values())
    result = {
        'level': level['number'],
        'tiles': len(cells),
        'checkpoint': level.get('checkpoint', False),
        'solvable': path is not None,
    }
    if path is None:
        return result
    on_path = Counter(cells[p] for p in path[1:])
    moves = len(path) - 1
    spikes = sum(on_path[s] for s in SPIKES)
    slack = (CLOCK - moves * FAST_STEP - TIME_TILE * on_path['t'] + TIME_TILE * on_path['m']
             - SPIKE_WAIT * spikes)
    result.update({
        'moves': moves,
        'time_loss_on_route': on_path['t'],
        'extra_time_on_route': on_path['m'],
        'extra_time_available': counts['m'],
        'sticky_on_route': on_path['y'],
        'reverse_on_route': on_path['r'],
        'spikes_on_route': spikes,
        'crumble_on_route': on_path['k'],
        'ice_on_route': sum(1 for p in crossed(path) if cells[p] == 'j'),
        'stars_available': counts['p'] + counts['@'],
        'deaths': counts['d'] + counts['!'],
        'slack_seconds': round(slack, 1),
        'needs_extra_time': slack < 0,
    })
    return result


def load_levels(path=LEVELS):
    with open(path) as f:
        return json.load(f)['levels']


def main(argv):
    as_json = '--json' in argv
    wanted = {int(a) for a in argv if a.isdigit()}
    path = LEVELS_B if '--rev-b' in argv else LEVELS
    if '--file' in argv:
        path = argv[argv.index('--file') + 1]
    levels = load_levels(path)
    rows = [analyse(lv) for lv in levels if not wanted or lv['number'] in wanted]
    if as_json:
        print(json.dumps(rows, indent=1))
        return
    head = ['lvl', 'moves', 'slack s', 't on route', 'm avail', 'sticky', 'reverse', 'new', 'stars', 'deaths', 'cp']
    print(' | '.join(head))
    print(' | '.join('---' for _ in head))
    for r in rows:
        if not r['solvable']:
            print('{0} | UNSOLVABLE'.format(r['level']))
            continue
        flag = ' !' if r['needs_extra_time'] else ''
        print(' | '.join(str(v) for v in [
            r['level'], r['moves'], '{0}{1}'.format(r['slack_seconds'], flag),
            r['time_loss_on_route'], r['extra_time_available'], r['sticky_on_route'],
            r['reverse_on_route'],
            '{0}k {1}j {2}^'.format(r['crumble_on_route'], r['ice_on_route'], r['spikes_on_route']),
            r['stars_available'], r['deaths'],
            'yes' if r['checkpoint'] else '']))


if __name__ == '__main__':
    main(sys.argv[1:])
