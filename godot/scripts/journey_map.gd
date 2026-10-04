class_name JourneyMap
extends LevelMap
## A LevelMap that can also play a journey (research prototype): one big
## sheet cut into screen-sized rooms. Only the room MapMan is in shows; walking
## off its edge slides the next room in. Each room hides on its own, so you
## study and walk one room at a time, and a room you hid stays hidden when you
## come back through it. K is a key, D a door it opens. A lost life restarts at
## the tile where MapMan entered the room he is in, still holding his key.
##
## Levels without "room_size" play exactly as a LevelMap.

signal room_entered(room: Vector2i, first_time: bool)
signal door_bumped

const SLIDE_TIME := 0.5

var journey := false
var room_size := Vector2i(15, 8)
var room := Vector2i.ZERO
var rooms := {}  # Vector2i room -> true, every room with tiles
var visited := {}  # Vector2i room -> true
var rooms_hidden := {}  # Vector2i room -> true
var entry_key := Vector2i.ZERO  # where a lost life restarts
var keys := {}  # Vector2i -> true while the key is still there
var doors := {}  # Vector2i -> true while locked
var carrying := 0
var key_room := Vector2i.ZERO
var door_room := Vector2i.ZERO
## The Control that clips the map to one room; set by main.gd.
var window: Control

var _marks := {}  # Vector2i -> Node2D (the key or door drawn on its tile)
var _screen := Vector2(667, 375)
var _slide: Tween


func room_of(key: Vector2i) -> Vector2i:
	return Vector2i(floori(float(key.x) / room_size.x), floori(float(key.y) / room_size.y))


func load_level(level: Dictionary, screen_size: Vector2, x_hides_override := -1) -> void:
	journey = level.has("room_size")
	if journey:
		room_size = Vector2i(int(level["room_size"][0]), int(level["room_size"][1]))
	keys.clear()
	doors.clear()
	_marks.clear()
	rooms.clear()
	visited.clear()
	rooms_hidden.clear()
	carrying = 0
	_screen = screen_size
	if _slide:
		_slide.kill()
	super.load_level(level, screen_size, x_hides_override)
	if not journey:
		position = Vector2.ZERO
		if window:
			window.clip_contents = false
			window.position = Vector2.ZERO
			window.size = screen_size
		return
	for tile: Tile in tiles.values():
		if not tile.blank:
			rooms[room_of(tile.key)] = true
	room = room_of(start_position)
	entry_key = start_position
	visited[room] = true
	if window:
		var size := Vector2(room_size.x * TILE_W, room_size.y * TILE_H)
		window.position = Vector2(screen_size.x / 2.0, CENTRE_Y) - size / 2.0
		window.size = size
		window.clip_contents = true
	position = _offset_for(room)
	var lines := MatchLines.new()
	lines.map = self
	lines.z_index = 2
	add_child(lines)


func _add_tile(t: String, key: Vector2i, loading, loadings: Dictionary, order: Array[Tile]) -> void:
	super._add_tile(t, key, loading, loadings, order)
	if t != "K" and t != "D":
		return
	var mark := Mark.new()
	mark.door = t == "D"
	mark.position = tiles[key].position
	mark.z_index = 3
	mark.scale = Vector2.ZERO
	add_child(mark)
	_marks[key] = mark
	_appear(mark, 0.0, 1.0)
	if mark.door:
		doors[key] = true
		door_room = room_of(key)
	else:
		keys[key] = true
		key_room = room_of(key)


## The map offset (inside the window) that puts this room in the window.
func _offset_for(r: Vector2i) -> Vector2:
	var a := _screen_pos(r * room_size, _rows_total)
	var b := _screen_pos(r * room_size + room_size - Vector2i.ONE, _rows_total)
	var centre := (a + b) / 2.0
	var window_pos := window.position if window else Vector2.ZERO
	return Vector2(_screen.x / 2.0, CENTRE_Y) - window_pos - centre


## In screen space, wherever the room has slid to.
func get_player_position() -> Vector2:
	var p := super.get_player_position()
	if window:
		return window.position + position + p
	return position + p


func move(step: Vector2i, seconds: float) -> void:
	if not journey:
		super.move(step, seconds)
		return
	var target := position_key + step
	if doors.get(target, false):
		if carrying > 0:
			_unlock(target)
		else:
			moving = false
			door_bumped.emit()
			return
	var to_room := room_of(target)
	if to_room != room and tiles.has(target) and not tiles[target].blank:
		super.move(step, SLIDE_TIME)
		if moving:
			_slide_to(to_room, target)
		return
	super.move(step, seconds)


func _slide_to(to_room: Vector2i, entry: Vector2i) -> void:
	room = to_room
	entry_key = entry
	var first := not visited.has(to_room)
	visited[to_room] = true
	tiles_hidden = rooms_hidden.has(to_room)
	if _slide:
		_slide.kill()
	if Blueprint.motion():
		_slide = create_tween()
		(
			_slide
			. tween_property(self, "position", _offset_for(to_room), SLIDE_TIME)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_IN_OUT)
		)
	else:
		position = _offset_for(to_room)
	room_entered.emit(to_room, first)


func sliding() -> bool:
	return _slide != null and _slide.is_running()


func _unlock(key: Vector2i) -> void:
	doors[key] = false
	carrying -= 1
	var mark: Mark = _marks[key]
	var tw := create_tween()
	tw.tween_property(mark, "scale:x", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(mark.queue_free)


## Pick up the key under MapMan.
func take_key() -> void:
	keys[position_key] = false
	carrying += 1
	var mark: Mark = _marks[position_key]
	var tw := create_tween().set_parallel()
	tw.tween_property(mark, "position:y", mark.position.y - 30.0, 0.3)
	tw.tween_property(mark, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(mark.queue_free)


# --- hiding, one room at a time ----------------------------------------------


func _in_room(tile: Tile) -> bool:
	return room_of(tile.key) == room


func hide_tiles() -> void:
	if not journey:
		super.hide_tiles()
		return
	for tile: Tile in tiles.values():
		if _in_room(tile):
			_hide_tile(tile, true)
	rooms_hidden[room] = true
	tiles_hidden = true


func unhide_tiles() -> void:
	if not journey:
		super.unhide_tiles()
		return
	for tile: Tile in tiles.values():
		if _in_room(tile):
			_unhide_tile(tile, true)
	rooms_hidden.erase(room)
	tiles_hidden = false


## After a lost life the room MapMan is in shows again, as a level does.
func reset_hide() -> void:
	if not journey:
		super.reset_hide()
		return
	for tile: Tile in tiles.values():
		if not _in_room(tile):
			continue
		if tile.start_hidden:
			_hide_tile(tile)
		elif rooms_hidden.has(room):
			_unhide_tile(tile)
	rooms_hidden.erase(room)
	tiles_hidden = false


func reset() -> void:
	super.reset()
	if journey:
		position_key = entry_key


## The key or the door, drawn in code on its tile.
class Mark:
	extends Node2D
	var door := false
	var _clock := 0.0

	func _process(delta: float) -> void:
		_clock += delta
		if not door:
			queue_redraw()

	func _draw() -> void:
		if door:
			# A slab standing on the tile, hatched, with a gold keyhole.
			var r := Rect2(-10, -30, 20, 30)
			draw_rect(r, Blueprint.FIELD.darkened(0.35))
			for i in range(-2, 5):
				var y0 := -30.0 + i * 8.0
				draw_line(
					Vector2(-10, clampf(y0 + 20, -30, 0)),
					Vector2(clampf(-10 + (y0 + 50) - 20, -10, 10), clampf(y0, -30, 0)),
					Color(1, 1, 1, 0.25),
					1.0
				)
			draw_rect(r, Blueprint.INK, false, 1.5)
			draw_circle(Vector2(0, -17), 3.0, Blueprint.GOLD)
			draw_colored_polygon(
				PackedVector2Array(
					[Vector2(-2, -16), Vector2(2, -16), Vector2(3, -9), Vector2(-3, -9)]
				),
				Blueprint.GOLD
			)
		else:
			JourneyMap.draw_key(self, Vector2(0, -14 + sin(_clock * 3.0) * 2.0), 1.0)


## A gold key, ring on the left, centred on at.
static func draw_key(c: CanvasItem, at: Vector2, s: float) -> void:
	var ink := Blueprint.FIELD.darkened(0.5)
	c.draw_circle(at + Vector2(-6, 0) * s, 5.5 * s, ink)
	c.draw_circle(at + Vector2(-6, 0) * s, 4.5 * s, Blueprint.GOLD)
	c.draw_circle(at + Vector2(-6, 0) * s, 1.8 * s, ink)
	c.draw_rect(Rect2(at + Vector2(-2, -1.5) * s, Vector2(11, 3) * s), Blueprint.GOLD)
	c.draw_rect(Rect2(at + Vector2(5, 1) * s, Vector2(2, 4) * s), Blueprint.GOLD)
	c.draw_rect(Rect2(at + Vector2(8, 1) * s, Vector2(1.6, 3) * s), Blueprint.GOLD)


## The key MapMan carries on a journey, by his shoulder.
class KeyBadge:
	extends Node2D
	var _clock := 0.0

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _draw() -> void:
		JourneyMap.draw_key(self, Vector2(0, sin(_clock * 4.0) * 1.5), 0.8)


## The journey's key plan for the HUD: one box per room, the room MapMan is in
## inked, rooms not yet seen dashed, the key and the door marked once seen.
class KeyPlan:
	extends Node2D
	const BOX := Vector2(22, 13)
	var map: JourneyMap

	func _process(_delta: float) -> void:
		visible = map != null and map.journey and map.get_parent() != null
		queue_redraw()

	func _draw() -> void:
		if not visible:
			return
		var font := Blueprint.mono(600)
		var size := Vector2.ZERO
		for r: Vector2i in map.rooms:
			size = size.max(Vector2(r.x + 1, r.y + 1))
		var names := map.room_names()
		draw_string(
			font, Vector2(0, -4), "KEY PLAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Blueprint.DIM
		)
		for r: Vector2i in map.rooms:
			var p := Vector2(r.x * (BOX.x + 3), r.y * (BOX.y + 3))
			var box := Rect2(p, BOX)
			var here: bool = r == map.room
			if map.visited.has(r):
				draw_rect(box, Color(1, 1, 1, 0.28 if here else 0.12))
				draw_rect(
					box, Blueprint.INK if here else Blueprint.FAINT, false, 1.5 if here else 1.0
				)
			else:
				_dashed_box(box)
			var label: String = names.get(r, "")
			draw_string(
				font,
				p + Vector2(3, 10),
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				9,
				Blueprint.INK if here else Blueprint.DIM
			)
			if (
				map.carrying == 0
				and map.visited.has(r)
				and r == map.key_room
				and map.keys.values().has(true)
			):
				JourneyMap.draw_key(self, p + Vector2(15, 6.5), 0.45)
			if map.visited.has(r) and r == map.door_room and map.doors.values().has(true):
				draw_rect(Rect2(p + Vector2(13, 3), Vector2(5, 7)), Blueprint.GOLD, false, 1.0)

	func _dashed_box(box: Rect2) -> void:
		var pts := [
			box.position,
			Vector2(box.end.x, box.position.y),
			box.end,
			Vector2(box.position.x, box.end.y)
		]
		for i in 4:
			draw_dashed_line(pts[i], pts[(i + 1) % 4], Blueprint.DIM, 1.0, 3.0)


## Sheet letters for the rooms: A is where MapMan starts, then the others
## in order of how far they are from it.
func room_names() -> Dictionary:
	var start := room_of(start_position)
	var order: Array = rooms.keys()
	order.sort_custom(
		func(a: Vector2i, b: Vector2i):
			var da := absi(a.x - start.x) + absi(a.y - start.y)
			var db := absi(b.x - start.x) + absi(b.y - start.y)
			return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x)))
	)
	var names := {}
	for i in order.size():
		names[order[i]] = "ABCDEFGH"[i]
	return names


## Match lines: where a path runs off this room into the next, a dashed line
## along that edge and the next sheet's letter, as on a set of drawings.
class MatchLines:
	extends Node2D
	var map: JourneyMap

	func _draw() -> void:
		if map == null or not map.journey:
			return
		var names := map.room_names()
		var font := Blueprint.mono(600)
		var done := {}
		for k: Vector2i in map.tiles:
			var tile: LevelMap.Tile = map.tiles[k]
			if tile.blank:
				continue
			for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var n := k + d
				if not map.tiles.has(n) or map.tiles[n].blank:
					continue
				var ra := map.room_of(k)
				var rb := map.room_of(n)
				if ra == rb:
					continue
				var mid: Vector2 = (tile.position + map.tiles[n].position) / 2.0
				var along := Vector2(0, 1) if d == Vector2i.RIGHT else Vector2(1, 0)
				var reach := (LevelMap.TILE_H if d == Vector2i.RIGHT else LevelMap.TILE_W) * 1.6
				draw_dashed_line(mid - along * reach, mid + along * reach, Blueprint.GOLD, 1.5, 4.0)
				# Each side names the sheet across the line.
				var off := Vector2(d) * 10.0
				var la: String = names.get(rb, "")
				var lb: String = names.get(ra, "")
				var t := along * (reach + 8.0)
				draw_string(
					font,
					mid - off + t + Vector2(-4, 4),
					la,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					11,
					Blueprint.GOLD
				)
				draw_string(
					font,
					mid + off + t + Vector2(-4, 4),
					lb,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					11,
					Blueprint.GOLD
				)
				done[k] = true
