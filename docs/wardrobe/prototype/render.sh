#!/usr/bin/env bash
# Renders the wardrobe contact sheets and menu mockups from this design
# prototype into docs/wardrobe/sheets (or out_dir). --video also records the
# parade, the animated contact sheet, as parade.mp4 there (git ignores it).
#
#   docs/wardrobe/prototype/render.sh [--video] [out_dir]
#
# Needs Godot 4.5 (`godot` on PATH or $GODOT), a display or xvfb-run, and
# ffmpeg for the video. Prints the identity check: outfit "classic" must draw
# exactly what Player draws.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
project="$(cd "$here/../../../godot" && pwd)"
video=0
out="$here/../sheets"
for arg in "$@"; do
  case "$arg" in
    --video) video=1 ;;
    *) out="$arg" ;;
  esac
done
mkdir -p "$out"
out="$(cd "$out" && pwd)"  # absolute: Godot resolves relative paths against the project
GODOT="${GODOT:-godot}"
# Offscreen whenever xvfb-run is there: no windows popping up, and it still
# works where $DISPLAY names a display that has gone away.
RUN=""
if command -v xvfb-run >/dev/null 2>&1; then
  RUN="xvfb-run -a"
elif [ -z "${DISPLAY:-}" ]; then
  echo "no display: set DISPLAY or install xvfb-run" >&2
  exit 2
fi
logs="$(mktemp -d)"
trap 'rm -rf "$logs"' EXIT

cd "$project"
# The prototype names the game's classes (Player, Blueprint, LevelMap), which
# an imported project knows.
[ -d .godot ] || "$GODOT" --headless --path . --import >/dev/null 2>&1

godot_run() {  # godot_run <name> <resolution> <script> [args...]
  local name="$1" resolution="$2" script="$3"
  shift 3
  # shellcheck disable=SC2086
  if ! $RUN "$GODOT" --path . --rendering-driver opengl3 --audio-driver Dummy \
      --resolution "$resolution" --script "$here/$script" "$@" >"$logs/$name.log" 2>&1 \
      || grep -q "SCRIPT ERROR\|Parse Error" "$logs/$name.log"; then
    echo "$name failed:" >&2
    tail -n 20 "$logs/$name.log" >&2
    exit 1
  fi
  grep -E "^(identity|saved|done)" "$logs/$name.log" || true
}

godot_run sheets 800x600 sheets.gd -- --out="$out"
godot_run menus 1650x750 ui.gd -- --out="$out"
godot_run menus_sheet 800x600 menus_sheet.gd -- --out="$out"

if [ "$video" = 1 ]; then
  godot_run parade 1920x1080 parade.gd --fixed-fps 30 --write-movie "$logs/parade.avi"
  ffmpeg -y -loglevel error -i "$logs/parade.avi" -c:v libx264 -pix_fmt yuv420p \
    -crf 22 -preset slow -movflags +faststart "$out/parade.mp4"
  echo "saved parade.mp4"
fi
echo "sheets in $out"
