extends GutTest
## Between two levels of the main game: the level clear's buttons and its
## WEAR IT slip, and the ready sheet the next level waits behind.

const MAIN_SCENE := preload("res://scenes/main.tscn")

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
	Save.checkpoints.clear()
	Save.furthest_level = 1
	Save.first_play = false
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	var levels := []
	for n in 10:
		levels.append({"number": n + 1, "rows": ["bw"], "checkpoint": false, "message": ""})
	game.levels = levels
	game.menus.close()


func after_each() -> void:
	Save.reduce_motion = false
	Save.worn = "classic"
	Save.released.clear()
	Save.seen.clear()
	Save.checkpoints.clear()
	Save.furthest_level = 1


## Clear `level` of a fresh game: its level clear is up.
func _clear(level: int) -> void:
	game.new_game(level)
	game.map._load_elapsed = game.map._load_time
	game.loaded()
	game.advance_level(false)
	assert_eq(game.menus.current, "end_level")


func test_next_level_waits_on_the_ready_sheet() -> void:
	_clear(3)
	var points: int = game.end_of_level_points
	game._on_menu_action("next level")
	assert_eq(game.menus.current, "ready")
	assert_eq(game.level, 4)
	assert_eq(game.score, points, "the level's points are in")
	assert_eq(Save.furthest_level, 4, "the next level opens in practice")
	assert_false(game._timer_running, "the clock waits")
	game._on_menu_action("start level")
	assert_eq(game.menus.current, "")
	assert_eq(game._current_level_data().number, 4)
	game.map._load_elapsed = game.map._load_time
	game.loaded()
	assert_true(game._timer_running, "and runs once it is started")


func test_wardrobe_from_the_ready_sheet_comes_back_to_it() -> void:
	Save.released.assign(["party_hat"])
	_clear(3)
	game._on_menu_action("next level")
	game._on_menu_action("wardrobe")
	assert_eq(game.menus.current, "wardrobe")
	game._on_menu_action("wear party_hat")
	assert_eq(game.menus.current, "wardrobe", "a look tapped stays on the sheet")
	assert_eq(game.player.outfit, "party_hat", "he plays in it")
	game.go_back()
	assert_eq(game.menus.current, "ready", "back goes to the ready sheet")
	assert_eq(game.menus._hero.outfit, "party_hat")
	assert_true(game.game_active, "the game goes on")
	game._on_menu_action("wardrobe")
	game._on_menu_action("ready")
	assert_eq(game.menus.current, "ready", "so does the sheet's last row")


func test_main_menu_from_the_level_clear_asks_first() -> void:
	_clear(3)
	game._on_menu_action("leave clear")
	assert_eq(game.menus.current, "confirm_quit")
	game.go_back()
	assert_eq(game.menus.current, "ready", "no: on to the ready sheet")
	assert_eq(game.level, 4, "the level cleared still counts")
	game._on_menu_action("leave ready")
	assert_eq(game.menus.current, "confirm_quit")
	game._on_menu_action("end game")
	assert_eq(game.menus.current, "main")
	assert_false(game.game_active)
	assert_false(game._between)


func test_leaving_a_checkpoint_level_keeps_its_checkpoint() -> void:
	game.levels[2].checkpoint = true
	_clear(3)
	game._on_menu_action("leave clear")
	game._on_menu_action("end game")
	assert_true(Save.checkpoints.has(3), "continue from it later")


func test_back_on_the_ready_sheet_asks_before_quitting() -> void:
	_clear(3)
	game._on_menu_action("next level")
	game.go_back()
	assert_eq(game.menus.current, "confirm_quit")
	game.go_back()
	assert_eq(game.menus.current, "ready")


func test_wear_it_on_the_level_clear() -> void:
	_clear(5)
	assert_eq(Save.released, ["party_hat"] as Array[String])
	game._on_menu_action("wear party_hat")
	assert_eq(Save.worn, "party_hat")
	assert_eq(game.player.outfit, "party_hat")
	assert_eq(game.menus.current, "end_level", "still on the level clear")
	assert_eq(game.menus._hero.outfit, "party_hat", "he has it on there and then")
	var texts: Array[String] = []
	for l in game.menus._panel.find_children("*", "Label", true, false):
		texts.append(l.text)
	assert_has(texts, tr("WORN"), "the slip says so")
	var buttons: Array = game.menus._panel.find_children("*", "Button", true, false)
	assert_eq(buttons.size(), 2, "and WEAR IT is gone")


func test_the_last_level_goes_straight_to_the_end() -> void:
	_clear(10)
	game._on_menu_action("next level")
	assert_eq(game.menus.current, "", "no ready sheet before the bonus map")
	assert_true(game.completed)
