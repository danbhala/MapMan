class_name LevelMap
extends Node2D
## The tile grid for one level. Port of map.py.
##
## Grid coordinates are Vector2i(column, row) with row 0 at the top of the
## level text. A border of empty cells surrounds every level, as in the
## original, so lookups one step off the map never fail.

const TILE_DIR := "res://assets/tiles/"
const ASSET_SCALE := 1.0 / 3.0  # the imported art is the original @3x set
const TILE_ALPHA := 0.8
const APPEAR_TIME := 0.25
const FOLD_TIME := 0.25
## Hiding and unhiding ripple out from the player, this long per tile away.
const RIPPLE_STEP := 0.02

## Original tile pitch in points (96x69 px @3x).
const TILE_W := 32.0
const TILE_H := 23.0
## Tile centres are centred on this line: the middle of the band between the
## HUD's header strip (which ends at 41, plus MapMan's 81 px of height above
## a tile) and its bottom bar (which starts at 318, less half a tile).
const CENTRE_Y := (122.0 + 306.0) / 2.0


class Tile:
	var key: Vector2i
	var type: String
	var sprite: Sprite2D  # null for empty cells ("-" or " ")
	var position: Vector2
	var can_hide := false
	var start_hidden := false

	var blank: bool:
		get:
			return sprite == null


var tiles := {}  # Vector2i -> Tile
var start_position := Vector2i.ZERO
var ends: Array[Tile] = []
var position_key := Vector2i.ZERO  # where the player is (or is moving from)
var tiles_hidden := false
var is_checkpoint := false
var checkpoint_flag: CheckpointFlag

# Tile effects. Each maps Vector2i -> bool (true = still active).
var reverses := {}
var vanishes := {}
var vanish_durations := {}
var deaths := {}
var lives := {}
var stickies := {}
var more_times := {}
var less_times := {}
var points := {}
var hides := {}
var unhides := {}

# Movement between two tiles.
var moving := false
var _move_from := Vector2i.ZERO
var _move_to := Vector2i.ZERO
var _move_elapsed := 0.0
var _move_seconds := 0.0

var _x_hides := 25
var _load_time := 0.0
var _load_elapsed := 0.0
var _min_x := 0.0
var _min_y := 0.0
var _screen_h := 375.0
var _rows_total := 0
var _textures := {}

# The assists (main.gd): pencil marks on hidden death tiles, a route sketch.
var _marks: PencilMarks
var _route: RouteSketch

# --- texture helpers -----------------------------------------------------


func _tex(file_name: String) -> Texture2D:
	if not _textures.has(file_name):
		_textures[file_name] = load(TILE_DIR + file_name)
	return _textures[file_name]


static func vanish_moves(t: String, x_hides: int) -> int:
	if t.is_valid_int():
		return int(t)
	if t == "v":
		return 5
	if t == "x":
		return x_hides
	return 0


func _texture_for(t: String, random_blank := true) -> Texture2D:
	if vanish_moves(t, _x_hides) > 0:
		return _tex("vanish.png")
	match t.to_lower():
		"b":
			return _tex("start.png")
		"h":
			return _tex("hide.png")
		"u":
			return _tex("unhide.png")
		"s":
			return _tex("south.png")
		"e":
			return _tex("east.png")
		"w":
			return _tex("west.png")
		"n":
			return _tex("north.png")
	match t:
		"p", "@":
			return _tex("points.png")
		"d", "!":
			return _tex("death.png")
		"l", "+":
			return _tex("life.png")
		"m":
			return _tex("more_time.png")
		"t":
			return _tex("less_time.png")
		"y":
			return _tex("sticky.png")
		"r":
			return _tex("reverse.png")
	if random_blank:
		return _tex("blank%d.png" % randi_range(1, 4))
	return _tex("blank1.png")


# --- loading -------------------------------------------------------------


func unload() -> void:
	for child in get_children():
		child.queue_free()
	tiles.clear()
	ends.clear()
	checkpoint_flag = null
	_marks = null
	_route = null
	moving = false


## level: one entry from data/levels.json or data/tutorial.json.
## screen_size: the visible viewport, used to centre the map like the original.
func load_level(level: Dictionary, screen_size: Vector2, x_hides_override := -1) -> void:
	unload()
	for d in [
		reverses,
		vanishes,
		vanish_durations,
		deaths,
		lives,
		stickies,
		more_times,
		less_times,
		points,
		hides,
		unhides
	]:
		d.clear()

	tiles_hidden = false
	is_checkpoint = level.get("checkpoint", false)
	_x_hides = x_hides_override if x_hides_override >= 0 else int(level.get("x_hides", 25))
	var delay: float = level.get("delay", 0.05)
	var rows: Array = level["rows"]
	var loading_rows = level.get("loading")

	var max_columns := 0
	for row in rows:
		max_columns = max(max_columns, String(row).length())

	# The original's centring maths in its y-up space, flipped to Godot's
	# y-down space in _screen_pos(), with the map centred on CENTRE_Y.
	_screen_h = screen_size.y
	# _screen_pos() puts row r at screen_h - _min_y - (rows - 2 - r) * TILE_H,
	# so the middle row lands on CENTRE_Y with this _min_y.
	_min_y = screen_size.y - CENTRE_Y - (rows.size() - 3) * TILE_H / 2.0
	_min_x = screen_size.x * 0.5 - (max_columns * 0.5) * TILE_W + 0.5 * TILE_W

	var loadings := {}  # loading char -> Array[Tile]
	var order: Array[Tile] = []
	var n := rows.size()
	_rows_total = n
	# Build bottom row first, like the original, so default appear order matches.
	_add_row(n, "", max_columns, null, loadings, order)
	for i in range(n - 1, -1, -1):
		var loading_line = null
		if loading_rows != null:
			loading_line = loading_rows[i]
		_add_row(i, rows[i], max_columns, loading_line, loadings, order)
	_add_row(-1, "", max_columns, null, loadings, order)

	position_key = start_position

	# Appear animation: groups of tiles pop in one after another.
	var groups: Array = []
	if not loadings.is_empty():
		var keys := loadings.keys()
		keys.sort()
		for k in keys:
			if k == "*":
				for tile: Tile in loadings[k]:
					_set_start_hidden(tile)
			else:
				groups.append(loadings[k])
	else:
		for tile in order:
			groups.append([tile])

	var count := 0
	for group in groups:
		if not group[0].blank:
			count += 1
		for tile: Tile in group:
			if not tile.blank:
				_appear(tile.sprite, count * delay)

	if is_checkpoint and not ends.is_empty():
		count += 1
		_add_checkpoint_flag(ends[0], count * delay)

	_load_time = count * delay
	_load_elapsed = 0.0


func _add_row(
	row: int, line: String, max_columns: int, loading_line, loadings: Dictionary, order: Array[Tile]
) -> void:
	_add_tile(" ", Vector2i(-1, row), null, loadings, order)
	var x := 0
	for ch in line:
		var lc = null
		if loading_line != null and x < String(loading_line).length():
			lc = String(loading_line)[x]
		_add_tile(ch, Vector2i(x, row), lc, loadings, order)
		x += 1
	while x < max_columns + 1:
		_add_tile(" ", Vector2i(x, row), null, loadings, order)
		x += 1


func _screen_pos(key: Vector2i, rows_total: int) -> Vector2:
	var y_up := rows_total - 1 - key.y  # original row index counted from the bottom
	var ox := _min_x + key.x * TILE_W
	var oy := _min_y + (y_up - 1) * TILE_H
	return Vector2(ox, _screen_h - oy)


func _add_tile(t: String, key: Vector2i, loading, loadings: Dictionary, order: Array[Tile]) -> void:
	var tile := Tile.new()
	tile.key = key
	tile.type = t
	tile.position = _screen_pos(key, _rows_total)
	if t != " " and t != "-":
		var s := Sprite2D.new()
		s.texture = _texture_for(t)
		s.modulate.a = TILE_ALPHA
		s.scale = Vector2.ZERO
		s.position = tile.position
		add_child(s)
		tile.sprite = s
		tile.can_hide = t.to_lower() in ["i", "@", "!", "+"]
	tiles[key] = tile
	order.append(tile)

	if loading != null:
		if not loadings.has(loading):
			loadings[loading] = []
		loadings[loading].append(tile)

	var v := vanish_moves(t, _x_hides)
	if v > 0:
		vanishes[key] = true
		vanish_durations[key] = v
	elif t.to_lower() == "b":
		start_position = key
	elif t.to_lower() in ["s", "w", "e", "n"]:
		ends.append(tile)
	elif t == "r":
		reverses[key] = true
	elif t in ["d", "!"]:
		deaths[key] = true
	elif t in ["l", "+"]:
		lives[key] = true
	elif t == "y":
		stickies[key] = true
	elif t == "m":
		more_times[key] = true
	elif t == "t":
		less_times[key] = true
	elif t in ["p", "@"]:
		points[key] = true
	elif t == "h":
		hides[key] = true
	elif t == "u":
		unhides[key] = true


func _appear(node: Node2D, wait: float, full := ASSET_SCALE) -> void:
	var tw := create_tween()
	tw.tween_interval(wait)
	(
		tw
		. tween_property(node, "scale", Vector2.ONE * full, APPEAR_TIME)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


func _set_start_hidden(tile: Tile) -> void:
	tile.start_hidden = true
	tile.can_hide = true
	# These tiles skip the appear animation, so give them full size now;
	# visibility alone decides whether they show.
	if tile.sprite:
		tile.sprite.scale = Vector2.ONE * ASSET_SCALE
	_hide_tile(tile)


func _add_checkpoint_flag(tile: Tile, wait: float) -> void:
	var flag := CheckpointFlag.new()
	# Its pole stands on the exit tile's north rim, like the original's.
	flag.position = tile.position - Vector2(0, TILE_H / 2.0)
	flag.z_index = 5
	flag.scale = Vector2.ZERO
	add_child(flag)
	checkpoint_flag = flag
	_appear(flag, wait, 1.0)


## The checkpoint flag, drawn in code: an inked pole with a gold pennant
## that waves. The original's dark flag art vanished on the blue field.
class CheckpointFlag:
	extends Node2D
	const POLE := 26.0
	var _clock := 0.0

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _draw() -> void:
		draw_line(Vector2.ZERO, Vector2(0, -POLE), Blueprint.INK, 1.5, true)
		var wave := sin(_clock * 6.0) * 1.5
		var pennant := PackedVector2Array(
			[
				Vector2(0.5, -POLE),
				Vector2(13.0 + wave, -POLE + 5.0 + wave * 0.5),
				Vector2(0.5, -POLE + 10.0)
			]
		)
		draw_colored_polygon(pennant, Blueprint.GOLD)


func loaded() -> bool:
	return _load_elapsed >= _load_time


func _process(delta: float) -> void:
	_load_elapsed += delta


# --- hiding --------------------------------------------------------------


# Hiding uses visibility, not scale: Godot never stores a scale of exactly
# zero, so a "scale == 0" check can't tell a hidden tile from a visible one.
# The fold and unfold animations run on top: a hidden tile is hidden at once
# and a stand-in folds away; an unhidden one is visible at once and unfolds.
func _hide_tile(tile: Tile, animate := false) -> void:
	if tile.can_hide and tile.sprite:
		if animate and tile.sprite.visible and Blueprint.motion():
			_fold(tile)
		tile.sprite.visible = false


func _unhide_tile(tile: Tile, animate := false) -> void:
	if tile.sprite:
		if animate and not tile.sprite.visible and Blueprint.motion():
			_unfold(tile)
		tile.sprite.visible = true


func _ripple_delay(tile: Tile) -> float:
	var d := tile.key - position_key
	return (absi(d.x) + absi(d.y)) * RIPPLE_STEP


## A copy of the tile folds flat (scale.y to zero) and goes.
func _fold(tile: Tile) -> void:
	var ghost := Sprite2D.new()
	ghost.texture = tile.sprite.texture
	ghost.position = tile.sprite.position
	ghost.scale = tile.sprite.scale
	ghost.modulate = tile.sprite.modulate
	add_child(ghost)
	var tw := create_tween()
	tw.tween_interval(_ripple_delay(tile))
	tw.tween_property(ghost, "scale:y", 0.0, FOLD_TIME).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(ghost.queue_free)


## The tile unfolds from flat to full height.
func _unfold(tile: Tile) -> void:
	var full: float = tile.sprite.scale.y
	tile.sprite.scale.y = 0.001
	var tw := create_tween()
	tw.tween_interval(_ripple_delay(tile))
	(
		tw
		. tween_property(tile.sprite, "scale:y", full, APPEAR_TIME)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


func unhide_tile_at(key: Vector2i) -> void:
	if tiles.has(key):
		_unhide_tile(tiles[key], true)


func hide_tiles() -> void:
	for tile: Tile in tiles.values():
		_hide_tile(tile, true)
	tiles_hidden = true


func unhide_tiles() -> void:
	for tile: Tile in tiles.values():
		_unhide_tile(tile, true)
	tiles_hidden = false


## A short note that floats up from the player's tile and fades: "+1 ★".
## Notes still in the air push a new one higher so they don't pile up.
func float_text(text: String, color: Color) -> void:
	if not tiles.has(position_key):
		return
	var in_flight := 0
	for child in get_children():
		if child is Label:
			in_flight += 1
	var pos: Vector2 = tiles[position_key].position
	var start := pos + Vector2(-40, -92 - 16 * in_flight)
	var l := Blueprint.label(self, text, 13, color, start, 700, 80, HORIZONTAL_ALIGNMENT_CENTER)
	l.z_index = 15
	if not Blueprint.motion():
		get_tree().create_timer(0.9).timeout.connect(l.queue_free)
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", start.y - 36, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func reset_hide() -> void:
	for tile: Tile in tiles.values():
		if tile.start_hidden:
			_hide_tile(tile)
		elif tiles_hidden:
			_unhide_tile(tile)
	tiles_hidden = false


# --- assists -------------------------------------------------------------


## Draw, or stop drawing, a dashed outline on every death tile that is
## hidden: the drafting convention for an edge you can't see.
func set_marks(on: bool) -> void:
	if on and _marks == null:
		_marks = PencilMarks.new(self)
		_marks.z_index = 4
		add_child(_marks)
	elif not on and _marks:
		_marks.queue_free()
		_marks = null


## How many death tiles the pencil marks outline right now.
func marked() -> int:
	return _marks.count() if _marks else 0


## Sketch the safe route from the start in gold for `seconds`, then let it fade.
func sketch_route(seconds: float) -> void:
	if _route:
		_route.queue_free()
	var points := PackedVector2Array()
	for key in safe_route():
		points.append(tiles[key].position)
	_route = RouteSketch.new(points, seconds)
	_route.z_index = 4
	add_child(_route)


## The shortest route from the start to an exit that touches no death tile,
## keeping off time-loss tiles when another way exists; empty if there is
## none. The same search the autoplay test walks.
func safe_route() -> Array[Vector2i]:
	for avoid_time_loss in [true, false]:
		var prev := {start_position: start_position}
		var queue: Array[Vector2i] = [start_position]
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			if ends.any(func(t: Tile) -> bool: return t.key == cur):
				var route: Array[Vector2i] = [cur]
				while cur != start_position:
					cur = prev[cur]
					route.push_front(cur)
				return route
			for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
				var nxt: Vector2i = cur + d
				if prev.has(nxt) or not tiles.has(nxt):
					continue
				var tile: Tile = tiles[nxt]
				if tile.blank or deaths.has(nxt):
					continue
				if avoid_time_loss and less_times.has(nxt):
					continue
				prev[nxt] = cur
				queue.append(nxt)
	return []


## Dashed outlines over the death tiles that are hidden right now. Which
## tiles those are changes as hide and unhide tiles are stepped on, so it
## looks again every frame; a sheet has a few dozen tiles at most.
class PencilMarks:
	extends Node2D
	const RX := 13.5
	const RY := 9.5
	const DASHES := 12
	var map: LevelMap

	func _init(on_map: LevelMap) -> void:
		map = on_map

	func _process(_delta: float) -> void:
		queue_redraw()

	func count() -> int:
		var n := 0
		for key in map.deaths:
			if _hidden(key):
				n += 1
		return n

	func _hidden(key: Vector2i) -> bool:
		var tile: Tile = map.tiles.get(key)
		return tile != null and tile.sprite != null and not tile.sprite.visible

	func _draw() -> void:
		for key in map.deaths:
			if not _hidden(key):
				continue
			var pts := Blueprint.ellipse_points(map.tiles[key].position, RX, RY, DASHES * 2)
			for i in range(0, pts.size() - 1, 2):
				draw_line(pts[i], pts[i + 1], Blueprint.PINK, 1.5, true)


## The safe route as a dashed gold line through the tiles, for a moment.
class RouteSketch:
	extends Node2D
	const FADE := 0.6
	var points: PackedVector2Array

	var seconds: float

	func _init(route: PackedVector2Array, for_seconds: float) -> void:
		points = route
		seconds = for_seconds

	func _ready() -> void:
		var tw := create_tween()
		tw.tween_interval(seconds)
		if Blueprint.motion():
			tw.tween_property(self, "modulate:a", 0.0, FADE)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		for i in points.size() - 1:
			draw_dashed_line(points[i], points[i + 1], Blueprint.GOLD, 2.0, 6.0, true, true)


# --- movement ------------------------------------------------------------


func get_player_position() -> Vector2:
	if moving:
		var a: Vector2 = tiles[_move_from].position
		var b: Vector2 = tiles[_move_to].position
		return a.lerp(b, clampf(_move_elapsed / _move_seconds, 0.0, 1.0))
	return tiles[position_key].position


func update_move(delta: float) -> void:
	if not moving:
		return
	_move_elapsed += delta
	if _move_elapsed >= _move_seconds:
		moving = false
		position_key = _move_to


## step is in screen directions: (1, 0) right, (0, -1) up.
func move(step: Vector2i, seconds: float) -> void:
	var target := position_key + step
	if tiles.has(target) and not tiles[target].blank:
		moving = true
		_move_from = position_key
		_move_to = target
		_move_elapsed = 0.0
		_move_seconds = seconds
	else:
		moving = false


## Restore consumable tiles after losing a life. Points and lives stay collected.
func reset() -> void:
	moving = false
	position_key = start_position
	for d in [unhides, hides, reverses, vanishes, stickies, deaths, more_times, less_times]:
		for key in d:
			d[key] = true
			var tile: Tile = tiles[key]
			tile.sprite.texture = _texture_for(tile.type)


func at_end() -> bool:
	for tile in ends:
		if tile.key == position_key:
			return true
	return false


## True if the tile under the player has this effect and it is still active.
func on(effect: Dictionary) -> bool:
	return effect.get(position_key, false)


## Consume the effect under the player and draw a plain tile there, with a
## little pop as it goes.
func clear(effect: Dictionary) -> void:
	if effect.has(position_key):
		effect[position_key] = false
		var sprite: Sprite2D = tiles[position_key].sprite
		sprite.texture = _tex("blank1.png")
		if Blueprint.motion() and sprite.visible:
			var tw := create_tween()
			tw.tween_property(sprite, "scale", Vector2.ONE * ASSET_SCALE * 1.18, 0.08)
			(
				tw
				. tween_property(sprite, "scale", Vector2.ONE * ASSET_SCALE, 0.16)
				. set_trans(Tween.TRANS_BACK)
				. set_ease(Tween.EASE_OUT)
			)


func vanish_duration() -> int:
	return vanish_durations[position_key]
