extends GutTest
## Every sheet's buttons report the action strings main.gd handles (the
## original game's strings), and the tap-to-continue sheets report theirs.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var game
var _actions: Array[String] = []


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false


func before_each() -> void:
	Save.reduce_motion = true  # sheets settle at once
	Save.music_on = true
	Save.fx_on = false
	Save.vibration_on = true
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	game.menus.close()
	_actions.clear()
	game.menus.action.connect(func(name: String): _actions.append(name))


func after_each() -> void:
	Save.reduce_motion = false
	Save.fx_on = true


## Press every enabled button on the open sheet, top to bottom, left to right.
func _press_all() -> Array[String]:
	_actions.clear()
	var buttons: Array = game.menus._panel.find_children("*", "Button", true, false)
	buttons.sort_custom(
		func(a: Control, b: Control) -> bool:
			var pa := a.global_position
			var pb := b.global_position
			return pa.y < pb.y if pa.y != pb.y else pa.x < pb.x
	)
	for b in buttons:
		if not b.disabled:
			b.pressed.emit()
	return _actions.duplicate()


func test_main_menu() -> void:
	game.menus.show_main(0, false)
	assert_eq(_press_all(), ["play from start", "practice", "tutorial", "options"])
	game.menus.show_main(10, true)
	assert_eq(
		_press_all(),
		["play from start", "restart from checkpoint", "practice", "tutorial", "options"]
	)


func test_first_run() -> void:
	game.menus.show_first_play()
	assert_eq(_press_all(), ["take tutorial", "play game", "main menu"])


func test_options_toggle_the_current_state() -> void:
	game.menus.show_options()
	assert_eq(
		_press_all(), ["music off", "fx on", "vibration off", "reduce motion off", "main menu"]
	)


func test_pause_and_confirm() -> void:
	game.menus.show_pause(false, 35, 12)
	assert_eq(_press_all(), ["unpause", "confirm quit"])
	game.menus.show_pause(true)
	assert_eq(_press_all(), ["unpause", "end tutorial"])
	game.menus.show_confirm_quit()
	assert_eq(_press_all(), ["unpause", "end game"])


func test_lose_life_and_game_over() -> void:
	game.menus.show_lose_life(2, 35)
	assert_eq(_press_all(), ["try again"])
	game.menus.show_game_over(100, true, false, 90)
	assert_eq(_press_all(), ["play from start", "main menu"])
	game.menus.show_game_over(100, false, true, 90)
	assert_eq(_press_all(), ["play from start", "restart from checkpoint", "main menu"])


func test_checkpoint_picker() -> void:
	game.menus.show_restart([10, 30])
	assert_eq(_press_all(), ["L10", "L30", "main menu"])


func test_practice_page() -> void:
	game.menus.show_practice(1, 25, {}, 100)
	var expected: Array[String] = []
	for level in range(21, 26):
		expected.append("practice level %d" % level)
	expected.append_array(["practice page 0", "practice page 2", "main menu"])
	assert_eq(_press_all(), expected)
	game.menus.show_practice(0, 3, {}, 3)
	assert_eq(
		_press_all(), ["practice level 1", "practice level 2", "practice level 3", "main menu"]
	)


func test_congratulations() -> void:
	game.menus.show_congratulations(2042, true)
	assert_eq(_press_all(), ["main menu"])


func _tap() -> void:
	game.menus._tap_ready_at = 0.0
	var event := InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	game.menus._unhandled_input(event)


func test_tap_to_continue_sheets() -> void:
	game.menus.show_end_level(100, 10, 7, 2, false, 35, 14)
	_tap()
	assert_eq(_actions, ["next level"])
	game.menus.show_game_complete(1842, 100, 100)
	_tap()
	assert_eq(_actions, ["next level", "completion done"])
