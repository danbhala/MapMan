---
name: release
description: Ship MapMan the right way, from an approved PR to a tagged release with its APK. Use whenever asked to merge a PR, cut or ship a release, fix release notes, or when a PR is ready for master.
argument-hint: "[PR number, or 'release']"
---

# Releasing MapMan

Versions, tags, changelog and the release APK are all generated from the
commits on master. Every step below exists so that machinery gets the right
input; doing any of it by hand (editing `CHANGELOG.md`, `version.txt`,
`.release-please-manifest.json`, `version/name` or `version/code`, or merging
with a merge commit) produces wrong versions or duplicated release notes.

## The flow, in order

1. **The feature PR is ready.** Its title is conventional (`/open-pr`), the
   checks on its latest commit are green (`verify`, `build`, `Conventional PR
   title`), `mergeable_state` is `clean`, and if it carries `needs phone test`
   the user has tried the Test APK from the PR comment. A PR you opened in a
   session is yours to drive to this state (`/verify`, fixes, baselines).

2. **Squash-merge it, with the PR title as the commit title.** This is the
   one commit release-please will read.
   - Cloud session (no `gh`): the GitHub MCP tool `merge_pull_request` with
     `merge_method: "squash"`, `commit_title: "<PR title> (#N)"` and
     `expectedHeadSha` set to the head you checked.
   - Terminal: `gh api -X PUT repos/danbhala/mapman/pulls/N/merge
     -f merge_method=squash -f commit_title="<PR title> (#N)"`.
   - Never "Create a merge commit" or "Rebase and merge". A merge commit puts
     every branch commit on master, and release-please turns each one into a
     changelog line (v1.3.0 listed "practice any level" and "blueprint look"
     twice for that reason). Only the owner can switch the repo's merge
     settings (below); until then, the squash is yours to insist on.

3. **Let release-please draft the release.** The push to master runs the
   Release workflow; its `release-please` job creates or updates the open
   `chore(master): release X.Y.Z` PR (branch
   `release-please--branches--master--components--mapman`). `feat` bumps the
   minor version, `fix`/`perf` the patch, `feat!`/`BREAKING CHANGE` the major.
   Read the PR body: it is the changelog as players will see it. One line per
   merged PR, written for players. If a line is wrong, the fix is the next
   PR's title, not the release PR: never edit its files.

4. **Merge the release PR only when the user asks for a release.** Squash,
   `commit_title: "chore(master): release X.Y.Z (#N)"`. It has no CI checks
   of its own (a PR opened by the Actions token does not trigger workflows),
   which is expected, not a failure.

5. **Wait for the Release workflow on that merge** (`release.yml`, about
   three minutes): `release-please` tags `vX.Y.Z` and publishes the GitHub
   Release; the `android` job builds `MapMan.apk`, attaches it to the release,
   appends the install note, and refreshes the `android-build` branch that the
   README's download link points at. Poll
   `https://api.github.com/repos/danbhala/MapMan/releases/latest` until the
   tag is the new one and `MapMan.apk` is among its assets (a short `until`
   loop with `curl`), or follow the run with the Actions tools.

6. **Report**: the release page, the APK asset link
   (`https://github.com/danbhala/MapMan/releases/download/vX.Y.Z/MapMan.apk`),
   the standing link `https://github.com/danbhala/MapMan/raw/android-build/MapMan.apk`,
   and the changelog lines.

7. **Start the next change from master.** After a squash merge the old
   branch is not an ancestor of master, so a follow-up branch must be
   recreated from `origin/master` (in a cloud session that is a
   force-with-lease push of the designated branch, which needs the user's
   go-ahead). Never stack new commits on merged history.

## Fixing things

- **Wrong or duplicated release notes** on a published release: edit the
  GitHub Release body (`gh release edit vX.Y.Z --notes-file notes.md` in a
  terminal; the cloud session's token cannot edit releases). Keep one line per
  PR under `### Features` / `### Bug Fixes`, plus the install note the
  workflow appends.
- **Release made, APK missing**: open the Release workflow run, read the
  `android` job log, fix the cause in a PR. Re-running the job with
  `actions_run_trigger`/`gh run rerun` is fine; `workflow_dispatch` on
  Release is for recovery only (release-please is idempotent).
- **A release that should not have happened**: don't delete tags. Ship a
  `fix:` PR and a patch release.
- **A hotfix**: the same flow with a `fix:` PR; it becomes a patch release.

## Repo settings only the owner can change

Settings → General → Pull Requests: **Allow squash merging** on, with
"Default commit message" set to "Pull request title"; **Allow merge
commits** and **Allow rebase merging** off. Settings → Actions → General:
"Allow GitHub Actions to create and approve pull requests" on (release-please
needs it to open its PR).
