class_name QrReader
extends RefCounted
## Reads a QR code from a camera picture, for scanning a friend's level on
## their phone's share sheet. It finds the three corner squares, follows the
## grid between them (with the small square near the fourth corner when the
## phone is held at an angle), reads the modules, repairs them with the
## code's own error correction, and returns the text, or "" if there is no
## readable code. It reads what `addons/kenyoni/qr_code/` writes (and any
## standard QR code), and runs off the main thread: it touches nothing but
## the picture it is given.

const QrCode := preload("res://addons/kenyoni/qr_code/qr_code.gd")

## Pictures are read at most this size: a code filling a quarter of the
## picture's height still gets three pixels a module, and a read stays
## under a fifth of a second.
const MAX_SIDE := 640
## The ways a picture is turned into dark and light, tried in turn: against
## the brightness around each pixel (over 16, then 32 pixels: shadows and
## glare), then against one level for the whole picture.
const PASSES := [4, 5, 0]
## The format bits of each error-correction level and mask, after the
## BCH code and the fixed mask: index (level << 3) | mask.
static var _formats: PackedInt32Array = []
## GF(256) under the QR polynomial 0x11D.
static var _exp: PackedByteArray = []
static var _log: PackedByteArray = []


## The text of the QR code in `picture`, or "".
static func read(picture: Image) -> String:
	if picture == null or picture.is_empty() or picture.is_compressed():
		return ""
	var img := picture.duplicate() as Image
	if img.get_format() != Image.FORMAT_L8:
		img.convert(Image.FORMAT_L8)
	var side := maxi(img.get_width(), img.get_height())
	if side > MAX_SIDE:
		var f := float(MAX_SIDE) / side
		img.resize(
			maxi(1, roundi(img.get_width() * f)),
			maxi(1, roundi(img.get_height() * f)),
			Image.INTERPOLATE_BILINEAR
		)
	for shrinks: int in PASSES:
		var text := _read_bits(_binarize(img, shrinks), img.get_width(), img.get_height())
		if text != "":
			return text
	return ""


# --- dark and light ---------------------------------------------------------------


## 1 for each dark pixel. shrinks > 0: darker than the blurred picture
## (halved that many times) around it; 0: darker than the middle of the
## picture's darkest and brightest.
static func _binarize(img: Image, shrinks: int) -> PackedByteArray:
	var w := img.get_width()
	var h := img.get_height()
	var lum := img.get_data()
	var bits := PackedByteArray()
	bits.resize(lum.size())
	if shrinks == 0:
		var counts := PackedInt32Array()
		counts.resize(256)
		for v: int in lum:
			counts[v] += 1
		var low := _percentile(counts, lum.size() / 20)
		var high := _percentile(counts, lum.size() - lum.size() / 20)
		var level := (low + high) / 2
		for i in lum.size():
			bits[i] = 1 if lum[i] < level else 0
		return bits
	var blur := img.duplicate() as Image
	for i in shrinks:
		if blur.get_width() < 4 or blur.get_height() < 4:
			break
		blur.shrink_x2()
	blur.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var mean := blur.get_data()
	for i in lum.size():
		bits[i] = 1 if lum[i] + 4 < mean[i] else 0
	return bits


static func _percentile(counts: PackedInt32Array, rank: int) -> int:
	var seen := 0
	for v in 256:
		seen += counts[v]
		if seen > rank:
			return v
	return 255


# --- finding the code -------------------------------------------------------------


static func _read_bits(bits: PackedByteArray, w: int, h: int) -> String:
	var found := _finders(bits, w, h)
	if found.size() < 3:
		return ""
	var corners := _corners(found)
	if corners.is_empty():
		return ""
	var tl: Dictionary = corners[0]
	var tr: Dictionary = corners[1]
	var bl: Dictionary = corners[2]
	var across: float = (tl.p as Vector2).distance_to(tr.p) / ((tl.m + tr.m) / 2.0)
	var down: float = (tl.p as Vector2).distance_to(bl.p) / ((tl.m + bl.m) / 2.0)
	var dim := roundi((across + down) / 2.0) + 7
	match dim % 4:
		0:
			dim += 1
		2:
			dim -= 1
		3:
			dim -= 2
	# At an angle the corner squares' sizes mislead a little: try nearby sizes.
	for d in [dim, dim + 4, dim - 4, dim + 8, dim - 8]:
		if d < 21 or d > 177:
			continue
		var text := _read_grid(bits, w, h, tl, tr, bl, d)
		if text != "":
			return text
	return ""


## The corner squares' centres and module sizes ({p, m, n}): rows of dark
## and light in the ratio 1:1:3:1:1, checked again down the column.
static func _finders(bits: PackedByteArray, w: int, h: int) -> Array:
	var found: Array = []
	var runs := PackedInt32Array()
	runs.resize(5)
	for y in range(0, h, 2):
		var row := y * w
		var x := 0
		# Skip the light at the row's start.
		while x < w and bits[row + x] == 0:
			x += 1
		var starts := PackedInt32Array()
		var lens := PackedInt32Array()
		while x < w:
			var colour := bits[row + x]
			var start := x
			while x < w and bits[row + x] == colour:
				x += 1
			starts.append(start)
			lens.append(x - start)
		# Runs alternate dark, light, ... from index 0.
		for i in range(0, lens.size() - 4, 2):
			for k in 5:
				runs[k] = lens[i + k]
			if not _ratio_ok(runs):
				continue
			var cx := starts[i + 2] + lens[i + 2] / 2.0
			var across := 0
			for k in 5:
				across += runs[k]
			var down := _cross(bits, w, h, cx, y, Vector2i(0, 1), across)
			if down.is_empty():
				continue
			var again := _cross(bits, w, h, cx, down.c, Vector2i(1, 0), across)
			if again.is_empty():
				continue
			var p := Vector2(again.c as float, down.c as float)
			var m: float = (down.total + again.total) / 14.0
			_add_finder(found, p, m)
	found.sort_custom(func(a, b): return a.n > b.n)
	return found


static func _ratio_ok(runs: PackedInt32Array) -> bool:
	var total := 0
	for k in 5:
		if runs[k] == 0:
			return false
		total += runs[k]
	if total < 7:
		return false
	var m := total / 7.0
	var slack := m * 0.7
	return (
		absf(runs[0] - m) < slack
		and absf(runs[1] - m) < slack
		and absf(runs[2] - 3.0 * m) < 3.0 * slack
		and absf(runs[3] - m) < slack
		and absf(runs[4] - m) < slack
	)


## Check a corner square through (x, y) along `step` (a column or a row):
## {c: its centre along that line, total: its width}, or {} if it isn't one.
static func _cross(
	bits: PackedByteArray, w: int, h: int, x: float, y: float, step: Vector2i, size: int
) -> Dictionary:
	var at := Vector2i(int(x), int(y))
	if at.x < 0 or at.y < 0 or at.x >= w or at.y >= h or bits[at.x + at.y * w] == 0:
		return {}
	var runs := PackedInt32Array([0, 0, 0, 0, 0])
	var far := size * 2
	# From the centre backwards: the middle, light, dark.
	var p := at
	for k in [2, 1, 0]:
		var colour := 1 if k != 1 else 0
		while _inside(p, w, h) and bits[p.x + p.y * w] == colour and runs[k] <= far:
			runs[k] += 1
			p -= step
	var first := p + step
	p = at + step
	for k in [2, 3, 4]:
		var colour := 1 if k != 3 else 0
		while _inside(p, w, h) and bits[p.x + p.y * w] == colour and runs[k] <= far:
			runs[k] += 1
			p += step
	var total := 0
	for k in 5:
		total += runs[k]
	if absf(total - size) > size * 0.6 or not _ratio_ok(runs):
		return {}
	var along := first.y if step.y != 0 else first.x
	return {c = along + runs[0] + runs[1] + runs[2] / 2.0, total = total}


static func _inside(p: Vector2i, w: int, h: int) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < w and p.y < h


## The same square seen from another row joins the earlier sighting.
static func _add_finder(found: Array, p: Vector2, m: float) -> void:
	for f: Dictionary in found:
		if (f.p as Vector2).distance_to(p) < f.m * 3.0 and absf(f.m - m) < f.m:
			f.p = (f.p * f.n + p) / (f.n + 1)
			f.m = (f.m * f.n + m) / (f.n + 1)
			f.n += 1
			return
	found.append({p = p, m = m, n = 1})


## The three squares that best make a corner, as [top left, top right,
## bottom left] of the code (whichever way the picture is turned), or [].
static func _corners(found: Array) -> Array:
	# Squares seen from several rows are real; one-row sightings are noise
	# unless there aren't three of the others.
	var pick := found.filter(func(f): return f.n >= 2)
	if pick.size() < 3:
		pick = found
	pick = pick.slice(0, 8)
	var best: Array = []
	var best_error := 0.6
	for i in pick.size():
		for j in range(i + 1, pick.size()):
			for k in range(j + 1, pick.size()):
				var trio := _as_corner([pick[i], pick[j], pick[k]])
				if trio.is_empty():
					continue
				if trio[3] < best_error:
					best_error = trio[3]
					best = trio.slice(0, 3)
	return best


## [top left, top right, bottom left, how far from a square corner], or [].
static func _as_corner(trio: Array) -> Array:
	var sizes: Array = trio.map(func(f): return f.m)
	if sizes.max() > sizes.min() * 1.8:
		return []
	# The corner is opposite the longest side.
	var a: Dictionary = trio[0]
	var b: Dictionary = trio[1]
	var c: Dictionary = trio[2]
	var bc := (b.p as Vector2).distance_to(c.p)
	var ac := (a.p as Vector2).distance_to(c.p)
	var ab := (a.p as Vector2).distance_to(b.p)
	if ac > bc and ac >= ab:
		var t := a
		a = b
		b = t
	elif ab > bc and ab > ac:
		var t := a
		a = c
		c = t
	var u: Vector2 = b.p - a.p
	var v: Vector2 = c.p - a.p
	if u.length() < a.m * 10.0 or v.length() < a.m * 10.0:
		return []
	var lengths := u.length() / v.length()
	if lengths < 0.6 or lengths > 1.67:
		return []
	# Screen y points down, so top right then bottom left turns clockwise.
	if u.cross(v) < 0:
		var t := b
		b = c
		c = t
	var bend := absf(u.normalized().dot(v.normalized()))
	return [a, b, c, bend + absf(log(lengths))]


# --- reading the grid -------------------------------------------------------------


static func _read_grid(
	bits: PackedByteArray, w: int, h: int, tl: Dictionary, tr: Dictionary, bl: Dictionary, dim: int
) -> String:
	var version := (dim - 17) / 4
	var o: Vector2 = tl.p
	var u: Vector2 = (tr.p - o) / (dim - 7.0)
	var v: Vector2 = (bl.p - o) / (dim - 7.0)
	var src := [Vector2(3.5, 3.5), Vector2(dim - 3.5, 3.5), Vector2(3.5, dim - 3.5)]
	var dst := [o, tr.p as Vector2, bl.p as Vector2]
	# The fourth corner: the small square near it, or straight lines.
	var guess := o + u * (dim - 10.0) + v * (dim - 10.0)
	var small := Vector2.INF
	if version >= 2:
		small = _alignment(bits, w, h, guess, u, v)
	if small != Vector2.INF:
		src.append(Vector2(dim - 6.5, dim - 6.5))
		dst.append(small)
	else:
		src.append(Vector2(dim - 3.5, dim - 3.5))
		dst.append(o + u * (dim - 7.0) + v * (dim - 7.0))
	var hm := homography(src, dst)
	if hm.is_empty():
		return ""
	var modules := PackedByteArray()
	modules.resize(dim * dim)
	for y in dim:
		for x in dim:
			var p := project(hm, Vector2(x + 0.5, y + 0.5))
			var at := Vector2i(roundi(p.x - 0.5), roundi(p.y - 0.5))
			if not _inside(at, w, h):
				return ""
			modules[x + y * dim] = bits[at.x + at.y * w]
	var text := decode_modules(modules, dim)
	if text != "":
		return text
	# A mirrored picture (some cameras' feeds, a front camera) reads as the
	# code turned over its diagonal.
	var turned := PackedByteArray()
	turned.resize(modules.size())
	for y in dim:
		for x in dim:
			turned[y + x * dim] = modules[x + y * dim]
	return decode_modules(turned, dim)


## The centre of the small square nearest `guess`, or INF: a dark module
## with light either side, across and down, then the dark ring around it.
## Found by its runs rather than its expected size, because at an angle the
## far corner of the code is bigger or smaller than the near ones.
static func _alignment(
	bits: PackedByteArray, w: int, h: int, guess: Vector2, u: Vector2, v: Vector2
) -> Vector2:
	var module := (u.length() + v.length()) / 2.0
	var reach := int(module * 7.0)
	var top := clampi(int(guess.y) - reach, 0, h - 1)
	var bottom := clampi(int(guess.y) + reach, 0, h - 1)
	var left := clampi(int(guess.x) - reach, 0, w - 1)
	var right := clampi(int(guess.x) + reach, 0, w - 1)
	var best := Vector2.INF
	for y in range(top, bottom + 1):
		var starts := PackedInt32Array()
		var lens := PackedInt32Array()
		var x := left
		while x <= right:
			var colour := bits[x + y * w]
			var start := x
			while x <= right and bits[x + y * w] == colour:
				x += 1
			starts.append(start)
			lens.append(x - start)
		# Light, dark, light, with dark beyond both ends.
		for i in range(2, lens.size() - 2):
			if bits[starts[i] + y * w] == 0:
				continue
			if not _even_runs(lens[i - 1], lens[i], lens[i + 1], module):
				continue
			var cx := starts[i] + lens[i] / 2.0
			var cy := _alignment_down(bits, w, h, int(cx), y, module)
			if cy < 0.0:
				continue
			var c := Vector2(cx, cy)
			if c.distance_to(guess) >= best.distance_to(guess):
				continue
			for scale in [1.0, 0.8, 1.25, 1.5]:
				if _alignment_score(bits, w, h, c, u * scale, v * scale) >= 23:
					best = c
					break
	return best


static func _even_runs(a: int, b: int, c: int, module: float) -> bool:
	var low := mini(a, mini(b, c))
	var high := maxi(a, maxi(b, c))
	return low >= module * 0.4 and high <= module * 2.2 and high <= low * 2 + 1


## The centre down the column through (x, y) of a dark run between two
## light ones, each about a module, or -1.
static func _alignment_down(
	bits: PackedByteArray, w: int, h: int, x: int, y: int, module: float
) -> float:
	var up := y
	while up > 0 and bits[x + (up - 1) * w] == 1:
		up -= 1
	var down := y
	while down < h - 1 and bits[x + (down + 1) * w] == 1:
		down += 1
	var above := 0
	while up - above - 1 >= 0 and bits[x + (up - above - 1) * w] == 0:
		above += 1
	var below := 0
	while down + below + 1 < h and bits[x + (down + below + 1) * w] == 0:
		below += 1
	if up - above - 1 < 0 or down + below + 1 >= h:
		return -1.0
	if not _even_runs(above, down - up + 1, below, module):
		return -1.0
	return (up + down + 1) / 2.0


## How many of the small square's 25 modules match around c (of 25).
static func _alignment_score(
	bits: PackedByteArray, w: int, h: int, c: Vector2, u: Vector2, v: Vector2
) -> int:
	var score := 0
	for j in range(-2, 3):
		for i in range(-2, 3):
			var p := c + u * i + v * j
			var at := Vector2i(floori(p.x), floori(p.y))
			if not _inside(at, w, h):
				continue
			var dark := maxi(absi(i), absi(j)) != 1
			if (bits[at.x + at.y * w] == 1) == dark:
				score += 1
	return score


## The perspective map taking the four points `src` to `dst`, or [] if they
## are in a line.
static func homography(src: Array, dst: Array) -> PackedFloat64Array:
	var rows: Array[PackedFloat64Array] = []
	for i in 4:
		var s: Vector2 = src[i]
		var d: Vector2 = dst[i]
		rows.append(PackedFloat64Array([s.x, s.y, 1, 0, 0, 0, -s.x * d.x, -s.y * d.x, d.x]))
		rows.append(PackedFloat64Array([0, 0, 0, s.x, s.y, 1, -s.x * d.y, -s.y * d.y, d.y]))
	for col in 8:
		var pivot := col
		for r in range(col + 1, 8):
			if absf(rows[r][col]) > absf(rows[pivot][col]):
				pivot = r
		if absf(rows[pivot][col]) < 1e-9:
			return PackedFloat64Array()
		var t := rows[col]
		rows[col] = rows[pivot]
		rows[pivot] = t
		for r in 8:
			if r == col:
				continue
			var f: float = rows[r][col] / rows[col][col]
			if f == 0.0:
				continue
			for k in range(col, 9):
				rows[r][k] -= f * rows[col][k]
	var out := PackedFloat64Array()
	for r in 8:
		out.append(rows[r][8] / rows[r][r])
	return out


static func project(hm: PackedFloat64Array, p: Vector2) -> Vector2:
	var z := hm[6] * p.x + hm[7] * p.y + 1.0
	return Vector2((hm[0] * p.x + hm[1] * p.y + hm[2]) / z, (hm[3] * p.x + hm[4] * p.y + hm[5]) / z)


# --- reading the modules ----------------------------------------------------------


## The text in a grid of modules (1 dark, index x + y * dim), or "".
static func decode_modules(modules: PackedByteArray, dim: int) -> String:
	var version := (dim - 17) / 4
	if version < 1 or version > 40 or dim != 17 + version * 4:
		return ""
	var format := _format(modules, dim)
	if format < 0:
		return ""
	var level := format >> 3
	var aligns := _alignment_positions(version, dim)
	var mask: Callable = QrCode._mask_pattern_fns()[format & 7]
	# Read the modules in the zigzag the encoder wrote them, unmasking.
	var words := PackedByteArray()
	var byte := 0
	var count := 0
	var col := dim - 1
	var upwards := true
	while col > 0:
		if col == 6:
			col -= 1
		for r in dim:
			var y := dim - 1 - r if upwards else r
			for off in 2:
				var pos := Vector2i(col - off, y)
				if not QrCode._is_data_module(dim, aligns, pos):
					continue
				var bit := modules[pos.x + pos.y * dim] ^ int(mask.call(pos))
				byte = (byte << 1) | bit
				count += 1
				if count == 8:
					words.append(byte)
					byte = 0
					count = 0
		col -= 2
		upwards = not upwards
	var data := _correct(words, QrCode._ERROR_CORRECTION[version - 1][level])
	if data.is_empty():
		return ""
	return _segments(data, version)


## The format's (level << 3) | mask, from whichever copy reads closest to a
## real one, or -1.
static func _format(modules: PackedByteArray, dim: int) -> int:
	var first := 0
	var second := 0
	for i in 8:
		var pos := i + 1 if i > 5 else i
		if modules[pos + 8 * dim] == 1:
			first |= 1 << (14 - i)
		if modules[8 + pos * dim] == 1:
			first |= 1 << i
		if modules[(dim - 1 - i) + 8 * dim] == 1:
			second |= 1 << i
	for i in 7:
		if modules[8 + (dim - 1 - i) * dim] == 1:
			second |= 1 << (14 - i)
	if _formats.is_empty():
		for base in 32:
			var code := base
			for i in 10:
				code = (code << 1) ^ ((code >> 9) * 0x537)
			_formats.append((base << 10 | code) ^ 0x5412)
	var best := -1
	var best_distance := 4
	for base in 32:
		for read: int in [first, second]:
			var distance := _ones(read ^ _formats[base])
			if distance < best_distance:
				best_distance = distance
				best = base
	return best


static func _ones(n: int) -> int:
	var count := 0
	while n != 0:
		count += n & 1
		n >>= 1
	return count


## As the encoder lists them (Vector2i(row, column), the same both ways).
static func _alignment_positions(version: int, dim: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var at: Array = QrCode._ALIGNMENT_PATTERN_POSITIONS[version - 1]
	for row: int in at:
		for col: int in at:
			if (
				(row - 2 < 8 and col - 2 < 8)
				or (row - 2 < 8 and col + 2 > dim - 8)
				or (row + 2 >= dim - 8 and col - 2 < 8)
			):
				continue
			out.append(Vector2i(row, col))
	return out


## Undo the block interleaving and repair each block; the data codewords,
## or [] if a block is past repair. table: [data words, check words per
## block, blocks in group 1, words each, blocks in group 2, words each].
static func _correct(words: PackedByteArray, table: Array) -> PackedByteArray:
	var checks: int = table[1]
	var sizes := PackedInt32Array()
	for g in 2:
		for _b in table[2 + g * 2]:
			sizes.append(table[3 + g * 2])
	var blocks: Array[PackedByteArray] = []
	for _s in sizes:
		blocks.append(PackedByteArray())
	var i := 0
	var longest: int = sizes[sizes.size() - 1]
	for k in longest:
		for b in sizes.size():
			if k < sizes[b]:
				if i >= words.size():
					return PackedByteArray()
				blocks[b].append(words[i])
				i += 1
	for k in checks:
		for b in sizes.size():
			if i >= words.size():
				return PackedByteArray()
			blocks[b].append(words[i])
			i += 1
	var data := PackedByteArray()
	for b in sizes.size():
		var fixed := repair(blocks[b], checks)
		if fixed.is_empty():
			return PackedByteArray()
		data.append_array(fixed.slice(0, sizes[b]))
	return data


## The text of the data codewords' segments (numbers, letters, bytes).
static func _segments(data: PackedByteArray, version: int) -> String:
	var at := [0]
	var total := data.size() * 8
	var text := ""
	var size_class := 0 if version < 10 else (1 if version < 27 else 2)
	while at[0] + 4 <= total:
		var mode := _take(data, at, 4)
		if mode == 0:
			break
		match mode:
			1:
				var n := _take(data, at, [10, 12, 14][size_class])
				while n >= 3:
					text += "%03d" % _take(data, at, 10)
					n -= 3
				if n == 2:
					text += "%02d" % _take(data, at, 7)
				elif n == 1:
					text += "%d" % _take(data, at, 4)
			2:
				var n := _take(data, at, [9, 11, 13][size_class])
				var letters := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"
				while n >= 2:
					var pair := _take(data, at, 11)
					if pair >= 45 * 45:
						return ""
					text += letters[pair / 45] + letters[pair % 45]
					n -= 2
				if n == 1:
					var one := _take(data, at, 6)
					if one >= 45:
						return ""
					text += letters[one]
			4:
				var n := _take(data, at, [8, 16, 16][size_class])
				var bytes := PackedByteArray()
				for k in n:
					bytes.append(_take(data, at, 8))
				text += bytes.get_string_from_utf8()
			7:
				# A character set: the text is read as UTF-8 regardless.
				if _take(data, at, 8) & 0x80:
					_take(data, at, 8)
			_:
				return text
		if at[0] > total:
			return ""
	return text


## The next `n` bits of `data` from bit at[0], moving at[0] on. Past the
## end reads zeros.
static func _take(data: PackedByteArray, at: Array, n: int) -> int:
	var out := 0
	for k in n:
		var i: int = at[0] + k
		var bit := 0
		if i < data.size() * 8:
			bit = (data[i >> 3] >> (7 - (i & 7))) & 1
		out = (out << 1) | bit
	at[0] += n
	return out


# --- error correction -------------------------------------------------------------


## `block` (data then `checks` check words, highest power first) with up to
## checks / 2 wrong words put right, or [] if it can't be.
static func repair(block: PackedByteArray, checks: int) -> PackedByteArray:
	_tables()
	var n := block.size()
	var syndromes := PackedByteArray()
	var clean := true
	for j in checks:
		var s := 0
		var x: int = _exp[j % 255]
		for c in block:
			s = _mul(s, x) ^ c
		syndromes.append(s)
		clean = clean and s == 0
	if clean:
		return block
	# Berlekamp-Massey: the error locator, lowest power first.
	var lam := PackedByteArray([1])
	var prev := PackedByteArray([1])
	var errors := 0
	var gap := 1
	var last := 1
	for k in checks:
		var d: int = syndromes[k]
		for i in range(1, errors + 1):
			if i < lam.size():
				d ^= _mul(lam[i], syndromes[k - i])
		if d == 0:
			gap += 1
			continue
		var scale := _div(d, last)
		var next := lam.duplicate()
		if next.size() < prev.size() + gap:
			next.resize(prev.size() + gap)
		for i in prev.size():
			next[i + gap] ^= _mul(scale, prev[i])
		if 2 * errors <= k:
			prev = lam
			errors = k + 1 - errors
			last = d
			gap = 1
		else:
			gap += 1
		lam = next
	if errors * 2 > checks:
		return PackedByteArray()
	# Chien search: an error at power p has lam(alpha^-p) == 0.
	var powers := PackedInt32Array()
	for p in n:
		if _eval_low(lam, _exp[(255 - p % 255) % 255]) == 0:
			powers.append(p)
	if powers.size() != errors:
		return PackedByteArray()
	# Forney: omega = S * lam mod x^checks; e = X * omega(X^-1) / lam'(X^-1).
	var omega := PackedByteArray()
	omega.resize(checks)
	for i in checks:
		var v := 0
		for k in range(0, mini(i, lam.size() - 1) + 1):
			v ^= _mul(lam[k], syndromes[i - k])
		omega[i] = v
	var out := block.duplicate()
	for p in powers:
		var x: int = _exp[p % 255]
		var x_inv: int = _exp[(255 - p % 255) % 255]
		var slope := 0
		for i in range(1, lam.size(), 2):
			slope ^= _mul(lam[i], _pow(x_inv, i - 1))
		if slope == 0:
			return PackedByteArray()
		out[n - 1 - p] ^= _mul(x, _div(_eval_low(omega, x_inv), slope))
	return out


static func _tables() -> void:
	if not _exp.is_empty():
		return
	_exp.resize(256)
	_log.resize(256)
	var v := 1
	for i in 255:
		_exp[i] = v
		_log[v] = i
		v <<= 1
		if v & 0x100:
			v ^= 0x11D
	_exp[255] = _exp[0]


static func _mul(a: int, b: int) -> int:
	if a == 0 or b == 0:
		return 0
	return _exp[(_log[a] + _log[b]) % 255]


static func _div(a: int, b: int) -> int:
	if a == 0:
		return 0
	return _exp[(_log[a] + 255 - _log[b]) % 255]


static func _pow(a: int, e: int) -> int:
	if e == 0:
		return 1
	if a == 0:
		return 0
	return _exp[(_log[a] * e) % 255]


## A polynomial (lowest power first) at x.
static func _eval_low(poly: PackedByteArray, x: int) -> int:
	var out := 0
	for i in range(poly.size() - 1, -1, -1):
		out = _mul(out, x) ^ poly[i]
	return out
