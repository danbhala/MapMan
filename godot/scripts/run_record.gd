class_name RunRecord
extends RefCounted
## One try at a level, kept as the tile steps MapMan took and when each began
## (seconds on the run clock, which only runs while the level is being
## played). MapMan always moves a whole tile at a time, at one of two speeds,
## so the steps alone say where he was at any moment: no tilt is kept. The
## level clear's replay plays every try of a level back at once, and the best
## run of each level is saved (encode()) to run beside the player as a ghost.

## How long one step takes on a gentle tilt (Main.STOP_TIME); a hard tilt
## takes half of it.
const STEP_SECONDS := 14.0 / 60.0
## The four ways a step can go, as stored.
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
## How a try ended, as stored.
const RESULTS: Array[String] = ["", "win", "death", "timeout"]
const VERSION := 1

static var _base64 := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")

## When each step began.
var times := PackedFloat32Array()
## Each step's direction (an index into DIRS), plus 4 for a fast step.
var steps := PackedByteArray()
## "" while the try is still going, else one of RESULTS.
var result := ""
## The run clock when the try ended.
var end_time := 0.0
## The level clock left at the end of a win: the best run keeps the most.
var time_left := 0.0


## A step from `t` on the run clock, `step` in screen directions (the way he
## went, after any reversed controls), taking `seconds`.
func add_step(t: float, step: Vector2i, seconds: float) -> void:
	var i := DIRS.find(step)
	if i < 0:
		return
	times.append(t)
	steps.append(i + (4 if seconds < STEP_SECONDS * 0.75 else 0))


func finish(t: float, how: String, left := 0.0) -> void:
	end_time = t
	result = how
	time_left = left


func won() -> bool:
	return result == "win"


func step_count() -> int:
	return steps.size()


func step_dir(i: int) -> Vector2i:
	return DIRS[steps[i] & 3]


func step_seconds(i: int) -> float:
	return STEP_SECONDS * (0.5 if steps[i] & 4 else 1.0)


## Where he is at `t` from `start` (a tile key): {"key", "next", "share",
## "dir", "moving"}; between `key` and `next`, `share` of the way along.
## The step he is on, or the last one taken, gives `dir`.
func at(start: Vector2i, t: float) -> Dictionary:
	var key := start
	var dir := Vector2i.ZERO
	for i in times.size():
		if times[i] > t:
			break
		dir = step_dir(i)
		var share := (t - times[i]) / step_seconds(i)
		if share < 1.0:
			return {"key": key, "next": key + dir, "share": share, "dir": dir, "moving": true}
		key += dir
	return {"key": key, "next": key, "share": 0.0, "dir": dir, "moving": false}


## Every tile he stood on up to `t`, then where he is at `t`, as positions
## from `pos_of` (a tile key to a position).
func path_to(start: Vector2i, t: float, pos_of: Callable) -> PackedVector2Array:
	var pts := PackedVector2Array([pos_of.call(start)])
	var key := start
	for i in times.size():
		if times[i] > t:
			break
		var dir := step_dir(i)
		var share := (t - times[i]) / step_seconds(i)
		if share < 1.0:
			var a: Vector2 = pos_of.call(key)
			pts.append(a.lerp(pos_of.call(key + dir), share))
			return pts
		key += dir
		pts.append(pos_of.call(key))
	return pts


## The tile he ended on.
func end_key(start: Vector2i) -> Vector2i:
	var key := start
	for i in steps.size():
		key += step_dir(i)
	return key


## A compact text for the save: a version byte, how it ended, then times in
## hundredths of a second as differences (varints) and one byte per step.
## About two bytes a step.
func encode() -> String:
	var out := PackedByteArray([VERSION, RESULTS.find(result)])
	_varint(out, roundi(time_left * 100.0))
	var last := 0
	for i in times.size():
		var cs := roundi(times[i] * 100.0)
		_varint(out, maxi(0, cs - last))
		last = maxi(last, cs)
		out.append(steps[i])
	var end_cs := roundi(end_time * 100.0)
	_varint(out, maxi(0, end_cs - last))
	return Marshalls.raw_to_base64(out)


## A record from encode()'s text, or null if it isn't one.
static func decode(text: String) -> RunRecord:
	# Godot complains aloud about text that isn't base64 at all.
	if text.length() % 4 != 0 or not _base64.search(text):
		return null
	var raw := Marshalls.base64_to_raw(text)
	if raw.size() < 3 or raw[0] != VERSION or raw[1] >= RESULTS.size():
		return null
	var r := RunRecord.new()
	r.result = RESULTS[raw[1]]
	var pos := [2]
	r.time_left = _read_varint(raw, pos) / 100.0
	var cs := 0
	while pos[0] < raw.size():
		var gap := _read_varint(raw, pos)
		if gap < 0:
			return null
		cs += gap
		if pos[0] >= raw.size():
			r.end_time = cs / 100.0
			return r
		var b: int = raw[pos[0]]
		pos[0] += 1
		if b > 7:
			return null
		r.times.append(cs / 100.0)
		r.steps.append(b)
	return null


static func _varint(out: PackedByteArray, n: int) -> void:
	while n >= 0x80:
		out.append((n & 0x7f) | 0x80)
		n >>= 7
	out.append(n)


## The varint at pos[0] (moved past it), or -1 if the bytes run out.
static func _read_varint(raw: PackedByteArray, pos: Array) -> int:
	var n := 0
	var shift := 0
	while pos[0] < raw.size():
		var b: int = raw[pos[0]]
		pos[0] += 1
		n |= (b & 0x7f) << shift
		if b < 0x80:
			return n
		shift += 7
		if shift > 28:
			return -1
	return -1
