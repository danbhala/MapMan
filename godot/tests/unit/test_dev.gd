extends GutTest
## Dev-build features: cheats, tilt tuning, the play log and level jumping.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false


func before_each() -> void:
	Dev.enabled = true
	Dev.tuning = Dev.DEFAULT_TUNING.duplicate()
	Dev.unlimited_time = false
	Dev.unlimited_lives = false
	Dev.playlog.clear()
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	game.levels = [
		{
			"number": 1,
			"rows": ["bcccccw"],
			"loading": null,
			"delay": 0.0,
			"x_hides": 25,
			"checkpoint": false,
			"message": ""
		},
		{
			"number": 2,
			"rows": ["bdcw"],
			"loading": null,
			"delay": 0.0,
			"x_hides": 25,
			"checkpoint": false,
			"message": ""
		},
	]
	game.menus.close()
	game.new_game(1)
	game.map._load_elapsed = game.map._load_time
	game.loaded()


func after_each() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "shake"]:
		Input.action_release(action)
	Dev.enabled = false
	Dev.tuning = Dev.DEFAULT_TUNING.duplicate()
	Dev.unlimited_time = false
	Dev.unlimited_lives = false
	Dev.playlog.clear()


func test_dev_panel_exists_only_in_dev_builds() -> void:
	assert_not_null(game.dev_panel, "dev build gets the panel")
	Dev.enabled = false
	var release = MAIN_SCENE.instantiate()
	add_child_autofree(release)
	assert_null(release.dev_panel, "release build has no panel")


func test_unlimited_time_stops_the_clock() -> void:
	Dev.unlimited_time = true
	var before: float = game._time_left
	game._update_timer(5.0)
	assert_eq(game._time_left, before)
	Dev.unlimited_time = false
	game._update_timer(5.0)
	assert_almost_eq(game._time_left, before - 5.0, 0.001)


func test_cheats_do_nothing_outside_dev_builds() -> void:
	Dev.unlimited_time = true
	Dev.enabled = false
	var before: float = game._time_left
	game._update_timer(5.0)
	assert_almost_eq(game._time_left, before - 5.0, 0.001)


func test_unlimited_lives_keeps_lives() -> void:
	Dev.unlimited_lives = true
	game.lose_life()
	game.finish_lose_life()
	assert_eq(game.lives, 3)


func test_tilt_threshold_decides_when_mapman_moves() -> void:
	Input.action_press("move_right")  # keys count as a 0.25 g tilt
	Dev.tuning.tilt_threshold = 0.3
	game.move_player(0.0)
	assert_false(game.map.moving, "0.25 g is below a 0.3 g threshold")
	Dev.tuning.tilt_threshold = 0.1
	game.move_player(0.0)
	assert_true(game.map.moving, "0.25 g is above a 0.1 g threshold")


func test_fast_threshold_decides_the_speed() -> void:
	Input.action_press("move_right")
	Dev.tuning.fast_threshold = 0.3
	game.move_player(0.0)
	assert_almost_eq(game.map._move_seconds, game.STOP_TIME, 0.001, "slow below 0.3 g")
	game.map.update_move(1.0)
	Dev.tuning.fast_threshold = 0.2
	game.move_player(0.0)
	assert_almost_eq(game.map._move_seconds, game.STOP_TIME * 0.5, 0.001, "fast above 0.2 g")


func _finish_move() -> void:
	game.map.update_move(1.0)
	game.update_player(0.0)


func test_keep_threshold_keeps_a_held_lean_moving() -> void:
	# 0.08 g is under the 0.1 start threshold but over the 0.07 keep one.
	game.steer(Vector2(0.08, 0), true)
	assert_false(game.map.moving, "a gentle lean doesn't start a move")
	game.steer(Vector2(0.15, 0), true)
	assert_true(game.map.moving, "a firm lean does")
	_finish_move()
	game.steer(Vector2(0.08, 0), true)
	assert_true(game.map.moving, "easing off a little keeps going")
	_finish_move()
	game.steer(Vector2(0.05, 0), true)
	assert_false(game.map.moving, "below the keep threshold stops")
	game.steer(Vector2(0.08, 0), true)
	assert_false(game.map.moving, "after stopping, it needs the start threshold again")


func test_keep_threshold_is_only_for_the_held_direction() -> void:
	game.steer(Vector2(0.15, 0), true)
	_finish_move()
	game.steer(Vector2(-0.08, 0), true)
	assert_false(game.map.moving, "the other way needs the start threshold")
	game.steer(Vector2(0, 0.08), true)
	assert_false(game.map.moving, "so does a new axis")


func test_keep_threshold_never_above_start() -> void:
	Dev.tuning.keep_threshold = 0.3
	game.steer(Vector2(0.15, 0), true)
	_finish_move()
	game.steer(Vector2(0.15, 0), true)
	assert_true(game.map.moving)


func test_unpause_recalibrates_tilt() -> void:
	Input.set_gravity(Vector3(0, -6.9, -6.9))
	game.tilt.calibrate()
	game.show_pause_menu()
	Input.set_gravity(Vector3(0, -9.81, 0))
	game._on_menu_action("unpause")
	assert_almost_eq(game.tilt._neutral, Vector3(0, -1, 0), Vector3.ONE * 0.001)
	Input.set_gravity(Vector3.ZERO)


func test_play_log_records_wins_deaths_and_timeouts() -> void:
	game.move(Vector2i.RIGHT, 0.1)
	game.map.update_move(1.0)
	game.lose_life("timeout")
	game.reset_all(false)
	game.lose_life()
	game.reset_all(false)
	game.advance_level(false)
	var row: Dictionary = Dev.playlog["1"]
	assert_eq(row.attempts, 3)
	assert_eq(row.timeouts, 1)
	assert_eq(row.deaths, 1)
	assert_eq(row.wins, 1)
	assert_eq(row.total_moves, 1, "one move before the first loss, none after")
	var exported = JSON.parse_string(Dev.playlog_text())
	assert_true(exported.has("levels") and exported.has("tuning"), "export has levels and tuning")


func test_go_to_level_and_skip_level() -> void:
	game.dev_go_to_level(2)
	assert_eq(game.level, 2)
	assert_eq(game.score, 0)
	game.dev_go_to_level(1)
	game.dev_skip_level()
	assert_eq(game.level, 2, "skip moves on without finishing")
	assert_eq(game.score, 0, "skipping scores nothing")
