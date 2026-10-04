class_name Intro
extends Node2D
## The intro and title screen, shown once at launch before the main menu.
##
## Sheet 000: the route draws itself in while MapMan walks on, the tiles
## hide, he looks around and walks it from memory, nearly steps on a hidden
## skull, takes the right way out, and the title stamps down over a pulsing
## TAP TO START. A tap (or a key, or the back button) skips straight to the
## title; the next one emits `finished`. With reduced motion it opens on the
## title.

signal finished

## The intro's own little level ("i" tiles hide, "!" is a hidden skull) and
## the order its tiles pop in, like the levels' loading strings.
const LEVEL := {
	"rows": ["    iiiiii     ", "    i    i   ie", "biiii!   iiiii "],
	"loading": ["    ghijkl     ", "    f    m   st", "abcdef   nopqr "],
	"delay": 0.045,
	"x_hides": 25,
}
## The way out once he has backed off the skull.
const ROUTE: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.RIGHT,
	Vector2i.RIGHT,
	Vector2i.RIGHT,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.DOWN,
	Vector2i.RIGHT,
	Vector2i.RIGHT,
	Vector2i.RIGHT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.RIGHT,
]
const STEP_TIME := 14.0 / 60.0  # Main.STOP_TIME: one tile on a gentle tilt
const TEXT := {"tap": "TAP TO START", "skip": "SKIP", "hidden": "TILES HIDDEN"}

var map: LevelMap
var player: Player
## "intro" while the scene plays, "title" once TAP TO START shows.
var state := "intro"

var _pos := Vector2.ZERO
var _size := Vector2(667, 375)
var _ui: Control
var _strip: Label
var _bar: ColorRect
var _skip: Label
var _title: Label
var _tap: Label
var _pulse: Tween
var _audio: Node


func _ready() -> void:
	_audio = Blueprint.autoload("Audio")
	_size = get_viewport_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	var inset := Vector2(11, 11)
	Blueprint.line(_ui, Blueprint.box_points(inset, _size - inset * 2.0), Blueprint.INK, 1.5)

	map = LevelMap.new()
	add_child(map)
	map.load_level(LEVEL, _size)
	player = Player.new()
	var save := Blueprint.autoload("Save")
	if save != null:
		player.outfit = save.worn
	add_child(player)
	if _audio != null:
		_audio.play_menu()
	if Blueprint.motion():
		_play()
	else:
		_show_title(false)


func _process(delta: float) -> void:
	if player.is_hidden:
		return
	player.update_at(_pos, delta)


func _unhandled_input(event: InputEvent) -> void:
	var tap: bool = event is InputEventMouseButton and not event.pressed
	if tap or event.is_action_pressed("ui_accept") or event.is_action_pressed("shake"):
		get_viewport().set_input_as_handled()
		advance()


## Skips to the title, or from the title on to the game.
func advance() -> void:
	if state == "intro":
		_show_title(false)
	elif state == "title":
		state = "done"
		finished.emit()


# --- the scene -----------------------------------------------------------


func _play() -> void:
	_skip = Blueprint.label(_ui, tr(TEXT.skip) + "  »", 12, Blueprint.INK, Vector2.ZERO, 800)
	_skip.size = _skip.get_minimum_size()
	_skip.position = Vector2(_size.x - 24 - _skip.size.x, 20)
	_pulse = _blink(_skip, 0.35, 0.6)
	_strip = Blueprint.label(_ui, "", 11, Blueprint.FAINT, Vector2(24, _size.y - 32), 700)
	_strip.text_direction = Control.TEXT_DIRECTION_LTR
	_bar = ColorRect.new()
	_bar.color = Blueprint.FAINT
	_bar.position = Vector2(70, _size.y - 25)
	_bar.size = Vector2(0, 2)
	_ui.add_child(_bar)

	# The route draws itself in while he walks on from the left.
	var start: Vector2 = map.tiles[map.start_position].position
	var from := start + Vector2(-120, 0)
	_pos = from
	player.show_player()
	player.face_right()
	var walk := 1.0
	var t := 0.0
	while t < walk or not map.loaded():
		if not await _frame():
			return
		t += get_process_delta_time()
		_pos = from.lerp(start, minf(t / walk, 1.0))
		var done := clampf(map._load_elapsed / maxf(map._load_time, 0.01), 0.0, 1.0)
		_strip.text = "%d%%" % int(done * 100.0)
		_bar.size.x = 120.0 * done
		if fmod(t, 0.23) < get_process_delta_time() and t < walk:
			_sfx_step()
	_pos = start
	player.face_right_idle()
	player.land()

	# He studies the route, it hides, he glances at you.
	player.auto_look = false
	player.look = Vector2(1, -0.4)
	if not await _wait(0.6):
		return
	_sfx("hide")
	map.hide_tiles()
	_bar.visible = false
	_strip.text = tr(TEXT.hidden)
	_strip.add_theme_color_override("font_color", Blueprint.MINT)
	player.face_idle()
	player.look = Vector2(-1, 0)
	if not await _wait(0.3):
		return
	player.look = Vector2(0, 0.6)
	if not await _wait(0.45):
		return
	player.auto_look = true

	# From memory... nearly straight on into the skull.
	for i in 4:
		if not await _step(Vector2i.RIGHT, STEP_TIME * 0.8):
			return
	var here := _pos
	var skull_key := map.position_key + Vector2i.RIGHT
	var skull: Vector2 = map.tiles[skull_key].position
	player.face_right()
	for i in 5:
		if not await _frame():
			return
		_pos = here.lerp(skull, (i + 1) / 5.0 * 0.4)
	map.unhide_tile_at(skull_key)
	_sfx("lose_life", 0.7, 1.3)
	player.face_right_idle()
	player.land()
	player.auto_look = false
	player.look = Vector2(1, 0.8)
	if not await _wait(0.3):
		return
	player.face_idle()
	player.look = Vector2(0, 0.5)
	if not await _wait(0.35):
		return
	player.face_left()
	var back := _pos
	for i in 4:
		if not await _frame():
			return
		_pos = back.lerp(here, (i + 1) / 4.0)
	player.auto_look = true
	# ...and the right way out, at a run.
	for d in ROUTE:
		if not await _step(d, STEP_TIME * 0.5):
			return
	_sfx("end_level")
	_show_title(true)


## Ends the scene on the title: MapMan on the exit, every tile showing,
## MAPMAN stamped above and TAP TO START pulsing below.
func _show_title(animate: bool) -> void:
	if state != "intro":
		return
	state = "title"
	if _pulse:
		_pulse.kill()
	for node in [_skip, _strip, _bar]:
		if node:
			node.visible = false
	map.unhide_tiles()
	map.position_key = map.ends[0].key
	_pos = map.ends[0].position
	player.reset_pose()
	player.show_player()
	player.auto_look = true
	player.face_idle()
	if animate:
		player.cheer()

	_title = Blueprint.label(_ui, "MAPMAN", 64, Blueprint.INK, Vector2.ZERO, 800)
	_title.size = _title.get_minimum_size()
	_title.pivot_offset = _title.size / 2.0
	_title.position = Vector2((_size.x - _title.size.x) / 2.0, 24)
	_tap = Blueprint.label(_ui, tr(TEXT.tap), 20, Blueprint.GOLD, Vector2.ZERO, 800)
	_tap.size = _tap.get_minimum_size()
	_tap.position = Vector2((_size.x - _tap.size.x) / 2.0, _size.y - 52)
	if not animate or not Blueprint.motion():
		_blink(_tap, 0.3, 0.5)
		return
	_title.scale = Vector2(2.2, 2.2)
	_title.modulate.a = 0.0
	_tap.visible = false
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(_title, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tw.parallel().tween_property(_title, "modulate:a", 1.0, 0.12)
	tw.tween_callback(_sfx.bind("stamp", 1.0, 0.8))
	tw.tween_interval(0.35)
	tw.tween_callback(_tap.show)
	tw.tween_callback(_blink.bind(_tap, 0.3, 0.5))


# --- helpers -------------------------------------------------------------


## One frame of the scene; false once it was skipped (the caller stops).
func _frame() -> bool:
	await get_tree().process_frame
	return state == "intro" and is_inside_tree()


func _wait(seconds: float) -> bool:
	var t := 0.0
	while t < seconds:
		if not await _frame():
			return false
		t += get_process_delta_time()
	return true


## Walks one tile the way the game does, landing with a step sound.
func _step(d: Vector2i, seconds: float) -> bool:
	map.move(d, seconds)
	player.face_direction(d, true)
	while map.moving:
		if not await _frame():
			return false
		map.update_move(get_process_delta_time())
		_pos = map.get_player_position()
	_pos = map.get_player_position()
	map.unhide_tile_at(map.position_key)
	player.land()
	_sfx_step()
	return true


func _blink(node: CanvasItem, low: float, half: float) -> Tween:
	var tw := create_tween().set_loops()
	tw.tween_property(node, "modulate:a", low, half).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "modulate:a", 1.0, half).set_trans(Tween.TRANS_SINE)
	return tw


func _sfx(sound: String, volume := 1.0, pitch := 1.0) -> void:
	if _audio != null:
		_audio.play(sound, volume, pitch)


func _sfx_step() -> void:
	if _audio != null:
		_audio.play_step()
