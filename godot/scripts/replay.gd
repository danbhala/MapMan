class_name Replay
extends Node2D
## The level clear's replay: every try at the level played back at once on
## the level's map, the winning run in full ink drawing its route as it goes,
## every lost try a faint MapMan with a faint pencil trail who leaves a pink
## cross where he fell (with a count where several fell). Finished when the
## winner has stood at the exit a moment; `finished` then fires.

signal finished

## How faint the lost tries are.
const LOST_ALPHA := 0.3
## How long the winner stands at the exit before the replay ends.
const HOLD_SECONDS := 1.5
## How long a lost try stays after he falls, his death played out.
const FALL_SECONDS := 0.9

var tries: Array[RunRecord] = []
var clock := 0.0

var _map: LevelMap
var _ghosts: Array[Player] = []
var _states: Array[Dictionary] = []
var _start := Vector2i.ZERO
var _length := 0.0
var _layer: CanvasLayer
var _clock_label: Label


## Plays `tries` (the winning one last) on `map`, which has the level loaded
## or loading, each MapMan in the look he wore for that try. `title` and
## `subtitle` head the screen.
func setup(map: LevelMap, try_list: Array[RunRecord], title: String, subtitle: String) -> void:
	_map = map
	tries = try_list
	_start = map.start_position
	z_index = 1  # over the tiles, under the MapMen (Player sets 10)
	for r in tries:
		_length = maxf(_length, r.end_time + (0.0 if r.won() else FALL_SECONDS))
		var g := Player.new()
		g.outfit = r.outfit if Wardrobe.is_look(r.outfit) else "classic"
		add_child(g)
		g.z_index = 11 if r.won() else 10
		_ghosts.append(g)
		_states.append({"dir": Vector2i(9, 9), "moving": false, "ended": false})
	for r in tries:
		if r.won():
			_length = maxf(_length, r.end_time + HOLD_SECONDS)
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)
	Blueprint.label(_layer, title, 15, Blueprint.INK, Vector2(24, 16), 700)
	Blueprint.label(_layer, subtitle, 11, Blueprint.FAINT, Vector2(24, 38))
	_clock_label = Blueprint.label(_layer, "", 15, Blueprint.INK, Vector2(500, 16), 700, 143)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.text_direction = Control.TEXT_DIRECTION_LTR


func _process(delta: float) -> void:
	if _map == null or not _map.loaded():
		return
	clock += delta
	for i in tries.size():
		_pose(i, delta)
	_clock_label.text = "T+%.1f" % minf(clock, _winner_time())
	queue_redraw()
	if clock >= _length:
		set_process(false)
		finished.emit()


func _winner_time() -> float:
	for r in tries:
		if r.won():
			return r.end_time
	return _length


func _pos(key: Vector2i) -> Vector2:
	var tile = _map.tiles.get(key)
	return tile.position if tile else Vector2.ZERO


func _pose(i: int, delta: float) -> void:
	var r := tries[i]
	var g := _ghosts[i]
	var s := _states[i]
	if s.ended:
		g.tick(delta)
		if not r.won() and clock > r.end_time + FALL_SECONDS:
			g.visible = false
		return
	if g.is_hidden:
		g.show_player()
		g.reset_pose()
	var at := r.at(_start, clock)
	var a := _pos(at.key)
	g.update_at(a.lerp(_pos(at.next), at.share), delta)
	g.modulate.a = 1.0 if r.won() else LOST_ALPHA
	if at.dir != s.dir or at.moving != s.moving:
		if at.dir == Vector2i.ZERO:
			g.face_idle()
		else:
			g.face_direction(at.dir, at.moving)
		s.dir = at.dir
		s.moving = at.moving
	if clock >= r.end_time:
		s.ended = true
		if r.won():
			g.cheer()
			g.face_down_idle()
		else:
			g.face_death()


func _draw() -> void:
	var pos_of := Callable(self, "_pos")
	var crosses := {}
	for r in tries:
		var t := minf(clock, r.end_time)
		var pts := r.path_to(_start, t, pos_of)
		if pts.size() > 1:
			if r.won():
				draw_polyline(pts, Color(Blueprint.INK, 0.9), 2.0, true)
			else:
				draw_polyline(pts, Color(Blueprint.INK, 0.16), 1.0, true)
		if not r.won() and clock >= r.end_time:
			var key := r.end_key(_start)
			crosses[key] = crosses.get(key, 0) + 1
	var font := Blueprint.mono(700)
	for key in crosses:
		var p := _pos(key) + Vector2(0, -6)
		var c := Color(Blueprint.PINK, 0.9)
		draw_line(p + Vector2(-4, -4), p + Vector2(4, 4), c, 1.5, true)
		draw_line(p + Vector2(-4, 4), p + Vector2(4, -4), c, 1.5, true)
		if crosses[key] > 1:
			draw_string(
				font, p + Vector2(6, -1), "×%d" % crosses[key], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, c
			)
