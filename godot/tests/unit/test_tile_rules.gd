extends GutTest
## Unit tests for each tile rule in main.gd's update_player(), on tiny
## hand-written levels so every rule is checked in isolation.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var game


func before_all() -> void:
	Save.persist = false  # never touch the player's real progress
	Dev.persist = false
	Dev.enabled = false


func after_each() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "shake"]:
		Input.action_release(action)


## A one-row level: the player starts on "b" (column 0) and walks right.
func _start(row: String, extra_rows: Array = [], loading = null) -> void:
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	var rows: Array = extra_rows.duplicate()
	rows.append(row)
	game.levels = [
		{
			"number": 1,
			"rows": rows,
			"loading": loading,
			"delay": 0.0,
			"x_hides": 25,
			"checkpoint": false,
			"message": "",
		}
	]
	game.menus.close()
	game.new_game(1)
	game.map._load_elapsed = game.map._load_time  # skip the appear animation
	game.loaded()


## Put MapMan on column x of the bottom row and apply that tile's rule.
func _step_on(x: int) -> void:
	var row: int = game.map.start_position.y
	game.map.position_key = Vector2i(x, row)
	game.update_player(0.0)


func test_level_starts_on_start_tile() -> void:
	_start("bcccw")
	assert_eq(game.map.position_key, Vector2i(0, 0))
	assert_true(game._timer_running, "clock starts once the level is loaded")


func test_reverse_tile_flips_controls_once() -> void:
	_start("brccw")
	_step_on(1)
	assert_true(game.reverse, "reverse tile flips controls")
	_step_on(1)
	assert_true(game.reverse, "a used reverse tile does nothing")


func test_reversed_controls_move_the_other_way() -> void:
	_start("cbcw")
	game.map.position_key = Vector2i(1, 0)
	game.reverse = true
	game.move(Vector2i.RIGHT, 0.1)
	assert_true(game.map.moving)
	game.map.update_move(1.0)
	assert_eq(game.map.position_key, Vector2i(0, 0), "right goes left when reversed")


func test_sticky_tile_holds_until_shaken() -> void:
	_start("bycw")
	_step_on(1)
	assert_true(game.stuck, "sticky tile sticks")
	Input.action_press("move_right")
	game.move_player(0.0)
	assert_false(game.map.moving, "can't move while stuck")
	Input.action_release("move_right")
	Input.action_press("shake")
	game.move_player(0.0)
	Input.action_release("shake")
	assert_false(game.stuck, "a shake frees MapMan")


func test_more_time_adds_five_seconds() -> void:
	_start("bmcw")
	var before: float = game._time_left
	_step_on(1)
	assert_almost_eq(game._time_left, before + 5.0, 0.001)


func test_less_time_removes_five_seconds() -> void:
	_start("btcw")
	var before: float = game._time_left
	_step_on(1)
	assert_almost_eq(game._time_left, before - 5.0, 0.001)


func test_points_tile_adds_a_star() -> void:
	_start("bpcw")
	_step_on(1)
	assert_eq(game.stars, 1)
	_step_on(1)
	assert_eq(game.stars, 1, "points are collected once")


func test_points_and_lives_stay_collected_after_a_death() -> void:
	_start("bplw")
	_step_on(1)
	_step_on(2)
	game.reset_all(false)
	assert_false(game.map.on(game.map.points), "points tile stays used")
	game.map.position_key = Vector2i(2, 0)
	assert_false(game.map.on(game.map.lives), "life tile stays used")
	assert_eq(game.stars, 1, "try again keeps collected stars")


func test_consumables_come_back_after_a_death() -> void:
	_start("bmtyw")
	_step_on(1)
	_step_on(2)
	_step_on(3)
	game.reset_all(false)
	for x in [1, 2, 3]:
		game.map.position_key = Vector2i(x, 0)
		var t: String = game.map.tiles[Vector2i(x, 0)].type
		var restored: bool = (
			game.map.on(game.map.more_times)
			or game.map.on(game.map.less_times)
			or game.map.on(game.map.stickies)
		)
		assert_true(restored, "%s tile restored" % t)


func test_life_tile_adds_a_life() -> void:
	_start("blcw")
	_step_on(1)
	assert_eq(game.lives, 4)


func test_death_tile_kills() -> void:
	_start("bdcw")
	_step_on(1)
	assert_true(game.dead)
	assert_false(game._timer_running, "clock stops on death")


func test_vanish_tile_hides_mapman_for_five_moves() -> void:
	_start("bvcccccccw")
	_step_on(1)
	assert_eq(game.vanish, 5)
	assert_true(game.player.is_hidden)
	game.move(Vector2i.RIGHT, 0.1)
	assert_eq(game.vanish, 4, "each move counts down")


func test_digit_tile_vanishes_for_that_many_moves() -> void:
	_start("b3cw")
	_step_on(1)
	assert_eq(game.vanish, 3)


func test_hide_and_unhide_tiles() -> void:
	_start("bhiuw")
	_step_on(1)
	assert_true(game.map.tiles_hidden, "hide tile hides")
	var hidden_tile = game.map.tiles[Vector2i(2, 0)]
	assert_false(hidden_tile.sprite.visible, "'i' tiles disappear")
	_step_on(3)
	assert_false(game.map.tiles_hidden, "unhide tile shows them again")
	assert_true(hidden_tile.sprite.visible, "'i' tiles come back")


func test_hidden_tiles_are_still_walkable() -> void:
	_start("bhiw")
	_step_on(1)
	game.move(Vector2i.RIGHT, 0.1)
	assert_true(game.map.moving, "can step onto an invisible tile")


func test_blank_cells_block_movement() -> void:
	_start("b-cw")
	game.move(Vector2i.RIGHT, 0.1)
	assert_false(game.map.moving)


func test_exit_scores_level_bonus_time_bonus_and_stars() -> void:
	_start("bpw")
	_step_on(1)
	game._time_left = 13.5  # shows 14 seconds -> time bonus 7
	_step_on(2)
	assert_eq(game.menus.current, "end_level")
	assert_eq(game.end_of_level_points, 10 + 7 + 1)


func test_running_out_of_time_costs_a_life() -> void:
	_start("bccw")
	game._time_left = 0.0
	game._process(0.0)
	assert_true(game.dead)


func test_start_hidden_tiles_appear_when_unhidden() -> void:
	# "*" in a loading row = hidden from the start (levels 4, 18, 57 ...).
	_start("bucpw", [], ["abc*d"])
	var tile = game.map.tiles[Vector2i(3, 0)]
	assert_false(tile.sprite.visible, "starts hidden")
	_step_on(1)
	assert_true(tile.sprite.visible, "unhide tile reveals it")
	assert_almost_eq(tile.sprite.scale.x, 1.0 / 3.0, 0.001, "at full size")


## Walk from column x one tile right, in one frame, applying the rules on the way.
func _walk_right_from(x: int) -> void:
	game.map.position_key = Vector2i(x, game.map.start_position.y)
	game.move(Vector2i.RIGHT, 0.1)
	game.update_player(0.0)  # the first moving frame: the tile left behind breaks
	game.map.update_move(1.0)
	game.update_player(0.0)  # landed


func test_crumble_tile_breaks_once_stepped_off() -> void:
	_start("bkcw")
	_walk_right_from(0)
	assert_true(game.map.on(game.map.crumbles), "a crumble tile holds while MapMan stands on it")
	_walk_right_from(1)
	assert_eq(game.map.position_key, Vector2i(2, 0))
	assert_true(game.map.broken.has(Vector2i(1, 0)), "stepping off breaks it")
	assert_false(game.map.crumbles[Vector2i(1, 0)], "it is used up")
	game.move(Vector2i.LEFT, 0.1)
	assert_false(game.map.moving, "a broken tile can't be stepped back onto")
	assert_eq(game.map.safe_route(), [] as Array[Vector2i], "a route never crosses the gap")


func test_crumble_tile_is_hidden_once_fallen() -> void:
	Save.reduce_motion = true  # skip the fall: the tile is gone at once
	_start("bkcw")
	_walk_right_from(0)
	_walk_right_from(1)
	var sprite: Sprite2D = game.map.tiles[Vector2i(1, 0)].sprite
	assert_false(sprite.visible, "the tile is gone from the sheet")
	_start("bhkuw")
	_step_on(1)
	game.map.crumble(Vector2i(2, 0))
	_step_on(3)
	assert_false(
		game.map.tiles[Vector2i(2, 0)].sprite.visible, "unhiding doesn't bring a broken tile back"
	)
	Save.reduce_motion = false


func test_crumble_tile_falls_then_goes() -> void:
	_start("bkcw")
	_walk_right_from(0)
	_walk_right_from(1)
	var tile = game.map.tiles[Vector2i(1, 0)]
	assert_true(tile.sprite.visible, "it is still falling")
	assert_true(game.map._falls.has(tile.key))
	game.map._falls[tile.key].custom_step(LevelMap.FALL_TIME + 0.1)
	assert_false(tile.sprite.visible, "and gone once it has fallen")


func test_crumble_tiles_come_back_after_a_death() -> void:
	_start("bkcw")
	_walk_right_from(0)
	_walk_right_from(1)
	game.reset_all(false)
	var tile = game.map.tiles[Vector2i(1, 0)]
	assert_true(game.map.broken.is_empty(), "nothing is broken on the next try")
	assert_true(game.map.crumbles[tile.key], "the crumble tile is whole again")
	assert_true(tile.sprite.visible, "and back on the sheet")
	assert_eq(tile.sprite.position, tile.position, "in its place")
	assert_almost_eq(tile.sprite.modulate.a, LevelMap.TILE_ALPHA, 0.001)


## Spikes: `^` is down for the first 55% of the beat, warns, then is up from 70%.
func _spike_time(phase: float) -> void:
	game.map.spike_time = phase * game.map.spike_cycle
	game.map.update_spikes(0.0)


func test_spikes_are_safe_while_down() -> void:
	_start("b^cw")
	_spike_time(0.2)
	_step_on(1)
	assert_false(game.dead, "down spikes are a plain tile")
	assert_eq(game.map.spike_state(Vector2i(1, 0)), 0)
	_spike_time(0.6)
	game.update_player(0.0)
	assert_false(game.dead, "the warning poke doesn't hurt")
	assert_eq(game.map.spike_state(Vector2i(1, 0)), 1)


func test_spikes_kill_while_up() -> void:
	_start("b^cw")
	_spike_time(0.8)
	_step_on(1)
	assert_true(game.dead, "stepping onto raised spikes kills")


func test_spikes_rising_underfoot_kill() -> void:
	_start("b^cw")
	_spike_time(0.5)
	_step_on(1)
	assert_false(game.dead)
	game.update_player(0.3 * game.map.spike_cycle)  # the beat moves on to 0.8: up
	assert_true(game.dead, "standing there as they rise kills")


func test_second_phase_spikes_run_half_a_beat_behind() -> void:
	_start("b%^w")
	_spike_time(0.3)
	assert_eq(game.map.spike_state(Vector2i(1, 0)), 2, "% is up when ^ is down")
	assert_eq(game.map.spike_state(Vector2i(2, 0)), 0)
	_step_on(2)
	assert_false(game.dead)
	_spike_time(0.8)
	assert_eq(game.map.spike_state(Vector2i(1, 0)), 0, "% is down when ^ is up")


func test_spike_tiles_redraw_with_the_beat() -> void:
	_start("b^cw")
	var sprite: Sprite2D = game.map.tiles[Vector2i(1, 0)].sprite
	var down := sprite.texture
	_spike_time(0.6)
	var warn := sprite.texture
	_spike_time(0.9)
	var up := sprite.texture
	assert_ne(down, warn, "the warning poke shows")
	assert_ne(warn, up, "raised spikes show")
	_spike_time(1.1)
	assert_eq(sprite.texture, down, "and they drop again next beat")


func test_spikes_restart_their_beat_after_a_death() -> void:
	_start("b^cw")
	_spike_time(0.9)
	game.reset_all(false)
	assert_eq(game.map.spike_time, 0.0)
	assert_eq(game.map.spike_state(Vector2i(1, 0)), 0, "down at the start of a try")
