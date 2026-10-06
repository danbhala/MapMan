extends GutTest
## A first-time player goes from TAP TO START straight into the tutorial,
## with SKIP back to the main menu; everyone else gets the main menu.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false


func before_each() -> void:
	_fresh_save()
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)


func after_all() -> void:
	Save.first_play = false


func _fresh_save() -> void:
	Save.first_play = true
	Save.has_completed = false
	Save.new_lessons = false
	Save.checkpoints.clear()
	Save.bests.clear()
	Save.furthest_level = 1
	Save.worn = "classic"
	Save.released.clear()
	Save.seen.clear()


func _skip_button() -> FirstRun:
	for c in game.hud.header.get_children():
		if c is FirstRun:
			return c
	return null


func test_a_new_player_gets_the_tutorial() -> void:
	assert_true(FirstRun.applies())


func test_players_who_have_played_get_the_menu() -> void:
	Save.first_play = false
	assert_false(FirstRun.applies(), "a game or the tutorial was started")
	_fresh_save()
	Save.furthest_level = 4
	assert_false(FirstRun.applies(), "levels reached in practice")
	_fresh_save()
	Save.bests[1] = {"time": 10, "stars": 1}
	assert_false(FirstRun.applies(), "a level cleared")
	_fresh_save()
	Save.has_completed = true
	assert_false(FirstRun.applies(), "the game finished")


func test_a_level_link_wins_over_the_tutorial() -> void:
	var link := LevelCode.link(LevelCode.encode(["bcdcw", "  p  "]))
	assert_false(FirstRun.applies(link), "the friend's level plays instead")


func test_starting_opens_the_first_lesson_once() -> void:
	FirstRun.start(game)
	assert_true(game.tutorial)
	assert_true(game.game_active)
	assert_eq(game.level, 1)
	assert_false(game.menus.visible, "no main menu over it")
	assert_false(Save.first_play, "next launch opens the main menu")
	assert_false(FirstRun.applies())
	for lesson in game.tutorial_levels:
		assert_false(lesson.get("rev_b", false), "no Revision B lesson yet")


func test_skip_ends_the_tutorial_on_the_main_menu() -> void:
	FirstRun.start(game)
	await get_tree().process_frame
	var skip := _skip_button()
	assert_not_null(skip)
	assert_true(skip.visible)
	skip.pressed.emit()
	assert_false(game.game_active)
	assert_eq(game.menus.current, "main")


func test_skip_hides_under_the_pause_and_goes_with_the_tutorial() -> void:
	FirstRun.start(game)
	await get_tree().process_frame
	var skip := _skip_button()
	game.show_pause_menu()
	await get_tree().process_frame
	assert_false(skip.visible, "the pause sheet has its own END TUTORIAL")
	game._on_menu_action("unpause")
	await get_tree().process_frame
	assert_true(skip.visible)
	game.tutorial = false  # the lessons ran on into level 1
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(_skip_button(), "the skip is gone")
