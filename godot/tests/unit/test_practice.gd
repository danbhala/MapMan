extends GutTest
## Practice mode: play any level reached in the main game on its own, with
## no lives or score, and keep each level's best time left and stars.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false


func before_each() -> void:
	Save.furthest_level = 1
	Save.bests.clear()
	Save.highscore = 0
	Save.checkpoints.clear()
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	var level := {
		"number": 1,
		"rows": ["bpcw"],
		"loading": null,
		"delay": 0.0,
		"x_hides": 25,
		"checkpoint": false,
		"message": "",
	}
	game.levels = [level, level.duplicate(), level.duplicate()]


func after_all() -> void:
	Save.furthest_level = 1
	Save.bests.clear()


func _loaded() -> void:
	game.map._load_elapsed = game.map._load_time
	game.loaded()


## Walk right to the exit, picking up the points tile on the way.
func _win() -> void:
	for i in 3:
		game.move(Vector2i.RIGHT, 0.01)
		game.map.update_move(1.0)
		game.update_player(0.0)


func test_main_game_records_furthest_level_and_bests() -> void:
	game.menus.close()
	game.new_game(1)
	_loaded()
	_win()
	assert_eq(Save.bests[1].stars, 1)
	assert_gt(Save.bests[1].time, 0)
	game._on_menu_action("next level")
	assert_eq(Save.furthest_level, 2)


func test_practice_menu_opens_on_the_furthest_page() -> void:
	game.levels = []
	for i in 100:
		game.levels.append({"rows": ["bw"]})
	Save.furthest_level = 45
	game._on_menu_action("practice")
	assert_eq(game.menus.current, "practice")
	assert_eq(game._practice_page, 2, "levels 41-60")


func test_practice_plays_one_level_without_lives_or_score() -> void:
	Save.furthest_level = 2
	Save.highscore = 77
	game._on_menu_action("practice")
	game._on_menu_action("practice level 2")
	assert_true(game.practice)
	assert_eq(game.level, 2)
	_loaded()
	game.lose_life()
	game.finish_lose_life()
	assert_eq(game.lives, 3, "no life lost")
	assert_eq(game.menus.current, "", "straight back into the level")
	assert_false(game.dead)
	_loaded()
	_win()
	assert_eq(game.menus.current, "practice", "back to the grid after a win")
	assert_false(game.practice)
	assert_false(game.game_active)
	assert_eq(Save.highscore, 77, "practice never touches the high score")
	assert_eq(Save.bests[2].stars, 1, "but it does keep the level's best")
	assert_eq(Save.furthest_level, 2)


func test_bests_keep_the_best_of_each() -> void:
	assert_true(Save.record_best(5, 10, 0))
	assert_true(Save.record_best(5, 8, 2), "more stars is a new best")
	assert_false(Save.record_best(5, 9, 1), "neither beaten")
	assert_eq(Save.bests[5], {"time": 10, "stars": 2})


func test_locked_levels_cannot_be_played() -> void:
	Save.furthest_level = 2
	game._on_menu_action("practice")
	var buttons: Array = game.menus._panel.find_children("*", "Button", true, false)
	var open: Array = buttons.filter(func(b): return not b.disabled)
	var locked: Array = buttons.filter(func(b): return b.disabled)
	assert_eq(locked.size(), 1, "level 3 of 3 is locked")
	assert_eq(open.size(), 3, "levels 1-2 and main menu")


func test_ending_practice_from_pause_returns_to_the_grid() -> void:
	game._on_menu_action("practice")
	game._on_menu_action("practice level 1")
	_loaded()
	game.show_pause_menu()
	game._on_menu_action("confirm quit")
	game._on_menu_action("end game")
	assert_eq(game.menus.current, "practice")
	assert_false(game.game_active)


func test_back_from_practice_goes_to_main_menu() -> void:
	game._on_menu_action("practice")
	game.go_back()
	assert_eq(game.menus.current, "main")


func test_old_saves_count_checkpoints_as_reached() -> void:
	# A save from before practice mode: checkpoints, but no furthest level.
	var path := "user://test_old_save.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "checkpoints", {30: 500, 10: 120})
	cfg.save(path)
	Save.load_all(path)
	assert_eq(Save.furthest_level, 31, "a checkpoint restarts on the level after it")
	cfg.set_value("progress", "has_completed", true)
	cfg.save(path)
	Save.load_all(path)
	assert_eq(Save.furthest_level, 100, "finished the game: everything is open")
	cfg.set_value("progress", "furthest_level", 42)
	cfg.save(path)
	Save.load_all(path)
	assert_eq(Save.furthest_level, 42, "a saved furthest level wins")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Save.checkpoints.clear()
	Save.has_completed = false
	# The finished save released every look: leave the wardrobe as found.
	Save.released.clear()
	Save.seen.clear()
	Save.worn = "classic"


func test_practising_the_last_level_never_starts_the_ending() -> void:
	# The last level is also a checkpoint: neither may follow a practice win.
	game.levels[2]["checkpoint"] = true
	Save.furthest_level = 3
	game._on_menu_action("practice")
	game._on_menu_action("practice level 3")
	_loaded()
	_win()
	assert_eq(game.menus.current, "practice")
	assert_false(game.completed)
	assert_false(Save.has_completed)
	assert_true(Save.checkpoints.is_empty())


func test_timeout_in_practice_restarts_the_level() -> void:
	game._on_menu_action("practice")
	game._on_menu_action("practice level 1")
	_loaded()
	game._time_left = 0.0
	game._process(0.0)  # the main loop notices the clock ran out
	assert_true(game.dead, "time up")
	game.finish_lose_life()
	assert_true(game.practice)
	assert_eq(game.menus.current, "")
	assert_false(game.dead)


func test_dev_skip_level_ends_practice() -> void:
	Dev.enabled = true
	game.levels[0]["checkpoint"] = true
	game._on_menu_action("practice")
	game._on_menu_action("practice level 1")
	_loaded()
	DevPanel.skip_level(game)
	Dev.enabled = false
	assert_eq(game.menus.current, "practice")
	assert_true(Save.checkpoints.is_empty(), "no checkpoint saved")
	assert_eq(Save.furthest_level, 1, "nothing unlocked")


func test_practice_keeps_the_first_play_screen() -> void:
	Save.first_play = true
	game._on_menu_action("practice")
	game._on_menu_action("practice level 1")
	assert_true(Save.first_play)
	Save.first_play = false
