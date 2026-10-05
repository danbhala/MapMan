# The drafting table

Players draw their own levels on the phone and pass them to a friend as a
short code. There are no accounts and no server: the code *is* the level.

## For players

- **Unlocks** once you reach level 11 (or have finished the game): sheet 001
  gains a sixth row, DRAFTING TABLE.
- **Six drafts.** Tap a slot to open the editor: a 17 × 12 grid, a palette of
  every tile the campaign uses, UNDO (one step per stroke), CLEAR (which
  UNDO also takes back), TEST and SHARE.
  Drags paint; one start tile per level (placing another moves it).
- **Beat it to share it.** TEST plays the draft like practice: no lives, no
  score, no saving. Reaching an exit **signs** it. Any later edit unsigns it.
- **Sharing** shows the code in groups of four (`0MM3-C7P1-P7R3-KWTS-4`) and a
  QR code. COPY CODE puts `MAPMAN <code>` on the clipboard.
- **Playing a friend's level:** ENTER A LEVEL CODE (type or PASTE), or just
  copy their message and open MapMan: a code on the clipboard is offered once
  on the main menu. The phone's own camera reads the QR as text, which lands
  on the clipboard the same way. The last six codes played are kept under
  RECEIVED LEVELS.
- The CODE meter shows how long the code is; it turns pink past 64
  characters. Longer codes still work, they're just harder to type.

- **Dev builds:** the DEV menu's "Seed drafting table" fills five drafts
  and five received codes with campaign levels and unlocks the table;
  "Clear drafting table" empties it.

## Level codes

Defined by `godot/tools/level_code.py` (reference) and matched bit for bit by
`godot/scripts/level_code.gd`; `tests/unit/test_level_code.gd` checks both
against `tests/data/level_codes.json` (all 100 campaign levels).

- Header (28 bits): version 4 · width−1 5 · height−1 4 · options 5 · check 10.
  Options carry the x_hides and loading-speed presets and whether any tile
  starts hidden. The check (FNV-1a, folded to 10 bits) catches about 999 typos
  in 1000.
- Body: the trimmed grid, arithmetic coded tile by tile, each tile guessed
  from the ones to its left and above with the counts in
  `godot/data/level_code_v0.json`, then the start-hidden flags.
- Text: Crockford base32 (no I, L, O or U; reading is forgiving about case,
  `O`/`0`, `I`/`L`/`1`, spaces and dashes), trailing zeros dropped.
- Campaign levels come to a median of 31 characters, 64 at most.

**The counts table is frozen.** Changing a count misreads every code already
shared. To change the model, write `level_code_v1.json` and bump `VERSION`;
older games answer a newer code with "needs a newer version of MapMan".

**New tile types** take the spare symbols after `SYMBOLS` (crumble, `k`, took
the first; 11 are left): append the tile's character to `SYMBOLS` in both
files and lower `RESERVED` by one, so the alphabet stays 43 symbols (never
reorder them). Add it to `DraftingSheet.TOOLS`, and regenerate the golden
codes (`python3 godot/tools/level_code.py --fixtures`). Old codes keep
reading; an older game answers a code using the new tile with "needs a newer
version".

## QR codes

`godot/addons/kenyoni/qr_code/` (MIT) draws the QR on the share sheet,
offline. Codes go in alphanumeric mode, which fits `MAPMAN ` plus a 64-character
code in a version-4 symbol.
