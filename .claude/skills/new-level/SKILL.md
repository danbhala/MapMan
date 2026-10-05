---
name: new-level
description: Add, edit or rebalance a MapMan level in godot/data/levels.json and prove it is solvable. Use when asked to design, change, fix or tune a level or its difficulty.
argument-hint: "[level number or description]"
---

Levels live in `godot/data/levels.json` (the original Pythonista levels in
`Script/game_levels.py` are a frozen reference; don't edit them).

## Level format

Each level: `number`, `rows` (top row first, at most 12 rows of at most 17
characters), optional `loading` (same shape as `rows`; tiles appear in the
sort order of their loading character, `*` = start hidden), `delay` (seconds
between appear groups, default 0.05), `x_hides` (moves an `x` tile hides
MapMan, default 25), `checkpoint` (bool; also list it in `check_points`),
`message` (shown in the bar for the first 5 seconds; it is shown through
`tr()`, uppercased, so add it to `godot/i18n/catalog.json` and every
`godot/i18n/<locale>.json` and run `python3 godot/tools/i18n.py`).

| Char | Tile | Char | Tile |
| --- | --- | --- | --- |
| `b` | start (exactly one) | `n s e w` (any case) | exit, at least one |
| `c` `z` `o` | plain tile | ` ` or `-` | empty, blocks movement |
| `i` | invisible when tiles are hidden | `h` / `u` | hide / unhide `i @ ! +` tiles |
| `p` / `@` | bonus star (`@` hideable) | `l` / `+` | extra life (`+` hideable) |
| `d` / `!` | death (`!` hideable) | `y` | sticky, shake to escape |
| `r` | reverse controls | `v` / `x` / `1`-`9` | vanish for 5 / x_hides / N moves |
| `m` / `t` | +5 s / -5 s on the 20 s clock | `k` | crumbles once stepped off; back after a lost life |
| `^` / `%` | spikes on a 2 s beat (`%` half a beat behind); deadly while up | | |

## Steps

1. Read the neighbouring levels so difficulty ramps smoothly.
2. Edit the JSON. Keep the 100-level count unless the user asks otherwise;
   inserting a level renumbers everything after it and shifts checkpoints.
3. Run `python3 godot/tools/level_report.py <numbers>` and check the level is
   solvable and that `slack s` (seconds to spare on the shortest safe route at
   full tilt) fits the intent. Below zero means it needs `m` tiles.
4. Run the `/verify` skill with `--full` so the autoplay test walks every level.
5. Show the new layout as a code block and the report line for it.
