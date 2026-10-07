"""Check a turn level: which tiles are next to which, from each side.

The rule of the turn levels (research/3d, fez3d.gd): the sheet is seen
square on, without perspective, from one of four sides, tilted 45 degrees.
A tile lands on screen cell (column, row), and MapMan can step to any tile
in a neighbouring cell that is at most one step higher or lower. When two
tiles share a cell, he steps to the one nearest to him in space. Stepping
onto a turn tile ("o") turns the sheet a quarter turn clockwise, once: a
turn tile is spent after that, like a crumble tile.

    python3 turn_solver.py            # solves the levels below
"""

from collections import deque

# [x, height, z, type]
LEVELS = {
    "bridge": [
        [0, 0, 5, "b"], [1, 0, 5, "c"], [2, 0, 5, "c"], [3, 0, 5, "o"],
        [5, 1, 5, "c"], [6, 1, 5, "p"], [7, 1, 5, "c"], [8, 1, 5, "c"],
        [8, 0, 5, "e"],
    ],
    "circle": [
        # Leg 1, on the paper. The flag is in the same screen cell as the start.
        [0, 0, 0, "b"], [1, 0, 0, "c"], [2, 0, 0, "c"], [3, 0, 0, "o"],
        # Leg 2, seen from the right: a flat row that is really a staircase.
        [4, 1, -1, "c"], [5, 2, -2, "p"], [6, 3, -3, "c"], [7, 4, -4, "o"],
        # Leg 3, seen from the back: a walkway along the top.
        [7, 4, -5, "c"], [6, 4, -5, "c"], [5, 4, -5, "c"], [4, 4, -5, "p"],
        [3, 4, -5, "c"], [2, 4, -5, "c"], [1, 4, -5, "c"], [0, 4, -5, "o"],
        # Leg 4, seen from the left: down the screen to the flag, which sits
        # four steps above the start.
        [0, 4, -4, "c"], [0, 4, -3, "c"], [0, 4, -2, "p"], [0, 4, -1, "c"],
        [0, 4, 0, "c"], [0, 4, 1, "c"], [0, 4, 2, "c"], [0, 4, 3, "c"],
        [0, 4, 4, "e"],
    ],
}


def cell(tile, view):
    """Screen cell of a tile from a side (0 front, 1 right, 2 back, 3 left)."""
    x, h, z, _ = tile
    if view == 0:
        return (x, z - h)
    if view == 1:
        return (-z, x - h)
    if view == 2:
        return (-x, -z - h)
    return (z, -x - h)


def dist(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])


def neighbours(level, i, view):
    """Tiles MapMan can step to from tile i, seen from `view`."""
    here = level[i]
    c = cell(here, view)
    out = []
    for dc in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
        target = (c[0] + dc[0], c[1] + dc[1])
        there = [
            j
            for j, t in enumerate(level)
            if cell(t, view) == target and abs(t[1] - here[1]) <= 1 and t[3] != "d"
        ]
        if there:
            out.append(min(there, key=lambda j: dist(level[j], here)))
    return out


def solve(level):
    """Shortest way from the start to the exit, as (tile, view) states."""
    start = next(i for i, t in enumerate(level) if t[3] == "b")
    first = (start, 0, frozenset())
    prev = {first: None}
    queue = deque([first])
    while queue:
        state = queue.popleft()
        i, view, spent = state
        if level[i][3] in "nsew":
            path = []
            s = state
            while s is not None:
                path.append(s[:2])
                s = prev[s]
            return path[::-1]
        for j in neighbours(level, i, view):
            nxt = (j, view, spent)
            if level[j][3] == "o" and j not in spent:
                nxt = (j, (view + 1) % 4, spent | {j})
            if nxt not in prev:
                prev[nxt] = state
                queue.append(nxt)
    return None


def shared_cells(level, view):
    seen = {}
    for t in level:
        seen.setdefault(cell(t, view), []).append(t)
    return {c: ts for c, ts in seen.items() if len(ts) > 1}


if __name__ == "__main__":
    for name, level in LEVELS.items():
        print(f"== {name}: {len(level)} tiles")
        for view, side in enumerate(["front", "right", "back", "left"]):
            shared = shared_cells(level, view)
            print(f"  {side}: {len(shared)} shared cells", shared if shared else "")
        path = solve(level)
        if path is None:
            print("  NO WAY THROUGH")
            continue
        steps = sum(1 for a, b in zip(path, path[1:]) if a[0] != b[0])
        turns = sum(1 for a, b in zip(path, path[1:]) if a[1] != b[1])
        print(f"  solved in {steps} steps and {turns} turns:")
        for i, view in path:
            x, h, z, ty = level[i]
            print(f"    {ty} at x={x:2d} h={h} z={z:3d}  seen from {['front','right','back','left'][view]}")
