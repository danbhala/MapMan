#!/usr/bin/env python3
"""Revision B: the hundred sheets again, mirrored and reworked with the second
playthrough's tiles, written to data/levels_b.json.

    python3 godot/tools/remix.py            # rewrite data/levels_b.json
    python3 godot/tools/remix.py --report   # table: Revision A next to B
    python3 godot/tools/remix.py 16 35      # report just these sheets

Each sheet of data/levels.json (the sheets PR #27 eased use their originals
from tools/remix_originals.json, the cruel versions belong here) is mirrored
left to right, so the shape is familiar but muscle memory is no help, then
plain tiles on the shortest safe route are swapped for crumble `k`, ice `j`
and spikes `^` `%`, more of them the further in. Every swap is on a corridor
tile (two walkable neighbours) so a crumble closes only the way back, an ice
run slides straight through, and a spike can be waited out. Spikes never
stand beside a sticky, reverse or spike tile (one wait never stacks on
another) or near the start; a sheet allowed spikes gets at least one; at most
three crumbles and two ice runs a sheet, and no crumble on a sheet that
lives on its +5 s tiles (it could cut one off); a sheet with no plain tile on its
route (all sticky, reverse or hidden) gets a crumble or two over those. The
result is proved solvable with level_report's solver and kept above a slack
floor: spikes come off again until it is. The level-analyst pass of
2026-10-06 set these rules and tools/remix_overrides.json.

tools/remix_overrides.json hand-tunes a sheet after the rules ran:
{"16": {"budget": 2, "kinds": "kj", "set": {"3,4": "m"}, "note": "..."}}.
`budget` caps the swaps, `kinds` limits which tiles, `set` writes a tile at
column,row (after mirroring) last of all. Rerunning the tool keeps every
override, so tune there, never in levels_b.json by hand.
"""

import json
import os
import random
import sys

import level_report as lr

HERE = os.path.dirname(os.path.abspath(__file__))
LEVELS = os.path.join(HERE, '..', 'data', 'levels.json')
OUT = os.path.join(HERE, '..', 'data', 'levels_b.json')
ORIGINALS = os.path.join(HERE, 'remix_originals.json')
OVERRIDES = os.path.join(HERE, 'remix_overrides.json')

PLAIN = set('czo')
# On a sheet whose route has no plain tile (all sticky, reverse or hidden),
# a crumble or two may stand in for one of these instead.
FALLBACK = set('yri')
MIRROR = {'e': 'w', 'w': 'e', 'E': 'W', 'W': 'E'}
# Never swap the first tiles after the start or the last one before the exit.
LEAD_IN = 2
LEAD_OUT = 1
# Spikes keep further from the start: the player is still finding the tilt.
SPIKE_LEAD_IN = 4
# Spikes never stand next to a tile that already costs a beat (sticky,
# reverse, another spike), so one wait never stacks on another.
NO_SPIKE_BESIDE = set('yr^%')
# Crumbles per sheet: more just closes the sheet behind the player.
MAX_CRUMBLE = 3
# Ice runs per sheet: a third one makes a sheet a luge.
MAX_ICE_RUNS = 2
# A sheet with less slack than this (before its +5 s tiles) lives on them.
TIGHT = 10.0


def kinds_for(n):
    """Which new tiles a sheet may get: crumble first, ice from 4, spikes
    from 9 (the lessons for all three come before Revision B opens)."""
    if n <= 3:
        return 'k'
    if n <= 8:
        return 'kj'
    return 'kj^'


def budget_for(n, moves):
    """How many swaps a sheet gets: one on the first sheets, one more every
    twenty, never more than one tile in five of the route."""
    return max(1, min(6, 1 + (n + 10) // 20, moves // 5))


def slack_floor(n, slack_a):
    """The least slack a Revision B sheet keeps: generous early, tighter late,
    and never more than the sheet had in Revision A."""
    floor = 6.0 if n <= 30 else 4.0 if n <= 60 else 2.5
    return min(floor, slack_a)


def mirror_rows(rows):
    width = max(len(r) for r in rows)
    out = []
    for r in rows:
        flipped = ''.join(MIRROR.get(ch, ch) for ch in r.ljust(width)[::-1])
        out.append(flipped.rstrip())
    return out


def mirror_level(level):
    out = dict(level)
    out['rows'] = mirror_rows(level['rows'])
    if level.get('loading'):
        out['loading'] = mirror_rows(level['loading'])
    return out


def neighbours(cells, p):
    """The tiles around p a player could stand on (death tiles don't count)."""
    return [q for q in ((p[0] + 1, p[1]), (p[0] - 1, p[1]), (p[0], p[1] + 1), (p[0], p[1] - 1))
            if q in cells and cells[q] not in lr.DEATH]


def route_of(cells):
    start = next(k for k, v in cells.items() if v.lower() == 'b')
    return lr.shortest(cells, start, lr.DEATH | {'t'}) or lr.shortest(cells, start, lr.DEATH)


def route_candidates(cells, route):
    """Route positions (indexes) holding a plain tile, clear of the start
    and the exit; `corridor` ones have exactly two walkable neighbours, the
    route's previous and next tiles."""
    plain = []
    corridor = []
    for i in range(LEAD_IN + 1, len(route) - LEAD_OUT - 1):
        p = route[i]
        if cells[p] not in PLAIN:
            continue
        plain.append(i)
        nb = neighbours(cells, p)
        if len(nb) == 2 and set(nb) == {route[i - 1], route[i + 1]}:
            corridor.append(i)
    return plain, corridor


def fallback_candidates(cells, route):
    """A sheet with no plain tile on its route: corridor tiles of its gimmick
    (sticky, reverse, hidden) a crumble may replace."""
    out = []
    for i in range(LEAD_IN + 1, len(route) - LEAD_OUT - 1):
        p = route[i]
        if cells[p] not in FALLBACK:
            continue
        nb = neighbours(cells, p)
        if len(nb) == 2 and set(nb) == {route[i - 1], route[i + 1]}:
            out.append(i)
    return out


def spike_ok(cells, route, i):
    return i > SPIKE_LEAD_IN and all(
        cells[q] not in NO_SPIKE_BESIDE for q in neighbours(cells, route[i]))


def lone_ice_ok(cells, route, i):
    """A single ice tile between sticky tiles slides one tile: not worth it."""
    return ice_safe(cells, route, i) and all(
        cells[route[j]] != 'y' for j in (i - 1, i + 1))


def straight(route, i):
    a, b, c = route[i - 1], route[i], route[i + 1]
    return (b[0] - a[0], b[1] - a[1]) == (c[0] - b[0], c[1] - b[1])


def ice_runs(route, corridor):
    """Runs of 2 to 3 route tiles in a straight corridor: an ice run slides
    from the tile before it to the tile after it."""
    runs = []
    run = []
    for i in corridor:
        if run and i == run[-1] + 1 and straight(route, i):
            run.append(i)
        else:
            if len(run) >= 2:
                runs.append(run[:3])
            run = [i] if straight(route, i) else []
    if len(run) >= 2:
        runs.append(run[:3])
    return runs


def ice_safe(cells, route, i):
    """A lone ice tile on an open sheet: the route must run straight through
    it, and a slide into it from any side must stop on a tile that isn't
    death (or at the edge, on the ice itself)."""
    p = route[i]
    if not straight(route, i):
        return False
    for q in neighbours(cells, p):
        if cells[q] in lr.DEATH:
            continue  # nobody arrives from a death tile
        landing = (2 * p[0] - q[0], 2 * p[1] - q[1])
        if landing in cells and (cells[landing] in lr.DEATH or cells[landing] == 'j'):
            return False
    return True


def apply(cells, route, n, budget, kinds, rng):
    """Swap tiles in `cells` (in place) and return what was placed."""
    plain, corridor = route_candidates(cells, route)
    taken = set()
    placed = []
    if not plain:
        singles = fallback_candidates(cells, route)
        rng.shuffle(singles)
        for i in singles[:min(budget, 2)]:
            cells[route[i]] = 'k'
            placed.append(('k', 1))
        return placed

    def free(i):
        return all(abs(i - j) > 1 for j in taken)

    if 'j' in kinds:
        runs = [r for r in ice_runs(route, corridor) if all(free(i) for i in r)]
        rng.shuffle(runs)
        for run in runs[:min(MAX_ICE_RUNS, budget // 2)]:
            if len(placed) >= budget:
                break
            for i in run:
                cells[route[i]] = 'j'
                taken.add(i)
            placed.append(('j', len(run)))
    singles = list(plain)
    rng.shuffle(singles)
    # Singles take the kinds in turn, so a sheet allowed spikes gets one.
    order = list(kinds)
    rng.shuffle(order)
    wave_ready = '^' in kinds and n > 60
    for i in singles:
        if len(placed) >= budget:
            break
        if not free(i):
            continue
        options = [k for k in kinds
                   if (k != 'j' or lone_ice_ok(cells, route, i))
                   and (k != '^' or spike_ok(cells, route, i))
                   and (k != 'k' or sum(1 for c in cells.values() if c == 'k') < MAX_CRUMBLE)]
        if not options:
            continue
        choice = order[len(placed) % len(order)]
        if '^' in options and not any(k == '^' for k, _ in placed):
            choice = '^'  # a sheet allowed spikes gets one before anything else
        elif choice not in options:
            choice = rng.choice(options)
        if (choice == '^' and wave_ready and (i + 1) in singles and free(i + 1)
                and spike_ok(cells, route, i + 1) and len(placed) + 1 < budget):
            cells[route[i]] = '^'
            cells[route[i + 1]] = '%'
            taken.update((i, i + 1))
            placed += [('^', 1), ('%', 1)]
            continue
        cells[route[i]] = choice
        taken.add(i)
        placed.append((choice, 1))
    return placed


def rows_from(cells, height, width):
    rows = []
    for y in range(height):
        rows.append(''.join(cells.get((x, y), ' ') for x in range(width)).rstrip())
    return rows


def remix(level, overrides, originals):
    n = level['number']
    base = dict(level)
    if str(n) in originals:
        base['rows'] = originals[str(n)]['rows']
        base['loading'] = originals[str(n)].get('loading')
    b = mirror_level(base)
    height = len(b['rows'])
    width = max(len(r) for r in b['rows'])
    cells = lr.grid(b)
    route = route_of(cells)
    over = overrides.get(str(n), {})
    report = lr.analyse(b)
    slack_a = report.get('slack_seconds', 0.0)
    if route:
        rng = random.Random(n * 7919)
        kinds = over.get('kinds', kinds_for(n))
        if slack_a < TIGHT and any(v == 'm' for v in cells.values()):
            # The clock needs the +5 s tiles: a crumble could cut one off.
            kinds = kinds.replace('k', '')
        budget = over.get('budget', budget_for(n, len(route) - 1))
        apply(cells, route, n, budget, kinds, rng)
        b['rows'] = rows_from(cells, height, width)
        # Spikes cost waiting: take them off, last placed first, until the
        # sheet keeps its slack floor.
        floor = slack_floor(n, slack_a)
        while True:
            check = lr.analyse(b)
            if check['solvable'] and check['slack_seconds'] >= floor:
                break
            spiked = [k for k, v in cells.items() if v in lr.SPIKES]
            if not spiked:
                break
            cells[spiked[-1]] = 'c'
            b['rows'] = rows_from(cells, height, width)
    for key, tile in over.get('set', {}).items():
        x, y = (int(v) for v in key.split(','))
        cells[(x, y)] = tile
        b['rows'] = rows_from(cells, height, width)
    b['message'] = ''
    return b


def build(levels, overrides, originals):
    return [remix(lv, overrides, originals) for lv in levels]


def report(levels_a, levels_b, wanted):
    head = ['lvl', 'A moves', 'A slack', 'B moves', 'B slack', 'B new tiles', 'solvable']
    print(' | '.join(head))
    print(' | '.join('---' for _ in head))
    for a, b in zip(levels_a, levels_b):
        if wanted and a['number'] not in wanted:
            continue
        ra, rb = lr.analyse(a), lr.analyse(b)
        tiles = ''.join(b['rows'])
        new = '{0}k {1}j {2}^'.format(tiles.count('k'), tiles.count('j'),
                                      tiles.count('^') + tiles.count('%'))
        print(' | '.join(str(v) for v in [
            a['number'], ra.get('moves', '-'), ra.get('slack_seconds', '-'),
            rb.get('moves', '-'), rb.get('slack_seconds', '-'), new,
            'yes' if rb['solvable'] else 'NO']))


def main(argv):
    levels = lr.load_levels(LEVELS)
    with open(LEVELS) as f:
        check_points = json.load(f)['check_points']
    with open(ORIGINALS) as f:
        originals = json.load(f)['levels']
    overrides = {}
    if os.path.exists(OVERRIDES):
        with open(OVERRIDES) as f:
            overrides = {k: v for k, v in json.load(f).items() if not k.startswith('_')}
    levels_b = build(levels, overrides, originals)
    wanted = {int(a) for a in argv if a.isdigit()}
    if '--report' in argv or wanted:
        report(levels, levels_b, wanted)
        return
    with open(OUT, 'w') as f:
        json.dump({'check_points': check_points, 'levels': levels_b}, f, indent=1)
    unsolvable = [lv['number'] for lv in levels_b if not lr.analyse(lv)['solvable']]
    print('wrote {0} sheets to {1}'.format(len(levels_b), os.path.relpath(OUT)))
    if unsolvable:
        print('UNSOLVABLE: {0}'.format(unsolvable))
        sys.exit(1)


if __name__ == '__main__':
    main(sys.argv[1:])
