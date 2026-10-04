#!/usr/bin/env bash
# The wardrobe's pose check (docs/wardrobe): every look worn by the real
# Player in every pose the game puts him in, as contact sheets, and with
# --video the parade of every look moving, as an mp4:
#
#   godot/tools/wardrobe_sheets.sh [--video] [out_dir]   # default: ${TMPDIR:-/tmp}/mapman-wardrobe
#
# Look at 01_collection.png, 02_poses_1..3.png (walking both ways, walking
# away, the cobweb, the spin, and the DYING and DEAD columns) and
# 04_at_playing_size.png; parade.mp4 with --video. The sheets are drawn by
# tools/wardrobe_sheets.gd, the parade by tools/wardrobe_parade.gd.
# Needs Godot 4.5 (`godot` on PATH or $GODOT), xvfb-run or a display, and
# ffmpeg for --video. Runs offscreen under xvfb-run whenever it is installed.
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
VIDEO=0
OUT=""
for arg in "$@"; do
  case "$arg" in
    --video) VIDEO=1 ;;
    -*) echo "unknown option: $arg (use --video)" >&2; exit 2 ;;
    *) OUT="$arg" ;;
  esac
done
OUT="${OUT:-${TMPDIR:-/tmp}/mapman-wardrobe}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"  # absolute: Godot resolves relative paths against the project

need=("$GODOT")
if [ "$VIDEO" = 1 ]; then need+=(ffmpeg); fi
for tool in "${need[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool not found (Godot 4.5 as 'godot' on PATH or \$GODOT; ffmpeg for --video)" >&2
    exit 2
  fi
done
# Offscreen whenever xvfb-run is there: no windows popping up, and it still
# works where $DISPLAY names a display that has gone away.
RUN=""
if command -v xvfb-run >/dev/null 2>&1; then
  RUN="xvfb-run -a"
elif [ -z "${DISPLAY:-}" ]; then
  echo "no display: set DISPLAY or install xvfb-run" >&2
  exit 2
fi
# A broken script would otherwise sit in Godot forever.
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 600"
# The tools name the game's classes (Player, Wardrobe, LevelMap), which only
# an imported project knows.
[ -d .godot ] || "$GODOT" --headless --path . --import >/dev/null 2>&1

run_godot() {  # run_godot <log> <godot args...>
  local log="$1"
  shift
  # shellcheck disable=SC2086
  if ! $LIMIT $RUN "$GODOT" --path . --rendering-driver opengl3 --audio-driver Dummy "$@" \
      >"$log" 2>&1 || grep -q "SCRIPT ERROR\|Parse Error" "$log"; then
    echo "Godot failed (log: $log):" >&2
    if grep -q "SCRIPT ERROR\|Parse Error" "$log"; then
      grep -A 3 "SCRIPT ERROR\|Parse Error" "$log" | head -n 24 >&2
    else
      tail -n 20 "$log" >&2
    fi
    exit 1
  fi
}

echo "== drawing the sheets"
run_godot "$OUT/sheets.log" --resolution 800x600 \
  --script res://tools/wardrobe_sheets.gd -- --out="$OUT"
grep "^saved" "$OUT/sheets.log" || true

if [ "$VIDEO" = 1 ]; then
  echo "== recording the parade (Movie Maker mode, 30 fps)"
  rm -f "$OUT/parade.avi" "$OUT/parade.mp4"
  run_godot "$OUT/parade.log" --resolution 1920x1080 --fixed-fps 30 \
    --write-movie "$OUT/parade.avi" --script res://tools/wardrobe_parade.gd
  if [ ! -s "$OUT/parade.avi" ]; then
    echo "Godot wrote no movie (log: $OUT/parade.log)" >&2
    exit 1
  fi
  ffmpeg -y -loglevel error -i "$OUT/parade.avi" -c:v libx264 -pix_fmt yuv420p \
    -crf 22 -preset slow -movflags +faststart "$OUT/parade.mp4"
  rm -f "$OUT/parade.avi"
  echo "saved parade.mp4"
fi

echo
echo "MapMan wardrobe sheets in $OUT:"
for f in "$OUT"/*.png "$OUT"/*.mp4; do
  if [ -e "$f" ]; then echo "  $f"; fi
done
exit 0
