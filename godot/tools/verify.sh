#!/usr/bin/env bash
# One command that checks MapMan: lint, import, unit tests, autoplay, screenshots.
#
#   godot/tools/verify.sh            # quick: autoplay stops after 10 levels
#   godot/tools/verify.sh --full     # autoplay plays all 100 levels (~4 min)
#   godot/tools/verify.sh --update-baseline   # accept new screenshots
#
# Needs Godot 4.5 as `godot` on PATH or in $GODOT. gdlint/gdformat (gdtoolkit 4)
# and xvfb-run are used when present and skipped with a warning when not.
set -uo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="${VERIFY_OUT:-${TMPDIR:-/tmp}/mapman-verify}"
LEVELS="--levels=10"
SHOT_MODE="--baseline=res://tests/baseline"
for arg in "$@"; do
  case "$arg" in
    --full) LEVELS="" ;;
    --update-baseline) SHOT_MODE="--baseline=res://tests/baseline --update-baseline" ;;
    *) echo "unknown option: $arg (use --full or --update-baseline)" >&2; exit 2 ;;
  esac
done
mkdir -p "$OUT"

results=()
failed=0
# A runtime error inside an awaited test can leave Godot running; cap each step.
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 900"
step() {  # step <name> <command...>
  local name="$1"; shift
  echo "== $name"
  # shellcheck disable=SC2086
  if $LIMIT "$@" >"$OUT/$name.log" 2>&1; then
    results+=("PASS  $name")
  else
    results+=("FAIL  $name  (log: $OUT/$name.log)")
    failed=1
    tail -n 25 "$OUT/$name.log"
  fi
}
skip() { results+=("SKIP  $1  ($2)"); }

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "Godot not found: put Godot 4.5 on PATH as 'godot' or set GODOT=/path/to/godot" >&2
  exit 2
fi

if command -v gdlint >/dev/null 2>&1; then
  step lint gdlint scripts tests
  step format gdformat --check scripts tests
else
  skip lint "gdtoolkit not installed: pip install 'gdtoolkit==4.*'"
fi

step import "$GODOT" --headless --path . --import
# An import that logs script errors still exits 0, so check its log too.
if grep -q "SCRIPT ERROR\|Parse Error" "$OUT/import.log"; then
  results+=("FAIL  script errors during import (log: $OUT/import.log)")
  failed=1
fi

step unit "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd
# shellcheck disable=SC2086
step autoplay "$GODOT" --headless --path . --script res://tests/autoplay_test.gd -- $LEVELS
last=$((${#results[@]} - 1))
if [ "${results[$last]:0:4}" = "PASS" ] && ! grep -q "ALL CHECKS PASSED" "$OUT/autoplay.log"; then
  results[$last]="FAIL  autoplay did not report success (log: $OUT/autoplay.log)"
  failed=1
fi

if command -v xvfb-run >/dev/null 2>&1 || [ -n "${DISPLAY:-}" ]; then
  RUN=""
  [ -z "${DISPLAY:-}" ] && RUN="xvfb-run -a"
  # shellcheck disable=SC2086
  step screenshots $RUN "$GODOT" --path . --rendering-driver opengl3 \
    --resolution 1334x750 --fixed-fps 60 --audio-driver Dummy \
    --script res://tests/screenshots.gd -- --out="$OUT/screens" $SHOT_MODE
else
  skip screenshots "no display and no xvfb-run"
fi

echo
echo "MapMan verify summary (logs and screenshots in $OUT):"
printf '  %s\n' "${results[@]}"
exit $failed
