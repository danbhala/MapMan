---
name: build-apk
description: Build, sign and publish the MapMan Android APK so it can be installed on a phone. Only when the user asks for a build.
disable-model-invocation: true
---

Build an installable Android APK of MapMan and publish it on the `android-build`
branch, which phones download from:
https://github.com/danbhala/MapMan/raw/android-build/MapMan.apk

Numbered releases don't need this skill: merging release-please's
"chore(main): release X.Y.Z" PR makes `.github/workflows/release.yml` build the
APK, attach it to the GitHub Release and refresh `android-build`. Use this skill
only for test builds between releases, and don't bump `version/name` or
`version/code` in the repo (release builds stamp them from `version.txt`; a
test build can set them locally without committing).

1. Run the `/verify` skill first. Don't build from a failing tree.
2. For the phone to install it as an update, its `version/code` must be higher
   than the installed one: set it locally to the last release's code + 1
   (release code = major×10000 + minor×100 + patch) and don't commit that.
3. Requirements: Godot 4.5.1 Android export templates in
   `~/.local/share/godot/export_templates/4.5.1.stable/`, and editor settings
   pointing `export/android/android_sdk_path` and `java_sdk_path` at an Android
   SDK and a JDK 17+. The preset exports unsigned (`package/signed=false`) so
   signing doesn't depend on the SDK's build-tools.
4. Export (the output path is relative to the project folder, and the folder
   must exist): `mkdir -p godot/build && godot --headless --path godot --export-release "Android" build/MapMan-unsigned.apk`
5. Sign and zipalign with apksigner + zipalign from build-tools, or with
   [uber-apk-signer](https://github.com/patrickfav/uber-apk-signer):
   `java -jar uber-apk-signer.jar -a godot/build/MapMan-unsigned.apk -o godot/build/signed`.
   Use the same key every time (uber-apk-signer's built-in debug key is stable),
   or Android will refuse to install over the previous build.
6. Check: the signer reports "signature verified", and
   `unzip -l <apk> | grep assets/data/levels.json` finds the level data.
7. Publish: copy the APK to `MapMan.apk` at the root of the `android-build`
   branch (an orphan branch with only the APK and a README), commit, push.
   Never commit APKs to master.
8. Tell the user the download link, the version name, and what changed since
   the last build.
