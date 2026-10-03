---
name: verify
description: Check MapMan still works after a change - lint, Godot import, GUT unit tests, the autoplay run through the levels, and screenshot comparison. Use before saying any change to the Godot game is done, or when asked to test or verify.
argument-hint: "[--full] [--update-baseline]"
context: fork
agent: general-purpose
allowed-tools: Bash(godot/tools/verify.sh *), Read
---

Run MapMan's checks and report back. Pass the arguments through: `$ARGUMENTS`
(`--full` plays all 100 levels instead of the first 10; `--update-baseline`
accepts new screenshots after an intended visual change).

1. Run `godot/tools/verify.sh $ARGUMENTS` from the repository root. It prints a
   PASS/FAIL/SKIP summary and the folder holding its logs and screenshots.
2. For every FAIL, read the matching log and report the first real error with
   its file and line. Don't paraphrase a stack trace; quote the error line.
3. If `screenshots` failed, open the `*_diff.png` images in the screenshots
   folder (changed pixels are red) and the new screenshot itself, and say what
   moved. Say whether it looks intended given the change being verified.
4. For a visual change that passed, still open the screenshots for the screens
   it touches and confirm by eye that they look right.

Reply with: the summary lines exactly as printed, then one short paragraph per
failure. Never call the work done while anything shows FAIL. A SKIP (missing
gdtoolkit or display) is not a failure, but mention it.
