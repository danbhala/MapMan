# MapMan in Godot

Godot 4.5, typed GDScript only, mobile renderer, 667×375 base viewport,
landscape. Your training data skews to Godot 3: no `yield`, `KinematicBody2D`,
`export var`, `onready var` or `instance()`.

## Architecture

- `scripts/main.gd` owns game flow and state. Tile rules live only in
  `update_player()`; movement in `move_player()` / `_try_axis()`. The
  assists (`ASSIST_*`): lives lost on a level in the main game this session
  (`losses`) earn, in turn, pencil marks on hidden death tiles plus the
  corner guard (`_guarded()`, `Dev.t("guard_hold")`), a sketch of the safe
  route at the start of each try, and a skip row on the lost-life sheet.
  `LevelMap.set_marks()`, `sketch_route()` and `safe_route()` draw them.
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
- The level clear of the main game (`scripts/clear_sheet.gd`, for
  `menus.gd`) counts its bonuses in (a tap mid-count finishes it), then
  offers NEXT, WARDROBE and MAIN MENU. Until NEXT banks the level
  (`main.gd` `_between`), the wardrobe and the quit question opened from it
  come back to it (`Menus.reopen_end_level()`). A tap on MapMan on any
  sheet makes him jump (`Menus._poke()`, `Player.jump()`).
- The drafting table (`docs/drafting-table.md`): `scripts/draft.gd` is a
  level being drawn, `scripts/drafting_sheet.gd` draws sheet 001-E, the
  editor, code entry, the share sheet (QR from `addons/kenyoni/qr_code/`)
  and the scan sheet (`scripts/qr_scanner.gd` camera view,
  `scripts/qr_reader.gd` QR decoder).
  `scripts/level_code.gd` turns a level into a short code and back, matching
  `tools/level_code.py` bit for bit; `data/level_code_v0.json` is frozen.
  `main.gd` plays drafts and friends' codes with `custom` set ("draft",
  "received"), like practice: no lives, score or saving;
  `scripts/drafting_table.gd` (`main.drafting`) runs that flow, and plays
  level links Android opens the game with (`addons/level_links/` puts them
  in the manifest; the Android presets use the gradle build for it).
- Tries (`scripts/run_record.gd`): `main.gd` records every try at a level
  as tile steps and when each began on its run clock (no tilt: a step is
  always a whole tile at one of two speeds), about two bytes a step. The
  level clear's WATCH REPLAY plays every try of the level at once
  (`scripts/replay.gd`), and the best win of each level (most time left) is
  saved in `Save.ghosts` and walks beside MapMan as a faint ghost
  (`scripts/best_ghost.gd`) when `Save.ghost_on` (Options: BEST-RUN GHOST).
  `scripts/tries.gd` keeps the level's tries, its ghost and the replay
  for `main.gd`. The ghost is only made when a level has one: a Player
  draws on the random numbers.
- The tutorial (`data/tutorial.json`) has lessons marked `rev_b`, for the
  tiles of the second playthrough: `main.gd` `lessons()` leaves them out until
  `Save.has_completed`. Finishing the game sets `Save.new_lessons`, which puts
  a note on the game-complete sheet and NEW on the main menu's TUTORIAL row
  until the tutorial is next started. A first-time player
  (`scripts/first_run.gd`, `FirstRun.applies()`: nothing played yet, no
  level link) picks TILT or DRAG TO MOVE (phones that can tilt), then goes
  straight into the tutorial, with SKIP in the header's corner back to the
  main menu; after two lessons, or three lost tries on one, it asks once
  whether to keep that steering or try the other.
- Revision B (`scripts/revision_b.gd`, `main.revision_b`): the second game,
  `data/levels_b.json`, every sheet of `levels.json` mirrored and reworked
  with the crumble, ice and spike tiles by `tools/remix.py` (rerun it after
  changing `levels.json`; hand-tuning goes in `tools/remix_overrides.json`,
  never in `levels_b.json`). It opens when the game has been finished
  (`Save.rev_b_open()`): PLAY REVISION B on the main menu, its own
  checkpoints sheet ("B<n>" actions). `main.gd` `revise()` swaps `levels`,
  the save track (`Save.rev_b`: checkpoints, furthest sheet, bests, ghosts
  and high score live per track in `Save.track_a` / `track_b`, read through
  the usual `Save.checkpoints` etc.) and the look (`Blueprint.revise()`:
  `Blueprint.field`, `grid_color`, `tile_tint`, the Redline palette). No
  assists in Revision B (`losses_here()`). The menus' actions themselves are
  carried out by `scripts/menu_actions.gd`, the Options sheet's by
  `scripts/options_actions.gd`, so `main.gd` stays under the lint's 1300 lines.
- Autoloads: `Save` (progress in `user://mapman.cfg`), `Audio`, `Dev`.
- `Dev` (`scripts/dev.gd`) holds the tilt tuning every build reads
  (`Dev.t("tilt_threshold")` etc.; defaults are the original's values), the
  dev cheats, build info and the play log. Dev tools are on when
  `Dev.enabled`: the "Android Dev" and "iOS Dev" export presets (feature tag
  `dev`, app "MapMan Dev" through `config/name.dev`, package/bundle ID
  `com.danbhala.mapman.dev`, own save) or any debug run.
  `scripts/dev_panel.gd` is the DEV button, dev menu and tilt readout. Never
  let a cheat work when `Dev.enabled` is false.
- `scripts/tilt_gauge.gd` is the players' tilt gauge in the field's
  bottom-right corner (CONTROLS sheet "TILT GAUGE", `Save.tilt_gauge`); tapping it
  recentres (`main.gd` `recentre()`) and never reaches the field, so it never
  pauses. It only shows on phones with an accelerometer; tests and
  screenshots set `show_gauge_anyway`.
- Options' CONTROLS row opens sheet 001-H (`scripts/controls_sheet.gd`):
  TILT TO MOVE or DRAG TO MOVE (`Save.controls`), TILT SENSITIVITY
  (`Save.tilt_sensitivity`, `TiltInput.SENSITIVITY` divides the tilt, so
  the thresholds and the gauge's rings stay put) and the tilt gauge. DRAG TO
  MOVE steers with `scripts/touch_stick.gd`, a floating stick drawn like the
  gauge that appears where a finger lands; `scripts/steering.gd` takes
  the touch through `TiltInput` for `main.gd`, and a quick tap that never
  drags still pauses.
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
- The iOS presets ("iOS", "iOS Dev") export the Xcode project only; CI's
  `.github/actions/build-ipa` signs, archives and uploads it to TestFlight.
  Their App Store icon, `assets/icon/app_icon_1024.png`, is drawn by
  `tools/app_icon.gd` (opaque, 1024×1024: App Store Connect refuses alpha).
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
  proof that all levels are still solvable (`--rev-b` for Revision B's sheets;
  `verify.sh --full` runs both).
- `tests/screenshots.gd` + `tests/baseline/` – pixel comparison of two dozen
  screens. Deterministic only with `--fixed-fps 60` and the fixed seed it sets.
- `tools/record_tour.sh` records a video tour (menus, a level, pause, level
  clear, a lost life) with Godot's Movie Maker mode, for showing changes.
