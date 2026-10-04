extends GutTest
## Every try at a level is kept as tile steps (RunRecord): the level clear's
## WATCH REPLAY plays them all back at once, and the best win of each level is
## saved to run beside the player as a ghost.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const STEP := RunRecord.STEP_SECONDS

var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false


func before_each() -> void:
	Save.reduce_motion = true
	Save.worn = "classic"
	Save.released.clear()
	Save.seen.clear()
	Save.ghosts.clear()
	Save.ghost_on = true
	Save.first_play = false
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	var levels := []
	for n in 10:
		# a death tile, the start, two plain tiles and the exit
		levels.append({"number": n + 1, "rows": ["dboow"], "checkpoint": false, "message": ""})
	game.levels = levels
	game.menus.close()


func after_each() -> void:
	Save.reduce_motion = false
	Save.ghosts.clear()
	Save.ghost_on = true
	Save.bests.clear()


## The level's tiles are in and its clock starts: a try begins.
func _start_try() -> void:
	game.map._load_elapsed = game.map._load_time
	game.loaded()


## One step, landed, `seconds` on the run clock after the last.
func _step(dir: Vector2i, wait := 0.5) -> void:
	game._run_clock += wait
	game.move(dir, STEP)
	game.map.update_move(STEP)


func _button(text: String) -> Button:
	for b in game.menus.find_children("*", "Button", true, false):
		if b.text == text:
			return b
	return null


func test_a_record_round_trips_through_its_save_text() -> void:
	var r := RunRecord.new()
	r.add_step(0.4, Vector2i.RIGHT, STEP)
	r.add_step(0.64, Vector2i.DOWN, STEP * 0.5)
	r.add_step(3.0, Vector2i.LEFT, STEP)
	r.finish(3.5, "win", 16.25)
	var back := RunRecord.decode(r.encode())
	assert_not_null(back)
	assert_eq(back.result, "win")
	assert_eq(back.steps, r.steps, "directions and speeds")
	for i in r.times.size():
		assert_almost_eq(back.times[i], r.times[i], 0.006)
	assert_almost_eq(back.end_time, 3.5, 0.006)
	assert_almost_eq(back.time_left, 16.25, 0.006)
	assert_lt(r.encode().length(), 20, "a few bytes a step")


func test_rubbish_is_not_a_record() -> void:
	assert_null(RunRecord.decode(""))
	assert_null(RunRecord.decode("not a run"))


func test_a_record_says_where_he_is() -> void:
	var r := RunRecord.new()
	r.add_step(1.0, Vector2i.RIGHT, STEP)
	r.add_step(2.0, Vector2i.UP, STEP * 0.5)
	var start := Vector2i(3, 3)
	assert_eq(r.at(start, 0.5).key, start, "standing at the start")
	var mid := r.at(start, 1.0 + STEP / 2.0)
	assert_true(mid.moving)
	assert_eq(mid.next, Vector2i(4, 3))
	assert_almost_eq(mid.share, 0.5, 0.001)
	var done := r.at(start, 5.0)
	assert_false(done.moving)
	assert_eq(done.key, Vector2i(4, 2), "after both steps")
	assert_eq(done.dir, Vector2i.UP, "facing the last way he went")
	assert_eq(r.end_key(start), Vector2i(4, 2))


func test_every_try_is_kept_and_the_clear_offers_a_replay() -> void:
	game.new_game(2)
	_start_try()
	_step(Vector2i.LEFT)
	game.lose_life("death")
	game.finish_lose_life()
	game._on_menu_action("try again")
	_start_try()
	_step(Vector2i.RIGHT)
	_step(Vector2i.RIGHT, 0.2)
	_step(Vector2i.RIGHT, 0.2)
	game.advance_level(false)
	assert_eq(game._tries.size(), 2, "the lost try and the win")
	assert_eq(game._tries[0].result, "death")
	assert_eq(game._tries[1].step_count(), 3)
	assert_true(game._tries[1].won())
	assert_eq(game.menus.current, "end_level")
	assert_not_null(_button("WATCH REPLAY"))


func test_a_new_level_starts_its_tries_afresh() -> void:
	game.new_game(2)
	_start_try()
	_step(Vector2i.LEFT)
	game.lose_life("death")
	game.level = 3
	game.load_level()
	game.reset_all()
	_start_try()
	assert_eq(game._tries.size(), 0, "level 2's tries are gone")


func test_the_replay_plays_and_comes_back_to_the_level_clear() -> void:
	game.new_game(2)
	_start_try()
	for i in 3:
		_step(Vector2i.RIGHT)
	game.advance_level(false)
	game._on_menu_action("replay")
	assert_not_null(game._replay, "the replay is on")
	assert_false(game.menus.visible, "over the level, not the sheet")
	assert_eq(game._replay.tries.size(), 1)
	game.go_back()
	assert_null(game._replay, "back ends it")
	assert_true(game.menus.visible)
	assert_eq(game.menus.current, "end_level", "on the same level clear")
	assert_eq(game.level, 2, "the level isn't banked yet")


func test_the_replay_ends_by_itself() -> void:
	game.new_game(2)
	_start_try()
	for i in 3:
		_step(Vector2i.RIGHT, 0.1)
	game.advance_level(false)
	game._on_menu_action("replay")
	var replay: Replay = game._replay
	game.map._load_elapsed = game.map._load_time
	for i in 40:
		replay._process(0.1)
	assert_null(game._replay, "over once the winner has stood at the exit")
	assert_eq(game.menus.current, "end_level")


func test_no_replay_without_a_win_on_this_level() -> void:
	game.new_game(2)
	_start_try()
	_step(Vector2i.LEFT)
	game.lose_life("death")
	assert_false(game._replayable())
	game._on_menu_action("replay")
	assert_null(game._replay)


func test_a_win_is_kept_as_the_level_ghost_and_runs_next_time() -> void:
	game.new_game(2)
	_start_try()
	for i in 3:
		_step(Vector2i.RIGHT)
	game.advance_level(false)
	assert_true(Save.ghosts.has(2), "the win is the level's ghost")
	game.new_game(2)
	_start_try()
	assert_not_null(game._ghost_run, "the ghost walks this try")
	game._run_clock = 0.6
	game._update_ghost(0.1)
	assert_true(game._ghost.visible)
	assert_almost_eq(game._ghost.modulate.a, game.GHOST_ALPHA, 0.001)


func test_the_ghost_can_be_turned_off() -> void:
	game.new_game(2)
	_start_try()
	for i in 3:
		_step(Vector2i.RIGHT)
	game.advance_level(false)
	game._on_menu_action("ghost off")
	assert_false(Save.ghost_on)
	assert_eq(game.menus.current, "options")
	game.new_game(2)
	_start_try()
	assert_null(game._ghost_run, "no ghost")


func test_only_a_better_win_replaces_the_ghost() -> void:
	var fast := RunRecord.new()
	fast.finish(3.0, "win", 15.0)
	var slow := RunRecord.new()
	slow.finish(6.0, "win", 12.0)
	assert_true(Save.record_ghost(4, slow))
	assert_true(Save.record_ghost(4, fast), "more time left")
	assert_false(Save.record_ghost(4, slow), "less time left")
	assert_almost_eq(RunRecord.decode(Save.ghosts[4]).time_left, 15.0, 0.006)
	var lost := RunRecord.new()
	lost.finish(1.0, "death")
	assert_false(Save.record_ghost(5, lost), "only wins")
