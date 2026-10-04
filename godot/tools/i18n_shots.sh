#!/usr/bin/env bash
# Every menu sheet and HUD state in every language, as pictures plus an
# automatic check for text that overflows, is clipped, overlaps or leaves the
# screen. A local check (about two minutes); it is not part of CI.
#
#   godot/tools/i18n_shots.sh                 # all languages -> /tmp/mapman-i18n
#   godot/tools/i18n_shots.sh /tmp/out ar,ja  # some languages, elsewhere
#   godot/tools/i18n_shots.sh /tmp/out "" --boxes   # outline every text's box
#
# Look at <out>/all_main_menus.png and <out>/<locale>.png; read <out>/report.txt.
# The rules are in tools/layout_check.gd; tests/unit/test_i18n.gd runs the
# same rules without pictures, in CI.
# Needs Godot 4.5 as `godot`, xvfb-run (or a display) and Pillow for the sheets.
set -uo pipefail

cd "$(dirname "$0")/.."
OUT="${1:-${TMPDIR:-/tmp}/mapman-i18n}"
LOCALES="${2:-}"
EXTRA="${3:-}"
mkdir -p "$OUT"
RUN=""
[ -z "${DISPLAY:-}" ] && RUN="xvfb-run -a"
# shellcheck disable=SC2086
$RUN godot --path . --rendering-driver opengl3 --resolution 1334x750 --fixed-fps 60 \
  --audio-driver Dummy --script res://tools/i18n_shots.gd \
  -- --out="$OUT" ${LOCALES:+--locales=$LOCALES} $EXTRA > "$OUT/godot.log" 2>&1
status=$?
if grep -q "SCRIPT ERROR" "$OUT/godot.log"; then
  echo "script errors (see $OUT/godot.log):"
  grep -A2 "SCRIPT ERROR" "$OUT/godot.log" | head -20
  status=1
fi
python3 tools/i18n_sheets.py "$OUT" || echo "no contact sheets: pip install pillow"
cat "$OUT/report.txt" 2>/dev/null
exit $status
