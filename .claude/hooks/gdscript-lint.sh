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

gdformat "$file" >/dev/null 2>&1
problems=$(cd "${CLAUDE_PROJECT_DIR:-.}/godot" 2>/dev/null && gdlint "$file" 2>&1 | grep -v "^Success")
if [ -n "$problems" ]; then
  python3 - "$file" "$problems" <<'PY'
import json, sys
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "gdlint found problems in %s (file was also run through gdformat):\n%s" % (sys.argv[1], sys.argv[2]),
}}))
PY
fi
exit 0
