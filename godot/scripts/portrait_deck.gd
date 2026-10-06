class_name PortraitDeck
extends Control
## The control deck under the field in the portrait prototype (Portrait): the
## place for the thumb, drawn like a detail on the sheet. PAUSE on the left
## and in the middle the tilt gauge, larger (tap it to recentre), or, steering
## by drag, the stick's resting ring. TILT or DRAG is chosen in Options, as in
## landscape. A drag anywhere on the screen still steers; the deck just says
## where the thumb goes. Only exists when Portrait.on().

const GAUGE_ZOOM := 1.8
const BUTTON := Vector2(86, 40)

var _game  # main.gd
var _pause: Button
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
	_caption.position = Vector2(r.get_center().x - 70.0, r.end.y - 20.0)
	Blueprint.fit(_caption, Vector2(140, 14))
	queue_redraw()


## Where the tilt gauge sits, drawn bigger, in the middle of the deck.
func place_gauge(gauge: TiltGauge) -> void:
	gauge.zoom = GAUGE_ZOOM
	var c := rect().get_center() + Vector2(0, 2)
	gauge.position = c - gauge.size / 2.0


func _process(_delta: float) -> void:
	visible = _game.game_active and not _game.menus.visible and _game.hud.bar.visible
	var touch: bool = Save.controls == "touch"
	_caption.text = "DRAG ANYWHERE" if touch else "TAP GAUGE TO LEVEL"
	queue_redraw()


func _on_pause() -> void:
	if _game._can_pause():
		_game.show_pause_menu()


func _draw() -> void:
	var r := rect()
	var ink := Blueprint.INK
	draw_rect(r, Blueprint.STRIP)
	draw_line(r.position, Vector2(r.end.x, r.position.y), ink, Blueprint.FRAME_WIDTH)
	draw_rect(Rect2(_pause.position, _pause.size), Color(ink, 0.8), false, 1.2)
	var touch: bool = Save.controls == "touch"
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
