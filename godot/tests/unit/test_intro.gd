extends GutTest
## The intro and title screen at launch: a tap skips to the title, the next
## one goes on to the main menu, and tests building Main never see it.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var intro: Intro


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false


func before_each() -> void:
	Save.worn = "classic"
	Save.reduce_motion = false
	intro = Intro.new()
	add_child_autofree(intro)


func after_each() -> void:
	Save.reduce_motion = false
	Save.set_locale("")


func test_it_plays_the_scene_first() -> void:
	await wait_frames(3)
	assert_eq(intro.state, "intro")
	assert_false(intro.player.is_hidden, "MapMan walks on")


func test_a_tap_skips_to_the_title_then_starts() -> void:
	await wait_frames(3)
	watch_signals(intro)
	intro.advance()
	assert_eq(intro.state, "title")
	assert_signal_not_emitted(intro, "finished")
	await wait_frames(3)
	assert_eq(intro.map.position_key, intro.map.ends[0].key, "on the exit arrow")
	for tile: LevelMap.Tile in intro.map.tiles.values():
		if not tile.blank:
			assert_true(tile.sprite.visible, "every tile shows on the title")
	intro.advance()
	assert_signal_emitted(intro, "finished")


func test_reduced_motion_opens_on_the_title() -> void:
	Save.reduce_motion = true
	var still := Intro.new()
	add_child_autofree(still)
	assert_eq(still.state, "title")


func test_the_title_fits_in_every_language() -> void:
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/catalog.json"))
	for locale in ["en"] + catalog.locales.keys():
		Save.set_locale(locale)
		var t := Intro.new()
		add_child_autofree(t)
		t.advance()
		var screen := t.get_viewport_rect().size
		for label in [t._title, t._tap]:
			var box := Rect2(label.position, label.size)
			assert_true(Rect2(Vector2.ZERO, screen).encloses(box), "%s fits" % locale)


func test_tests_building_main_skip_it() -> void:
	var game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	assert_null(game.intro)
	assert_true(game.menus.visible, "straight to the main menu")


func _click(pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	return e


func test_a_stray_release_or_an_early_tap_does_not_skip() -> void:
	await wait_frames(3)
	intro._unhandled_input(_click(false))
	assert_eq(intro.state, "intro", "a release without its press (a finger from the launcher)")
	intro._unhandled_input(_click(true))
	intro._unhandled_input(_click(false))
	assert_eq(intro.state, "intro", "too soon after launch")
	intro._born_ms -= Intro.INPUT_DELAY_MS
	intro._unhandled_input(_click(true))
	intro._unhandled_input(_click(false))
	assert_eq(intro.state, "title", "a whole tap skips")
