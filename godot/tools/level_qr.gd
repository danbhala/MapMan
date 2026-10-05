extends SceneTree
## A level as a shareable code and QR, checked the way the drafting table
## checks a draft. The /custom-level skill runs it on levels Claude designs.
##
##   godot --headless --path godot -s tools/level_qr.gd -- <level> [out.png]
##
## <level> is a text file of rows (one per line, top row first, the tile
## characters of data/levels.json), a JSON file in levels.json's shape
## ("rows", and "loading" with "*" for tiles that start hidden), or a level
## code ("MAPMAN 0S01-…" or bare). Use absolute paths.
##
## It fails (exit 1) unless the level is one the editor could share: known
## tiles only, at most 17 × 12, exactly one start, an exit, a safe route from
## the start to an exit (LevelMap.safe_route(), the assists' solver), and a
## code that reads back as the same level. Then it prints the code, a picture
## of the level with its route and the level's numbers, and with out.png
## writes the QR (blue on white) and reads it back with QrReader.
##
## Only names classes that leave the autoloads alone (LevelCode, Draft,
## LevelMap, QrReader): DraftingSheet or Save here would hang or not compile.

const QrCode := preload("res://addons/kenyoni/qr_code/qr_code.gd")
const QR_SCALE := 16
const QR_QUIET := 4
const QR_DARK := Color("#16407a")
## As tools/level_report.py: the 20 s clock, a step at a firm tilt (main.gd
## STOP_TIME / 2) and what a time tile is worth.
const CLOCK := 20.0
const FAST_STEP := 7.0 / 60.0
const TIME_TILE := 5.0
const EXITS := "nesw"
const NAMES := {
	"c": "path",
	"b": "start",
	"d": "death",
	"p": "star",
	"y": "sticky",
	"r": "reverse",
	"i": "invisible path",
	"!": "hideable death",
	"t": "time lost",
	"m": "extra time",
	"w": "exit",
	"e": "exit",
	"n": "exit",
	"s": "exit",
	"u": "unhide",
	"h": "hide",
	"l": "extra life",
	"v": "vanish 5",
	"x": "vanish 25",
	"@": "hideable star",
	"+": "hideable life",
	"k": "crumble",
	"j": "ice",
	"^": "spikes",
	"%": "off-beat spikes",
}


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		_fail("usage: -s tools/level_qr.gd -- <rows file | json file | code> [out.png]")
		return
	var level := _read(args[0])
	if level.is_empty():
		return
	var errors := _problems(level)
	if not errors.is_empty():
		_fail("not a level the drafting table can share:\n  " + "\n  ".join(errors))
		return

	# Draw it on the editor's grid, as a player would, and take its code.
	var draft := Draft.from_level(0, level)
	if draft.problem() != "":
		_fail("the editor says: no " + draft.problem())
		return
	var trimmed := LevelCode.trim(draft.rows, draft.hidden)
	var code := draft.code()
	var back := LevelCode.decode(code)
	if back.get("rows") != trimmed[0] or back.get("hidden") != trimmed[1]:
		_fail("the code %s does not read back as the same level" % code)
		return

	var map := LevelMap.new()
	root.add_child(map)
	map.load_level(draft.level(), Vector2(667, 375))
	var route := _walk(map.safe_route())
	var rows: Array = trimmed[0]
	print(_picture(rows, trimmed[1], route))
	if route.is_empty():
		_fail("no safe route from the start to an exit")
		return
	print(_numbers(rows, route, code))
	map.queue_free()

	print("\nCODE  " + LevelCode.PREFIX + " " + LevelCode.pretty(code))
	print("LINK  " + LevelCode.link(code))
	if args.size() > 1:
		if not _write_qr(LevelCode.link(code), args[1]):
			return
	quit(0)


## safe_route() lists where MapMan comes to rest; a slide across ice passes
## more tiles on the way. Every tile the route crosses, in order.
func _walk(stops: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in stops.size():
		if i > 0:
			var step := (stops[i] - stops[i - 1]).sign()
			var at := stops[i - 1] + step
			while at != stops[i]:
				out.append(at)
				at += step
		out.append(stops[i])
	return out


## The level from a file or a code, in levels.json's shape; {} after a failure.
func _read(arg: String) -> Dictionary:
	if FileAccess.file_exists(arg):
		var text := FileAccess.get_file_as_string(arg)
		if text.strip_edges().begins_with("{"):
			var data = JSON.parse_string(text)
			if data is Dictionary and data.get("rows") is Array:
				return data
			_fail('%s: JSON needs a "rows" list' % arg)
			return {}
		var rows: Array[String] = []
		for line in text.replace("\r", "").split("\n"):
			rows.append(line)
		while not rows.is_empty() and rows.back().strip_edges() == "":
			rows.pop_back()
		while not rows.is_empty() and rows.front().strip_edges() == "":
			rows.pop_front()
		return {"rows": rows}
	var got := LevelCode.decode(arg)
	if got.has("rows"):
		return {"rows": got.rows, "loading": _loading(got.rows, got.hidden)}
	if arg.ends_with(".txt") or arg.ends_with(".json") or arg.contains("/"):
		_fail("no such file: " + arg)
	else:
		_fail(
			(
				"not a file, and not a level code that reads%s"
				% (" (newer version)" if got.has("newer") else "")
			)
		)
	return {}


func _loading(rows: Array, hidden: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for y in rows.size():
		var line := ""
		for x in String(rows[y]).length():
			line += "*" if hidden.has(Vector2i(x, y)) else "a"
		out.append(line)
	return out


## The editor's rules, before the level goes near it: known tiles, the grid's
## size, one start tile, an exit.
func _problems(level: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	var grid := LevelCode.grid_of(level)
	if grid.is_empty():
		return ["no tiles at all"]
	var rows: Array = grid[0]
	var w := String(rows[0]).length()
	if w > LevelCode.MAX_W or rows.size() > LevelCode.MAX_H:
		errors.append(
			(
				"%d wide × %d high; the grid is at most %d × %d"
				% [w, rows.size(), LevelCode.MAX_W, LevelCode.MAX_H]
			)
		)
	var starts := 0
	var exits := 0
	for y in rows.size():
		for x in w:
			var ch: String = rows[y][x]
			if not LevelCode.SYMBOLS.contains(ch):
				errors.append("row %d column %d: %s is not a tile" % [y + 1, x + 1, ch])
			starts += 1 if ch == "b" else 0
			exits += 1 if EXITS.contains(ch) else 0
	if starts != 1:
		errors.append("%d start tiles (b); a level has exactly one" % starts)
	if exits == 0:
		errors.append("no exit (n, e, s or w)")
	return errors


## The level as text, "." for empty cells, and beside it the same with the
## safe route drawn in "o".
func _picture(rows: Array, hidden: Dictionary, route: Array[Vector2i]) -> String:
	var on_route := {}
	for key in route:
		on_route[key] = true
	var out: PackedStringArray = []
	var w := String(rows[0]).length()
	var rule := "+" + "-".repeat(w) + "+"
	out.append("LEVEL".rpad(w + 4) + "ROUTE")
	out.append(rule + "  " + rule)
	for y in rows.size():
		var a := ""
		var b := ""
		for x in w:
			var ch: String = rows[y][x]
			var key := Vector2i(x, y)
			a += "." if ch == " " else ch
			var keep := ch == "b" or EXITS.contains(ch)
			b += "o" if on_route.has(key) and not keep else ("." if ch == " " else ch)
		out.append("|" + a + "|  |" + b + "|")
	out.append(rule + "  " + rule)
	if not hidden.is_empty():
		out.append("start hidden: %d tile(s)" % hidden.size())
	return "\n".join(out)


## The numbers tools/level_report.py gives a campaign level, plus the code's.
func _numbers(rows: Array, route: Array[Vector2i], code: String) -> String:
	var counts := {}
	var tiles := 0
	for row in rows:
		for ch in String(row):
			if ch != " ":
				tiles += 1
				counts[ch] = counts.get(ch, 0) + 1
	var on_route := {}
	for key in route.slice(1):
		var ch: String = rows[key.y][key.x]
		on_route[ch] = on_route.get(ch, 0) + 1
	var moves := route.size() - 1
	var slack: float = (
		CLOCK
		- moves * FAST_STEP
		- TIME_TILE * on_route.get("t", 0)
		+ TIME_TILE * on_route.get("m", 0)
	)
	var used: PackedStringArray = []
	var keys := counts.keys()
	keys.sort()
	for ch in keys:
		used.append("%s %s ×%d" % [ch, NAMES.get(ch, "vanish " + ch), counts[ch]])
	var lines: PackedStringArray = [
		"size      %d × %d, %d tiles" % [String(rows[0]).length(), rows.size(), tiles],
		(
			"route     %d steps, slack %.1f s%s"
			% [moves, slack, " (needs m tiles)" if slack < 0 else ""]
		),
		"on route  " + _summary(on_route),
		"tiles     " + ", ".join(used),
		(
			"code      %d characters%s"
			% [
				LevelCode.length(code),
				(
					" (over %d: long to type)" % Draft.SHORT_CODE
					if LevelCode.length(code) > Draft.SHORT_CODE
					else ""
				)
			]
		),
	]
	return "\n".join(lines)


func _summary(on_route: Dictionary) -> String:
	var parts: PackedStringArray = []
	for ch in ["t", "m", "y", "r", "k", "j", "^", "%", "p", "@", "h", "u", "i"]:
		if on_route.get(ch, 0) > 0:
			parts.append("%s %s ×%d" % [ch, NAMES[ch], on_route[ch]])
	return ", ".join(parts) if not parts.is_empty() else "plain path"


## Write the QR of `text` and read it back; false (after failing) if it doesn't.
func _write_qr(text: String, out: String) -> bool:
	var qr := QrCode.new(QrCode.ErrorCorrection.MEDIUM)
	# The share sheet's QR: the link, byte by byte (DraftingSheet.qr_image).
	qr.put_byte(text.to_utf8_buffer())
	var modules := qr.encode()
	var img := QrCode.generate_image(modules, QR_SCALE, Color.WHITE, QR_DARK, QR_QUIET)
	var err := img.save_png(out)
	if err != OK:
		_fail("could not write %s (error %d)" % [out, err])
		return false
	var read := QrReader.read(Image.load_from_file(out))
	if read != text:
		_fail("the QR in %s reads %s, not %s" % [out, read, text])
		return false
	var side := int(sqrt(modules.size()))
	@warning_ignore("integer_division")
	var version := (side - 17) / 4
	print("QR    %s (version %d, %d px), reads back: %s" % [out, version, img.get_width(), read])
	return true


func _fail(why: String) -> void:
	printerr("level_qr: " + why)
	quit(1)
