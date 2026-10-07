extends GutTest
## A drafting table level's card: tapping a level opens it, it plays, edits,
## remixes, renames and deletes the level, and keeps the level's own record
## (tries, wins, best time and best-run ghost) by its code.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false


func before_each() -> void:
	Save.furthest_level = 11
	Save.ghost_on = true
	Save.drafts.clear()
	Save.received.clear()
	Save.received_names.clear()
	Save.level_stats.clear()
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)


func after_all() -> void:
	Save.furthest_level = 1
	Save.drafts.clear()
	Save.received.clear()
	Save.received_names.clear()
	Save.level_stats.clear()


## A start tile, `length` path tiles and an exit to the east, in row `row`.
func _corridor(slot := 0, length := 2, row := 3) -> Draft:
	var d := Draft.new(slot)
	d.begin_stroke()
	d.paint(Vector2i(2, row), "b")
	for x in length:
		d.paint(Vector2i(3 + x, row), "c")
	d.paint(Vector2i(3 + length, row), "e")
	return d


func _loaded() -> void:
	game.map._load_elapsed = game.map._load_time
	game.loaded()


## Walk right until the exit.
func _win(steps := 3) -> void:
	for i in steps:
		game._tries.tick(game.map, 0.4)
		game.move(Vector2i.RIGHT, 0.01)
		game.map.update_move(1.0)
		game.update_player(0.0)


func _on_sheet(text: String) -> bool:
	for b in game.menus._panel.find_children("*", "Button", true, false):
		if text in (b as Button).text:
			return true
	return false


func _received(code: String) -> void:
	Save.receive(code)
	game.drafting.show()


func test_a_drawn_draft_opens_its_card_and_an_empty_one_the_editor() -> void:
	var d := _corridor(1)
	d.signed = true
	Save.store_draft(d)
	game.drafting.show()
	game._on_menu_action("draft 0")
	assert_eq(game.menus.current, "editor", "nothing drawn yet")
	game.go_back()
	game._on_menu_action("draft 1")
	assert_eq(game.menus.current, "card")
	assert_true(_on_sheet("PLAY") and _on_sheet("EDIT") and _on_sheet("DELETE"))
	game._on_menu_action("card edit")
	assert_eq(game.menus.current, "editor")
	game.go_back()
	assert_eq(game.menus.current, "card", "back from editing to its card")
	game.go_back()
	assert_eq(game.menus.current, "drafting")


func test_playing_from_the_card_keeps_a_record_and_comes_back() -> void:
	var code := _corridor().code()
	_received(code)
	game._on_menu_action("received 0")
	assert_eq(game.menus.current, "card")
	game._on_menu_action("card play")
	assert_eq(game.custom, "received")
	_loaded()
	_win()
	assert_eq(game.menus.current, "card", "back to the card")
	var s := Save.level_stat(code)
	assert_eq(s.played, 1)
	assert_eq(s.cleared, 1)
	assert_gt(s.best, 0)
	assert_ne(s.ghost, "", "its best run is kept")
	assert_true(_on_sheet("WATCH REPLAY"), "the try can be watched")
	assert_eq(Save.received, [LevelCode.pretty(code)], "it stays where it was")


func test_a_custom_level_walks_beside_its_own_ghost_only() -> void:
	var code := _corridor().code()
	_received(code)
	game.drafting.play_code(code, "card")
	_loaded()
	_win()
	game.drafting.play_code(code, "card")
	_loaded()
	assert_not_null(game._tries.ghost, "its own ghost")
	assert_not_null(game._tries.ghost.run)
	game.game_over(false)
	var other := _corridor(0, 4).code()
	game.drafting.play_code(other)
	_loaded()
	assert_true(game._tries.ghost == null or game._tries.ghost.run == null, "not the other's")


func test_the_card_replays_the_tries() -> void:
	var code := _corridor().code()
	_received(code)
	game._on_menu_action("received 0")
	game._on_menu_action("card play")
	_loaded()
	_win()
	game._on_menu_action("card replay")
	assert_not_null(game._tries.replay, "a replay plays")
	assert_false(game.menus.visible)
	game._end_replay()
	assert_true(game.menus.visible)
	assert_eq(game.menus.current, "card")


func test_deleting_a_received_level_forgets_it() -> void:
	var a := _corridor().code()
	var b := _corridor(0, 4).code()
	_received(a)
	_received(b)
	Save.name_received(a, "SNAKE")
	Save.level_tried(a)
	game._on_menu_action("received 1")
	game._on_menu_action("card delete")
	assert_eq(game.menus.current, "card_delete")
	game._on_menu_action("card")
	assert_eq(game.menus.current, "card", "KEEP IT")
	game._on_menu_action("card delete")
	game._on_menu_action("card delete yes")
	assert_eq(game.menus.current, "drafting")
	assert_eq(Save.received, [LevelCode.pretty(b)])
	assert_eq(Save.received_name(a), "")
	assert_eq(Save.level_stat(a).played, 0)


func test_deleting_a_draft_empties_its_slot() -> void:
	Save.store_draft(_corridor(2))
	game.drafting.show()
	game._on_menu_action("draft 2")
	game._on_menu_action("card delete")
	game._on_menu_action("card delete yes")
	assert_true(Save.all_drafts()[2].is_empty())
	assert_eq(game.menus.current, "drafting")


func test_renaming_keeps_a_tidy_name_on_the_phone() -> void:
	Save.store_draft(_corridor(0))
	var code := _corridor().code()
	_received(code)
	game._on_menu_action("draft 0")
	game._on_menu_action("card rename")
	assert_eq(game.menus.current, "card_rename")
	game.menus.code_input.text = "  my   spiral 😀 of utter doom  "
	game._on_menu_action("card rename save")
	assert_eq(game.menus.current, "card")
	assert_eq(Save.all_drafts()[0].name, "MY SPIRAL", "the box holds 16 characters")
	assert_eq(Draft.tidy_name("  my   spiral 😀 of utter doom  "), "MY SPIRAL OF UTT")
	game.go_back()
	game._on_menu_action("received 0")
	game._on_menu_action("card rename")
	game.menus.code_input.text = "skull alley"
	game._on_menu_action("card rename save")
	assert_eq(Save.received_name(code), "SKULL ALLEY")
	assert_false(LevelCode.link(code).contains("SKULL"), "the name never travels")


func test_editing_a_draft_starts_its_record_afresh() -> void:
	var d := _corridor(0)
	Save.store_draft(d)
	Save.level_tried(d.code())
	assert_eq(Save.level_stat(d.code()).played, 1)
	var old := d.code()
	d.begin_stroke()
	d.paint(Vector2i(2, 5), "c")
	Save.store_draft(d)
	assert_eq(Save.level_stat(old).played, 0, "the old map's record goes")
	assert_eq(Save.level_stat(d.code()).played, 0)


func test_remix_copies_a_friends_level_into_a_free_draft() -> void:
	Save.store_draft(_corridor(0))
	var code := _corridor(0, 3).code()
	_received(code)
	Save.name_received(code, "LONG ONE")
	game._on_menu_action("received 0")
	game._on_menu_action("card remix")
	assert_eq(game.menus.current, "editor")
	var d: Draft = Save.all_drafts()[1]
	assert_eq(d.name, "LONG ONE")
	assert_false(d.signed, "beat it again to share it")
	assert_eq(d.code(), code)


func test_remix_waits_for_a_free_draft() -> void:
	for i in Draft.SLOTS:
		Save.store_draft(_corridor(i))
	_received(_corridor(0, 3).code())
	game._on_menu_action("received 0")
	game._on_menu_action("card remix")
	assert_eq(game.menus.current, "card")


func test_twelve_received_levels_are_kept_and_named_ones_stay_longest() -> void:
	var codes: Array[String] = []
	for i in Draft.RECEIVED_KEPT + 1:
		codes.append(_corridor(0, 1 + i).code())
	for i in Draft.RECEIVED_KEPT:
		Save.receive(codes[i])
	Save.name_received(codes[0], "KEEPER")
	Save.receive(codes[Draft.RECEIVED_KEPT])
	assert_eq(Save.received.size(), Draft.RECEIVED_KEPT)
	assert_true(LevelCode.pretty(codes[0]) in Save.received, "the named oldest stays")
	assert_false(LevelCode.pretty(codes[1]) in Save.received, "the oldest unnamed goes")


func test_names_and_records_survive_the_save() -> void:
	var path := "user://test_level_card.cfg"
	var d := _corridor(0)
	d.name = "SPIRAL"
	Save.store_draft(d)
	var code := _corridor(0, 3).code()
	Save.receive(code)
	Save.name_received(code, "SKULL")
	Save.level_tried(code)
	Save.persist = true
	Save.save_all(path)
	Save.persist = false
	Save.drafts.clear()
	Save.received_names.clear()
	Save.level_stats.clear()
	Save.load_all(path)
	assert_eq(Save.all_drafts()[0].name, "SPIRAL")
	assert_eq(Save.received_name(code), "SKULL")
	assert_eq(Save.level_stat(code).played, 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
