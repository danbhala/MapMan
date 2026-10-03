---
name: commit
description: Write and make a git commit for MapMan using Conventional Commits (feat:, fix:, chore: ...). Use whenever committing changes in this repo, or when asked what type or message a change should have.
argument-hint: "[what changed]"
---

# Committing in MapMan

## Why the format matters

MapMan's version numbers and changelog are generated from commit messages by
release-please. A commit's **type decides the next version** and **its subject
becomes a line in the player-facing changelog**:

| Type | Use for | Release |
| --- | --- | --- |
| `feat` | Something a player can see or do that's new: a tile, level, menu, option | minor: 1.1.0 → 1.2.0 |
| `fix` | Something that was broken now works | patch: 1.1.0 → 1.1.1 |
| `perf` | Faster or lighter with no behaviour change | patch |
| `revert` | Undoing an earlier commit | patch |
| `feat!` / `fix!`, or a `BREAKING CHANGE:` footer | Old saves, settings or level data stop working | major: 1.1.0 → 2.0.0 |
| `docs`, `test`, `refactor`, `build`, `ci`, `chore`, `style` | Anything players won't notice | none, and hidden from the changelog |

Get it wrong and the damage is real: a bug fix typed `chore` never ships in a
release; a refactor typed `feat` bumps the version and puts a meaningless line
in the changelog; a save-format change without `!` installs over old saves
with no warning.

## Format

```
<type>[optional scope][!]: <subject>

[body: what and why, wrapped at 72]

[footers]
```

- **Subject:** lowercase start, imperative or plain description, no full
  stop, under about 60 characters, written for players when the type is
  `feat`/`fix`/`perf` ("fix: unhide tiles bring hidden tiles back", not
  "fix: change scale check in _unhide_tile").
- **Scope** (optional) is one MapMan area: `gameplay`, `levels`, `ui`, `art`,
  `audio`, `android`, `tests`, `tooling`. Example: `feat(levels): add lava levels 101-110`.
- **Body:** why the change was needed and anything surprising. Code details
  belong in the diff.
- **Breaking:** add `!` after the type/scope and a `BREAKING CHANGE: <what
  players must do>` footer.
- **Footers, always last, in this order:** `BREAKING CHANGE:` if any, then
  the attribution lines the session requires (`Co-Authored-By: ...`,
  `Claude-Session: ...`).

## Steps

1. Look at what's staged: `git status --short` and `git diff --cached --stat`.
   If unrelated changes are mixed together, split them into separate commits;
   one type per commit.
2. Pick the type from the table. When torn between two: would a player notice?
   No → not `feat`/`fix`. Did it work before? Yes → `feat`, no → `fix`.
3. For game changes, the `/verify` skill should already have passed.
4. Commit as the user, with their private noreply address:
   ```
   git -c user.name=danbhala -c user.email="2726152+danbhala@users.noreply.github.com" \
     commit -F - <<'MSG'
   fix(gameplay): tiles hidden from the start appear when revealed

   Start-hidden tiles skipped the appear animation and kept a near-zero
   scale, so unhiding made them visible but microscopic.

   Co-Authored-By: ...
   MSG
   ```
5. Check it: `git log -1 --format=%B` starts with a valid type and the
   subject reads well on its own.

Branch commits matter less than the PR title (PRs are squash-merged and the
title becomes the commit release-please reads), but keep them conventional so
history stays readable and a rebase-merge would still be correct. To open the
PR, use the `/open-pr` skill.
