#!/usr/bin/env bash
# Records a video tour of MapMan (menus, a walk through level 1 with a pause,
# the level-clear sheet, losing a life) with Godot's Movie Maker mode, then
# converts it to an mp4 and a half-size gif:
#
#   godot/tools/record_tour.sh [out_dir]    # default: ${TMPDIR:-/tmp}/mapman-tour
#
# Writes tour.avi (raw Movie Maker output), tour.mp4, tour.gif and godot.log
# into out_dir and prints their paths and the mp4's length. The tour itself is
# tools/tour.gd. Needs Godot 4.5 (`godot` on PATH or $GODOT), ffmpeg/ffprobe
# and a display: xvfb-run is used when $DISPLAY is empty.
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="${1:-${TMPDIR:-/tmp}/mapman-tour}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"  # absolute: Godot resolves relative paths against the project

for tool in "$GODOT" ffmpeg ffprobe; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool not found (Godot 4.5 as 'godot' on PATH or \$GODOT, plus ffmpeg)" >&2
    exit 2
  fi
done
RUN=""
if [ -z "${DISPLAY:-}" ]; then
  if ! command -v xvfb-run >/dev/null 2>&1; then
    echo "no display: set DISPLAY or install xvfb-run" >&2
    exit 2
  fi
  RUN="xvfb-run -a"
fi
# A broken tour would otherwise sit in Godot forever (tour.gd has its own watchdog too).
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 900"

rm -f "$OUT/tour.avi" "$OUT/tour.mp4" "$OUT/tour.gif"
echo "== recording the tour (Movie Maker mode, 30 fps)"
# shellcheck disable=SC2086
if ! $LIMIT $RUN "$GODOT" --path . --rendering-driver opengl3 --resolution 1334x750 \
    --fixed-fps 30 --audio-driver Dummy --write-movie "$OUT/tour.avi" \
    --script res://tools/tour.gd >"$OUT/godot.log" 2>&1; then
  echo "Godot failed (log: $OUT/godot.log)" >&2
  tail -n 20 "$OUT/godot.log" >&2
  exit 1
fi
if grep -q "SCRIPT ERROR" "$OUT/godot.log"; then
  echo "script errors during the tour (log: $OUT/godot.log):" >&2
  grep -A 3 "SCRIPT ERROR" "$OUT/godot.log" | head -n 24 >&2
  exit 1
fi
if [ ! -s "$OUT/tour.avi" ]; then
  echo "Godot wrote no movie (log: $OUT/godot.log)" >&2
  exit 1
fi

echo "== converting to mp4 and gif"
ffmpeg -y -loglevel error -i "$OUT/tour.avi" \
  -c:v libx264 -pix_fmt yuv420p -crf 23 -movflags +faststart "$OUT/tour.mp4"
ffmpeg -y -loglevel error -i "$OUT/tour.avi" \
  -vf "fps=15,scale=667:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" \
  "$OUT/tour.gif"
DURATION="$(ffprobe -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$OUT/tour.mp4")"

echo
echo "MapMan tour recorded ($(printf '%.1f' "$DURATION") s):"
echo "  mp4: $OUT/tour.mp4"
echo "  gif: $OUT/tour.gif"
echo "  avi: $OUT/tour.avi (raw Movie Maker output)"
echo "  log: $OUT/godot.log"
