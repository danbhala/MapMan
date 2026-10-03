# MapMan

A tilt-to-move maze game for phones. Originally written in Pythonista for iOS;
now ported to Godot 4.5.

## Layout

- `godot/` – the live game (Godot 4.5, GDScript). Engine rules: `godot/CLAUDE.md`.
- `Script/` – the original Pythonista game. Frozen reference: read it to check
  how something behaved, never edit it.
- `godot/tools/convert_assets.py` – regenerates `godot/assets/` and `godot/data/`
  from `Script/`. Rerunning it overwrites hand edits to `godot/data/levels.json`.
- `android-build` branch – holds only the latest APK for phones. Never commit
  APKs or `godot/build/` to master.

## Checking your work

IMPORTANT: run `godot/tools/verify.sh` (or the `/verify` skill) before saying a
change to the game is done, and show its summary. Use `--full` when levels or
movement changed. For visual changes, look at the screenshots it saves; only
pass `--update-baseline` when the visual change was intended.

Other commands, from the repo root:

- Import after adding assets: `godot --headless --path godot --import`
- Unit tests only: `godot --headless --path godot -s addons/gut/gut_cmdln.gd`
- Level difficulty numbers: `python3 godot/tools/level_report.py [levels]`
- Lint: `cd godot && gdlint scripts tests && gdformat --check scripts tests`

## Workflow

- Skills: `/verify`, `/new-level`, `/new-tile`, `/build-apk`.
- Agents: `level-analyst` for difficulty, `playtester` to review a recorded run,
  `reviewer` for a fresh-eyes check of a multi-file change before it's done.
- Branch per change, PR into master. Commit as the user's GitHub noreply
  address (`2726152+danbhala@users.noreply.github.com`); their email is private.
- The user plays on an Android phone (OnePlus 12). Tilt, shake and feel can
  only be judged there: say what to try on the phone after gameplay changes.
