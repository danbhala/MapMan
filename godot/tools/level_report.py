#!/usr/bin/env python3
"""Per-level difficulty numbers for MapMan, from data/levels.json.

    python3 godot/tools/level_report.py            # table of every level
    python3 godot/tools/level_report.py --json     # same data as JSON
    python3 godot/tools/level_report.py 35 43      # just these levels

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

CLOCK = 20.0
FAST_STEP = 7.0 / 60.0      # seconds per tile at a firm tilt (main.gd STOP_TIME / 2)
TIME_TILE = 5.0
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
        x, y = cur
        for nxt in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if nxt in cells and nxt not in prev and cells[nxt] not in avoid:
                prev[nxt] = cur
                queue.append(nxt)
    return None


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
    slack = CLOCK - moves * FAST_STEP - TIME_TILE * on_path['t'] + TIME_TILE * on_path['m']
    result.update({
        'moves': moves,
        'time_loss_on_route': on_path['t'],
        'extra_time_on_route': on_path['m'],
        'extra_time_available': counts['m'],
        'sticky_on_route': on_path['y'],
        'reverse_on_route': on_path['r'],
        'stars_available': counts['p'] + counts['@'],
        'deaths': counts['d'] + counts['!'],
        'slack_seconds': round(slack, 1),
        'needs_extra_time': slack < 0,
    })
    return result


def main(argv):
    as_json = '--json' in argv
    wanted = {int(a) for a in argv if a.isdigit()}
    with open(LEVELS) as f:
        levels = json.load(f)['levels']
    rows = [analyse(lv) for lv in levels if not wanted or lv['number'] in wanted]
    if as_json:
        print(json.dumps(rows, indent=1))
        return
    head = ['lvl', 'moves', 'slack s', 't on route', 'm avail', 'sticky', 'reverse', 'stars', 'deaths', 'cp']
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
            r['reverse_on_route'], r['stars_available'], r['deaths'],
            'yes' if r['checkpoint'] else '']))


if __name__ == '__main__':
    main(sys.argv[1:])
