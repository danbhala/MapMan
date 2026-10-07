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
- Every PR and master push also uploads a **MapMan Dev** build to TestFlight
  (once the Apple secrets below are set); testers install it with the
  TestFlight app on an iPhone, about 10 minutes after the PR comment says so.
- The **Play build** workflow (Actions tab → Play build → Run workflow)
  builds the signed app bundle Google Play takes and uploads it to the
  internal testing track, or leaves it as the run's artifact to upload by hand
  (setup below under *Play builds*).
- release-please keeps a `chore(master): release X.Y.Z` PR open. Merging it tags
  the release, publishes it on GitHub with the APK and the `.ipa`, uploads a
  **MapMan** build to TestFlight, and updates
  https://github.com/danbhala/MapMan/raw/android-build/MapMan.apk
  Submitting a TestFlight build to the App Store is done by hand in App Store
  Connect.

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

### iPhone builds (TestFlight)

The Test builds and Release workflows skip their iPhone job, with a notice,
until these are set up. Once, by the owner:

1. Join the Apple Developer Program.
2. In the developer portal, register two App IDs with no extra capabilities:
   `com.danbhala.mapman` (MapMan) and `com.danbhala.mapman.dev` (MapMan Dev).
3. In App Store Connect, create an app record for each (name, primary language,
   bundle ID, SKU). Under TestFlight, add an internal group to each with the
   testers' Apple IDs (internal testing needs no review).
4. Create an App Store Connect API key (Users and Access → Integrations, role
   App Manager): note the Key ID and the Issuer ID, download the `.p8`.
5. Create an **Apple Distribution** certificate and export it with its private
   key as a `.p12` (Keychain Access on a Mac, or make the CSR with openssl,
   upload it in the portal, and join the downloaded `.cer` and the key with
   `openssl pkcs12 -export`).
6. **Settings → Secrets and variables → Actions:** add `APPLE_TEAM_ID`,
   `APPSTORE_ISSUER_ID`, `APPSTORE_KEY_ID`, `APPSTORE_PRIVATE_KEY` (the `.p8`
   file's text), `IOS_DIST_CERT_P12_BASE64` (`base64 -i dist.p12`) and
   `IOS_DIST_CERT_PASSWORD`.

No provisioning profile needs storing: each build fetches the app's App Store
profile with the API key (`fastlane sigh`, which creates it the first time).
Build numbers only go up (the run number for MapMan Dev, major×10000 +
minor×100 + patch for MapMan), and TestFlight builds expire after 90 days.

### Play builds (Google Play)

The Play build workflow signs the bundle with a throwaway key, with a warning,
until these are set up. Once, by the owner:

1. Make the upload key on your own machine (keep the file and the password
   somewhere safe; if they are lost, Play Console can reset the upload key):

   ```
   keytool -genkeypair -v -keystore mapman-upload.keystore -alias upload \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -dname "CN=MapMan upload key, O=danbhala, C=IE"
   ```

   Use the same password for the keystore and the key when it asks.
2. **Settings → Secrets and variables → Actions:** add
   `PLAY_UPLOAD_KEYSTORE_BASE64` (`base64 -w0 mapman-upload.keystore`, or
   `base64 -i mapman-upload.keystore` on a Mac) and
   `PLAY_UPLOAD_KEYSTORE_PASSWORD`.
3. In Play Console, create the app `com.danbhala.mapman` (free, game). Play App
   Signing is on by default: Google makes the signing key from the first
   bundle you upload, and the bundle carries the upload certificate.
4. Run the Play build workflow once with the track set to *none*, download
   the `.aab` from the run's artifacts and upload it by hand under *Test and
   release → Internal testing → Create new release*. Play's API refuses an
   app's very first bundle, so the first one is always by hand. Add testers
   there as an email list; they opt in once through the link and then get
   every later build from the Play Store.
5. Optional, so later runs upload themselves: in Google Cloud make a service
   account in the project Play Console created, download its JSON key, invite
   its email in Play Console under *Users and permissions* with *Release to
   testing tracks* on this app, and add the JSON's text as the
   `PLAY_SERVICE_ACCOUNT_JSON` secret.

Version codes on Play are the release code (major×10000 + minor×100 + patch)
times 1000 plus the workflow's run number, so they only ever go up; the version
name is `X.Y.Z-play.N`. The sideloadable APKs keep their own debug-key signing
and are unaffected.

