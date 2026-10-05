class_name Steering
extends RefCounted
## How the player steers, for main.gd: the CONTROLS sheet's choices
## (ControlsSheet) and the floating touch stick (TouchStick) with its taps.
## Loads only with the game scene, so it may name Save.

## The stick drawn under the finger.
var stick: TouchStick

var _game  # main.gd


func _init(game, layer: CanvasLayer) -> void:
	_game = game
	stick = TouchStick.new()
	layer.add_child(stick)


## Takes up the player's control options (Save.controls, tilt_sensitivity).
func apply() -> void:
	var tilt: TiltInput = _game.tilt
	tilt.stick = Save.controls == "touch"
	tilt.sensitivity = Save.tilt_sensitivity
	tilt.stick_release()
	tilt.touch(false, Vector2.ZERO)
	_game._held_step = Vector2i.ZERO


## Each frame: the stick shows under the finger while playing; a menu lets go.
func update() -> void:
	var tilt: TiltInput = _game.tilt
	if tilt.stick_held() and (not _game.game_active or _game.menus.visible):
		tilt.stick_release()
	stick.held = tilt.stick_held()
	if stick.held:
		stick.origin = tilt.stick_origin()
		stick.knob = tilt.stick_offset()
		stick.pace = _game.pace(tilt.stick_vector())


## Handles `act` if it is one of the CONTROLS sheet's; false if it isn't.
func handle(act: String) -> bool:
	var choice := false
	for kind in ["controls ", "sensitivity ", "tilt gauge "]:
		choice = choice or act.begins_with(kind)
	if choice:
		ControlsSheet.choose(act)
		apply()
	elif act != "controls":
		return false
	_game.menus.show_controls()
	return true


## A touch on the field while playing: the stick when steering by touch,
## else the original's edge zones on a phone without an accelerometer, else a
## tap pauses.
func input(event: InputEvent) -> void:
	var tilt: TiltInput = _game.tilt
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not _game.game_active or _game.menus.visible:
			return
		if tilt.stick:
			_stick_touch(event.pressed, event.position)
		elif tilt.touch_steering_enabled():
			# No accelerometer: hold towards an edge to steer (the original's
			# tilt simulator). A fresh tap also frees MapMan from a sticky tile.
			tilt.touch(event.pressed, event.position)
			if event.pressed and _game.stuck:
				_game.stuck = false
		elif not event.pressed and _game._can_pause():
			_game.show_pause_menu()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if tilt.stick:
			tilt.stick_drag(event.position)
		elif tilt.touch_steering_enabled():
			tilt.touch(true, event.position)


## A finger lands on the field (the stick appears under it) or lifts; a tap
## that never dragged pauses. Without an accelerometer to shake, a fresh
## touch also frees MapMan from a sticky tile.
func _stick_touch(pressed: bool, pos: Vector2) -> void:
	var tilt: TiltInput = _game.tilt
	if pressed:
		tilt.stick_press(pos)
		_game.stuck = _game.stuck and TiltInput.has_accelerometer()
	elif tilt.stick_release() and _game._can_pause():
		_game.show_pause_menu()
