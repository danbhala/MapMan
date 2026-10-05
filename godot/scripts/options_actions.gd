class_name OptionsActions
extends RefCounted
## The Options sheet's actions, for main.gd's menu actions: opening it, its
## switches ("<name> on" or "<name> off" sets the matching setting) and the
## language sheet. Loads only with the game scene, so it may name Save.


## Handles `act` if it is one of the Options sheet's; false if it isn't.
static func handle(act: String, menus: Menus) -> bool:
	if act == "options":
		menus.show_options()
	elif act == "language":
		menus.show_language()
	elif act.begins_with("language "):
		# "language system" follows the phone; otherwise a locale code.
		var code := act.get_slice(" ", 1)
		Save.set_locale("" if code == "system" else code)
		menus.show_language()
	elif _switch(act):
		menus.show_options()
	else:
		return false
	return true


## Sets the switch `act` names; false if `act` isn't one.
static func _switch(act: String) -> bool:
	var on := act.ends_with(" on")
	match act.trim_suffix(" on").trim_suffix(" off"):
		"music":
			Audio.set_music_enabled(on)
		"fx":
			Audio.set_fx_enabled(on)
		"vibration":
			Save.vibration_on = on
			Save.save_all()
			Haptics.feel("toggle")
		"ghost":
			Save.ghost_on = on
			Save.save_all()
		"reduce motion":
			Save.reduce_motion = on
			Save.save_all()
		"tilt gauge":
			Save.tilt_gauge = on
			Save.save_all()
		_:
			return false
	return true
