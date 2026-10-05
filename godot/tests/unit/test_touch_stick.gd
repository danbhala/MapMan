extends GutTest
## The floating touch stick (Options "CONTROLS": DRAG TO MOVE) and the tilt
## sensitivity: where the stick appears, what a drag does, that a quick tap
## still pauses, and how each sensitivity reads the same tilt.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var game


func before_all() -> void:
	Save.persist = false
	Dev.persist = false


func before_each() -> void:
	Dev.enabled = false
	Dev.tuning = Dev.DEFAULT_TUNING.duplicate()
	Save.controls = "touch"
	Save.tilt_sensitivity = 1
	game = MAIN_SCENE.instantiate()
	add_child_autofree(game)
	game.show_gauge_anyway = true
	game.menus.close()
	# The tutorial: a tap pauses at any time there.
	game.new_game(1, true)
	game.map._load_elapsed = game.map._load_time
	game.loaded()


func after_each() -> void:
	Save.controls = "tilt"
	Save.tilt_sensitivity = 1


func _touch(pressed: bool, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	game._unhandled_input(e)


func _drag(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.position = pos
	game._unhandled_input(e)


func test_appears_where_the_finger_lands() -> void:
	_touch(true, Vector2(150, 200))
	game.steering.update()
	assert_true(game.steering.stick.held)
	assert_eq(game.steering.stick.origin, Vector2(150, 200))
	assert_eq(game.tilt.get_vector(), Vector2.ZERO, "a finger that hasn't moved steers nowhere")


func test_drag_walks_then_runs() -> void:
	var fast: float = Dev.t("fast_threshold")
	var start: float = Dev.t("tilt_threshold")
	var rim := TouchStick.RADIUS
	_touch(true, Vector2(150, 200))
	# The rings sit where the gauge's do: dashed at the start tilt, solid at full speed.
	_drag(Vector2(150 - rim * start / (fast * 1.5) - 2.0, 200))
	assert_eq(game.pace(game.tilt.get_vector()), 1, "past the dashed ring he walks")
	assert_lt(game.tilt.get_vector().x, 0.0, "to the left")
	_drag(Vector2(150, 200 + rim * 2.0))
	var v: Vector2 = game.tilt.get_vector()
	assert_almost_eq(v.y, fast * 1.5, 0.001, "the knob stops at the rim")
	assert_eq(game.pace(v), 2, "past the solid ring he runs")
	game.steering.update()
	assert_eq(game.steering.stick.pace, 2)


func test_quick_tap_pauses() -> void:
	_touch(true, Vector2(300, 200))
	_touch(false, Vector2(300, 200))
	assert_true(game.paused)
	assert_eq(game.menus.current, "pause")
	assert_false(game.tilt.stick_held())


func test_drag_does_not_pause() -> void:
	_touch(true, Vector2(300, 200))
	_drag(Vector2(330, 200))
	_touch(false, Vector2(330, 200))
	assert_false(game.paused)
	assert_eq(game.tilt.get_vector(), Vector2.ZERO, "letting go stops him")


func test_a_menu_lets_go_of_the_stick() -> void:
	_touch(true, Vector2(300, 200))
	_drag(Vector2(330, 200))
	game.show_pause_menu()
	game.steering.update()
	assert_false(game.tilt.stick_held())
	assert_false(game.steering.stick.held)


func test_no_gauge_while_steering_by_touch() -> void:
	game._update_gauge(0.0)
	assert_false(game.gauge.visible)
	Save.controls = "tilt"
	game.steering.apply()
	game._update_gauge(0.0)
	assert_true(game.gauge.visible)


func test_tutorial_teaches_the_stick() -> void:
	assert_string_contains(game.hud.tutorial_label.text, "drag")


func test_sensitivity_reads_the_same_tilt_differently() -> void:
	var tilt := TiltInput.new()
	var lean := Vector2(0.145, 0.0)  # about 8.3 degrees
	tilt.sensitivity = 1
	assert_eq(game.pace(tilt.sensitive(lean)), 1, "NORMAL walks")
	tilt.sensitivity = 0
	assert_eq(game.pace(tilt.sensitive(lean)), 0, "LOW stays put")
	tilt.sensitivity = 2
	assert_eq(game.pace(tilt.sensitive(lean)), 2, "HIGH runs")


func test_sensitivity_leaves_the_stick_alone() -> void:
	Save.tilt_sensitivity = 2
	game.steering.apply()
	_touch(true, Vector2(150, 200))
	_drag(Vector2(150 + TouchStick.RADIUS, 200))
	assert_almost_eq(game.tilt.get_vector().x, Dev.t("fast_threshold") * 1.5, 0.001)
