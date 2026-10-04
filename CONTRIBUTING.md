# Contributing to MapMan

MapMan is mostly developed with Claude Code. The rules below are written for
people and Claude alike; Claude's versions live in `CLAUDE.md` and the skills
in `.claude/skills/`.

## The short version

1. Branch off `master` as `<type>/<short-description>`, e.g. `fix/sticky-shake`.
2. Make the change. For anything under `godot/`, run `godot/tools/verify.sh`
   (`--full` if levels or movement changed) until it passes.
3. Open a PR titled in [Conventional Commits](https://www.conventionalcommits.org)
   form, e.g. `fix: shaking frees mapman on the first try`. Add `area: …` labels.
4. Install the **MapMan Dev** test build from the link the PR gets and try it on
   a phone.
5. Squash-merge. The PR title becomes the commit that decides the next version.

## Why titles matter

[release-please](https://github.com/googleapis/release-please) reads the
squashed commits on `master` to pick the next version and write the changelog:

| Title starts with | Release | Changelog |
| --- | --- | --- |
| `feat:` | minor (1.1.0 → 1.2.0) | Features |
| `fix:`, `perf:` | patch (1.1.0 → 1.1.1) | Bug Fixes / Performance |
| `feat!:`, `fix!:` or a `BREAKING CHANGE:` footer | major (1.1.0 → 2.0.0) | Breaking |
| `docs:`, `test:`, `refactor:`, `build:`, `ci:`, `chore:`, `style:` | none | hidden |

Write `feat` and `fix` subjects for players: they become release notes.

## Test builds and releases

- Every PR gets a **MapMan Dev** APK: it installs next to the real app with its
  own save and has a DEV menu (level select, cheats, tilt tuning, play log).
  The latest master build is always at
  https://github.com/danbhala/MapMan/raw/apk-master/MapMan-Dev.apk
- release-please keeps a `chore(master): release X.Y.Z` PR open. Merging it tags
  the release, publishes it on GitHub with the APK, and updates
  https://github.com/danbhala/MapMan/raw/android-build/MapMan.apk

## Asking Claude from GitHub

Write `@claude` in an issue or PR comment ("@claude make level 35 a bit
easier") and Claude Code picks it up in GitHub Actions, following the same
skills, checks and title rules. The issue templates (bug, level, feature)
collect what it needs.

## One-time repository settings

These can only be changed by the repo owner on github.com:

- **Settings → Actions → General → Workflow permissions:** tick *Allow GitHub
  Actions to create and approve pull requests* (release-please needs it).
- **Settings → General → Pull Requests:** allow squash merging only, and set
  the default squash commit message to *Pull request title*.
- **Settings → Rules → Rulesets → New branch ruleset** for `master`: restrict
  deletions, block force pushes, require a pull request, and require the
  status checks `verify` and `Conventional PR title`.
- **Settings → Secrets and variables → Actions:** add `ANTHROPIC_API_KEY` (or
  `CLAUDE_CODE_OAUTH_TOKEN`, from `claude setup-token`) for the @claude action.
