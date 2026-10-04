extends GutTest
## The assists: help a sheet earns by beating the player, tier by tier
## (main.gd ASSIST_*): pencil marks on hidden death tiles and the corner
## guard, the route sketch, and the offer to skip the sheet.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var game


func before_all() -> void:
	Save.persist = false  # never touch the player's real progress
	Dev.persist = false
	Dev.enabled = false


func after_each() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "shake"]:
		Input.action_release(action)


## A game of the given levels (each a list of rows), started on level 1.
func _start(level_rows: Array, loading = null) -> void:
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	var levels: Array = []
	for i in level_rows.size():
		(
			levels
			. append(
				{
					"number": i + 1,
					"rows": level_rows[i],
					"loading": loading if i == 0 else null,
					"delay": 0.0,
					"x_hides": 25,
					"checkpoint": false,
					"message": "",
				}
			)
		)
	game.levels = levels
	game.menus.close()
	game.new_game(1)
	game.map._load_elapsed = game.map._load_time  # skip the appear animation
	game.loaded()


## Lose `n` lives on the current level and start the next try.
func _lose(n: int) -> void:
	for i in n:
		game.lose_life()
		game.dead = false
		game.menus.close()
		game.reset_all(false)
	game.map._load_elapsed = game.map._load_time
	game.loaded()


func test_losses_count_per_level_in_the_main_game_only() -> void:
	_start([["bcccw"]])
	assert_eq(game.losses_here(), 0)
	_lose(2)
	assert_eq(game.losses_here(), 2, "two lives lost on level 1")
	assert_true(game.assists_on(game.ASSIST_MARKS))
	assert_false(game.assists_on(game.ASSIST_ROUTE))
	game.practice = true
	assert_eq(game.losses_here(), 0, "practice gets no help")
	game.practice = false
	game.level = 2
	assert_eq(game.losses_here(), 0, "another level starts fresh")


func test_clearing_the_level_forgets_its_losses() -> void:
	_start([["bcccw"], ["bcw"]])
	_lose(3)
	game.map.position_key = Vector2i(4, 0)
	game.advance_level(false)
	assert_false(game.losses.has(1), "a cleared level's losses are gone")


func test_pencil_marks_outline_the_hidden_death_tiles() -> void:
	# A death tile that starts hidden ("*" in the loading row) and one in view.
	_start([["b!dcw"]], ["a*bcd"])
	assert_eq(game.map.marked(), 0, "no help before two lives are lost")
	_lose(2)
	assert_eq(game.map.marked(), 1, "the hidden death tile is marked, the visible one not")
	game.map.position_key = Vector2i(3, 0)
	game.map.unhide_tiles()
	assert_eq(game.map.marked(), 0, "unhidden, it needs no mark")


func test_marks_leave_when_the_level_is_cleared() -> void:
	_start([["b!cw"], ["bcw"]], ["a*bc"])
	_lose(2)
	assert_eq(game.map.marked(), 1)
	game.map.position_key = Vector2i(3, 0)
	game.advance_level(false)
	game.next_level()
	game.map._load_elapsed = game.map._load_time
	game.loaded()
	assert_eq(game.level, 2)
	assert_eq(game.map.marked(), 0, "level 2 starts without marks")


func test_corner_guard_holds_a_death_step_until_rested() -> void:
	_start([["bdcw"]])
	_lose(2)
	# Just landed (reset_all counts as landing): the death step is held.
	game.steer(Vector2(1.0, 0.0), true)
	assert_false(game.map.moving, "a death step straight after landing is ignored")
	assert_eq(game.map.position_key, Vector2i(0, 0))
	# Rested long enough: it goes.
	game._landed_at = game._now() - Dev.t("guard_hold") - 0.01
	game.steer(Vector2(1.0, 0.0), true)
	assert_true(game.map.moving, "a held tilt still walks onto the death tile")


func test_corner_guard_lets_the_other_axis_move() -> void:
	# Tilted mostly right (into death) and a little down (onto a plain tile):
	# the guard turns the overshoot into the turn.
	_start([["bdcw", "cccc"]])
	_lose(2)
	game.steer(Vector2(1.0, 0.4), true)
	assert_true(game.map.moving)
	assert_eq(game.map._move_to, Vector2i(0, 1), "down, not into the death tile")


func test_no_guard_without_the_assists() -> void:
	_start([["bdcw"]])
	game.steer(Vector2(1.0, 0.0), true)
	assert_true(game.map.moving, "without help a death step is a death step")


func test_safe_route_avoids_death_and_time_loss_tiles() -> void:
	_start([["cccc", "btdw"]])
	var route: Array[Vector2i] = game.map.safe_route()
	assert_eq(route.size(), 6, "up, along the top row and down to the exit")
	assert_eq(route[0], Vector2i(0, 1))
	assert_eq(route[-1], Vector2i(3, 1))
	for key in route:
		assert_false(game.map.deaths.has(key), "no death tile on the route")
		assert_false(game.map.less_times.has(key), "no time-loss tile on the route")


func test_safe_route_takes_time_loss_tiles_when_it_must() -> void:
	_start([["btcw"]])
	assert_eq(game.map.safe_route().size(), 4)


func test_route_is_sketched_from_the_fourth_loss() -> void:
	_start([["bcccw"]])
	_lose(3)
	assert_null(game.map._route, "no sketch after three lives lost")
	_lose(1)
	assert_not_null(game.map._route, "the route sketch after four")
	assert_eq(game.map._route.points.size(), 5)


func test_lose_life_sheet_names_the_help() -> void:
	_start([["bcccw"]])
	assert_eq(game.assist_name(), "")
	_lose(2)
	assert_eq(game.assist_name(), "marks")
	_lose(2)
	assert_eq(game.assist_name(), "route")
	_lose(2)
	assert_eq(game.assist_name(), "skip")


func test_skip_needs_six_losses() -> void:
	Save.bests.clear()
	_start([["bcccw"], ["bcw"]])
	_lose(5)
	game._on_menu_action("skip sheet")
	assert_eq(game.level, 1, "five lives lost: no skip yet")
	_lose(1)
	game._on_menu_action("skip sheet")
	assert_eq(game.level, 2, "six lives lost: skipped to level 2")
	assert_eq(game.score, 0, "a skipped sheet scores nothing")
	assert_false(game.losses.has(1))
	assert_false(Save.bests.has(1), "no best is recorded for a skipped sheet")


func test_lose_life_sheet_offers_the_skip() -> void:
	_start([["bcccw"]])
	game.menus.show_lose_life(2, 1, "death", "skip")
	var buttons: Array = game.menus._panel.find_children("*", "Button", true, false)
	assert_eq(buttons.size(), 2, "try again and skip")
	game.menus.show_lose_life(2, 1, "death", "route")
	buttons = game.menus._panel.find_children("*", "Button", true, false)
	assert_eq(buttons.size(), 1, "no skip row below the sixth loss")
