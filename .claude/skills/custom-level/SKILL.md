---
name: custom-level
description: Design a one-off MapMan level from someone's description and hand it back as a level code and a QR to scan, without touching the campaign. Use when someone describes a level or map they want to play or share ("make me a spiral level", "a hard level shaped like a heart", "a level code for my kid") and wants a code or QR.
argument-hint: "[what the level should look like or feel like]"
---

# A custom level as a code and a QR

The drafting table (`docs/drafting-table.md`) turns any level into a short
code, and a phone plays it by scanning the QR or pasting the code. This skill
draws such a level from a description. Nothing in the repo changes: the
level lives in its code. (To add a level to the campaign, use `/new-level`.)

`godot/tools/level_qr.gd` does the mechanical part with the game's own code:
it checks the level the way the editor does, finds the safe route with the
assists' solver, prints the code, a picture and the numbers, writes the QR
and reads it back.

## 1. Ask only what's missing

Read the request first. If it already settles the shape and the difficulty,
or says "surprise me", ask nothing and use the defaults. Otherwise ask once,
in one message, at most three short questions, each with its default so a
one-word answer (or "go") works:

| Question | Default |
| --- | --- |
| Shape or theme (spiral, letter, heart, maze, their name...) | a winding maze |
| Difficulty: easy, medium or hard | medium |
| Size: small (about 9 × 6), medium (13 × 9) or full (17 × 12) | what the shape needs |
| Tiles to use or leave out (no ice, lots of stars...) | the difficulty's set below |

Never theme a level on MapWoman or hint that she exists, and don't reveal
other secrets of the game in a level, its name or the message around it.

## 2. Design the rows

A level is up to 12 rows of up to 17 characters, top row first, the same
characters as `godot/data/levels.json` (full legend in `/new-level`):

| Char | Tile | Char | Tile |
| --- | --- | --- | --- |
| `b` | start, exactly one | `n` `e` `s` `w` | exit, at least one |
| `c` | path | space | nothing (a wall) |
| `p` | star (off the route makes a good detour) | `l` | extra life |
| `m` / `t` | +5 s / -5 s on the 20 s clock | `d` | death tile |
| `y` | sticky: shake the phone to get off | `r` | reverse: flips the controls |
| `k` | crumbles behind him | `j` | ice: slides on to a non-ice tile |
| `^` / `%` | spikes, deadly while up (2 s beat, `%` off-beat) | `v` / `x` / `1`-`9` | he turns invisible for 5 / 25 / N moves |
| `h` / `u` | hide / unhide the tiles below | `i` `@` `!` `+` | path, star, death, life that `h` hides |

How MapMan moves shapes the drawing:

- He steps between tiles that touch side by side; diagonals don't connect.
  Two corridors drawn next to each other become one wide area, so leave a
  row or column of spaces between parallel paths (the spiral below does).
- A firm tilt carries him along a straight row, so death tiles at the end of
  a straight run or on the outside of a corner are the hard ones.
- He has 20 seconds. `slack` (the tool prints it) is what's left on the
  shortest safe route at full tilt; under zero needs `m` tiles.
- A dead-end branch with a `p` at the end is the gentlest way to add play.

Difficulty, in concrete terms:

| | Easy | Medium | Hard |
| --- | --- | --- | --- |
| Route (steps) | up to ~35 | ~30-60 | ~50-90 |
| Slack | over 12 s | 6-12 s | 2-6 s, or needs `m` |
| Hazards | none, maybe one `t` off the route | 1-3 `d` at corners, a `t` shortcut trap, one or two of `k` `j` `^` | `d` along straight runs, `^`/`%` on the route, `r`, `y`, `h` with `i`/`!` |
| Extras | 2-4 `p`, maybe an `l` | stars on detours, one `m` | stars next to hazards, vanish tiles |

## 3. Check it and make the code

Write the rows to a text file, one row per line (trailing spaces don't
matter). Put files for Dan under `/mnt/project-files/level-codes/` (make the
folder if needed; elsewhere, use the scratchpad), named after the level,
never over an existing file:

```
godot --headless --path godot -s tools/level_qr.gd -- \
  /mnt/project-files/level-codes/<name>.txt /mnt/project-files/level-codes/<name>-qr.png
```

Use absolute paths. On a fresh checkout, import first
(`godot --headless --path godot --import`, again if it crashes). For tiles
that start hidden, give a JSON file instead: `{"rows": [...], "loading":
[...]}` with `*` in `loading` over each hidden tile. The tool also takes a
code in place of the file, to check or redraw a code someone sent.

It exits 1 with the reason when the level isn't one the editor could share
(unknown tile, over 17 × 12, not exactly one `b`, no exit, no safe route
from `b` to an exit, a code that doesn't read back, a QR that doesn't scan).
Fix the rows and run it again. Otherwise it prints the level beside its
route (`o`), then `size`, `route` (steps and slack), what's on the route,
every tile used, the code length, the `CODE` line and the QR's check.

Compare the numbers with the difficulty asked for and adjust: lengthen or
shorten the route, move a hazard onto or off it. Codes over 64 characters
still work but are long to type; trimming rarely used tile types and
repeated patterns shortens them.

## 4. Hand it back

- The code exactly as the `CODE` line prints it (`MAPMAN XXXX-XXXX-...`),
  and the `LINK` line, which is what the QR holds.
- The QR PNG's path (attach it when the session can attach files).
- The level as a code block (the tool's left-hand picture, or the rows), a
  name for it, and one line on what makes it tick ("the short way costs you
  5 seconds; the long way slides across the ice").
- How to play it: scan the QR with the phone's camera (or tap the link) and
  press OPEN IN MAPMAN on the page; or in MapMan, DRAFTING TABLE (open after
  level 11) → SCAN A QR CODE or ENTER A LEVEL CODE; or copy the code and
  open MapMan, which offers it from the clipboard.

## Worked example: the spiral

"Make me a spiral level." Shape given; difficulty defaults to medium, so no
questions. A 13 × 9 spiral in from the top-left corner, corridors a space
apart, stars along the way and an `m` on the way in:

```
bccccccccccpc
            c
ccccccccpcc c
m         c c
c cccccce c c
c c       c c
p cccpccccc c
c           c
cccccccccpccc
```

The tool reports `route 68 steps, slack 17.1 s` (one long walk, gentle on
time: medium for its length, easy on hazards) and

```
CODE  MAPMAN 0S01-6SZK-476Z-CV1S-3E6R-79E6-QS87-FQZ5-CT5D-S4NT-ZPR
LINK  https://danbhala.github.io/MapMan/0S01-6SZK-476Z-CV1S-3E6R-79E6-QS87-FQZ5-CT5D-S4NT-ZPR
QR    .../spiral-qr.png (version 6, ...), reads back: https://danbhala.github.io/MapMan/0S01-...
```

To make it harder, put `d` tiles on the outside of the spiral's corners and
a `t` on the last stretch before the exit.
