#!/usr/bin/env bash
# PostToolUse hook: after Claude edits a .gd file, format it with gdformat and
# report gdlint problems back to Claude. Silent when gdtoolkit isn't installed.
input=$(cat)
file=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)
case "$file" in
  *.gd) ;;
  *) exit 0 ;;
esac
[ -f "$file" ] || exit 0
command -v gdformat >/dev/null 2>&1 || exit 0
case "$file" in */addons/*) exit 0 ;; esac

note=""
if gdformat "$file" 2>&1 | grep -q "^reformatted"; then
  note="gdformat reformatted $file; re-read it before editing it again."
fi
problems=$(cd "${CLAUDE_PROJECT_DIR:-.}/godot" 2>/dev/null && gdlint "$file" 2>&1 | grep -v "^Success")
if [ -n "$problems" ]; then
  note="${note:+$note }gdlint found problems in $file:
$problems"
fi
if [ -n "$note" ]; then
  python3 - "$note" <<'PY'
import json, sys
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": sys.argv[1],
}}))
PY
fi
exit 0
