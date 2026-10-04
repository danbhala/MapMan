class_name Hud
extends Control
## The drawing frame around the playing field, with the header strip (sheet
## number, score, lives) and the bottom bar (effect icon, note, countdown
## drawn as a dimension line). Port of bottom_bar.py, effect.py, timer.py and
## the *_display.py modules, in the Blueprint style.

const HEADER_HEIGHT := 28.0
const BAR_HEIGHT := 44.0
const TEXT_SIZE := 13
const TIMER_SIZE := 14
const TUTORIAL_SIZE := 12
## The countdown line is drawn to this many seconds; extra time fills past it.
const TIMER_SPAN := 20.0
const TIMER_LENGTH := 150.0

static var mono: Font
static var sans_bold: Font
static var sans: Font

var frame: Line2D
var header: ColorRect
var level_label: Label
var score_label: Label
var lives_label: Label

var bar: ColorRect
var effect_single: TextureRect
var effect_top: TextureRect
var effect_bottom: TextureRect
var note_label: Label
var tutorial_label: Label
var timer_label: Label
var timer_line: TimerLine

var _effect_textures := {}
var _controls_text := ""
var _time_text := ""
var _state_color := Blueprint.INK


## Bundled fonts. The dev panel still uses Liberation Sans for its dense text.
static func fonts() -> void:
	if mono == null:
		mono = Blueprint.mono(500)
		sans = load("res://assets/fonts/LiberationSans-Regular.ttf")
		sans_bold = load("res://assets/fonts/LiberationSans-Bold.ttf")


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

	frame = Blueprint.line(self, PackedVector2Array(), Blueprint.INK, Blueprint.FRAME_WIDTH)

	header = Blueprint.rect(self, Blueprint.STRIP, Vector2.ZERO, Vector2.ZERO)
	level_label = Blueprint.label(header, "", TEXT_SIZE, Blueprint.INK, Vector2.ZERO, 700)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.accessibility_name = "Level"
	score_label = Blueprint.label(
		header, "", TEXT_SIZE, Blueprint.INK, Vector2.ZERO, 700, 0.0, HORIZONTAL_ALIGNMENT_CENTER
	)
	score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_label.accessibility_name = "Score"
	lives_label = Blueprint.label(
		header, "", TEXT_SIZE, Blueprint.INK, Vector2.ZERO, 700, 0.0, HORIZONTAL_ALIGNMENT_RIGHT
	)
	lives_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lives_label.accessibility_name = "Lives"

	bar = Blueprint.rect(self, Blueprint.BAR, Vector2.ZERO, Vector2.ZERO)
	effect_single = TextureRect.new()
	effect_top = TextureRect.new()
	effect_bottom = TextureRect.new()
	for r in [effect_single, effect_top, effect_bottom]:
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.visible = false
		bar.add_child(r)
	effect_single.size = Vector2(30, 30)
	effect_single.position = Vector2(10, (BAR_HEIGHT - 30) / 2.0)
	effect_top.size = Vector2(22, 22)
	effect_top.position = Vector2(8, (BAR_HEIGHT - 22) / 2.0)
	effect_bottom.size = Vector2(22, 22)
	effect_bottom.position = Vector2(30, (BAR_HEIGHT - 22) / 2.0)

	note_label = Blueprint.label(bar, "", TEXT_SIZE, Blueprint.INK, Vector2.ZERO, 500, 10.0)
	note_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note_label.accessibility_live = DisplayServer.LIVE_POLITE
	tutorial_label = Blueprint.label(bar, "", TUTORIAL_SIZE, Blueprint.INK, Vector2.ZERO, 500, 10.0)
	tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_label.accessibility_live = DisplayServer.LIVE_POLITE
	timer_line = TimerLine.new()
	bar.add_child(timer_line)
	timer_label = Blueprint.label(bar, "", TIMER_SIZE, Blueprint.INK, Vector2.ZERO, 700)
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.accessibility_name = "Time left"

	get_viewport().size_changed.connect(layout)
	layout()


func layout() -> void:
	var s := get_viewport_rect().size
	var inset := Blueprint.INSET
	var inner_x := inset + 1.0
	var inner_w := s.x - 2.0 * inner_x
	frame.points = Blueprint.frame_points(s)

	header.position = Vector2(inner_x, inset + 1.0)
	header.size = Vector2(inner_w, HEADER_HEIGHT)
	level_label.position = Vector2(12, 0)
	level_label.size = Vector2(200, HEADER_HEIGHT)
	score_label.position = Vector2(0, 0)
	score_label.size = Vector2(inner_w, HEADER_HEIGHT)
	lives_label.position = Vector2(inner_w - 12 - 120, 0)
	lives_label.size = Vector2(120, HEADER_HEIGHT)

	bar.position = Vector2(inner_x, s.y - inset - 1.0 - BAR_HEIGHT)
	bar.size = Vector2(inner_w, BAR_HEIGHT)
	var timer_w := TIMER_LENGTH + 80.0
	timer_label.size = Vector2(70, BAR_HEIGHT)
	timer_label.position = Vector2(inner_w - 12 - 70, 0)
	timer_line.position = Vector2(inner_w - 12 - 70 - 10 - TIMER_LENGTH, BAR_HEIGHT / 2.0)
	_layout_note(inner_w - timer_w)
	tutorial_label.position = Vector2(12, 0)
	tutorial_label.size = Vector2(inner_w - 24, BAR_HEIGHT)


func _layout_note(width_to_timer: float) -> void:
	var x := 12.0
	if effect_single.visible:
		x = 48.0
	elif effect_top.visible:
		x = 60.0
	note_label.position = Vector2(x, 0)
	note_label.size = Vector2(width_to_timer - x - 8.0, BAR_HEIGHT)


## The frame, note and countdown take the colour of the current effect.
func set_state_color(color: Color) -> void:
	_state_color = color
	frame.default_color = color
	note_label.add_theme_color_override("font_color", color)
	timer_line.color = color
	timer_line.queue_redraw()


# --- header -------------------------------------------------------------


func set_level(level: int, count: int) -> void:
	level_label.text = "SHEET %03d / %d" % [level, count]


func set_level_text(text: String) -> void:
	level_label.text = text


func set_score(score: int) -> void:
	score_label.text = "★ %d" % score


func set_lives(lives: int) -> void:
	lives_label.text = "♥ %d" % lives


func show_stats(on: bool) -> void:
	for n in [level_label, score_label, lives_label]:
		n.visible = on


func show_level(on: bool) -> void:
	level_label.visible = on


## The frame and strips show while a level is on screen.
func show_bar(on: bool) -> void:
	bar.visible = on
	header.visible = on
	frame.visible = on


# --- bottom bar ----------------------------------------------------------


## The note shows the controls message if there is one, else the time message.
func _refresh_note() -> void:
	note_label.text = _controls_text if _controls_text != "" else _time_text


func set_controls_message(text: String, _size := 20) -> void:
	_controls_text = text.to_upper()
	_refresh_note()


func set_tutorial_text(text: String) -> void:
	tutorial_label.text = text
	# The tutorial fills the bar: no countdown runs during it.
	var s := get_viewport_rect().size
	var inner_w := s.x - 2.0 * (Blueprint.INSET + 1.0)
	_layout_note(inner_w if text != "" else inner_w - TIMER_LENGTH - 80.0)


func set_time_message(text: String, _size := 30) -> void:
	_time_text = text.to_upper()
	_refresh_note()


## seconds: whole seconds shown; fractional: exact time left (for the pulse).
func set_timer(seconds: int, fractional: float, visible_timer := true) -> void:
	timer_label.visible = visible_timer
	timer_line.visible = visible_timer
	timer_label.text = "T-0:%02d" % seconds
	var multiplier := 1.0
	if fractional >= 0.0 and fractional <= 3.0:
		var whole := int(fractional)
		multiplier = 1.0 + (3.0 - whole + (fractional - whole) * 2.0) * 0.12
	timer_label.add_theme_font_size_override("font_size", maxi(1, int(TIMER_SIZE * multiplier)))
	var urgent := seconds > 0 and seconds <= 3
	timer_label.add_theme_color_override("font_color", _state_color if urgent else Blueprint.INK)
	timer_line.share = clampf(fractional / TIMER_SPAN, 0.0, 1.0) if fractional >= 0.0 else 0.0
	timer_line.queue_redraw()


func blank_timer() -> void:
	timer_label.text = ""
	timer_line.share = 0.0
	timer_line.queue_redraw()


func show_effect(name: String) -> void:
	effect_single.texture = _effect_textures[name]
	effect_single.visible = true
	effect_top.visible = false
	effect_bottom.visible = false
	layout()


func show_double_effect(top: String, bottom: String) -> void:
	effect_top.texture = _effect_textures[top]
	effect_bottom.texture = _effect_textures[bottom]
	effect_single.visible = false
	effect_top.visible = true
	effect_bottom.visible = true
	layout()


func clear_effect() -> void:
	effect_single.visible = false
	effect_top.visible = false
	effect_bottom.visible = false
	layout()


## The countdown as a dimension line: a faint full length, the time left
## drawn solid over it, with a tick every five seconds.
class TimerLine:
	extends Node2D
	var share := 0.0
	var color := Blueprint.INK

	func _draw() -> void:
		draw_line(Vector2.ZERO, Vector2(TIMER_LENGTH, 0), Color(1, 1, 1, 0.35), 2.0)
		if share > 0.0:
			draw_line(Vector2.ZERO, Vector2(TIMER_LENGTH * share, 0), color, 3.0)
		var step := TIMER_LENGTH / (TIMER_SPAN / 5.0)
		var x := 0.0
		while x <= TIMER_LENGTH + 0.5:
			draw_line(Vector2(x, -6), Vector2(x, 6), Blueprint.INK, 1.0)
			x += step
