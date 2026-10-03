# MapMan in Godot

Godot 4.5, typed GDScript only, mobile renderer, 667×375 base viewport,
landscape. Your training data skews to Godot 3: no `yield`, `KinematicBody2D`,
`export var`, `onready var` or `instance()`.

## Architecture

- `scripts/main.gd` owns game flow and state. Tile rules live only in
  `update_player()`; movement in `move_player()` / `_try_axis()`.
- `scripts/level_map.gd` owns the tile grid, loading animation and per-tile
  effect state. Grid keys are `Vector2i(column, row)`, row 0 at the top.
- `scripts/menus.gd` draws menus from the original @3x art; buttons emit the
  original's action strings, handled in `main.gd` `_on_menu_action()`.
- Autoloads: `Save` (progress in `user://mapman.cfg`), `Audio`, `Dev`.
- `Dev` (`scripts/dev.gd`) holds the tilt tuning every build reads
  (`Dev.t("tilt_threshold")` etc.; defaults are the original's values), the
  dev cheats, build info and the play log. Dev tools are on when
  `Dev.enabled`: the "Android Dev" export preset (feature tag `dev`, app
  "MapMan Dev", package `com.danbhala.mapman.dev`, own save) or any debug run.
  `scripts/dev_panel.gd` is the DEV button, dev menu and tilt gauge. Never
  let a cheat work when `Dev.enabled` is false.
- Everything is built in code; `scenes/main.tscn` is just the root node.
- Art is the original @3x set, drawn at scale 1/3. Fonts are bundled
  (Liberation, OFL) so screenshots match on every machine.

## Traps already hit here

- Don't name a property after a built-in: `hidden` on a Node2D is a signal.
- Full-screen Controls under a CanvasLayer: `set_anchors_and_offsets_preset`,
  not `set_anchors_preset`, or they end up 0×0.
- Godot never stores a scale of exactly zero; hide things with `visible`.
- Phone sensors are off unless enabled in `project.godot`
  (`input_devices/sensors/*`). `Input.get_gravity()` points at the ground,
  rotated to the screen, +y towards the top edge.
- Tests must set `Save.persist = false` and `Dev.persist = false` so they never
  overwrite real progress, and `Dev.enabled = false` unless testing dev tools.
- Don't hand-edit `.uid` files, UIDs in `.tscn` files, or anything in `.godot/`.

## Tests

- `tests/unit/` – GUT tests, one per tile rule; add one for every new rule.
- `tests/autoplay_test.gd` – a bot walks every level along a safe route; the
  proof that all levels are still solvable.
- `tests/screenshots.gd` + `tests/baseline/` – pixel comparison of ten screens.
  Deterministic only with `--fixed-fps 60` and the fixed seed it sets.
