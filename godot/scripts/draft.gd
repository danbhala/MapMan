class_name Draft
extends RefCounted
## A level on the drafting table: a 17 × 12 grid of tiles (the characters of
## data/levels.json), the tiles that start hidden, and whether its maker has
## beaten it ("signed"), which a draft must be before it can be shared. Any
## change unsigns it. Painting happens in strokes, each one step of undo.

## How many drafts the drafting table keeps, and how many received levels.
const SLOTS := 6
const RECEIVED_KEPT := 6
const COLUMNS := 17
const ROWS := 12
const UNDO_LIMIT := 60
## The longest code the drafting table calls short: it fits a small QR and
## can still be typed. Longer codes still work.
const SHORT_CODE := 64
## The "tile" that marks tiles to start hidden instead of placing one.
const HIDE_TOOL := "*"

var slot := 0
var rows: Array[String] = []
## Vector2i -> true for each tile that starts hidden.
var hidden := {}
var signed := false

var _undo: Array = []


func _init(slot_number := 0) -> void:
	slot = slot_number
	clear()


func clear() -> void:
	rows.clear()
	for y in ROWS:
		rows.append(" ".repeat(COLUMNS))
	hidden.clear()
	signed = false


func is_empty() -> bool:
	for row in rows:
		if row.strip_edges() != "":
			return false
	return true


func tile(key: Vector2i) -> String:
	return rows[key.y][key.x]


static func on_grid(key: Vector2i) -> bool:
	return key.x >= 0 and key.y >= 0 and key.x < COLUMNS and key.y < ROWS


## Remember the grid as it is: the start of a stroke, which undo() returns to.
func begin_stroke() -> void:
	_undo.append([rows.duplicate(), hidden.duplicate(), signed])
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()


func can_undo() -> bool:
	return not _undo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	var last: Array = _undo.pop_back()
	rows.assign(last[0])
	hidden = last[1]
	signed = last[2]
	return true


## Put `t` at `key` (" " clears it). There is only ever one start tile, so a
## new one moves it. True if the grid changed.
func paint(key: Vector2i, t: String) -> bool:
	if not on_grid(key) or tile(key) == t:
		return false
	if t == "b":
		for y in ROWS:
			var at := rows[y].find("b")
			if at >= 0:
				_put(Vector2i(at, y), " ")
	_put(key, t)
	if t == " ":
		hidden.erase(key)
	signed = false
	return true


## Mark the tile at `key` to start hidden, or not; empty cells can't be.
func set_hidden(key: Vector2i, on: bool) -> bool:
	if not on_grid(key) or tile(key) == " " or hidden.has(key) == on:
		return false
	if on:
		hidden[key] = true
	else:
		hidden.erase(key)
	signed = false
	return true


func _put(key: Vector2i, t: String) -> void:
	var row := rows[key.y]
	rows[key.y] = row.left(key.x) + t + row.substr(key.x + 1)


## What stops the draft being played: "start" (no start tile), "exit" (no
## exit), or "" when it can be tested.
func problem() -> String:
	var text := "".join(rows)
	if not text.contains("b"):
		return "start"
	for e in ["n", "e", "s", "w"]:
		if text.contains(e):
			return ""
	return "exit"


## Its level code, or "" while there is nothing on the grid.
func code() -> String:
	var trimmed := LevelCode.trim(rows, hidden)
	if trimmed.is_empty():
		return ""
	return LevelCode.encode(trimmed[0], trimmed[1])


## The draft as a level to play (data/levels.json's shape), the same as a
## friend gets from its code.
func level() -> Dictionary:
	var trimmed := LevelCode.trim(rows, hidden)
	return LevelCode.to_level(
		{"rows": trimmed[0], "hidden": trimmed[1], "x_hides": 25, "delay": 0.05}
	)


func to_save() -> Dictionary:
	var keys: Array[Vector2i] = []
	for key: Vector2i in hidden:
		keys.append(key)
	return {"rows": rows.duplicate(), "hidden": keys, "signed": signed}


static func from_save(slot_number: int, saved: Variant) -> Draft:
	var d := Draft.new(slot_number)
	if not saved is Dictionary:
		return d
	var src: Variant = saved.get("rows")
	if src is Array and src.size() == ROWS:
		for y in ROWS:
			var line := String(src[y])
			if line.length() != COLUMNS or not _known(line):
				return Draft.new(slot_number)
			d.rows[y] = line
	for key in saved.get("hidden", []):
		if key is Vector2i and on_grid(key) and d.tile(key) != " ":
			d.hidden[key] = true
	d.signed = bool(saved.get("signed", false)) and d.problem() == ""
	return d


static func _known(line: String) -> bool:
	for ch in line:
		if not LevelCode.SYMBOLS.contains(ch):
			return false
	return true
