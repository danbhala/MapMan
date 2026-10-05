extends GutTest
## Level codes (scripts/level_code.gd): every campaign level makes the same
## code as the reference, tools/level_code.py (tests/data/level_codes.json),
## and reads back as the same level.

const FIXTURES := "res://tests/data/level_codes.json"


func _levels() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))["levels"]


func _fixtures() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURES))["codes"]


func test_codes_match_the_reference() -> void:
	var levels := _levels()
	var fixtures := _fixtures()
	assert_eq(fixtures.size(), levels.size())
	for i in levels.size():
		var grid := LevelCode.grid_of(levels[i])
		var level: Dictionary = levels[i]
		var code := LevelCode.encode(grid[0], grid[1], level.x_hides, level.delay)
		assert_eq(code, fixtures[i].code, "level %d" % level.number)


func test_every_level_reads_back() -> void:
	for level in _levels():
		var grid := LevelCode.grid_of(level)
		var got := LevelCode.decode(LevelCode.encode(grid[0], grid[1]))
		assert_eq(got.get("rows"), grid[0], "level %d rows" % level.number)
		assert_eq(got.get("hidden"), grid[1], "level %d hidden tiles" % level.number)


func test_options_travel_with_the_code() -> void:
	var got := LevelCode.decode(LevelCode.encode(["bccw"], {}, 50, 0.1))
	assert_eq(got.x_hides, 50)
	assert_almost_eq(got.delay, 0.1, 0.0001)


func test_reading_is_forgiving() -> void:
	var code := LevelCode.encode(["bcdcw", "  p  "])
	var loose := "mapman " + code.to_lower().replace("-", " ")
	assert_eq(LevelCode.decode(loose).get("rows"), ["bcdcw", "  p  "])
	# O for 0 and I or L for 1, as people type them.
	assert_eq(LevelCode.clean("o1-IL"), "0111")
	assert_eq(LevelCode.clean("0MM3-U"), "", "U is never in a code")


func test_typos_are_caught() -> void:
	var code := LevelCode.clean(LevelCode.encode(["bcccccccw", "c d d d c", "ccccppccc"]))
	var original := LevelCode.decode(code)
	var wrong := 0
	for i in code.length():
		for ch in ["0", "7", "Z"]:
			if code[i] == ch:
				continue
			var typo: String = code.left(i) + ch + code.substr(i + 1)
			var got := LevelCode.decode(typo)
			if got.has("rows") and got.rows != original.rows:
				wrong += 1
	assert_eq(wrong, 0, "a mistyped character never loads a different level")
	assert_eq(LevelCode.decode("HELLO"), {})
	assert_eq(LevelCode.decode(""), {})


func test_a_shared_level_plays() -> void:
	var got := LevelCode.decode(LevelCode.encode(["bcc", "  c", "  w"], {Vector2i(2, 2): true}))
	var level := LevelCode.to_level(got)
	assert_eq(level.rows, ["bcc", "  c", "  w"])
	assert_eq(String(level.loading[2])[2], "*", "hidden tiles start hidden")
	assert_lt(level.loading[0][0], level.loading[0][1], "tiles appear outwards from the start")


func test_trim() -> void:
	var got := LevelCode.trim(["     ", "  bc ", "   w ", "     "], {Vector2i(3, 2): true})
	assert_eq(got[0], ["bc", " w"])
	assert_eq(got[1], {Vector2i(1, 1): true})
	assert_eq(LevelCode.trim(["   "], {}), [])


func test_tiles_added_later_keep_the_alphabet() -> void:
	# A new tile takes a spare symbol; the alphabet's size never changes.
	assert_eq(LevelCode.SYMBOLS.length() + LevelCode.RESERVED, 43)
	var rows := ["bkkcw"]
	assert_eq(LevelCode.decode(LevelCode.encode(rows, {})).rows, rows, "crumble tiles")
	rows = ["bjj^%cw"]
	assert_eq(LevelCode.decode(LevelCode.encode(rows, {})).rows, rows, "ice and spikes")


func test_share_text_is_what_copy_code_and_the_qr_hold() -> void:
	var spiral := [
		"bccccccccccpc",
		"            c",
		"ccccccccpcc c",
		"m         c c",
		"c cccccce c c",
		"c c       c c",
		"p cccpccccc c",
		"c           c",
		"cccccccccpccc",
	]
	var code := LevelCode.encode(spiral, {})
	var want := "MAPMAN 0S01-6SZK-476Z-CV1S-3E6R-79E6-QS87-FQZ5-CT5D-S4NT-ZPR"
	assert_eq(LevelCode.share_text(code), want)
	assert_eq(LevelCode.share_text(LevelCode.clean(code)), want, "bare codes come out pretty")
	assert_eq(LevelCode.decode(want).rows, spiral, "and it reads back")
