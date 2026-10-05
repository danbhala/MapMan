---
name: new-tile
description: Add a new tile type (a new effect a player can step on) to MapMan end to end. Use when asked for a new tile, power-up, hazard or map mechanic.
argument-hint: "[what the tile does]"
---

A tile type touches several files. Work through all of them; a tile missing
any step either won't load, won't draw, or won't be tested.

1. **Pick a character** not already in the legend in the `/new-level` skill.
2. **Art:** add a 96×69 px tile image (@3x) to `godot/assets/tiles/` and, if it
   shows an effect icon in the bottom bar, a 228×228 px icon to
   `godot/assets/effects/`. Match the existing flat white-oval style.
3. **`godot/scripts/level_map.gd`:** add its texture in `_texture_for()`, a state
   dictionary next to `reverses`/`stickies` (and add it to the list cleared at
   the top of `load_level()`, or its state leaks into the next level),
   registration in `_add_tile()`,
   restore-on-death in `reset()` if it should come back after a lost life, and
   `can_hide` in `_add_tile()` if it should vanish with hide tiles.
4. **`godot/scripts/main.gd`:** apply the rule in `update_player()` with
   `map.on(...)` / `map.clear(...)`, play a sound via `Audio.play()`, and add a
   bottom-bar message in `set_controls_message()` and a background colour in
   `set_background()` if it's a lasting state. The message is an uppercase
   English msgid through `tr()`: add it to `godot/i18n/catalog.json` (note,
   `max` 36 for the bar) and to every `godot/i18n/<locale>.json`, then run
   `python3 godot/tools/i18n.py` (and `tools/subset_fonts.py` if a CJK or
   Arabic translation needs characters the subsets lack). `test_i18n.gd`
   fails until every language has it.
5. **`godot/scripts/audio.gd`:** register any new sound in `SFX`.
6. **Tests:** add a test to `godot/tests/unit/test_tile_rules.gd` on a one-row
   level such as `"b?cw"`; if it affects whether levels can be finished, teach
   the solver in `godot/tests/autoplay_test.gd` and `godot/tools/level_report.py`.
7. **Tutorial:** consider a level in `godot/data/tutorial.json` with a one-line
   `description`, as the original did for each tile; the description is a
   msgid too, so catalog and translate it as in step 4. A tile for the
   second playthrough (Revision B) gets `"rev_b": true`: the lesson only
   shows once the game has been finished, and finishing then says the
   tutorial has new lessons.
8. **Drafting table:** append the tile's character to `SYMBOLS` in both
   `godot/tools/level_code.py` and `godot/scripts/level_code.gd` (it takes
   one of the spare symbols, so lower `RESERVED` by one; never reorder them or touch
   `godot/data/level_code_v0.json`, or shared codes misread), add it with a
   name msgid to `DraftingSheet.TOOLS` and its swatch art, then rerun
   `python3 godot/tools/level_code.py --fixtures`. See
   `docs/drafting-table.md`.
9. Run the `/verify` skill. If the bottom bar or tiles look different, check the
   screenshots and update the baseline only for intended changes.
