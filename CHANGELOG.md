# Changelog

All notable changes to MapMan. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions match
the Android app's version name (`godot/export_presets.cfg`).

## [Unreleased]

## [1.1] - 2026-10-03

### Fixed
- Unhide tiles now bring hidden tiles back. Previously, once a hide tile was
  stepped on, those tiles stayed invisible for the rest of the level.
- Tiles hidden from the start of a level now appear when revealed
  (levels 4, 18, 57, 68, 71, 85 and 86).
- Running the tests no longer overwrites saved progress and best score.

### Changed
- Text uses bundled Liberation fonts, so it looks the same on every phone.

### Added
- Claude Code project setup: `CLAUDE.md` files, `/verify`, `/new-level`,
  `/new-tile` and `/build-apk` skills, level-analyst, playtester and reviewer
  agents, a GDScript lint hook, and the godot-mcp server.
- GUT unit tests for every tile rule and the level data.
- `godot/tools/verify.sh`: lint, import, unit tests, the autoplay bot and a
  screenshot comparison in one command; GitHub Actions runs it on every push.
- `godot/tools/level_report.py`: route length and clock slack per level.
- Tagging a version builds the Android APK and publishes a GitHub Release.

## [1.0] - 2026-10-03

First release of the Godot 4.5 port of the Pythonista original.

### Added
- All 100 levels and the 12-level tutorial, every tile type, lives, score,
  the 20-second clock, checkpoints, and the main, pause, level-clear,
  lose-life, game-over, checkpoint and options menus, with the original art
  and music.
- Android build for phones (arm64).
- Keyboard, gamepad and mouse controls for playing on a computer.
- Autoplay test that walks every level, and the asset and level converter.

### Changed
- Tilt calibrates to however the phone is held when each level starts,
  replacing the sitting/standing option.
- Checkpoints are free: in-app purchases, rating prompts and score tweeting
  are gone.
- Sound effects that were Pythonista built-ins are replaced by synthesised
  stand-ins.

### Fixed
- Tilt on Android: the motion sensors are now switched on and steer the right
  way.

### Not yet ported
- The ending sequence (MapWoman, the vortex and hearts) and the credits.

[Unreleased]: https://github.com/danbhala/MapMan/compare/v1.1...HEAD
[1.1]: https://github.com/danbhala/MapMan/compare/v1.0...v1.1
[1.0]: https://github.com/danbhala/MapMan/releases/tag/v1.0
