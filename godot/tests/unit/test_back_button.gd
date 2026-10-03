extends GutTest
## Android's back button steps out one level at a time instead of closing
## the app.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false


func before_each() -> void:
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	game.levels = [
		{
			"number": 1,
			"rows": ["bccw"],
			"loading": null,
			"delay": 0.0,
			"x_hides": 25,
			"checkpoint": false,
			"message": "",
		}
	]


func _play() -> void:
	game.menus.close()
	game.new_game(1)
	game.map._load_elapsed = game.map._load_time
	game.loaded()


func test_back_does_not_quit_the_app() -> void:
	assert_false(ProjectSettings.get_setting("application/config/quit_on_go_back"))


func test_back_while_playing_pauses() -> void:
	_play()
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(game.menus.current, "pause")
	assert_false(game._timer_running, "the clock stops")


func test_back_from_pause_resumes() -> void:
	_play()
	game.go_back()
	game.go_back()
	assert_eq(game.menus.current, "")
	assert_true(game.game_active)
	assert_true(game._timer_running)


func test_back_from_quit_question_resumes() -> void:
	_play()
	game.go_back()
	game._on_menu_action("confirm quit")
	assert_eq(game.menus.current, "confirm_quit")
	game.go_back()
	assert_eq(game.menus.current, "")
	assert_true(game.game_active, "back never ends the game")


func test_back_from_sub_menus_goes_to_main_menu() -> void:
	for act in ["options", "restart from checkpoint"]:
		game.show_start_menu()
		game._on_menu_action(act)
		assert_ne(game.menus.current, "main", act)
		game.go_back()
		assert_eq(game.menus.current, "main", act)


func test_back_from_game_over_goes_to_main_menu() -> void:
	_play()
	game.game_over()
	assert_eq(game.menus.current, "game_over")
	game.go_back()
	assert_eq(game.menus.current, "main")


func test_back_ignored_while_dying_and_on_tap_screens() -> void:
	_play()
	game.lose_life()
	game.go_back()
	assert_eq(game.menus.current, "", "the death animation plays out")
	game.finish_lose_life()
	assert_eq(game.menus.current, "lose_life")
	game.go_back()
	assert_eq(game.menus.current, "lose_life")
