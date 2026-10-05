@tool
extends EditorPlugin
## Adds the level link to the Android manifest at export, so a phone opens
## https://danbhala.github.io/mapman/<code> in MapMan (DraftingTable.check_link).
## Needs the presets' gradle build; the site's assetlinks.json names the
## signing key, so Android opens links without asking.

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
<intent-filter android:autoVerify="true">
	<action android:name="android.intent.action.VIEW" />
	<category android:name="android.intent.category.DEFAULT" />
	<category android:name="android.intent.category.BROWSABLE" />
	<data android:scheme="https" />
	<data android:host="danbhala.github.io" />
	<data android:pathPrefix="/mapman/" />
	<data android:pathPrefix="/MAPMAN/" />
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
