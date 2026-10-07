---
name: new-look
description: Add or change a look in MapMan's wardrobe (a hat, outfit or colour he can wear) end to end, and prove it survives every pose. Use when asked for a new look, costume, hat, skin or colour scheme, to change one, or to release one differently.
argument-hint: "[the look, and when it's released]"
---

A look is one id worn at a time, like a skin. It is drawn in code, in
MapMan's own `_draw()`, so it follows every dial the game turns. Read
`docs/wardrobe/README.md` ("Rules for future sessions") before drawing: the
bugs it lists don't show on a still of him standing.

1. **List it** in `godot/scripts/wardrobe.gd` `LOOKS`: id, name (an English
   msgid), the level whose first clear releases it, and its tier. Levels are
   every 5th, one look each, rarer tiers later (`test_wardrobe.gd` checks).
   A look of MapWoman's goes in `HERS` instead (released by that Revision B
   sheet; the figure is her in it, with her bow unless the id is in
   `Outfits.BARE_HEAD`).
   A look released another way (a feat) needs a rule and save storage, so
   plan that with the user first.
2. **Colours** in `godot/scripts/outfits/outfits.gd` `PALETTES`, by role:
   body, head, eyes, legs, outline, leg_outline, head_outline, glow,
   head_glow. Keep a dark mass and a light one: the body at 1.8:1 or more on
   the paper, the legs at 2.5:1 or more on a tile, or an outline that is
   (`test_outfits.gd` checks every palette).
3. **Parts**, in the file for the layer, through the pen (never `draw_*` or
   screen positions):
   - `outfit_hats.gd`: HAT, points relative to the head's centre through
     `pen.hat_*` (they ride the head and fly off when he dies);
   - `outfit_faces.gd`: HEAD parts through `pen.h()`, replacement eyes in
     `eyes()` (they must still blink, look about and widen), FACE parts on
     `pen.eye()`; a new head shape in `head_shape()` must shrink inside the
     dead body;
   - `outfit_bodies.gd`: LEGS on `pen.hips`/`pen.feet`, BODY and NECK at rest
     through `pen.b()`/`pen.band()`/`pen.stripe()`;
   - `outfit_backs.gd`: BACK (add the id to `Outfits.BACKS`; it covers his
     back when he walks away) and FRONT (decoration only with `pen.motion`).
   Front-only details check `pen.front()`. State comes from Player's dials
   (`pen.walking`, `pen.phase`, `pen.dead`...), never a tween, `randf()` or
   the clock, so nothing needs resetting and screenshots stay the same.
   Stay inside 110 units up and 42 to a side.
4. **Name** in `godot/i18n/catalog.json` (note, `max` 14) and all 14
   `godot/i18n/<locale>.json`, then `python3 godot/tools/i18n.py`, and
   `python3 godot/tools/subset_fonts.py <noto dir>` if a CJK or Arabic name
   needs new characters.
5. **Look at it**: `godot/tools/wardrobe_sheets.sh [out dir]` draws every look
   in every pose the game uses. Check walking both ways, walking away, the
   cobweb, the spin and the DYING and DEAD columns, then the collection and
   playing-size sheets. `--video` adds the parade of every look moving.
6. Run the `/verify` skill. A new look changes no baseline unless it's
   released at level 10 (the level-clear screenshot) or worn in a shot.
7. **On the phone**: wear it from the wardrobe (the dev build's "Release
   every look" cheat) and play a few levels: does it read while he moves?
