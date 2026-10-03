class_name Hud
extends Control
## Level/score/lives along the top, and the bottom bar with the effect icon,
## status message, countdown and tutorial text. Port of bottom_bar.py,
## effect.py, timer.py and the *_display.py modules.

const BAR_HEIGHT := 80.0
const BAR_COLOR := Color("#1c1c1c")
const TIMER_FONT_SIZE := 50
const LOW_TIME := Color("#ffffff")
const NORMAL_TIME := Color("#ffffff")
const TIME_UP := Color("#aeaeae")

static var mono: Font
static var sans: Font

var level_label: Label
var score_label: Label
var star: TextureRect
var lives_label: Label
var heart: TextureRect

var bar: ColorRect
var effect_single: TextureRect
var effect_top: TextureRect
var effect_bottom: TextureRect
var controls_label: Label
var tutorial_label: Label
var timer_label: Label
var time_message_label: Label

var _effect_textures := {}


## Bundled Liberation fonts: metric-compatible with the original's Courier
## and Arial, and identical on every platform (screenshots compare cleanly).
static func fonts() -> void:
	if mono == null:
		mono = load("res://assets/fonts/LiberationMono-Regular.ttf")
		sans = load("res://assets/fonts/LiberationSans-Regular.ttf")


static func make_label(font: Font, size: int, color := Color.WHITE) -> Label:
	fonts()
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func make_icon(path: String, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(path)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _ready() -> void:
	fonts()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for n in [
		"reverse", "vanish", "sticky", "points", "more_time", "less_time", "life", "hide", "unhide"
	]:
		_effect_textures[n] = load("res://assets/effects/%s.png" % n)

	level_label = make_label(mono, 40)
	add_child(level_label)
	score_label = make_label(mono, 40)
	add_child(score_label)
	star = make_icon("res://assets/star/star_white_transparent.png", Vector2(28, 27))
	add_child(star)
	lives_label = make_label(mono, 40)
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(lives_label)
	heart = make_icon("res://assets/heart/heart.png", Vector2(38, 36))
	add_child(heart)

	bar = ColorRect.new()
	bar.color = BAR_COLOR
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	effect_single = TextureRect.new()
	effect_top = TextureRect.new()
	effect_bottom = TextureRect.new()
	for r in [effect_single, effect_top, effect_bottom]:
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.visible = false
		bar.add_child(r)
	effect_single.size = Vector2(76, 76)
	effect_single.position = Vector2(5, 2)
	effect_top.size = Vector2(38, 38)
	effect_top.position = Vector2(25, 0)
	effect_bottom.size = Vector2(38, 38)
	effect_bottom.position = Vector2(25, 40)

	controls_label = make_label(sans, 20)
	controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(controls_label)
	tutorial_label = make_label(sans, 15)
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(tutorial_label)
	timer_label = make_label(mono, TIMER_FONT_SIZE)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(timer_label)
	time_message_label = make_label(sans, 30)
	time_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(time_message_label)

	get_viewport().size_changed.connect(layout)
	layout()


func layout() -> void:
	var s := get_viewport_rect().size
	level_label.position = Vector2(10, 30 - 25)
	lives_label.size = Vector2(120, 50)
	lives_label.position = Vector2(s.x - 45 - 120, 5)
	heart.position = Vector2(s.x - 45 + 18 - 19, 30 - 2 - 18)
	_layout_score()

	bar.position = Vector2(0, s.y - BAR_HEIGHT)
	bar.size = Vector2(s.x, BAR_HEIGHT)
	var cw := s.x * 0.27
	controls_label.position = Vector2(87, 0)
	controls_label.size = Vector2(cw, BAR_HEIGHT)
	var tx := 87 + cw + 10
	tutorial_label.position = Vector2(tx, 0)
	tutorial_label.size = Vector2(s.x - tx - 10, BAR_HEIGHT)
	timer_label.size = Vector2(160, BAR_HEIGHT)
	timer_label.position = Vector2(s.x * 0.5 - 80, 0)
	time_message_label.size = Vector2(220, BAR_HEIGHT)
	time_message_label.position = Vector2(s.x * 0.75 + 10 - 110, 0)


func _layout_score() -> void:
	var s := get_viewport_rect().size
	var text_w := score_label.get_minimum_size().x
	var total := star.size.x + text_w
	var lhs := s.x * 0.5 - total * 0.5
	star.position = Vector2(lhs, 30 - star.size.y * 0.6)
	score_label.position = Vector2(lhs + star.size.x, 5)


# --- top row -------------------------------------------------------------


func set_level(level: int, count: int) -> void:
	level_label.text = "L%d/%d" % [level, count]


func set_score(score: int) -> void:
	score_label.text = str(score)
	_layout_score()


func set_lives(lives: int) -> void:
	lives_label.text = str(lives)


func show_stats(on: bool) -> void:
	for n in [level_label, score_label, star, lives_label, heart]:
		n.visible = on


func show_bar(on: bool) -> void:
	bar.visible = on


# --- bottom bar ----------------------------------------------------------


func set_controls_message(text: String, size := 20) -> void:
	controls_label.text = text
	controls_label.add_theme_font_size_override("font_size", size)


func set_tutorial_text(text: String) -> void:
	tutorial_label.text = text


func set_time_message(text: String, size := 30) -> void:
	time_message_label.text = text
	time_message_label.add_theme_font_size_override("font_size", size)


## seconds: whole seconds shown; fractional: exact time left (for the font pulse).
func set_timer(seconds: int, fractional: float, visible_timer := true) -> void:
	timer_label.visible = visible_timer
	timer_label.text = str(seconds)
	var multiplier := 1.0
	if fractional >= 0.0 and fractional <= 3.0:
		var whole := int(fractional)
		multiplier = 1.0 + (3.0 - whole + (fractional - whole) * 2.0) * 0.2
	timer_label.add_theme_font_size_override(
		"font_size", maxi(1, int(TIMER_FONT_SIZE * multiplier))
	)
	if seconds <= 0:
		timer_label.add_theme_color_override("font_color", TIME_UP)
	elif seconds <= 3:
		timer_label.add_theme_color_override("font_color", LOW_TIME)
	else:
		timer_label.add_theme_color_override("font_color", NORMAL_TIME)


func blank_timer() -> void:
	timer_label.text = ""


func show_effect(name: String) -> void:
	effect_single.texture = _effect_textures[name]
	effect_single.visible = true
	effect_top.visible = false
	effect_bottom.visible = false


func show_double_effect(top: String, bottom: String) -> void:
	effect_top.texture = _effect_textures[top]
	effect_bottom.texture = _effect_textures[bottom]
	effect_single.visible = false
	effect_top.visible = true
	effect_bottom.visible = true


func clear_effect() -> void:
	effect_single.visible = false
	effect_top.visible = false
	effect_bottom.visible = false
