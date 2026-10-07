# The drafting table

Players draw their own levels on the phone and pass them to a friend as a
short code. There are no accounts and no server: the code *is* the level.

## For players

- **Unlocks** once you reach level 11 (or have finished the game): sheet 001
  gains a sixth row, DRAFTING TABLE.
- **Six drafts.** Tap an empty slot to open the editor: a 17 × 12 grid, a palette of
  every tile the campaign uses, UNDO (one step per stroke), CLEAR (which
  UNDO also takes back), TEST and SHARE.
  Drags paint; one start tile per level (placing another moves it).
- **Beat it to share it.** TEST plays the draft like practice: no lives, no
  score, no saving. Reaching an exit **signs** it. Any later edit unsigns it.
- **Sharing** shows the code in groups of four (`0MM3-C7P1-P7R3-KWTS-4`) and a
  QR code. Both hold a level link, `https://danbhala.github.io/MapMan/<code>`:
  COPY CODE puts it on the clipboard.
- **Playing a friend's level:** SCAN A QR CODE points the camera at the QR
  on their share sheet and plays the level as soon as it reads; ENTER A
  LEVEL CODE types or PASTEs one. Or just copy their message and open
  MapMan: a code on the clipboard is offered once on the main menu (the
  phone's own camera app can put a QR's text there too). Up to twelve codes
  played are kept under RECEIVED LEVELS, in two rows, until the player deletes
  them; a thirteenth lets go of the oldest one without a name.
- **Level cards.** Tapping a drawn draft or a received level opens its card
  (sheet D1 or R1, `scripts/level_card.gd`): the map, its name, PLAYED (tries),
  CLEARED (wins) and BEST (most seconds left), and PLAY, EDIT (REMIX for a
  friend's level: a copy in the first empty draft), SHARE, WATCH REPLAY (the
  tries since the game opened) and DELETE, which asks once. Playing from a
  card comes back to it.
- **Names stay on the phone.** RENAME names a level (capitals, 16
  characters, only what the bundled fonts can draw, `Draft.tidy_name()`).
  Codes and links never carry a name, so a friend never sees text someone
  typed; a received level arrives as R1, R2… and its player can name it.
  Drafts keep their name in the draft; received levels' names are in
  `Save.received_names`.
- **Records and ghosts.** `Save.level_stats` keeps each level's tries, wins,
  best time and best run (its ghost) by its code, so a draft that changes is
  a new level and starts afresh, and a level that leaves the table takes its
  record with it (`Save.forget_unused()`). The game plays these levels as
  level 0 with the code as the key (`Tries.begin()`), apart from level 1.
- **Level links:** scanning the QR with the phone's camera or tapping the
  link in a chat opens a page with the code. On Android its OPEN IN MAPMAN
  opens the game straight into the level, whether it was closed or in the
  background, and even before level 11 (in the middle of the main game the
  level waits for the main menu). A player can skip the page for good:
  Settings, Apps, MapMan, Open by default, add danbhala.github.io.
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

**New tile types** take the spare symbols after `SYMBOLS` (crumble `k`, ice
`j` and the spikes `^` and `%` took the first four; 8 are left): append the
tile's character to `SYMBOLS` in both files and lower `RESERVED` by one, so
the alphabet stays 43 symbols (never reorder them). Add it to `DraftingSheet.TOOLS`, and regenerate the golden
codes (`python3 godot/tools/level_code.py --fixtures`). Old codes keep
reading; an older game answers a code using the new tile with "needs a newer
version".

## Levels from a description

The `/custom-level` skill has Claude draw a level from a description ("a
spiral", "a hard heart") and hand back its code and QR.
`godot/tools/level_qr.gd` does the checking with the game's own code: the
editor's rules (known tiles, 17 × 12, one start, an exit), a safe route by
`LevelMap.safe_route()`, a code that reads back, and a QR that `QrReader`
reads. Its QR holds the level link (`LevelCode.link()`), like the share
sheet's.

## QR codes

`godot/addons/kenyoni/qr_code/` (MIT) draws the QR on the share sheet,
offline. A link has small letters, so it goes in byte mode (a version-6 or 7
symbol); a bare code goes in alphanumeric mode. Codes read back from a link,
`MAPMAN <code>` or the bare code alike (`LevelCode.clean`).

The scan sheet (001-G) reads them back in the game: `scripts/qr_scanner.gd`
shows the back camera (`CameraServer`; Android asks for the camera
permission on the sheet's first visit, iOS shows the presets' camera usage
line) and hands a picture five times a second to `scripts/qr_reader.gd`, a
small QR decoder of our own, on a worker thread. It finds the three corner
squares, follows the grid to the small square in the fourth corner (so a
phone held at an angle still reads), and repairs damaged modules with the
code's Reed-Solomon check words. `tests/unit/test_qr_reader.gd` reads
turned, tilted, mirrored, noisy and damaged codes. The camera itself can
only be tried on a phone.

## Level links

- **The page:** `site/`, published to the repo's GitHub Pages by
  `.github/workflows/pages.yml` on every master push that changes it. Its
  `404.html` serves every `/MapMan/<code>` address: the code to copy, and on
  Android an `intent://` link to `mapman://level/<code>` (or the download
  page without the game). Android can't verify the https link itself (that
  needs a file at the domain root, which only a `danbhala.github.io` repo
  could publish), so it opens the page unless the player allows the link.
- **The game:** `addons/level_links/` is an editor plugin that adds the
  `mapman://level/` and https `intent-filter`s to the Android manifest at
  export, which needs the presets' gradle build (CI installs the build
  template into the ignored `godot/android/`). `DraftingTable.check_link()` reads the link Android
  opened the game with (the `AndroidRuntime` singleton) as the intro ends,
  on returning to the game and on the main menu, and plays each link once.
- **iPhone:** not yet: the page shows the code to copy.
