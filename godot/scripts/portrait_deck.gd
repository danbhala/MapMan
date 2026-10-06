class_name PortraitDeck
extends Control
## The control deck under the field in the portrait prototype (Portrait): the
## place for the thumbs, drawn like a detail on the sheet. PAUSE on the left,
## TILT / DRAG on the right, and in the middle the tilt gauge, larger (tap it
## to recentre), or, steering by drag, the stick's resting ring. A drag
## anywhere on the screen still steers; the deck just says where the thumb
## goes. Only exists when Portrait.on().

const GAUGE_SCALE := 1.8
const BUTTON := Vector2(86, 40)

var _game  # main.gd
var _pause: Button
var _tilt: Button
var _drag: Button
var _caption: Label
var _title: Label


## The deck for `game` (main.gd) on `layer`, or null when not in portrait.
static func attach(game, layer: CanvasLayer) -> PortraitDeck:
	if not Portrait.on():
		return null
	var deck := PortraitDeck.new(game)
	deck.visible = false
	layer.add_child(deck)
	layer.move_child(deck, game.gauge.get_index())  # under the gauge
	layer.move_child(game.steering.stick, -1)  # and the stick over both
	game.gauge.deck = deck
	game.gauge.place(deck.get_viewport_rect().size)
	return deck


func _init(game) -> void:
	_game = game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title = Blueprint.label(self, "DETAIL A  —  CONTROLS", 10, Blueprint.FAINT)
	_caption = Blueprint.label(self, "", 10, Blueprint.FAINT)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause = _button("II  PAUSE")
	_pause.pressed.connect(_on_pause)
	_tilt = _button("TILT")
	_tilt.pressed.connect(_choose.bind("tilt"))
	_drag = _button("DRAG")
	_drag.pressed.connect(_choose.bind("touch"))
	get_viewport().size_changed.connect(layout)
	layout()


func _button(text: String) -> Button:
	var b := Button.new()
	b.theme = Blueprint.theme()
	add_child(b)
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_override("font", Blueprint.mono(700))
	b.add_theme_font_size_override("font_size", 13)
	b.size = BUTTON
	return b


func rect() -> Rect2:
	return Portrait.deck_rect(get_viewport_rect().size)


func layout() -> void:
	var r := rect()
	_title.position = r.position + Vector2(10, 6)
	var mid := r.position.y + r.size.y / 2.0 + 6.0
	_pause.position = Vector2(r.position.x + 10, mid - BUTTON.y / 2.0)
	_pause.size = BUTTON
	var right := r.end.x - 10 - BUTTON.x
	_tilt.position = Vector2(right, mid - BUTTON.y - 2.0)
	_drag.position = Vector2(right, mid + 2.0)
	for b in [_tilt, _drag]:
		b.size = Vector2(BUTTON.x, BUTTON.y - 4.0)
	_caption.position = Vector2(r.get_center().x - 70.0, r.end.y - 20.0)
	Blueprint.fit(_caption, Vector2(140, 14))
	queue_redraw()


## Where the tilt gauge sits, scaled up, in the middle of the deck.
func place_gauge(gauge: Control) -> void:
	gauge.scale = Vector2.ONE * GAUGE_SCALE
	var c := rect().get_center() + Vector2(0, 2)
	gauge.position = c - gauge.size * GAUGE_SCALE / 2.0


func _process(_delta: float) -> void:
	visible = _game.game_active and not _game.menus.visible and _game.hud.bar.visible
	var touch: bool = Save.controls == "touch"
	_caption.text = "DRAG ANYWHERE" if touch else "TAP GAUGE TO LEVEL"
	_tilt.add_theme_color_override("font_color", Blueprint.FAINT if touch else Blueprint.GOLD)
	_drag.add_theme_color_override("font_color", Blueprint.GOLD if touch else Blueprint.FAINT)
	queue_redraw()


func _on_pause() -> void:
	if _game._can_pause():
		_game.show_pause_menu()


func _choose(mode: String) -> void:
	ControlsSheet.choose("controls " + mode)
	_game.steering.apply()


func _draw() -> void:
	var r := rect()
	var ink := Blueprint.INK
	draw_rect(r, Blueprint.STRIP)
	draw_line(r.position, Vector2(r.end.x, r.position.y), ink, Blueprint.FRAME_WIDTH)
	# Outlines for the buttons; the chosen way of steering is boxed in gold.
	draw_rect(Rect2(_pause.position, _pause.size), Color(ink, 0.8), false, 1.2)
	var touch: bool = Save.controls == "touch"
	draw_rect(
		Rect2(_tilt.position, _tilt.size), Blueprint.FAINT if touch else Blueprint.GOLD, false, 1.2
	)
	draw_rect(
		Rect2(_drag.position, _drag.size), Blueprint.GOLD if touch else Blueprint.FAINT, false, 1.2
	)
	if touch and not _game.steering.stick.held:
		# The stick's resting ring, where a thumb would naturally land.
		var c := r.get_center() + Vector2(0, 2)
		var radius := TouchStick.RADIUS
		draw_circle(c, radius, Blueprint.STRIP)
		draw_arc(c, radius, 0, TAU, 64, Color(ink, 0.5), 1.4, true)
		for i in 24:
			var a := TAU * i / 24.0
			draw_arc(c, radius * 0.45, a, a + TAU / 24.0 * 0.55, 4, Color(ink, 0.5), 1.2, true)
		draw_arc(c, TouchStick.KNOB, 0, TAU, 32, Color(ink, 0.7), 1.4, true)
