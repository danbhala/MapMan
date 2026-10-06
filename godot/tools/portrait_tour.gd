extends "res://tools/portrait_shots.gd"
## A video of the portrait prototype for Movie Maker mode: the main menu,
## level 6 steered by tilt (the arrow keys stand in for it, so the gauge in
## the deck moves), its level clear, then level 7 steered by dragging a
## thumb in the deck (mouse events stand in for it).
##
##   env -u DISPLAY xvfb-run -a godot --path godot --rendering-driver opengl3 \
##       --resolution 750x1334 --fixed-fps 30 --audio-driver Dummy \
##       --write-movie /tmp/portrait.avi --script res://tools/portrait_tour.gd

## The window is twice the viewport (750x1334 for 375x667).
const WINDOW_SCALE := 2.0
const THUMB_REACH := 34.0

var _thumb := Vector2.ZERO
var _thumb_down := false


func _mouse(pos: Vector2, pressed: bool, motion := false) -> void:
	var e: InputEvent
	if motion:
		var m := InputEventMouseMotion.new()
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		e = m
	else:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed
		e = b
	e.position = pos * WINDOW_SCALE
	e.global_position = e.position
	Input.parse_input_event(e)


func step_to(target: Vector2i) -> bool:
	if not game.tilt.stick:
		return await super.step_to(target)
	var map = game.map
	var dir: Vector2i = target - map.position_key
	if game.reverse:
		dir = -dir
	dir = Portrait.screen_dir(dir)
	if not _thumb_down:
		_thumb = game.deck.rect().get_center() + Vector2(0, 2)
		_mouse(_thumb, true)
		_thumb_down = true
		await frames(3)
	# Ease the thumb over towards the way to go.
	var to: Vector2 = _thumb + Vector2(dir) * THUMB_REACH
	var from: Vector2 = game.tilt.stick_origin() + game.tilt.stick_offset()
	for i in 4:
		_mouse(from.lerp(to, (i + 1) / 4.0), true, true)
		await process_frame
	for i in 4 * FPS:
		await process_frame
		if map.position_key == target and not map.moving:
			return true
		if game.dead or game.menus.visible:
			return false
	return false


func release_all() -> void:
	super.release_all()
	if _thumb_down:
		_mouse(_thumb, false)
		_thumb_down = false


func run() -> void:
	seed(20261004)
	var save = root.get_node("Save")
	save.persist = false
	save.first_play = false
	save.worn = "classic"
	save.released.clear()
	save.seen.clear()
	save.controls = "tilt"
	save.tilt_gauge = true
	var dev = root.get_node("Dev")
	dev.enabled = false
	dev.persist = false
	game = load("res://scenes/main.tscn").instantiate()
	game.show_gauge_anyway = true
	root.add_child(game)
	say("main menu")
	await hold(2.5)
	game.menus.close()
	game.new_game(6)
	say("level 6, tilt")
	await wait_until(func(): return game._timer_running)
	await hold(0.6)
	await walk(safe_route(game.map))
	await wait_until(func(): return game.menus.current == "end_level")
	say("level clear")
	await hold(3.5)
	game._on_menu_action("next level")
	await wait_until(func(): return game.menus.current == "")
	game.deck._choose("touch")
	say("level 7, drag")
	await wait_until(func(): return game._timer_running)
	await hold(0.8)
	await walk(safe_route(game.map))
	await wait_until(func(): return game.menus.current == "end_level")
	await hold(3.0)
	say("done")
	quit(0)
