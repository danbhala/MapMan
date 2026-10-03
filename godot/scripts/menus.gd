class_name Menus
extends Control
## Full-screen menus drawn with the original menu art. Port of the parts of
## game_menus.py the playable core needs. Every button reports its action
## string (the same strings the original used) through the `action` signal.

signal action(name: String)

const BASE_BG := Color("#71c0e2")
const SCALE := 1.0 / 3.0  # menu art is @3x
const SPACE := 13.5  # space_x / space_y in points
const PANEL_SIZE := Vector2(1843, 1036)
const PANEL_H_PTS := 1036.0 / 3.0
## Practice grid: levels per page, as 5 columns of 4 rows.
const PRACTICE_PAGE := 20

var current := ""
var _panel: Control
var _first_button: Control
var _tap_action := ""
var _tap_ready_at := 0.0
var _tween: Tween
## Button art with its baked-in text wiped, for buttons the original lacked.
var _blank_buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_recentre)


func _bottom() -> float:
	return -PANEL_H_PTS * 0.35


func _top() -> float:
	return PANEL_H_PTS * 0.25


## Convert the original's point coordinates (origin at the panel centre, y up)
## and anchor into a top-left position in the panel's @3x pixel space.
func _place(node: Control, size_px: Vector2, pos_pts: Vector2, anchor: Vector2) -> void:
	node.position = Vector2(
		pos_pts.x * 3.0 - anchor.x * size_px.x, -pos_pts.y * 3.0 - (1.0 - anchor.y) * size_px.y
	)


func _recentre() -> void:
	if _panel:
		_panel.position = get_viewport_rect().size / 2.0


func close() -> void:
	if _tween:
		_tween.kill()
	for c in get_children():
		c.queue_free()
	_panel = null
	_first_button = null
	_tap_action = ""
	current = ""
	visible = false


func _open(tag: String, bg_name: String, fade := true) -> void:
	close()
	current = tag
	visible = true
	var bg := ColorRect.new()
	bg.color = BASE_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_panel = Control.new()
	_panel.scale = Vector2.ONE * SCALE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_recentre()

	var art := TextureRect.new()
	art.texture = load("res://assets/menu/%s.png" % bg_name)
	art.position = -PANEL_SIZE / 2.0
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(art)

	if fade:
		_panel.modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_property(_panel, "modulate:a", 1.0, 0.4)


func _button(
	tag: String, act: String, pos_pts: Vector2, anchor: Vector2, enabled := true
) -> TextureButton:
	var b := TextureButton.new()
	var normal: Texture2D = load("res://assets/buttons/%s.png" % tag)
	var on: Texture2D = load("res://assets/buttons/%s_on.png" % tag)
	b.texture_normal = normal
	b.texture_pressed = on
	b.texture_hover = on
	b.texture_focused = on
	b.size = normal.get_size()
	_place(b, normal.get_size(), pos_pts, anchor)
	if enabled:
		b.pressed.connect(func(): action.emit(act))
	else:
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
	_panel.add_child(b)
	if enabled and _first_button == null:
		_first_button = b
	return b


## A button in the original's style with our own text: the art of `tag` with
## its baked-in text wiped, and `text` drawn over it.
func _text_button(
	tag: String,
	text: String,
	act: String,
	pos_pts: Vector2,
	anchor: Vector2,
	size_pts := Vector2.ZERO
) -> TextureButton:
	var b := TextureButton.new()
	var normal := _blank_button(tag)
	var on := _blank_button(tag + "_on")
	b.texture_normal = normal
	b.texture_pressed = on
	b.texture_hover = on
	b.texture_focused = on
	var size_px := normal.get_size()
	if size_pts != Vector2.ZERO:  # stretch the art to a smaller button
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		size_px = size_pts * 3.0
	b.size = size_px
	_place(b, size_px, pos_pts, anchor)
	b.pressed.connect(func(): action.emit(act))
	_panel.add_child(b)
	Hud.fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Hud.mono)
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", Color.WHITE)
	# A thin outline in the same colour matches the art's heavier lettering.
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	if _first_button == null:
		_first_button = b
	return b


## Blend each row of the button from its left edge to its right edge, which
## keeps the art's soft gradient but drops the text in the middle.
func _blank_button(tag: String) -> Texture2D:
	if _blank_buttons.has(tag):
		return _blank_buttons[tag]
	var img: Image = load("res://assets/buttons/%s.png" % tag).get_image()
	img.decompress()
	var w := img.get_width()
	var margin := int(w * 0.12)
	for y in img.get_height():
		var left := img.get_pixel(margin, y)
		var right := img.get_pixel(w - 1 - margin, y)
		for x in range(margin, w - margin):
			var c := left.lerp(right, float(x - margin) / float(w - 1 - 2 * margin))
			c.a = img.get_pixel(x, y).a
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_blank_buttons[tag] = tex
	return tex


func _label(
	text: String,
	size_pts: float,
	color: Color,
	pos_pts: Vector2,
	anchor: Vector2,
	font: Font = null
) -> Label:
	Hud.fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font else Hud.mono)
	l.add_theme_font_size_override("font_size", int(size_pts * 3.0))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(l)
	var sz := l.get_minimum_size()
	l.size = sz
	_place(l, sz, pos_pts, anchor)
	return l


func _main_menu_button() -> void:
	var b := _button(
		"main_menu", "main menu", Vector2(0, _bottom() - SPACE / 2.0), Vector2(0.5, 1.0)
	)
	b.z_index = 1


func _two_buttons(
	lhs_tag: String, lhs_act: String, rhs_tag: String, rhs_act: String, rhs_enabled := true
) -> void:
	var y := _bottom() + SPACE
	var lw: float = load("res://assets/buttons/%s.png" % lhs_tag).get_width() / 3.0
	var rw: float = load("res://assets/buttons/%s.png" % rhs_tag).get_width() / 3.0
	_button(lhs_tag, lhs_act, Vector2(-lw / 2.0 - SPACE / 2.0, y), Vector2(0.5, 0.0))
	_button(rhs_tag, rhs_act, Vector2(rw / 2.0 + SPACE / 2.0, y), Vector2(0.5, 0.0), rhs_enabled)


func _focus_first() -> void:
	if _first_button:
		_first_button.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _tap_action == "":
		return
	if Time.get_ticks_msec() / 1000.0 < _tap_ready_at:
		return
	var tapped := event.is_action_pressed("ui_accept") or event.is_action_pressed("shake")
	if tapped:
		get_viewport().set_input_as_handled()
		action.emit(_tap_action)


func _gui_input(event: InputEvent) -> void:
	# Taps on the background (not on a button) for "tap to continue" menus.
	if _tap_action == "" or Time.get_ticks_msec() / 1000.0 < _tap_ready_at:
		return
	if (
		event is InputEventMouseButton
		and not event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		accept_event()
		action.emit(_tap_action)


func _tap_to(act: String, delay := 0.3) -> void:
	_tap_action = act
	_tap_ready_at = Time.get_ticks_msec() / 1000.0 + delay


# --- the menus -----------------------------------------------------------


func show_main(highscore: int, has_checkpoint: bool) -> void:
	_open("main", "welcome")
	var space_y := SPACE * 0.75
	var y := _bottom() + space_y
	# Options and practice share the bottom row; each is half its width.
	_button("options", "options", Vector2(-SPACE / 2.0, y), Vector2(1.0, 0.0))
	_text_button("options", "practice", "practice", Vector2(SPACE / 2.0, y), Vector2(0.0, 0.0))
	y += 119.0 / 3.0 + space_y
	_button("tutorial", "tutorial", Vector2(0, y), Vector2(0.5, 0.0))
	y += 119.0 / 3.0 + space_y
	var cp_tag := "restart_active" if has_checkpoint else "restart_inactive"
	_button(cp_tag, "restart from checkpoint", Vector2(0, y), Vector2(0.5, 0.0), has_checkpoint)
	y += 119.0 / 3.0 + space_y
	_button("play_from_start", "play from start", Vector2(0, y), Vector2(0.5, 0.0))
	_first_button = _panel.get_child(_panel.get_child_count() - 1)
	if highscore > 0:
		_label(
			"best score %d" % highscore,
			20,
			Color.WHITE,
			Vector2(0, _bottom() - SPACE * 1.2),
			Vector2(0.5, 1.0)
		)
	_focus_first()


func show_first_play() -> void:
	_open("first_play", "newbie")
	_two_buttons("take_tutorial", "take tutorial", "play_game", "play game")
	_main_menu_button()
	_focus_first()


func show_options() -> void:
	_open("options", "options")
	# The art has "playing position" printed on it; that setting is replaced
	# by automatic tilt calibration, so cover it with a heading of our own.
	var cover := ColorRect.new()
	cover.color = Color.WHITE
	cover.position = Vector2(-560, -150)
	cover.size = Vector2(1120, 110)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(cover)
	_label("sound and vibration", 16, Color.BLACK, Vector2(0, 50), Vector2(0.5, 0.5))

	# Three columns: music, sound effects, vibration (the last is ours).
	var bw := 359.0 / 3.0
	var bh := 110.0 / 3.0
	var x_left := -bw * 1.5 - SPACE
	var x_right := -bw * 0.5
	var x_vib := bw * 0.5 + SPACE
	var y := _bottom() + SPACE * 2.0
	var m_off := "options_musicoff" + ("" if Save.music_on else "_active")
	var m_on := "options_musicon" + ("_active" if Save.music_on else "")
	var f_off := "options_fxoff" + ("" if Save.fx_on else "_active")
	var f_on := "options_fxon" + ("_active" if Save.fx_on else "")
	_button(m_off, "music off", Vector2(x_left, y), Vector2.ZERO)
	_button(m_on, "music on", Vector2(x_left, y + bh + SPACE), Vector2.ZERO)
	_button(f_off, "fx off", Vector2(x_right, y), Vector2.ZERO)
	_button(f_on, "fx on", Vector2(x_right, y + bh + SPACE), Vector2.ZERO)
	# The fx buttons' art in the matching on/off state, with our own text.
	var v_off := "options_fxoff" + ("" if Save.vibration_on else "_active")
	var v_on := "options_fxon" + ("_active" if Save.vibration_on else "")
	_text_button(v_off, "vibrate off", "vibration off", Vector2(x_vib, y), Vector2.ZERO)
	_text_button(v_on, "vibrate on", "vibration on", Vector2(x_vib, y + bh + SPACE), Vector2.ZERO)
	_main_menu_button()
	_focus_first()


func show_pause(tutorial: bool) -> void:
	_open("pause", "paused_game")
	if tutorial:
		_two_buttons("paused_tutorial_return", "unpause", "paused_tutorial_end", "end tutorial")
	else:
		_two_buttons("paused_game_return", "unpause", "paused_game_end", "confirm quit")
	_focus_first()


func show_confirm_quit() -> void:
	_open("confirm_quit", "confirm_quit")
	_two_buttons("confirm_quit_yes", "end game", "confirm_quit_no", "unpause")
	_focus_first()


func show_lose_life(lives: int) -> void:
	_open("lose_life", "lose_life")
	_button("try_again", "try again", Vector2(0, _bottom() + SPACE), Vector2(0.5, 0.0))
	_label(str(lives), 22, BASE_BG, Vector2(-22, 23), Vector2(0.5, 0.0))
	_focus_first()


func show_game_over(score: int, pb: bool, has_checkpoint: bool) -> void:
	_open("game_over", "game_over")
	var cp_tag := "game_over_checkpoint" if has_checkpoint else "game_over_checkpoint_locked"
	_two_buttons(
		"game_over_restart", "play from start", cp_tag, "restart from checkpoint", has_checkpoint
	)
	_main_menu_button()
	var text := ("%d - new PB!" % score) if pb else str(score)
	_label(text, 30, Color.BLACK, Vector2(0, 35), Vector2(0.5, 0.5))
	_focus_first()


func show_restart(reached: Array) -> void:
	_open("restart", "restart_from_checkpoint")
	var rows := [[80, 85, 90, 95], [50, 60, 70, 75], [10, 20, 30, 40]]
	var bw := 259.0 / 3.0
	var bh := 117.0 / 3.0
	var width := 4.0 * bw + 3.0 * SPACE
	var y := _bottom() + SPACE
	for row in rows:
		var x := -0.5 * width
		for level in row:
			var ok: bool = level in reached
			var tag := "Checkpoint_%d" % level if ok else "Checkpoint_%d_locked" % level
			_button(tag, "L%d" % level, Vector2(x, y), Vector2.ZERO, ok)
			x += bw + SPACE
		y += bh + SPACE
	_main_menu_button()
	_focus_first()


## Practice: pick any level reached in the main game and play just that one.
## furthest: levels 1..furthest are open. bests: Save.bests.
## note: a line under the heading, e.g. how the last practice run went.
func show_practice(page: int, furthest: int, bests: Dictionary, count: int, note := "") -> void:
	_open("practice", "restart_from_checkpoint")
	# The art says RESTART / select checkpoint: cover both with our own words.
	var title_cover := ColorRect.new()
	title_cover.color = BASE_BG
	title_cover.position = Vector2(-340, -380)
	title_cover.size = Vector2(680, 122)
	title_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(title_cover)
	# The letters dip into the panel's top edge too.
	var edge_cover := ColorRect.new()
	edge_cover.color = Color.WHITE
	edge_cover.position = Vector2(-340, -257)
	edge_cover.size = Vector2(680, 30)
	edge_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(edge_cover)
	var edge_blend := ColorRect.new()  # the art's one anti-aliased edge row
	edge_blend.color = Color("#d0eaf5")
	edge_blend.position = Vector2(-340, -258)
	edge_blend.size = Vector2(680, 1)
	edge_blend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(edge_blend)
	var heading_cover := ColorRect.new()
	heading_cover.color = Color.WHITE
	heading_cover.position = Vector2(-340, -200)
	heading_cover.size = Vector2(680, 70)
	heading_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(heading_cover)
	# Sits where the art's own titles do, just above the panel.
	_label("PRACTICE", 38, Color.WHITE, Vector2(0, 87), Vector2(0.5, 0.0), Hud.sans_bold)
	var first := page * PRACTICE_PAGE + 1
	var last := mini(first + PRACTICE_PAGE - 1, count)
	var heading := note if note != "" else "levels %d-%d" % [first, last]
	_label(heading, 13, Color.BLACK, Vector2(0, 54), Vector2(0.5, 0.5))

	var cw := 70.0
	var ch := 31.0
	var gap := 8.0
	var x0 := -2.5 * cw - 2.0 * gap
	var y := 33.0
	for i in range(PRACTICE_PAGE):
		var level := first + i
		if level > count:
			break
		var pos := Vector2(x0 + (i % 5) * (cw + gap), y - (i / 5) * (ch + gap / 2.0))
		_level_cell(level, level <= furthest, bests.get(level, {}), pos, Vector2(cw, ch))

	var pages := ceili(float(count) / PRACTICE_PAGE)
	# Page arrows either side of the main menu button.
	var arrow_y := _bottom() - SPACE / 2.0
	var arrow := Vector2(45, load("res://assets/buttons/main_menu.png").get_height() / 3.0)
	if page > 0:
		var act := "practice page %d" % (page - 1)
		_text_button("options", "<", act, Vector2(-83, arrow_y), Vector2(1.0, 1.0), arrow)
	if page < pages - 1:
		var act := "practice page %d" % (page + 1)
		_text_button("options", ">", act, Vector2(83, arrow_y), Vector2(0.0, 1.0), arrow)
	_main_menu_button()
	_focus_first()


## One level in the practice grid: its number, and its best time and stars.
func _level_cell(
	level: int, open: bool, best: Dictionary, pos_pts: Vector2, size_pts: Vector2
) -> void:
	var tag := "Checkpoint_10" if open else "Checkpoint_10_locked"
	var b := TextureButton.new()
	b.texture_normal = _blank_button(tag)
	b.texture_pressed = _blank_button(tag + "_on")
	b.texture_hover = b.texture_pressed
	b.texture_focused = b.texture_pressed
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	var size_px := size_pts * 3.0
	b.size = size_px
	_place(b, size_px, pos_pts, Vector2(0, 1))
	if open:
		b.pressed.connect(func(): action.emit("practice level %d" % level))
		if _first_button == null:
			_first_button = b
	else:
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
	_panel.add_child(b)
	Hud.fonts()
	var number := Label.new()
	number.text = str(level)
	number.add_theme_font_override("font", Hud.mono)
	number.add_theme_font_size_override("font_size", 40)
	number.add_theme_color_override("font_color", Color.WHITE)
	number.add_theme_color_override("font_outline_color", Color.WHITE)
	number.add_theme_constant_override("outline_size", 3)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.position = Vector2(0, 2)
	number.size = Vector2(size_px.x, 50)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(number)
	if open and not best.is_empty():
		var detail := Label.new()
		detail.text = "%ds" % best.time + ("   %d" % best.stars if best.stars > 0 else "")
		detail.add_theme_font_override("font", Hud.mono)
		detail.add_theme_font_size_override("font_size", 24)
		detail.add_theme_color_override("font_color", Color.WHITE)
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.position = Vector2(0, 54)
		detail.size = Vector2(size_px.x, 30)
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(detail)
		if best.stars > 0:
			# The HUD's star, just before the star count.
			var star := TextureRect.new()
			star.texture = load("res://assets/star/star_white_transparent.png")
			star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			star.size = Vector2(24, 23)
			var text_w := Hud.mono.get_string_size(detail.text, 0, -1, 24).x
			star.position = Vector2((size_px.x + text_w) / 2.0 - 44, 58)
			star.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(star)


## Level clear: the three bonuses count down into the score, star by star.
func show_end_level(
	score: int, level_bonus: int, time_bonus: int, stars: int, checkpoint: bool
) -> void:
	_open("end_level", "end_level_checkpoint" if checkpoint else "end_level", false)
	var score_label := _label(
		"score %d" % score, 20, Color.WHITE, Vector2(0, _bottom() - SPACE * 1.2), Vector2(0.5, 1.0)
	)
	var rows: Array[StarRow] = []
	rows.append(StarRow.new(self, level_bonus, _top() - 4.5 * SPACE))
	rows.append(StarRow.new(self, time_bonus, _top() - 9.0 * SPACE))
	if stars > 0:
		rows.append(StarRow.new(self, stars, _top() - 13.1 * SPACE))
	_tap_to("next level")
	_count_up(rows, score, score_label, "score %d")


func show_congratulations(score: int, pb: bool) -> void:
	_open("congratulations", "congratulations")
	var text := ("%d - new PB!" % score) if pb else str(score)
	_label(text, 30, Color.BLACK, Vector2(0, 5), Vector2(0.5, 0.5))
	_main_menu_button()
	_focus_first()


func show_game_complete(score: int, completion_bonus: int, lives_bonus: int) -> void:
	_open("completion", "completion", false)
	var score_label := _label(
		"score %d" % score, 20, Color.WHITE, Vector2(0, _bottom() - SPACE * 1.2), Vector2(0.5, 1.0)
	)
	var rows: Array[StarRow] = []
	rows.append(StarRow.new(self, completion_bonus, _top() - 5.0 * SPACE))
	rows.append(StarRow.new(self, lives_bonus, _top() - 12.0 * SPACE))
	_tap_to("completion done")
	_count_up(rows, score, score_label, "score %d")


func _count_up(rows: Array[StarRow], score: int, score_label: Label, fmt: String) -> void:
	_tween = create_tween()
	var total := [score]
	for row in rows:
		_tween.tween_interval(0.2)
		var points := row.points
		while points > 0:
			var step := 5 if points > StarRow.THRESHOLD else 1
			points -= step
			_tween.tween_interval(0.2 if points + step == row.points else 0.1)
			_tween.tween_callback(
				func():
					row.take(step)
					total[0] += step
					score_label.text = fmt % total[0]
					var sz := score_label.get_minimum_size()
					score_label.size = sz
					_place(score_label, sz, Vector2(0, _bottom() - SPACE * 1.2), Vector2(0.5, 1.0))
					Audio.play("star", 0.2)
			)


class StarRow:
	## A row of blue stars (or "N ★" when there are too many) on a score menu.
	const LONG_STARS := 12
	const THRESHOLD := 50
	var menus: Menus
	var points: int
	var remaining: int
	var y: float
	var stars: Array[TextureRect] = []
	var label: Label

	func _init(m: Menus, p: int, y_pts: float) -> void:
		menus = m
		points = p
		remaining = p
		y = y_pts
		var tex: Texture2D = load("res://assets/star/star_blue.png")
		for i in LONG_STARS:
			var r := TextureRect.new()
			r.texture = tex
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			m._panel.add_child(r)
			stars.append(r)
		label = m._label("", 25, Menus.BASE_BG, Vector2(0, y), Vector2(0.5, 0.5))
		_update()

	func take(step: int) -> void:
		remaining = maxi(0, remaining - step)
		_update()

	func _update() -> void:
		var star_w := 84.0 / 3.0
		var star_size := Vector2(84, 81)
		if remaining > LONG_STARS:
			label.text = str(remaining)
			var lsz := label.get_minimum_size()
			label.size = lsz
			var lw := lsz.x / 3.0
			var width := (lw + star_w) * 1.1
			menus._place(
				label, lsz, Vector2(-0.5 * width + 0.5 * lw, y - 0.1 * 27.0), Vector2(0.5, 0.5)
			)
			for i in stars.size():
				stars[i].visible = i == 0
			menus._place(
				stars[0], star_size, Vector2(0.5 * width - 0.5 * star_w, y), Vector2(0.5, 0.5)
			)
		else:
			label.text = ""
			var lhs := -0.5 * (remaining * star_w - star_w)
			for i in stars.size():
				stars[i].visible = i < remaining
				if i < remaining:
					menus._place(
						stars[i], star_size, Vector2(lhs + i * star_w, y), Vector2(0.5, 0.5)
					)
