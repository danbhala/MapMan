extends GutTest
## The ending after the last level (completion.py): the bonus map where
## MapWoman waits, the meeting, and the walk into the vortex.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const FRAME := 1.0 / 60.0

var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false


func after_each() -> void:
	Save.has_completed = false


func before_each() -> void:
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	game.levels = [
		{
			"number": 1,
			"rows": ["bw"],
			"loading": null,
			"delay": 0.0,
			"x_hides": 25,
			"checkpoint": false,
			"message": "",
		}
	]
	game.menus.close()
	game.new_game(1)
	# Finish the only level: on to the ending.
	game.end_of_level_points = 0
	game.next_level()
	game.map._load_elapsed = game.map._load_time


func _frame(delta := FRAME) -> void:
	game.move_player(delta)
	game.update_player(delta)


func test_last_level_leads_to_the_ending_map() -> void:
	assert_true(game.completed)
	assert_true(game.started(), "no clock: play starts once the map is in")
	assert_true(Save.has_completed, "finishing level 100 counts, like the original")
	_frame()
	assert_true(game._woman.visible, "MapWoman waits on the bottom path")
	assert_true(game._vortex.visible, "the vortex swirls on the exit")
	assert_eq(game._woman.position, game.map.tiles[Vector2i(4, 8)].position)
	assert_eq(game._vortex.position, game.map.ends[0].position)


func test_meeting_then_walking_into_the_vortex() -> void:
	# Put MapMan next to her on the bottom path.
	game.map.position_key = Vector2i(3, 8)
	_frame()
	assert_eq(game._ending_phase, game.EndingPhase.MEETING)
	assert_true(game._hearts.visible, "hearts float up when they meet")
	# Tilting does nothing while they stand facing each other.
	Input.action_press("move_left")
	_frame()
	Input.action_release("move_left")
	assert_false(game.map.moving)

	_frame(game.MEETING_SECONDS)
	assert_eq(game._ending_phase, game.EndingPhase.LEAVING)
	assert_false(game._hearts.visible)

	# They walk right on their own until MapMan reaches the vortex.
	var exit: Vector2i = game.map.ends[0].key
	var frames := 0
	while game.menus.current == "" and frames < 600:
		_frame()
		frames += 1
	assert_eq(game.map.position_key, exit, "MapMan walked to the exit")
	assert_false(game._woman.visible, "she steps into the vortex first")
	assert_false(game._vortex.visible)
	assert_eq(game.menus.current, "completion", "then the completion scoring")


func test_no_meeting_from_another_row() -> void:
	game.map.position_key = Vector2i(4, 4)
	_frame()
	assert_eq(game._ending_phase, game.EndingPhase.WAITING)


func test_ending_can_be_paused_and_quit() -> void:
	_frame()
	assert_true(game._can_pause())
	game.show_pause_menu()
	game._on_menu_action("end game")
	assert_false(game.completed)
	assert_false(game._woman.visible)
	assert_false(game._vortex.visible)
