#!/usr/bin/env python3
"""Builds data/journeys.json from the room drawings below (research prototype).

A journey is one big sheet cut into screen-sized rooms. Rooms sit on a grid;
a path that runs off one room's edge carries straight on into the next.
Tiles as in levels.json, plus K (key) and D (locked door).
"""
import json
import pathlib
from collections import deque

W, H = 15, 8  # room size in tiles

JOURNEYS = [
    {
        "name": "the long way round",
        "rooms": {
            # (room column, room row): drawing
            (0, 1): [  # A: start, and the locked door by the exit
                "---------------",
                "-wDcccccp------",
                "-------c-------",
                "--cccc-c-------",
                "--c--cccccccccc",
                "--c------------",
                "-bc------------",
                "---------------",
            ],
            (1, 1): [  # B: hidden bridges; cross it there and back from memory
                "----------c----",
                "--ccc-----c----",
                "--c-c-c-cic!---",
                "--!-!-c!c--cc--",
                "chcic!c!i---c--",
                "----c---c---c--",
                "-cc!iccic!ccc--",
                "---------------",
            ],
            (1, 0): [  # C: the key
                "---------------",
                "--Kcccd-cccc---",
                "--d--cc-c--c---",
                "--ccdc--cd-c---",
                "---c-cccc--cc--",
                "---cccd-d---c--",
                "----------ccc--",
                "----------c----",
            ],
        },
    }
]


def build(j):
    cols = max(c for c, _ in j["rooms"]) + 1
    rows = max(r for _, r in j["rooms"]) + 1
    world = [["-"] * (cols * W) for _ in range(rows * H)]
    for (rc, rr), art in j["rooms"].items():
        assert len(art) == H and all(len(line) == W for line in art), (rc, rr)
        for y, line in enumerate(art):
            for x, ch in enumerate(line):
                world[rr * H + y][rc * W + x] = ch
    text = ["".join(r) for r in world]
    start = next((x, y) for y, r in enumerate(text) for x, ch in enumerate(r) if ch == "b")
    start_room = (start[0] // W, start[1] // H)
    # The start room draws on from the start tile outwards; the other rooms
    # pop in together, off screen, as one last group.
    loading = []
    for y, r in enumerate(text):
        line = ""
        for x, ch in enumerate(r):
            if (x // W, y // H) == start_room and ch not in "- ":
                d = abs(x - start[0]) + abs(y - start[1])
                line += "0123456789abcdefghijklmnopqrstuvwxy"[min(d, 34)]
            else:
                line += "z"
        loading.append(line)
    check(text)
    return {
        "name": j["name"],
        "room_size": [W, H],
        "rows": text,
        "loading": loading,
        "delay": 0.03,
        "x_hides": 25,
        "checkpoint": False,
        "message": "",
    }


def check(text):
    """The key is reachable, and the exit is reachable once the door is open."""
    def bfs(src, door_open):
        seen, q = {src}, deque([src])
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= ny < len(text) and 0 <= nx < len(text[0])):
                    continue
                ch = text[ny][nx]
                if (nx, ny) in seen or ch in "-! d" or (ch == "D" and not door_open):
                    continue
                seen.add((nx, ny))
                q.append((nx, ny))
        return seen

    find = lambda c: next((x, y) for y, r in enumerate(text) for x, ch in enumerate(r) if ch == c)
    start, key = find("b"), find("K")
    assert key in bfs(start, False), "key unreachable"
    assert find("w") not in bfs(start, False), "exit reachable without the door"
    assert find("w") in bfs(start, True), "exit unreachable"


out = pathlib.Path(__file__).resolve().parent.parent / "data" / "journeys.json"
out.write_text(json.dumps({"journeys": [build(j) for j in JOURNEYS]}, indent=1) + "\n")
print("wrote", out)
