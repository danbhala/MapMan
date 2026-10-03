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

The autoplay test walks every tutorial and game level along a safe path, then checks losing lives, game over and pausing:

```
godot --headless --path godot --script res://tests/autoplay_test.gd
```

`tests/screenshots.gd` captures the main screens (needs a display, e.g. `xvfb-run`).
