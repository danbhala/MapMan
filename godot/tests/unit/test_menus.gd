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
	Save.new_lessons = false
	_wardrobe([])
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	game.menus.close()
	_actions.clear()
	game.menus.action.connect(func(name: String): _actions.append(name))


func after_each() -> void:
	Save.reduce_motion = false
	Save.fx_on = true
	Save.set_locale("")  # pressing every language button leaves the last one on
	_wardrobe([])


## Pins the wardrobe: `released` in it, all seen but those in `fresh`, and
## `worn` on.
func _wardrobe(released: Array, worn := "classic", fresh: Array = []) -> void:
	Save.released.assign(released)
	Save.seen.assign(released.filter(func(id: String) -> bool: return id not in fresh))
	Save.worn = worn


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


## Every Label's text on the open sheet.
func _texts() -> Array[String]:
	var out: Array[String] = []
	for l in game.menus._panel.find_children("*", "Label", true, false):
		out.append(l.text)
	return out


## The screen reader names of the open sheet's buttons.
func _a11y_names() -> Array[String]:
	var out: Array[String] = []
	for b in game.menus._panel.find_children("*", "Button", true, false):
		out.append(b.accessibility_name)
	return out


func test_main_menu() -> void:
	# The wardrobe's row sits under MapMan, level with the last rows.
	game.menus.show_main(0, false)
	assert_eq(_press_all(), ["play from start", "practice", "tutorial", "wardrobe", "options"])
	game.menus.show_main(10, true)
	assert_eq(
		_press_all(),
		[
			"play from start",
			"restart from checkpoint",
			"practice",
			"tutorial",
			"wardrobe",
			"options"
		]
	)


func test_first_run() -> void:
	game.menus.show_first_play()
	assert_eq(_press_all(), ["take tutorial", "play game", "main menu"])


func test_options_toggle_the_current_state() -> void:
	game.menus.show_options()
	assert_eq(
		_press_all(),
		[
			"music off",
			"fx on",
			"vibration off",
			"reduce motion off",
			"tilt gauge off",
			"language",
			"main menu"
		]
	)


func test_language_sheet_lists_every_language() -> void:
	game.menus.show_language()
	var expected: Array[String] = ["language system"]
	for entry in Menus.LANGUAGES:
		expected.append("language " + entry[0])
	expected.append("options")
	assert_eq(_press_all(), expected)


func test_picking_a_language_saves_it_and_stays_on_the_sheet() -> void:
	game._on_menu_action("language es")
	assert_eq(Save.locale, "es")
	assert_eq(TranslationServer.get_locale(), "es")
	assert_eq(game.menus.current, "language")
	game._on_menu_action("language system")
	assert_eq(Save.locale, "", "back to the phone's language")
	var phone := TranslationServer.standardize_locale(OS.get_locale())
	assert_eq(TranslationServer.get_locale(), phone)
	game.go_back()
	assert_eq(game.menus.current, "options", "back goes to the options sheet")


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


func test_level_clear_buttons() -> void:
	game.menus.show_end_level(100, 10, 7, 2, false, 35, 14)
	assert_eq(_press_all(), ["next level", "clear wardrobe", "leave clear"])


func test_a_tap_mid_count_finishes_it_and_stays() -> void:
	Save.reduce_motion = false
	var m = game.menus
	m.show_end_level(100, 10, 7, 2, false, 35, 14)
	var buttons: Array = m._panel.find_children("*", "Button", true, false)
	for b in buttons:
		assert_eq(b.mouse_filter, Control.MOUSE_FILTER_IGNORE, "out of reach mid-count")
	assert_has(_texts(), "100", "the total starts from the score")
	assert_has(_texts(), "+0", "and each row from nothing")
	_tap()
	assert_eq(_actions, [], "the first tap doesn't leave")
	assert_eq(m.current, "end_level")
	assert_has(_texts(), "119", "it's all in")
	assert_has(_texts(), "PASSED")
	buttons = m._panel.find_children("*", "Button", true, false)
	for b in buttons:
		assert_eq(b.mouse_filter, Control.MOUSE_FILTER_STOP, "and the buttons work")
	_tap()
	assert_eq(_actions, ["next level"], "the next tap goes on")


func test_wardrobe_from_the_level_clear() -> void:
	game.menus.show_wardrobe(7)
	var rows: Array = game.menus._panel.find_children("*", "Button", true, false)
	assert_eq(rows.back().text, "<  RETURN TO SHEET 007")
	assert_eq(_press_all().back(), "back to clear", "the wardrobe goes back to the level clear")
	game.menus.show_confirm_quit("back to clear")
	assert_eq(_press_all(), ["back to clear", "end game"])


func test_tapping_mapman_makes_him_jump() -> void:
	Save.reduce_motion = false
	var m = game.menus
	m.show_end_level(100, 10, 7, 2, false, 35, 14)
	var head: Vector2 = m._hero.global_position + Vector2(0, -60)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = head
	m._gui_input(press)
	assert_gt(m._hero._jump, 0.0, "he jumps")
	m._tap_ready_at = 0.0
	m._tap_action = "next level"
	var release := press.duplicate()
	release.pressed = false
	m._gui_input(release)
	assert_eq(_actions, [], "and the tap on him doesn't continue the sheet")
	press.position = Vector2(60, 340)
	m._gui_input(press)
	release.position = press.position
	m._gui_input(release)
	assert_eq(_actions, ["next level"], "a tap elsewhere still does")


func test_tap_to_continue_sheets() -> void:
	game.menus.show_end_level(100, 10, 7, 2, false, 35, 14)
	_tap()
	assert_eq(_actions, ["next level"])
	game.menus.show_game_complete(1842, 100, 100)
	_tap()
	assert_eq(_actions, ["next level", "completion done"])


# --- the wardrobe (docs/wardrobe) ----------------------------------------------------


func test_wardrobe_wears_released_looks_and_returns() -> void:
	_wardrobe(["party_hat", "signal_red", "cowboy"], "cowboy")
	game.menus.show_wardrobe()
	var buttons: Array = game.menus._panel.find_children("*", "Button", true, false)
	var locked := buttons.filter(func(b: Button) -> bool: return b.disabled)
	assert_eq(locked.size(), Wardrobe.LOOKS.size() - 4, "every look still locked is disabled")
	for b: Button in locked:
		assert_eq(b.focus_mode, Control.FOCUS_NONE, "and out of the focus order")
	assert_eq(
		_press_all(),
		["wear classic", "wear party_hat", "wear signal_red", "wear cowboy", "main menu"]
	)


func test_wardrobe_for_screen_readers() -> void:
	Save.set_locale("en")
	_wardrobe(["party_hat", "cowboy"], "cowboy")
	game.menus.show_wardrobe()
	var names := _a11y_names()
	assert_has(names, "Classic")
	assert_has(names, "Party hat, Common")
	assert_has(names, "Cowboy, worn")
	assert_has(names, "Locked, released at level 10", "its name stays a secret")
	assert_has(names, "Locked, released for finishing the game")
	var focus: Button = game.menus._first_button
	assert_eq(focus.accessibility_name, "Cowboy, worn", "the focus starts on the worn look")


func test_a_tap_on_a_look_wears_it() -> void:
	_wardrobe(["party_hat"])
	game._on_menu_action("wardrobe")
	game._on_menu_action("wear party_hat")
	assert_eq(Save.worn, "party_hat")
	assert_eq(game.menus.current, "wardrobe", "the sheet stays up")
	assert_eq(game.menus._hero.outfit, "party_hat", "and he has it on")
	game._on_menu_action("wear gold")
	assert_eq(Save.worn, "party_hat", "a look still locked stays in the wardrobe")


func test_every_hero_wears_the_worn_look() -> void:
	_wardrobe(["shades"], "shades")
	var m = game.menus
	var sheets := [
		func(): m.show_main(0, false),
		func(): m.show_first_play(),
		func(): m.show_options(),
		func(): m.show_pause(false, 35, 12),
		func(): m.show_confirm_quit(),
		func(): m.show_lose_life(2, 35),
		func(): m.show_game_over(100, true, false, 90),
		func(): m.show_restart([10]),
		func(): m.show_end_level(100, 10, 7, 2, false, 35, 14),
		func(): m.show_congratulations(2042, true),
		func(): m.show_game_complete(1842, 100, 100),
		func(): m.show_wardrobe(),
	]
	for open_sheet in sheets:
		open_sheet.call()
		assert_eq(m._hero.outfit, "shades", m.current)


func test_the_dimension_line_measures_the_worn_look() -> void:
	assert_almost_eq(Player.standing_height("classic"), Menus.HERO_HEIGHT, 0.01, "as before")
	game.menus.show_main(0, false)
	assert_has(_texts(), "92")
	_wardrobe(["party_hat"], "party_hat")
	game.menus.show_main(0, false)
	var height := roundi(Player.standing_height("party_hat") * Menus.HERO_SCALE)
	assert_gt(height, 92, "a hat makes him taller")
	assert_has(_texts(), str(height))


## Where the stamp that says `text` sits on the open sheet.
func _stamp_at(text: String) -> Vector2:
	for l in game.menus._panel.find_children("*", "Label", true, false):
		if l.text == text:
			return l.get_parent().position
	return Vector2.INF


func test_a_stamp_over_his_head_clears_his_hat() -> void:
	Save.set_locale("en")
	game.menus.show_end_level(100, 10, 7, 2, false, 35, 14)
	assert_eq(_stamp_at("PASSED").y, 90.0, "where it always was over Classic")
	_wardrobe(["party_hat"], "party_hat")
	game.menus.show_end_level(100, 10, 7, 2, false, 35, 14)
	var height := Player.standing_height("party_hat") + Player.FEET_LIFT
	var top := Menus.HERO_POS.y - height * Menus.HERO_SCALE
	assert_lte(_stamp_at("PASSED").y + Menus.STAMP_DEPTH, top, "above the party hat")


func test_wearing_mapwoman_she_is_the_hero_at_the_end() -> void:
	_wardrobe(["shades", "mapwoman"], "shades")
	var m = game.menus
	m.show_congratulations(2042, false)
	assert_eq(m._hero.outfit, "shades", "MapMan in his look")
	assert_eq(m._woman.art, "woman", "with MapWoman")
	Save.worn = "mapwoman"
	var sheets := [
		func(): m.show_congratulations(2042, false),
		func(): m.show_game_complete(1842, 100, 100),
	]
	for open_sheet in sheets:
		open_sheet.call()
		assert_eq(m._hero.outfit, "mapwoman", "she is the hero")
		assert_eq(m._woman.art, "man", "MapMan stands with her")
		assert_eq(m._woman.outfit, "classic", "as he is")
		assert_lt(m._hero.position.x, m._woman.position.x, "where the hero stands")
		assert_eq(m._woman.flip, -1.0, "facing her")


func test_new_until_the_wardrobe_has_been_seen() -> void:
	Save.set_locale("en")
	_wardrobe(["party_hat", "signal_red"], "classic", ["signal_red"])
	game.show_start_menu()
	assert_has(_texts(), "3/22", "Classic and the two released")
	assert_has(_texts(), "NEW", "one not seen yet")
	assert_has(_a11y_names(), "Wardrobe, 3 of 22 released")
	game._on_menu_action("wardrobe")
	var dots: Array = game.menus._panel.find_children("*", "Polygon2D", true, false)
	assert_eq(dots.size(), 1, "the new one is marked on the sheet")
	game._on_menu_action("wear party_hat")
	dots = game.menus._panel.find_children("*", "Polygon2D", true, false)
	assert_eq(dots.size(), 1, "still marked after a tap redraws the sheet")
	game._on_menu_action("main menu")
	assert_eq(Save.unseen(), 0, "seen once the sheet is left")
	assert_does_not_have(_texts(), "NEW")


func test_release_slips() -> void:
	Save.set_locale("en")
	var m = game.menus
	m.show_end_level(100, 10, 7, 2, false, 35, 14)
	assert_does_not_have(_texts(), "NEW IN THE WARDROBE", "no slip without a release")
	m.show_end_level(100, 10, 7, 2, false, 35, 14, false, "cowboy")
	assert_has(_texts(), "NEW IN THE WARDROBE")
	assert_has(_texts(), "COWBOY")
	assert_has(_texts(), "UNCOMMON")
	var acts := ["next level", "clear wardrobe", "leave clear", "wear cowboy"]
	assert_eq(_press_all(), acts, "WEAR IT on the slip")
	m.show_end_level(100, 10, 7, 2, false, 35, 14, false, "cowboy")
	_actions.clear()
	_tap()
	assert_eq(_actions, ["next level"], "the sheet still taps through")
	m.show_congratulations(2042, true, "mapwoman")
	assert_has(_texts(), "MAPWOMAN JOINS THE WARDROBE")
	assert_eq(_press_all(), ["main menu"], "the slip has nothing to press")
