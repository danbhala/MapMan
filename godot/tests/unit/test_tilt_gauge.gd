extends GutTest
## The tilt gauge in the field's corner: when it shows, what its dot says, and
## tapping it to take the phone's current angle as level.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false


func before_each() -> void:
	Dev.enabled = false
	Dev.tuning = Dev.DEFAULT_TUNING.duplicate()
	Save.tilt_gauge = true
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	game.show_gauge_anyway = true
	game.levels = [
		{
			"number": 1,
			"rows": ["bcccccw"],
			"loading": null,
			"delay": 0.0,
			"x_hides": 25,
			"checkpoint": false,
			"message": ""
		},
	]
	game.menus.close()
	game.new_game(1)
	game.map._load_elapsed = game.map._load_time
	game.loaded()


func after_each() -> void:
	Save.tilt_gauge = true


func test_shows_while_playing() -> void:
	game._update_gauge(0.0)
	assert_true(game.gauge.visible)


func test_hidden_when_turned_off_in_options() -> void:
	Save.tilt_gauge = false
	game._update_gauge(0.0)
	assert_false(game.gauge.visible)


func test_hidden_without_a_tilt_to_show() -> void:
	game.show_gauge_anyway = false
	game._update_gauge(0.0)
	assert_eq(game.gauge.visible, TiltInput.has_accelerometer())


func test_hidden_behind_menus() -> void:
	game.show_pause_menu()
	game._update_gauge(0.0)
	assert_false(game.gauge.visible)


func test_pace_follows_the_thresholds() -> void:
	assert_eq(game.pace(Vector2(0.05, 0.0)), 0, "under the start tilt he stays put")
	assert_eq(game.pace(Vector2(0.0, -0.15)), 1, "past it he walks")
	assert_eq(game.pace(Vector2(-0.3, 0.1)), 2, "past the full-speed tilt he runs")


func test_pace_uses_keep_threshold_while_moving() -> void:
	game._held_step = Vector2i.RIGHT
	assert_eq(game.pace(Vector2(0.08, 0.0)), 1)


func test_sits_in_the_bottom_right_corner() -> void:
	var s: Vector2 = game.get_viewport_rect().size
	var c: Vector2 = game.gauge.centre()
	assert_gt(c.x, s.x * 0.85)
	assert_gt(c.y, s.y * 0.7)
	assert_lt(c.y + TiltGauge.RADIUS, s.y - Hud.BAR_HEIGHT - Blueprint.INSET)


func test_tap_recentres_and_never_pauses() -> void:
	game._update_gauge(0.0)
	game._calibrate_pending = false
	game._held_step = Vector2i.RIGHT
	watch_signals(game.gauge)
	for pressed in [true, false]:
		var tap := InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.pressed = pressed
		tap.position = game.gauge.size / 2.0
		game.gauge._gui_input(tap)
	assert_signal_emit_count(game.gauge, "recentre", 1)
	assert_eq(game._held_step, Vector2i.ZERO)
	assert_false(game.menus.visible, "the tap stays on the gauge")


func test_round_tap_target() -> void:
	var g: TiltGauge = game.gauge
	assert_true(g._has_point(g.size / 2.0))
	assert_false(g._has_point(Vector2.ZERO), "the square's corner is outside the dial")


func test_option_row_toggles_it() -> void:
	game._on_menu_action("tilt gauge off")
	assert_false(Save.tilt_gauge)
	game._on_menu_action("tilt gauge on")
	assert_true(Save.tilt_gauge)
