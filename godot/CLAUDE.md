# MapMan in Godot

Godot 4.5, typed GDScript only, mobile renderer, 667×375 base viewport,
landscape. Your training data skews to Godot 3: no `yield`, `KinematicBody2D`,
`export var`, `onready var` or `instance()`.

## Architecture

- `scripts/main.gd` owns game flow and state. Tile rules live only in
  `update_player()`; movement in `move_player()` / `_try_axis()`.
- `scripts/level_map.gd` owns the tile grid, loading animation and per-tile
  effect state. Grid keys are `Vector2i(column, row)`, row 0 at the top.
- `scripts/menus.gd` draws every menu as a Blueprint drawing sheet (frame,
  grid, parts-list rows, stamps) in code; buttons emit the original's action
  strings, handled in `main.gd` `_on_menu_action()`.
- `scripts/blueprint.gd` is the look: the palette (every colour checked for
  contrast on the blue field), JetBrains Mono at its weights, and the sheet
  furniture the menus, `hud.gd` and the field share. All decorative motion
  (stamp slams, sheets drawing on, tiles folding) goes through
  `Blueprint.motion()`, which is off when the player sets "reduce motion".
- `scripts/player.gd` draws MapMan (and MapWoman, `art = "woman"`) in
  `_draw()`: look, blink, walk, squash, cobweb, spin and death are dials the
  game turns; the facing API is the sprite version's. He wears one look
  (`outfit`, a `Wardrobe` id) and is drawn in layers through
  `scripts/outfits/outfit_pen.gd`, the pose plus drawing calls that follow
  it; `outfits.gd` holds each look's colours and `outfit_*.gd` its parts per
  layer. `measure()` gives his box without drawing (tests, the menus'
  dimension line).
- The wardrobe (`docs/wardrobe/README.md`, the `/new-look` skill):
  `scripts/wardrobe.gd` lists the looks (id, name msgid, release level,
  tier). `Save` keeps `worn`, `released` and `seen`, and on load releases
  whatever the progress has earned. `main.gd` releases a look on the first
  clear of every 5th level in the main game (never practice or the
  tutorial) and MapWoman on finishing; wearing MapWoman, MapMan waits at the
  end. `scripts/wardrobe_sheet.gd` draws sheet 001-D and the release slips
  for `menus.gd`.
- Autoloads: `Save` (progress in `user://mapman.cfg`), `Audio`, `Dev`.
- `Dev` (`scripts/dev.gd`) holds the tilt tuning every build reads
  (`Dev.t("tilt_threshold")` etc.; defaults are the original's values), the
  dev cheats, build info and the play log. Dev tools are on when
  `Dev.enabled`: the "Android Dev" export preset (feature tag `dev`, app
  "MapMan Dev", package `com.danbhala.mapman.dev`, own save) or any debug run.
  `scripts/dev_panel.gd` is the DEV button, dev menu and tilt gauge. Never
  let a cheat work when `Dev.enabled` is false.
- Everything is built in code; `scenes/main.tscn` is just the root node.
- Languages: every player-facing string is an English msgid passed to `tr()`
  (plurals through `tr_n()`), listed with a note and a width budget in
  `i18n/catalog.json`. Translations are `i18n/<locale>.json`; `tools/i18n.py`
  turns them into the `.po` files `project.godot` loads (run it after editing,
  `--check` in CI). `tools/subset_fonts.py` cuts Noto Sans fonts down to the
  characters the translations use (`assets/fonts/i18n/`), so add a glyph source
  there before adding a script. `Save.locale` is the chosen language ("" follows
  the phone); Arabic mirrors the sheets (`Menus._mx()`, with Godot's own
  mirroring off in `project.godot`). `tests/unit/test_i18n.gd` checks the
  catalog, the translations, the glyphs and, through `tools/layout_check.gd`,
  that every sheet and HUD state lays out in every language: text fits the
  box it was given (`Blueprint.fit()` remembers it), stays in the frame and
  crosses no other text. `tools/i18n_shots.sh` runs the same rules with
  pictures of every screen in every language (local only, about two minutes).
- Blueprint labels and buttons join the tree before they are sized: a Control
  sized outside the tree measures its text with the default theme's font and
  keeps that box. Figures ("+10", "T-0:20") are forced left-to-right
  (`Blueprint.direction()`) so they don't flip on an Arabic phone.
- Tile art is the original @3x set, drawn at scale 1/3 (the menu, button and
  character art is no longer used). Fonts are bundled (JetBrains Mono,
  Liberation; OFL) so screenshots match on every machine.

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
- A `--script` SceneTree script (autoplay, screenshots, tools) compiles every
  class it names (`LevelMap`, and so `Blueprint`) before the autoloads exist:
  a bare `Save`/`Audio`/`Dev` in those scripts is a compile error. Reach them
  through `Blueprint.autoload("Save")` there, or keep the reference in
  `main.gd`/`menus.gd`, which only load with the scene.
- `DisplayServer`'s live-region enum is `DisplayServer.LIVE_POLITE`, not
  `ACCESSIBILITY_LIVE_POLITE`.
- A look's parts draw through the pen (`pen.b()`, `pen.h()`, `pen.hat_*`),
  never with `draw_*` or screen positions, and keep no state of their own:
  anything moving comes from Player's dials, so `reset_pose()` resets it and
  screenshots stay the same. Front-only details check `pen.front()`. Look at
  every pose (`tools/wardrobe_sheets.sh`) before calling a look done.
- The screenshot tools, and tests that check a sheet's layout or picture,
  must pin `Save.worn`, `released` and `seen`: MapMan wears the worn look on
  every sheet, and the main menu shows the wardrobe's count, and the autoload
  reads this machine's real save even with `persist` off.

## Tests

- `tests/unit/` – GUT tests, one per tile rule; add one for every new rule.
- `tests/autoplay_test.gd` – a bot walks every level along a safe route; the
  proof that all levels are still solvable.
- `tests/screenshots.gd` + `tests/baseline/` – pixel comparison of two dozen
  screens. Deterministic only with `--fixed-fps 60` and the fixed seed it sets.
- `tools/record_tour.sh` records a video tour (menus, a level, pause, level
  clear, a lost life) with Godot's Movie Maker mode, for showing changes.
