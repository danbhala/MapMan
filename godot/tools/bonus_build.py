#!/usr/bin/env python3
"""Builds data/bonus.json: one long bonus roll (research prototype).

The sheet scrolls left on its own and MapMan has to keep up. Drawn as runs of
path; p = star, d = death, y = sticky, r = reverse, l = extra life.
"""
import json
import pathlib

ROWS, COLS = 9, 104
g = [["-"] * COLS for _ in range(ROWS)]


def h(row, x0, x1, ch="c"):
    for x in range(x0, x1 + 1):
        g[row][x] = ch


def v(col, y0, y1, ch="c"):
    for y in range(min(y0, y1), max(y0, y1) + 1):
        g[y][col] = ch


def put(x, y, ch):
    assert g[y][x] != "-", (x, y, "not on the path")
    g[y][x] = ch


def stars(row, x0, x1, step=1):
    for x in range(x0, x1 + 1, step):
        if g[row][x] == "c":
            g[row][x] = "p"


# Warm up: one lane, a line of stars.
h(4, 1, 14)
stars(4, 5, 13)
# Split: stars on the top lane past two death tiles (step round them),
# a safe bottom lane with few.
v(14, 1, 7)
h(1, 14, 34)
h(7, 14, 34)
for x in (20, 27):
    put(x, 1, "d")
    h(2, x - 1, x + 1)
stars(1, 15, 33)
stars(2, 15, 33)
stars(7, 18, 30, 6)
# Rejoin into the middle; a cobweb in the way.
v(34, 1, 7)
h(4, 34, 46)
put(40, 4, "y")
stars(4, 36, 45, 2)
# Zigzag.
v(46, 1, 4)
h(1, 46, 50)
v(50, 1, 7)
h(7, 50, 54)
v(54, 1, 7)
h(1, 54, 58)
v(58, 1, 7)
stars(1, 47, 49)
stars(7, 51, 53)
stars(1, 55, 57)
# Mirror run: a reverse tile flips the controls for the middle lane,
# a second one flips them back; the bottom lane is plain.
h(4, 58, 80)
h(7, 58, 80)
put(62, 4, "r")
put(74, 4, "r")
stars(4, 63, 73)
stars(7, 64, 76, 4)
# Home straight with an extra life on a short spur, then the finish.
v(80, 4, 7)
h(4, 80, 101)
v(90, 2, 4)
put(90, 2, "l")
stars(4, 82, 100, 3)
g[4][102] = "e"
g[4][1] = "b"

rows = ["".join(r) for r in g]
level = {
    "name": "bonus roll",
    "scroll": [1.8, 3.2],  # tiles per second at the start and at the end
    "rows": rows,
    "delay": 0.004,
    "x_hides": 25,
    "checkpoint": False,
    "message": "",
}
out = pathlib.Path(__file__).resolve().parent.parent / "data" / "bonus.json"
out.write_text(json.dumps(level, indent=1) + "\n")
print("\n".join(rows))
print("stars:", sum(r.count("p") for r in rows))
