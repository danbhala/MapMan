@tool
extends EditorPlugin
## Adds level links to the Android manifest at export (DraftingTable.check_link):
## mapman://level/<code>, which the link page (site/) opens, and
## https://danbhala.github.io/MapMan/<code> itself, which opens the game
## straight away once a player allows it (Settings, Open by default: the
## domain root isn't ours, so Android can't verify it). Needs the presets'
## gradle build.

var _export: LinkExport


func _enter_tree() -> void:
	_export = LinkExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class LinkExport:
	extends EditorExportPlugin

	const FILTER := """
<intent-filter>
	<action android:name="android.intent.action.VIEW" />
	<category android:name="android.intent.category.DEFAULT" />
	<category android:name="android.intent.category.BROWSABLE" />
	<data android:scheme="mapman" android:host="level" />
</intent-filter>
<intent-filter>
	<action android:name="android.intent.action.VIEW" />
	<category android:name="android.intent.category.DEFAULT" />
	<category android:name="android.intent.category.BROWSABLE" />
	<data android:scheme="https" android:host="danbhala.github.io" />
	<data android:pathPrefix="/MapMan/" />
</intent-filter>
"""

	func _get_name() -> String:
		return "LevelLinks"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_manifest_activity_element_contents(
		_platform: EditorExportPlatform, _debug: bool
	) -> String:
		return FILTER
