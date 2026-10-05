class_name LevelCode
extends RefCounted
## Level codes: a whole level as a short text such as "0MM3-C7P1-P7R3-KWTS-4",
## for passing a level from the drafting table to a friend's phone, typed,
## pasted or scanned from a QR code. No server is involved: the code is the
## level.
##
## The format is defined by tools/level_code.py, which this must match bit for
## bit (tests/unit/test_level_code.gd checks every campaign level against it).
## The tiles are arithmetic coded, each guessed from the tiles to its left and
## above with the counts in data/level_code_v0.json. That table is frozen: a
## changed count misreads every code already shared.

const VERSION := 0
const TABLE_PATH := "res://data/level_code_v0.json"
## Symbol index -> tile. New tile types take spare symbols after these.
## Each new one takes a spare symbol, so RESERVED drops by one: the alphabet
## (SYMBOLS + RESERVED) never changes size, or every shared code misreads.
const SYMBOLS := " cbdpyri!tmwensuhlvx@+123456789kj^%"
const RESERVED := 8
const X_HIDES := [25, 12, 50, 100]
const DELAYS := [0.05, 0.1, 0.2, 0.03]
const MAX_W := 17
const MAX_H := 12
const B32 := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
## What a shared code starts with, so a phone's camera or a chat shows whose
## it is; reading a code skips it.
const PREFIX := "MAPMAN"
## A shared level as a link: a phone opens it in the game, or, without the
## game, on a page that shows the code (danbhala.github.io, site/). The QR
## code writes it in capitals, which take fewer modules.
const LINK := "https://danbhala.github.io/mapman/"
const EDGE := -1
const WEIGHT := 8
const ADAPT := 8
const HEADER_BITS := 28
const TOP := 0xFFFFFFFF
const HALF := 0x80000000
const QUARTER := 0x40000000
## The reveal order of a shared level starts here (LevelMap sorts these
## characters): a wave out from the start tile, well clear of "*".
const WAVE_CHAR := 0x100

static var _counts: Dictionary = {}

# --- levels -----------------------------------------------------------------------


## The tile a character plays as: "-" is empty, z and o are plain tiles, and
## exits read the same in either case.
static func canonical(ch: String) -> String:
	if ch == "-":
		return " "
	if ch == "z" or ch == "o":
		return "c"
	if ch in ["N", "S", "E", "W"]:
		return ch.to_lower()
	return ch


## A level dictionary (data/levels.json's shape) as [rows, hidden]: canonical
## tiles trimmed to the drawn area, and the tiles that start hidden
## (Vector2i -> true).
static func grid_of(level: Dictionary) -> Array:
	var rows: Array[String] = []
	for r in level["rows"]:
		var row := ""
		for ch in String(r):
			row += canonical(ch)
		rows.append(row)
	var hidden := {}
	var loading = level.get("loading")
	if loading != null:
		for y in loading.size():
			var line := String(loading[y])
			for x in line.length():
				if line[x] == "*" and x < rows[y].length() and rows[y][x] != " ":
					hidden[Vector2i(x, y)] = true
	return trim(rows, hidden)


## Rows (and hidden tiles) cut down to the box around the tiles drawn; rows
## come back all the same width. [] when there are no tiles at all.
static func trim(rows: Array, hidden: Dictionary) -> Array:
	var top := -1
	var bottom := -1
	var left := 1 << 30
	var right := -1
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			if row[x] != " ":
				top = y if top < 0 else top
				bottom = y
				left = mini(left, x)
				right = maxi(right, x)
	if top < 0:
		return []
	var out: Array[String] = []
	for y in range(top, bottom + 1):
		out.append(String(rows[y]).rpad(right + 1).substr(left, right - left + 1))
	var moved := {}
	for key: Vector2i in hidden:
		if key.y >= top and key.y <= bottom and key.x >= left and key.x <= right:
			moved[key - Vector2i(left, top)] = true
	return [out, moved]


## A decoded code (decode()) as a level LevelMap can play: its tiles appear
## in a wave from the start tile, and the hidden ones start hidden.
static func to_level(code: Dictionary) -> Dictionary:
	var rows: Array = code.rows
	var hidden: Dictionary = code.hidden
	var dist := _distances(rows)
	var far := 0
	for key in dist:
		far = maxi(far, dist[key])
	var loading: Array[String] = []
	for y in rows.size():
		var line := ""
		for x in String(rows[y]).length():
			var key := Vector2i(x, y)
			if rows[y][x] == " ":
				line += " "
			elif hidden.has(key):
				line += "*"
			else:
				line += char(WAVE_CHAR + dist.get(key, far + 1))
		loading.append(line)
	return {
		"number": 0,
		"rows": rows,
		"loading": loading,
		"delay": code.delay,
		"x_hides": code.x_hides,
		"checkpoint": false,
		"message": "",
	}


## Steps from the start tile to every tile it connects to.
static func _distances(rows: Array) -> Dictionary:
	var dist := {}
	var queue: Array[Vector2i] = []
	for y in rows.size():
		var at := String(rows[y]).find("b")
		if at >= 0:
			dist[Vector2i(at, y)] = 0
			queue.append(Vector2i(at, y))
	var i := 0
	while i < queue.size():
		var cur := queue[i]
		i += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nxt: Vector2i = cur + step
			if nxt.y < 0 or nxt.y >= rows.size() or nxt.x < 0:
				continue
			var row := String(rows[nxt.y])
			if nxt.x >= row.length() or row[nxt.x] == " " or dist.has(nxt):
				continue
			dist[nxt] = dist[cur] + 1
			queue.append(nxt)
	return dist


# --- codes ------------------------------------------------------------------------


## The code of a grid: `rows` all the same width, at most 17 × 12, every
## character one of SYMBOLS; `hidden` the tiles that start hidden.
static func encode(rows: Array, hidden := {}, x_hides := 25, delay := 0.05) -> String:
	var h := rows.size()
	var w := String(rows[0]).length()
	var symbols: Array[int] = []
	for row in rows:
		for ch in String(row):
			symbols.append(SYMBOLS.find(ch))
	var flags: Array[int] = []
	if not hidden.is_empty():
		for y in h:
			for x in w:
				if rows[y][x] != " ":
					flags.append(1 if hidden.has(Vector2i(x, y)) else 0)
	var options := _nearest(X_HIDES, x_hides) | _nearest(DELAYS, delay) << 2
	if not flags.is_empty():
		options |= 16
	var enc := _Encoder.new()
	var seen := {}
	for i in symbols.size():
		var f := _freqs(symbols, i, w, seen)
		enc.put(f, symbols[i])
		_update(seen, symbols, i, w)
	var flag_freqs := [[8, 1], [1, 2]]
	var prev := 0
	for bit in flags:
		enc.put(flag_freqs[prev], bit)
		flag_freqs[prev][bit] += 4
		prev = bit
	var bits: Array[int] = []
	_push(bits, VERSION, 4)
	_push(bits, w - 1, 5)
	_push(bits, h - 1, 4)
	_push(bits, options, 5)
	_push(bits, _check(w, h, options, symbols, flags), 10)
	bits.append_array(enc.finish())
	while bits.size() % 5 != 0:
		bits.append(0)
	var text := ""
	for i in range(0, bits.size(), 5):
		var v := 0
		for j in 5:
			v = v * 2 + bits[i + j]
		text += B32[v]
	# A reader takes missing characters as zeros.
	while text.ends_with("0"):
		text = text.left(-1)
	return pretty(text)


## What a code says: {"rows", "hidden" (Vector2i -> true), "x_hides",
## "delay"}, or {} when it doesn't read (a typo, or not a level code). A code
## from a newer MapMan reads as {"newer": true}.
static func decode(code: String) -> Dictionary:
	var text := clean(code)
	if text.length() * 5 < HEADER_BITS:
		return {}
	var bits: Array[int] = []
	for ch in text:
		_push(bits, B32.find(ch), 5)
	if _field(bits, 0, 4) != VERSION:
		return {"newer": true}
	var w := _field(bits, 4, 5) + 1
	var h := _field(bits, 9, 4) + 1
	var options := _field(bits, 13, 5)
	var want := _field(bits, 18, 10)
	if w > MAX_W or h > MAX_H:
		return {}
	var dec := _Decoder.new(bits.slice(HEADER_BITS))
	var symbols: Array[int] = []
	var seen := {}
	for i in w * h:
		symbols.append(0)
		symbols[i] = dec.get_symbol(_freqs(symbols, i, w, seen))
		_update(seen, symbols, i, w)
	var flags: Array[int] = []
	if options & 16:
		var flag_freqs := [[8, 1], [1, 2]]
		var prev := 0
		for s in symbols:
			if s == 0:
				continue
			var bit := dec.get_symbol(flag_freqs[prev])
			flag_freqs[prev][bit] += 4
			flags.append(bit)
			prev = bit
	if _check(w, h, options, symbols, flags) != want:
		return {}
	var rows: Array[String] = []
	for y in h:
		var row := ""
		for x in w:
			var s := symbols[y * w + x]
			if s >= SYMBOLS.length():
				# A tile this version doesn't know yet.
				return {"newer": true}
			row += SYMBOLS[s]
		rows.append(row)
	var hidden := {}
	var f := 0
	for y in h:
		for x in w:
			if rows[y][x] != " " and not flags.is_empty():
				if flags[f] == 1:
					hidden[Vector2i(x, y)] = true
				f += 1
	return {
		"rows": rows,
		"hidden": hidden,
		"x_hides": X_HIDES[options & 3],
		"delay": DELAYS[(options >> 2) & 3],
	}


## A code reduced to its characters: upper case, without the MAPMAN prefix
## or the link before it, dashes or spaces, with O read as 0 and I or L as 1.
## "" when it holds anything else.
static func clean(code: String) -> String:
	var text := code.to_upper().strip_edges()
	var path := "/" + PREFIX + "/"
	if text.contains(path):
		text = text.get_slice(path, 1).get_slice("?", 0).get_slice("#", 0)
	elif text.begins_with(PREFIX):
		text = text.substr(PREFIX.length())
	var out := ""
	for ch in text:
		if ch == "O":
			ch = "0"
		elif ch == "I" or ch == "L":
			ch = "1"
		if B32.contains(ch):
			out += ch
		elif ch != "-" and ch != " " and ch != "\n":
			return ""
	return out


## "0MM3C7P1P7" -> "0MM3-C7P1-P7": groups of four for reading aloud.
static func pretty(code: String) -> String:
	var text := clean(code)
	var groups: PackedStringArray = []
	for i in range(0, text.length(), 4):
		groups.append(text.substr(i, 4))
	return "-".join(groups)


## The link a level is shared as.
static func link(code: String) -> String:
	return LINK + pretty(code)


## How many characters a code takes, not counting dashes.
static func length(code: String) -> int:
	return clean(code).length()


## Whether a piece of text (the clipboard, say) holds a level code that reads.
static func find(text: String) -> String:
	var t := text.strip_edges()
	if t.length() > 120:
		return ""
	var got := decode(t)
	return pretty(t) if got.has("rows") else ""


# --- the model --------------------------------------------------------------------


static func _table() -> Dictionary:
	if _counts.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
		_counts = data["counts"]
	return _counts


## Each symbol's weight for cell `i`, from the cells left of and above it.
static func _freqs(symbols: Array[int], i: int, w: int, seen: Dictionary) -> Array[int]:
	var key := _context(symbols, i, w)
	var table := _table()
	var base: Array = table.get(key, table.get(key.get_slice(",", 0), table[""]))
	var out: Array[int] = []
	out.resize(SYMBOLS.length() + RESERVED)
	for s in out.size():
		out[s] = 1 + WEIGHT * int(base[s])
	if seen.has(key):
		var more: Array = seen[key]
		for s in out.size():
			out[s] += ADAPT * int(more[s])
	return out


static func _update(seen: Dictionary, symbols: Array[int], i: int, w: int) -> void:
	var key := _context(symbols, i, w)
	if not seen.has(key):
		var zeros := []
		zeros.resize(SYMBOLS.length() + RESERVED)
		zeros.fill(0)
		seen[key] = zeros
	seen[key][symbols[i]] += 1


static func _context(symbols: Array[int], i: int, w: int) -> String:
	var left := symbols[i - 1] if i % w > 0 else EDGE
	var up := symbols[i - w] if i >= w else EDGE
	return "%d,%d" % [left, up]


## 10 bits of FNV-1a over everything a code says.
static func _check(w: int, h: int, options: int, symbols: Array[int], flags: Array[int]) -> int:
	var v := 0x811C9DC5
	var data: Array[int] = [w, h, options]
	data.append_array(symbols)
	data.append_array(flags)
	for b in data:
		v = ((v ^ b) * 0x01000193) & 0xFFFFFFFF
	return (v ^ (v >> 10) ^ (v >> 20)) & 0x3FF


static func _nearest(values: Array, v: float) -> int:
	var best := 0
	for i in values.size():
		if absf(values[i] - v) < absf(values[best] - v):
			best = i
	return best


static func _push(bits: Array[int], value: int, n: int) -> void:
	for i in n:
		bits.append((value >> (n - 1 - i)) & 1)


static func _field(bits: Array[int], start: int, n: int) -> int:
	var v := 0
	for i in n:
		v = v * 2 + bits[start + i]
	return v


# --- arithmetic coding (Witten, Neal and Cleary, 32-bit) ------------------------------


class _Encoder:
	var low := 0
	var high := TOP
	var pending := 0
	var bits: Array[int] = []

	func put(freqs: Array, s: int) -> void:
		var total := 0
		var lo := 0
		for i in freqs.size():
			if i == s:
				lo = total
			total += freqs[i]
		var hi: int = lo + freqs[s]
		var r := high - low + 1
		high = low + r * hi / total - 1
		low = low + r * lo / total
		while true:
			if high < HALF:
				_out(0)
			elif low >= HALF:
				_out(1)
				low -= HALF
				high -= HALF
			elif low >= QUARTER and high < 3 * QUARTER:
				pending += 1
				low -= QUARTER
				high -= QUARTER
			else:
				break
			low *= 2
			high = high * 2 + 1

	func finish() -> Array[int]:
		pending += 1
		_out(0 if low < QUARTER else 1)
		return bits

	func _out(bit: int) -> void:
		bits.append(bit)
		for i in pending:
			bits.append(1 - bit)
		pending = 0


class _Decoder:
	var low := 0
	var high := TOP
	var value := 0
	var bits: Array[int] = []
	var at := 0

	func _init(source: Array[int]) -> void:
		bits = source
		for i in 32:
			value = value * 2 + _next()

	func get_symbol(freqs: Array) -> int:
		var total := 0
		for f in freqs:
			total += f
		var r := high - low + 1
		var target := ((value - low + 1) * total - 1) / r
		var lo := 0
		var s := 0
		while lo + int(freqs[s]) <= target:
			lo += freqs[s]
			s += 1
		var hi: int = lo + freqs[s]
		high = low + r * hi / total - 1
		low = low + r * lo / total
		while true:
			if high < HALF:
				pass
			elif low >= HALF:
				low -= HALF
				high -= HALF
				value -= HALF
			elif low >= QUARTER and high < 3 * QUARTER:
				low -= QUARTER
				high -= QUARTER
				value -= QUARTER
			else:
				break
			low *= 2
			high = high * 2 + 1
			value = value * 2 + _next()
		return s

	func _next() -> int:
		var bit := bits[at] if at < bits.size() else 0
		at += 1
		return bit
