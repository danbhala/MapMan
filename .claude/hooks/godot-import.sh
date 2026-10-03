#!/usr/bin/env bash
# SessionStart: a fresh cloud clone has no godot/.godot/ import cache, so
# class_name types (LevelMap, ...) are unknown and running the game (e.g. via
# the Godot MCP run_project tool) fails with parse errors. Import once up front.
set -u

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0
cd "${CLAUDE_PROJECT_DIR:-.}/godot" || exit 0
[ -f .godot/global_script_class_cache.cfg ] && exit 0
command -v godot >/dev/null || exit 0

godot --headless --path . --import >/dev/null 2>&1 \
  || echo "godot --import failed; run it by hand before run_project" >&2
exit 0
