extends GutTest
## Revision B, the second game: the hundred sheets mirrored and reworked
## (data/levels_b.json), opened by finishing the first game, played on its
## own save track with no assists and the Redline look.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SAVE_PATH := "user://test_revision_b.cfg"

var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false


func before_each() -> void:
	Save.rev_b = false
	Save.has_completed = false
	Save.first_play = false
	Save.new_lessons = false
	Save.track_a = Save.Track.new()
	Save.track_b = Save.Track.new()
	Save.worn = "classic"
	Save.released.clear()
	Save.seen.clear()
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)


func after_each() -> void:
	Save.rev_b = false
	Save.has_completed = false
	Save.track_a = Save.Track.new()
	Save.track_b = Save.Track.new()
	Blueprint.revise(false)
	DirAccess.remove_absolute(SAVE_PATH)


func _mirrored(rows: Array) -> Array:
	var width := 0
	for r in rows:
		width = maxi(width, String(r).length())
	var out := []
	for r in rows:
		var padded := String(r).rpad(width)
		var flipped := ""
		for i in range(width - 1, -1, -1):
			flipped += {"e": "w", "w": "e", "E": "W", "W": "E"}.get(padded[i], padded[i])
		out.append(flipped.rstrip(" "))
	return out


func test_sheets_are_the_first_game_mirrored_with_new_tiles() -> void:
	var a: Array = game.levels
	var b: Array = game.revision_b.levels
	assert_eq(b.size(), a.size())
	var mirrored := _mirrored(a[0]["rows"])
	var rows: Array = b[0]["rows"]
	assert_eq(rows.size(), mirrored.size(), "sheet 1 has the same rows")
	var same := 0
	var new_tiles := 0
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch in "kj^%":
				new_tiles += 1
			elif ch == String(mirrored[y])[x]:
				same += 1
	assert_gt(new_tiles, 0, "sheet 1 has a tile of the second playthrough")
	assert_eq(same + new_tiles, "".join(mirrored).length(), "every other tile is the mirror")


func test_revision_b_waits_for_a_finished_game() -> void:
	game._on_menu_action("revision b")
	assert_eq(game.menus.current, "main", "nothing opens before the game is finished")
	assert_false(game.game_active)
	assert_false(Save.rev_b_open())
	Save.has_completed = true
	assert_true(Save.rev_b_open())


func test_the_main_menu_offers_revision_b_once_finished() -> void:
	game.show_start_menu()
	assert_null(_button("PLAY REVISION B"), "no row before the finish")
	Save.has_completed = true
	game.show_start_menu()
	assert_not_null(_button("PLAY REVISION B"))


func test_revision_b_starts_from_sheet_one_in_its_own_look() -> void:
	Save.has_completed = true
	game._on_menu_action("revision b")
	assert_true(game.game_active)
	assert_true(Save.rev_b)
	assert_eq(game.level, 1)
	assert_eq(game.levels, game.revision_b.levels, "its sheets are played")
	assert_eq(Blueprint.field, Blueprint.FIELD_B, "the Redline field")
	assert_eq(Blueprint.grid_color, Blueprint.GRID_B, "a red-pencil grid")
	assert_eq(game._bg.color, Blueprint.FIELD_B)
	assert_eq(game.losses_here(), 0, "and no assists")
	game.losses[1] = 6
	assert_false(game.assists_on(game.ASSIST_MARKS), "however many lives go")


func test_revision_b_has_its_own_progress() -> void:
	Save.has_completed = true
	Save.track_a.furthest_level = 100
	Save.track_a.checkpoints[90] = 900
	Save.track_a.highscore = 1234
	game._on_menu_action("revision b")
	assert_eq(Save.furthest_level, 1, "Revision B starts from nothing")
	assert_true(Save.checkpoints.is_empty())
	assert_eq(Save.highscore, 0)
	Save.checkpoint_reached(10, 100)
	Save.level_reached(11)
	Save.record_best(3, 12, 1)
	assert_eq(Save.track_b.checkpoints[10], 100)
	assert_eq(Save.track_a.checkpoints.get(10, -1), -1, "Revision A untouched")
	assert_eq(Save.track_a.furthest_level, 100)
	assert_false(Save.track_a.bests.has(3))
	game._on_menu_action("main menu")
	assert_false(Save.rev_b, "back on the main menu, Revision A's progress reads again")
	assert_eq(Save.furthest_level, 100)
	assert_eq(Save.highscore, 1234)
	assert_eq(Blueprint.field, Blueprint.FIELD, "in the blueprint look")


func test_both_tracks_survive_a_save_and_load() -> void:
	Save.persist = true
	Save.has_completed = true
	Save.track_a.checkpoints[20] = 200
	Save.track_a.furthest_level = 21
	Save.track_b.checkpoints[10] = 100
	Save.track_b.furthest_level = 12
	Save.track_b.highscore = 150
	Save.track_b.bests[4] = {"time": 9, "stars": 2}
	Save.save_all(SAVE_PATH)
	Save.track_a = Save.Track.new()
	Save.track_b = Save.Track.new()
	Save.load_all(SAVE_PATH)
	Save.persist = false
	assert_eq(Save.track_a.checkpoints, {20: 200})
	assert_eq(Save.track_a.furthest_level, 21)
	assert_eq(Save.track_b.checkpoints, {10: 100})
	assert_eq(Save.track_b.furthest_level, 12)
	assert_eq(Save.track_b.highscore, 150)
	assert_eq(Save.track_b.bests[4], {"time": 9, "stars": 2})
	assert_false(Save.rev_b, "a load reads as Revision A")


func test_revision_b_checkpoints_sheet_once_it_has_one() -> void:
	Save.has_completed = true
	Save.track_b.checkpoints[10] = 100
	game._on_menu_action("revision b")
	assert_eq(game.menus.current, "restart", "its checkpoints sheet")
	assert_false(game.game_active)
	assert_not_null(_button("PLAY FROM SHEET 001"))
	game._on_menu_action("B10")
	assert_true(game.game_active and Save.rev_b)
	assert_eq(game.level, 10)


func test_the_pause_sheet_is_numbered_b() -> void:
	Save.has_completed = true
	game._on_menu_action("revision b")
	game.show_pause_menu()
	assert_true(game.menus._header.text.contains("001-B"), game.menus._header.text)


func test_finishing_the_first_game_stamps_revision_b_released() -> void:
	game.new_game(100)
	game.level = 101
	game.finish_advancing_level()
	assert_true(game.completed)
	assert_true(game._first_finish)
	game._on_menu_action("completion done")
	assert_eq(game.menus.current, "congratulations")
	assert_not_null(_label("REV B RELEASED"))
	# Finishing again is not news.
	game.new_game(100)
	game.level = 101
	game.finish_advancing_level()
	assert_false(game._first_finish)


func test_finishing_revision_b_stamps_it_approved() -> void:
	Save.has_completed = true
	game.revision_b.start(100)
	game.level = 101
	game.finish_advancing_level()
	game._on_menu_action("completion done")
	assert_not_null(_label("REV B APPROVED"))
	assert_null(_label("REV B RELEASED"))


func test_the_dev_menu_can_open_a_revision_b_sheet() -> void:
	Dev.enabled = true
	DevPanel.go_to_level(game, 42, true)
	Dev.enabled = false
	assert_true(Save.rev_b)
	assert_eq(game.level, 42)
	assert_true(Save.has_completed, "as a player who has finished")


func _button(text: String) -> Button:
	for b in game.menus.find_children("*", "Button", true, false):
		if b.text.ends_with(text):
			return b
	return null


func _label(text: String) -> Label:
	for l in game.menus.find_children("*", "Label", true, false):
		if l.text == text:
			return l
	return null
