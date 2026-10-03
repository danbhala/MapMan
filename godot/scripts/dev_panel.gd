class_name DevPanel
extends CanvasLayer
## The dev-build overlay: a DEV button and build label in the corner, the dev
## menu (level select, cheats, tilt tuning, play log) and the live tilt gauge.
## Only created when Dev.enabled.

const PANEL_BG := Color(0.07, 0.07, 0.07, 0.92)
const FONT_SIZE := 13

var game  # main.gd
var _button: Button
var _build_label: Label
var _panel: Control
var _gauge: TiltGauge
var _level_box: SpinBox
var _toast: Label
var _playlog_label: Label
var _value_labels := {}


func _init(main) -> void:
	game = main
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	Hud.fonts()
	var theme := Theme.new()
	theme.default_font = Hud.sans
	theme.default_font_size = FONT_SIZE

	_button = Button.new()
	_button.text = "DEV"
	_button.theme = theme
	_button.focus_mode = Control.FOCUS_NONE
	_button.modulate.a = 0.7
	_button.pressed.connect(open)
	add_child(_button)

	_build_label = Hud.make_label(Hud.sans, 10, Color(1, 1, 1, 0.7))
	_build_label.text = Dev.build_label()
	_build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_build_label)

	_gauge = TiltGauge.new()
	_gauge.game = game
	add_child(_gauge)

	_panel = _build_panel(theme)
	_panel.visible = false
	add_child(_panel)

	_toast = Hud.make_label(Hud.sans, 14)
	_toast.visible = false
	add_child(_toast)

	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	_button.size = Vector2(40, 22)
	_button.position = Vector2(s.x - 48, 52)
	_build_label.size = Vector2(260, 14)
	_build_label.position = Vector2(s.x - 268, 76)
	_gauge.position = Vector2(8, 54)
	_panel.size = s
	_toast.position = Vector2(s.x * 0.5 - 60, s.y - 120)


func _process(_delta: float) -> void:
	_gauge.visible = Dev.show_tilt and game.game_active and not _panel.visible
	_gauge.queue_redraw()


func open() -> void:
	_level_box.value = clampi(game.level, 1, game.levels.size())
	_refresh_playlog()
	_panel.visible = true
	get_tree().paused = true


func close() -> void:
	_panel.visible = false
	get_tree().paused = false


func _toast_text(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	await get_tree().create_timer(1.5, true).timeout
	_toast.visible = false


# --- the menu ----------------------------------------------------------------


func _build_panel(theme: Theme) -> Control:
	var root := ColorRect.new()
	root.color = PANEL_BG
	root.theme = theme
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 16
	scroll.offset_right = -16
	scroll.offset_top = 8
	scroll.offset_bottom = -8
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	var head := HBoxContainer.new()
	head.add_child(_heading("MapMan dev menu  ·  " + Dev.build_label()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(_button_for("Close", close))
	box.add_child(head)

	# Levels
	box.add_child(_heading("Levels"))
	var row := HBoxContainer.new()
	row.add_child(_text("Level"))
	_level_box = SpinBox.new()
	_level_box.min_value = 1
	_level_box.max_value = game.levels.size()
	row.add_child(_level_box)
	row.add_child(_button_for("Play from here", _on_play_from_here))
	row.add_child(_button_for("Skip this level", _on_skip_level))
	box.add_child(row)

	# Cheats
	box.add_child(_heading("Cheats (dev builds only)"))
	row = HBoxContainer.new()
	row.add_child(_toggle("Unlimited time", Dev.unlimited_time, func(on): Dev.unlimited_time = on))
	row.add_child(
		_toggle("Unlimited lives", Dev.unlimited_lives, func(on): Dev.unlimited_lives = on)
	)
	row.add_child(_toggle("Tilt gauge", Dev.show_tilt, func(on): Dev.show_tilt = on))
	box.add_child(row)

	# Tilt tuning
	box.add_child(_heading("Tilt tuning (saved on this phone, applies to this app)"))
	box.add_child(_slider("tilt_threshold", "Tilt to start moving (g)", 0.02, 0.4, 0.01))
	box.add_child(_slider("keep_threshold", "Tilt to keep moving (g)", 0.02, 0.4, 0.01))
	box.add_child(_slider("fast_threshold", "Tilt for full speed (g)", 0.05, 0.8, 0.01))
	box.add_child(_slider("shake_threshold", "Shake to get unstuck (g)", 0.1, 2.0, 0.05))
	row = HBoxContainer.new()
	row.add_child(
		_toggle("Invert left/right", Dev.t("invert_x"), func(on): Dev.set_tuning("invert_x", on))
	)
	row.add_child(
		_toggle("Invert up/down", Dev.t("invert_y"), func(on): Dev.set_tuning("invert_y", on))
	)
	box.add_child(row)
	row = HBoxContainer.new()
	row.add_child(_button_for("Reset to defaults", _on_reset_tuning))
	row.add_child(_button_for("Copy tuning", _on_copy_tuning))
	box.add_child(row)

	# Play log
	box.add_child(_heading("Play log"))
	_playlog_label = _text("")
	box.add_child(_playlog_label)
	row = HBoxContainer.new()
	row.add_child(_button_for("Copy play log", _on_copy_playlog))
	row.add_child(_button_for("Clear play log", _on_clear_playlog))
	box.add_child(row)
	box.add_child(
		_text("Paste the log into a GitHub issue or chat; tools/playlog_report.py reads it.", true)
	)
	return root


func _on_play_from_here() -> void:
	close()
	game.dev_go_to_level(int(_level_box.value))


func _on_skip_level() -> void:
	close()
	game.dev_skip_level()


func _on_reset_tuning() -> void:
	Dev.reset_tuning()
	_sync_sliders()


func _on_copy_tuning() -> void:
	DisplayServer.clipboard_set(Dev.tuning_text())
	_toast_text("Tuning copied")


func _on_copy_playlog() -> void:
	DisplayServer.clipboard_set(Dev.playlog_text())
	_toast_text("Play log copied")


func _on_clear_playlog() -> void:
	Dev.clear_playlog()
	_refresh_playlog()


func _refresh_playlog() -> void:
	_playlog_label.text = Dev.playlog_summary()


func _sync_sliders() -> void:
	for key in _value_labels:
		var pair: Array = _value_labels[key]
		pair[0].set_value_no_signal(Dev.t(key))
		pair[1].text = "%.2f" % Dev.t(key)


func _heading(text: String) -> Label:
	var l := _text(text)
	l.add_theme_font_size_override("font_size", FONT_SIZE + 2)
	l.add_theme_color_override("font_color", Color("#71c0e2"))
	return l


func _text(text: String, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		# Wrapping labels need a width; only use inside the full-width column.
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _button_for(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b


func _toggle(text: String, on: bool, action: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(action)
	return c


func _slider(key: String, text: String, lo: float, hi: float, step: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := _text(text)
	name_label.custom_minimum_size = Vector2(190, 0)
	row.add_child(name_label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = Dev.t(key)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 28)
	row.add_child(s)
	var value_label := _text("%.2f" % Dev.t(key))
	value_label.custom_minimum_size = Vector2(44, 0)
	row.add_child(value_label)
	s.value_changed.connect(
		func(v):
			Dev.set_tuning(key, v)
			value_label.text = "%.2f" % v
	)
	_value_labels[key] = [s, value_label]
	return row


class TiltGauge:
	extends Control
	## Live view of the phone's tilt: the dot is the steering input, the inner
	## ring the start-moving threshold, the outer ring the full-speed threshold.
	const SIZE := Vector2(220, 112)
	const RADIUS := 44.0
	var game

	func _init() -> void:
		size = SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Hud.fonts()
		var c := Vector2(RADIUS + 6, RADIUS + 6)
		var fast: float = Dev.t("fast_threshold")
		var scale := RADIUS / maxf(fast * 1.5, 0.01)
		draw_circle(c, RADIUS, Color(0, 0, 0, 0.35))
		draw_arc(c, Dev.t("tilt_threshold") * scale, 0, TAU, 48, Color(1, 1, 1, 0.6), 1.0)
		draw_arc(c, fast * scale, 0, TAU, 48, Color(1, 0.8, 0.3, 0.8), 1.0)
		var v: Vector2 = game.tilt.get_vector()
		var p := c + (v * scale).limit_length(RADIUS)
		draw_circle(p, 5, Color.WHITE)
		var g := Input.get_gravity()
		var lines := [
			"steer %+.2f %+.2f" % [v.x, v.y],
			"gravity %+.1f %+.1f %+.1f" % [g.x, g.y, g.z],
			"shake %.2f g" % game.tilt.shake_strength(),
			(
				"start %.2f  keep %.2f  fast %.2f"
				% [Dev.t("tilt_threshold"), Dev.t("keep_threshold"), fast]
			),
		]
		var y := 16.0
		for line in lines:
			draw_string(Hud.sans, Vector2(RADIUS * 2 + 16, y), line, 0, -1, 11)
			y += 15.0
