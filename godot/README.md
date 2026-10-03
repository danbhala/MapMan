# MapMan for Godot 4

A port of MapMan from Pythonista to Godot 4.5 (GDScript). This first pass covers the playable core: all 100 levels, the 12-level tutorial, every tile type, lives, score, the countdown, checkpoints and the main menus, using the original art and music.

## Running it

Open this `godot` folder in Godot 4.5 (or later) and press Play. The first open takes a moment while Godot imports the assets.

| Action | Phone / tablet | Desktop |
| --- | --- | --- |
| Move | Tilt the device | Arrow keys or WASD, a gamepad, or hold the mouse button down near a screen edge |
| Free MapMan from a sticky tile | Shake | Space, or click |
| Pause | Tap the screen | Esc or P |

Tilt is calibrated automatically when each level starts, so whatever angle you're holding the phone at becomes "level". This replaces the original's sitting/standing option. If tilting steers the wrong way on a real device, flip `INVERT_X` / `INVERT_Y` at the top of `scripts/tilt_input.gd`.

## Dev builds

"MapMan Dev" is a second app that installs alongside the real one, with its own save. It has a **DEV** button (top right) that opens:

- level select and skip level
- unlimited time and unlimited lives
- a live tilt gauge, and sliders for how much tilt starts a move, how much gives full speed and how hard to shake; settings are saved on the phone and can be copied as text
- a play log of attempts, deaths and timeouts per level, copied as text for `tools/playlog_report.py`

The build and commit it came from are shown under the DEV button. Running the project from the Godot editor also has the dev tools.

## What's where

- `scripts/main.gd` – game flow and the per-frame movement and tile rules (from `map_man.py`)
- `scripts/level_map.gd` – tile grid, loading animation, tile effects (from `map.py`)
- `scripts/player.gd` – MapMan's animation (from `player.py`)
- `scripts/tilt_input.gd` – tilt, shake, keys and touch steering (from `shake.py`)
- `scripts/hud.gd`, `scripts/menus.gd` – top stats, bottom bar, menus
- `scripts/save.gd`, `scripts/audio.gd` – autoloads for saved progress, effects and music
- `data/levels.json`, `data/tutorial.json` – level data converted from `game_levels.py` and `tutorial.py`
- `tools/convert_assets.py` – regenerates `assets/` and `data/` from the original `Script/` folder

## Differences from the original

- In-app purchases, rating prompts and score tweeting are gone; checkpoints are free.
- The ending sequence (MapWoman, vortex and hearts) isn't ported yet. Finishing level 100 goes to the completion scoring and congratulations screens.
- Credits and the first-run file-copy startup screen aren't ported.
- Several sound effects were Pythonista built-ins that can't be shipped, so `tools/convert_assets.py` synthesises simple stand-ins (`assets/sfx/*.wav`). Swap in better ones whenever you like.
- Progress is stored in `user://mapman.cfg` instead of dot-files.

## Tests

Everything runs from one script (Godot 4.5 as `godot` on your PATH, or set `GODOT`):

```
godot/tools/verify.sh          # lint, import, unit tests, first 10 levels, screenshots
godot/tools/verify.sh --full   # same, playing all 100 levels
```

- `tests/unit/` – [GUT](https://github.com/bitwes/Gut) unit tests, one per tile rule (GUT 9.5 lives in `addons/gut`).
- `tests/autoplay_test.gd` – a bot walks the tutorial and every level, then checks losing lives, game over and pausing.
- `tests/screenshots.gd` – renders ten screens and compares them with `tests/baseline/` (needs a display or `xvfb-run`).
- `tools/level_report.py` – route length and spare seconds for every level.

Linting uses [gdtoolkit](https://pypi.org/project/gdtoolkit) (`pip install "gdtoolkit==4.*"`). GitHub Actions runs the full check on every push and pull request.

## Working with Claude

The repo is set up for Claude Code: `CLAUDE.md` files describe the project, `.claude/skills/` holds `/verify`, `/new-level`, `/new-tile`, `/build-apk`, `/commit` and `/open-pr`, `.claude/agents/` holds the level-analyst, playtester and reviewer agents, a hook lints every GDScript edit, and `.mcp.json` adds the [godot-mcp](https://github.com/Coding-Solo/godot-mcp) server (set `GODOT_PATH` if Godot isn't found automatically).
