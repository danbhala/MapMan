extends GutTest
## Vibration: each sound effect has a buzz, independent of the fx setting,
## and the options menu turns it on and off.

const MAIN_SCENE := preload("res://scenes/main.tscn")


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false


func before_each() -> void:
	Save.vibration_on = true
	Save.fx_on = true
	Haptics.last = []


func after_all() -> void:
	Save.vibration_on = true
	Save.fx_on = true


func test_every_effect_has_a_buzz() -> void:
	for name in Audio.SFX:
		assert_true(Haptics.PATTERNS.has(name), name)


func test_harder_hits_buzz_longer() -> void:
	assert_lt(Haptics.PATTERNS.step[0], Haptics.PATTERNS.sticky[0])
	assert_lt(Haptics.PATTERNS.sticky[0], Haptics.PATTERNS.lose_life[0])


func test_effects_buzz() -> void:
	Audio.play("sticky")
	assert_eq(Haptics.last, ["sticky", 80, 0.8])
	Audio.play_step()
	assert_eq(Haptics.last[0], "step")


func test_buzz_even_with_sound_effects_off() -> void:
	Save.fx_on = false
	Audio.play("lose_life")
	assert_eq(Haptics.last[0], "lose_life")


func test_no_buzz_when_turned_off() -> void:
	Save.vibration_on = false
	Audio.play("lose_life")
	assert_eq(Haptics.last, [])


func test_options_menu_turns_vibration_off_and_on() -> void:
	var game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	game._on_menu_action("options")
	game._on_menu_action("vibration off")
	assert_false(Save.vibration_on)
	assert_eq(game.menus.current, "options", "stays on the options screen")
	assert_eq(Haptics.last, [], "no buzz when turning it off")
	game._on_menu_action("vibration on")
	assert_true(Save.vibration_on)
	assert_eq(Haptics.last[0], "toggle", "a buzz to show it's on")
