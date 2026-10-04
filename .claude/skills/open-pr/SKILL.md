---
name: open-pr
description: Open a pull request on danbhala/MapMan with a Conventional Commits title, a clear description and the right labels. Use whenever a change is ready to propose, or when asked to open, title, label or merge a PR.
argument-hint: "[summary of the change]"
---

# Opening a pull request

## Why the title matters most

PRs are **squash-merged**, so the PR title becomes the single commit on
master. release-please reads that commit to pick the next version (`fix` →
patch, `feat` → minor, `!` → major) and copies the subject into the
player-facing changelog and GitHub Release notes. A **PR title** check fails
the PR if the title isn't conventional, and a bad but valid title (wrong
type, unclear subject) ships the wrong version number or a confusing release
note. See the `/commit` skill for the type table and subject rules; they apply
to PR titles exactly.

## Steps

1. **Branch:** work on `<type>/<short-kebab-description>` off up-to-date
   master, e.g. `fix/start-hidden-tiles`, `feat/lava-tile`. Never commit to
   master directly.
2. **Check:** for any change under `godot/`, run the `/verify` skill (with
   `--full` if levels or movement changed) and keep its summary for the body.
3. **Commits:** conventional, via the `/commit` skill. If the branch mixes a
   feature and an unrelated fix, split it into two PRs: each PR is one
   changelog line.
4. **Push:** `git fetch origin master && git rebase origin/master`, then
   `git push -u origin <branch>`.
5. **Title:** `<type>[(scope)][!]: <subject>`, lowercase subject, no full
   stop, under about 60 characters, written for a player when it's `feat`,
   `fix` or `perf`. Good: `fix: unhide tiles bring hidden tiles back`.
   Bad: `Fix bug`, `fix: Update level_map.gd`, `feat: refactor menus`.
6. **Body**, in this shape:
   ```
   <one or two sentences: what changes for the player, or for development>

   **Why:** <the problem or request behind it>

   **Changes**
   - <grouped by area, not by file>

   **Testing:** <verify.sh summary lines; what wasn't tested>

   **On the phone:** <what to try on the OnePlus 12, or "nothing to check">

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   <session link line, as the session's attribution instructions require>
   ```
   For a breaking change, add a `BREAKING CHANGE: <what players must do>`
   line at the end of the body: squash merges keep the body, and
   release-please reads that footer.
7. **Create it** (write the body to a file first):
   ```
   gh api repos/danbhala/mapman/pulls -f title="<title>" -f head=<branch> \
     -f base=master -F body=@<body-file> --jq '.number, .html_url'
   ```
8. **Labels:** the PR-title workflow adds the `type: …` label and
   `breaking change` automatically from the title. Add the rest yourself:
   - one or more `area: …` labels: `gameplay` (movement, tile rules, lives,
     clock, scoring), `levels`, `ui` (menus, HUD, fonts), `art`, `audio`,
     `android` (build, tilt, sensors), `tests`, `tooling` (CI, release,
     Claude setup);
   - `needs phone test` when tilt, shake, timing, audio or anything about
     feel changed, since only the user's phone can judge it.
   ```
   gh api repos/danbhala/mapman/issues/<N>/labels \
     -f "labels[]=area: gameplay" -f "labels[]=needs phone test"
   ```
   The full list with descriptions is `.github/labels.json`; use only labels
   from it. To add a new label, add it to that file in the same PR, and the
   Labels workflow will create it on merge.
9. **Report** the PR link, title, labels, and anything the user should check.
   For changes to try on the phone, wait for the Test builds workflow's comment
   on the PR and give the user its download link (MapMan Dev installs next to
   the real app, so testing never touches their real save).

## Merging

Only merge when the user asks, and follow the `/release` skill for the whole
flow (squash only; a merge commit doubles up the changelog). Wait for the
checks (`MapMan checks` and `PR title`) to pass, then squash with the PR
title as the commit title:

```
gh api -X PUT repos/danbhala/mapman/pulls/<N>/merge -f merge_method=squash \
  -f commit_title="<PR title> (#<N>)"
```

Never merge release-please's `chore(main): release X.Y.Z` PR unless the user
asked for a release.
