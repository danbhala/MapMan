# AdMob plugin in MapMan

Poing Studios' [Godot AdMob plugin](https://github.com/poingstudios/godot-admob-plugin)
v5.1.0 (MIT, see LICENSE), from the release's `poing-godot-admob-v5.1.0.zip`
without its `csharp/`, `skills/` and `gdscript/sample/` folders (and the
sample's music, theme, font and big icon in `assets/`, so they stay out of the APK). `android/bin/` holds the `ads`
library from `android-template-v4.5.0.zip` (no mediation networks), so exports
never download anything (the plugin's own `.gitignore`s for `android/bin/` and
`ios/bin/` are removed so they are committed). `scripts/ads_admob.gd` is the
only game code that uses it.

Two lines are changed, both in `internal/services/project_settings_service.gd`
and marked `MapMan:`:

- `register_settings()` no longer saves `project.godot`. Godot never writes a
  setting that is at its default and doesn't load one named `.../enabled`, so
  the plugin found its settings "missing" and rewrote the file, losing its
  comments, every time the editor (or a headless import or export) started.
- `admob/general/ios/enabled` defaults to false. `ios/bin/package.gd` is only a
  marker so the headless editor doesn't fetch the iOS binaries. For iPhone ads,
  install them from Project > Tools > AdMob Manager > iOS and flip the default.

Updating the plugin: copy the new release over this folder, keep `android/bin/`
in step with the Godot version, and redo the two changes above.
