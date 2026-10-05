extends GutTest
## The drafting table: drafts paint, undo and keep one start tile; beating a
## draft signs it; a friend's code plays like practice and is kept; and the
## table only opens once the game is far enough along.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false


func before_each() -> void:
	Save.furthest_level = 11
	Save.has_completed = false
	Save.drafts.clear()
	Save.received.clear()
	Save.clipboard_seen = ""
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)


func after_all() -> void:
	Save.furthest_level = 1
	Save.drafts.clear()
	Save.received.clear()


## A start tile, two path tiles and an exit to the east, in row 3.
func _corridor(slot := 0) -> Draft:
	var d := Draft.new(slot)
	d.begin_stroke()
	d.paint(Vector2i(2, 3), "b")
	d.paint(Vector2i(3, 3), "c")
	d.paint(Vector2i(4, 3), "c")
	d.paint(Vector2i(5, 3), "e")
	return d


func _loaded() -> void:
	game.map._load_elapsed = game.map._load_time
	game.loaded()


## Walk right until the exit.
func _win() -> void:
	for i in 3:
		game.move(Vector2i.RIGHT, 0.01)
		game.map.update_move(1.0)
		game.update_player(0.0)


func _on_sheet(text: String) -> bool:
	for b in game.menus._panel.find_children("*", "Button", true, false):
		if text in (b as Button).text:
			return true
	return false


# --- Draft ---------------------------------------------------------------------


func test_a_draft_keeps_one_start_tile() -> void:
	var d := _corridor()
	d.paint(Vector2i(8, 8), "b")
	assert_eq("".join(d.rows).count("b"), 1)
	assert_eq(d.tile(Vector2i(8, 8)), "b")
	assert_eq(d.tile(Vector2i(2, 3)), " ")


func test_undo_takes_back_a_whole_stroke() -> void:
	var d := _corridor()
	d.begin_stroke()
	d.paint(Vector2i(6, 3), "c")
	d.paint(Vector2i(7, 3), "c")
	assert_true(d.undo())
	assert_eq(d.tile(Vector2i(6, 3)), " ")
	assert_eq(d.tile(Vector2i(5, 3)), "e", "the stroke before stays")
	assert_true(d.undo())
	assert_true(d.is_empty())
	assert_false(d.can_undo())


func test_problem_names_what_is_missing() -> void:
	var d := Draft.new()
	assert_eq(d.problem(), "start")
	d.paint(Vector2i(1, 1), "b")
	assert_eq(d.problem(), "exit")
	d.paint(Vector2i(2, 1), "n")
	assert_eq(d.problem(), "")


func test_any_change_unsigns_a_draft() -> void:
	var d := _corridor()
	d.signed = true
	d.paint(Vector2i(6, 3), "p")
	assert_false(d.signed)
	d.signed = true
	d.set_hidden(Vector2i(3, 3), true)
	assert_false(d.signed)
	assert_false(d.set_hidden(Vector2i(0, 0), true), "an empty cell can't start hidden")


func test_a_draft_survives_the_save() -> void:
	var d := _corridor(3)
	d.set_hidden(Vector2i(4, 3), true)
	d.signed = true
	var back := Draft.from_save(3, d.to_save())
	assert_eq(back.rows, d.rows)
	assert_eq(back.hidden.keys(), [Vector2i(4, 3)])
	assert_true(back.signed)
	assert_eq(back.code(), d.code())


func test_a_damaged_save_gives_an_empty_draft() -> void:
	var saved := _corridor().to_save()
	saved.rows[0] = "not a row"
	assert_true(Draft.from_save(0, saved).is_empty())
	assert_true(Draft.from_save(0, "junk").is_empty())


# --- playing -------------------------------------------------------------------


func test_the_table_opens_after_level_ten() -> void:
	Save.furthest_level = 10
	game.show_start_menu()
	assert_false(_on_sheet("DRAFTING TABLE"))
	Save.furthest_level = 11
	game.show_start_menu()
	assert_true(_on_sheet("DRAFTING TABLE"))


func test_beating_a_draft_signs_it() -> void:
	game.drafting.show()
	game._on_menu_action("draft 0")
	game.drafting.draft = _corridor()
	game._on_menu_action("test draft")
	assert_eq(game.custom, "draft")
	_loaded()
	_win()
	assert_eq(game.custom, "", "back from the test")
	assert_eq(game.menus.current, "editor")
	assert_true(game.drafting.draft.signed)
	assert_true(Save.all_drafts()[0].signed, "saved signed")


func test_a_friends_code_plays_without_lives_and_is_kept() -> void:
	var code := _corridor().code()
	Save.highscore = 55
	game.drafting.show()
	assert_eq(game.drafting.play_code("mapman " + code.to_lower()), "")
	assert_eq(game.custom, "received")
	assert_eq(Save.received, [LevelCode.pretty(code)])
	_loaded()
	_win()
	assert_eq(game.menus.current, "drafting")
	assert_eq(Save.highscore, 55, "no score")


func test_a_bad_code_is_turned_away() -> void:
	game.drafting.show()
	game._on_menu_action("enter code")
	game.menus.code_input.text = "0000-0000-0000-0000"
	game._on_menu_action("play code")
	assert_eq(game.menus.current, "enter_code")
	assert_eq(game.custom, "")
	assert_eq(Save.received, [])


func test_back_steps_out_of_the_drafting_sheets() -> void:
	game.drafting.show()
	game._on_menu_action("draft 1")
	assert_eq(game.menus.current, "editor")
	game.go_back()
	assert_eq(game.menus.current, "drafting")
	game._on_menu_action("enter code")
	game.go_back()
	assert_eq(game.menus.current, "drafting")
	game.go_back()
	assert_eq(game.menus.current, "main")
