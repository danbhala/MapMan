extends GutTest
## Checks the converted level data is well formed. Whether each level can be
## finished is proven by tests/autoplay_test.gd.

const MAX_ROWS := 12
const MAX_COLUMNS := 17
const ENDS := ["n", "s", "e", "w"]


func _load(path: String) -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(path))["levels"]


func _check(levels: Array, label: String) -> void:
	for level in levels:
		var rows: Array = level["rows"]
		var where := "%s level %d" % [label, level["number"]]
		assert_lte(rows.size(), MAX_ROWS, where + " rows")
		var starts := 0
		var ends := 0
		for row in rows:
			assert_lte(String(row).length(), MAX_COLUMNS, where + " columns")
			for ch in String(row):
				if ch.to_lower() == "b":
					starts += 1
				elif ch.to_lower() in ENDS:
					ends += 1
		assert_eq(starts, 1, where + " has one start")
		assert_gt(ends, 0, where + " has an exit")
		if level.get("loading") != null:
			assert_eq(level["loading"].size(), rows.size(), where + " loading rows match")


func test_game_levels() -> void:
	var levels := _load("res://data/levels.json")
	assert_eq(levels.size(), 100)
	_check(levels, "game")


func test_tutorial_levels() -> void:
	var levels := _load("res://data/tutorial.json")
	assert_eq(levels.size(), 15)
	_check(levels, "tutorial")


func test_checkpoints_are_real_levels() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	for cp in data["check_points"]:
		assert_between(int(cp), 1, 100)
