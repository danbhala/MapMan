extends "res://tools/portrait_shots.gd"
## A video of the portrait prototype for Movie Maker mode: the main menu,
## level 6 steered by tilt, its level clear, then level 7 steered by a thumb
## in the deck. The input is played like a hand: the lean eases in and out,
## wanders a little off the axis, trembles even when held still (so the
## gauge's dot never sits dead centre), runs on long straights, and the thumb
## lands a little off the ring's middle and shakes.
##
##   env -u DISPLAY xvfb-run -a godot --path godot --rendering-driver opengl3 \
##       --resolution 1080x1920 --fixed-fps 30 --audio-driver Dummy \
##       --write-movie /tmp/portrait.avi --script res://tools/portrait_tour.gd

## The window over the 375-wide viewport (1080x1920 for 375x667).
const WINDOW_SCALE := 1080.0 / 375.0
## How fast the hand follows a new lean (seconds, roughly).
const EASE := 0.07
const WALK_LEAN := Vector2(0.13, 0.17)
const RUN_LEAN := Vector2(0.23, 0.27)
## Straights at least this long are run.
const RUN_FROM := 4
const OFF_AXIS := 0.04
const TREMOR := 0.012
const DRIFT := 0.018
const THUMB_SHAKE := 1.2
## How long a hand takes to catch on to a reverse tile.
const REACT := 0.35

var hand  # tools/human_tilt.gd, standing in for the phone
var _lean := Vector2.ZERO
var _target := Vector2.ZERO
var _off := 0.0
var _clock := 0.0
var _thumb_down := false
var _thumb := Vector2.ZERO
var _driving := false


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


## The hand's own wobble: a tremor of a few hertz and a slow drift.
func _wobble(t: float) -> Vector2:
	var tremor := Vector2(
		sin(t * 17.3) + 0.6 * sin(t * 29.1 + 1.3), cos(t * 15.7) + 0.6 * sin(t * 31.9 + 0.4)
	)
	var drift := Vector2(sin(t * 1.1 + 0.5), sin(t * 0.83 + 2.0))
	return tremor * TREMOR / 1.6 + drift * DRIFT


## Called every frame while the hand is on the phone.
func _hand(delta: float) -> void:
	_clock += delta
	_lean = _lean.lerp(_target, 1.0 - exp(-delta / EASE))
	var v := _lean + _wobble(_clock)
	if game.tilt.stick:
		if not _thumb_down:
			return
		var reach := 46.0 / (0.2 * 1.5)  # TouchStick.RADIUS over its rim tilt
		var at := _thumb + v * reach + Vector2(randf() - 0.5, randf() - 0.5) * THUMB_SHAKE
		_mouse(at, true, true)
	else:
		hand.lean = v


func _thumb_on() -> void:
	_thumb = game.deck.rect().get_center() + Vector2(randf_range(-6, 6), randf_range(-4, 6))
	_mouse(_thumb, true)
	_thumb_down = true


func _thumb_off() -> void:
	if _thumb_down:
		_mouse(_thumb + _lean * 40.0, false)
		_thumb_down = false


## Frames with the hand on the phone (and the thumb resting, when dragging).
func idle(seconds: float) -> void:
	for i in ceili(seconds * FPS):
		_hand(1.0 / FPS)
		await process_frame


## The way to lean for a step in the map's directions.
func _lean_for(step: Vector2i, run: bool) -> Vector2:
	if step == Vector2i.ZERO:
		return Vector2.ZERO
	if game.reverse:
		step = -step
	var dir := Vector2(Portrait.screen_dir(step))
	var span := RUN_LEAN if run else WALK_LEAN
	var side := Vector2(-dir.y, dir.x) * _off
	return dir * randf_range(span.x, span.y) + side


## How many steps the straight from route[i] keeps going the same way.
func _straight(route: Array, i: int, from: Vector2i) -> int:
	var d: Vector2i = route[i] - from
	var n := 1
	while i + n < route.size() and route[i + n] - route[i + n - 1] == d:
		n += 1
	return n


## Leans MapMan along the route. The next lean starts while he is still
## stepping onto the corner, as a player's hand does.
func drive(route: Array) -> void:
	var map = game.map
	var leaning_for := -1
	var reversed: bool = game.reverse
	for frame in 60 * FPS:
		if game.dead or game.menus.visible or route.is_empty():
			break
		var i := route.find(map.position_key)  # -1 before the first step
		var next := i + 1
		if map.moving:
			next = route.find(map._move_to) + 1
		var from: Vector2i = route[next - 1] if next > 0 else map.position_key
		if next >= route.size():
			_target = Vector2.ZERO
		elif game.reverse != reversed and not map.moving:
			# A reverse tile: the hand stops, catches on, then leans the other way.
			reversed = game.reverse
			_target = Vector2.ZERO
			await idle(REACT)
			leaning_for = -1
			continue
		elif next != leaning_for:
			var step: Vector2i = route[next] - from
			var prev: Vector2i = from - (route[next - 2] if next > 1 else from)
			if step != prev or leaning_for < 0:
				_off = randf_range(-OFF_AXIS, OFF_AXIS)
				_target = _lean_for(step, _straight(route, next, from) >= RUN_FROM)
			leaning_for = next
		_hand(1.0 / FPS)
		await process_frame
	_target = Vector2.ZERO


func run() -> void:
	seed(20261006)
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
	hand = load("res://tools/human_tilt.gd").new()
	game.tilt = hand
	root.add_child(game)
	say("main menu")
	await hold(2.5)
	game.menus.close()
	game.new_game(6)
	say("level 6, tilt")
	await idle(0.4)
	await wait_until(func(): return game._timer_running)
	await idle(0.9)
	await drive(safe_route(game.map))
	await idle(0.3)
	await wait_until(func(): return game.menus.current == "end_level")
	say("level clear")
	await hold(3.5)
	game._on_menu_action("next level")
	await wait_until(func(): return game.menus.current == "")
	save.controls = "touch"
	game.steering.apply()
	say("level 7, drag")
	await wait_until(func(): return game._timer_running)
	await hold(0.7)
	_lean = Vector2.ZERO
	_thumb_on()
	await idle(0.3)
	await drive(safe_route(game.map))
	_thumb_off()
	await wait_until(func(): return game.menus.current == "end_level")
	await hold(3.0)
	say("done")
	quit(0)
