class_name TiltGauge
extends Control
## The tilt gauge in the field's bottom-right corner, drawn like a drafting
## centre mark. The dot is how far the phone is tipped from "level": inside
## the dashed ring MapMan stays put, past it he walks, past the solid ring he
## runs. Tapping it makes the way the phone is held now the new level (the
## tutorial teaches that); the tap never reaches the field, so it never pauses.
## Not in the original. Off in Options (Save.tilt_gauge); hidden without an
## accelerometer, where there is no tilt to show.

## The player tapped the gauge to take the phone's current angle as level.
signal recentre

## Radius of the gauge's rim; the rim is 1.5 × the full-speed tilt.
const RADIUS := 26.0
## Room around the rim for the centre mark's ticks.
const PAD := 6.0
## Space between the gauge and the frame / bottom bar.
const MARGIN := 8.0
const DOT := 3.4
const DASHES := 16
const RIPPLE_SECONDS := 0.45
## Faded right down while MapMan walks underneath, so he's never hidden.
const FADED := 0.3
## How close MapMan's feet come before the gauge fades: across, and above or
## below the rim (he stands up from his feet, so more room below).
const FADE_SIDE := 28.0
const FADE_ABOVE := 12.0
const FADE_BELOW := 70.0

## The steering vector to show (TiltInput.get_vector()).
var steer := Vector2.ZERO
## What that tilt does: 0 MapMan stays put, 1 walks, 2 runs.
var pace := 0

## The portrait prototype's control deck, when there is one (Portrait).
var deck: PortraitDeck

var _ripple := -1.0
var _fade := 1.0


func _init() -> void:
	size = Vector2.ONE * (RADIUS + PAD) * 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


## Sits in the field's bottom-right corner, above the bottom bar.
func place(screen: Vector2) -> void:
	if deck != null:  # portrait prototype: big, in the control deck
		deck.place_gauge(self)
		return
	var inner := Blueprint.INSET + 1.0
	position = Vector2(
		screen.x - inner - MARGIN - size.x + PAD,
		screen.y - inner - Hud.BAR_HEIGHT - MARGIN - size.y + PAD
	)


func centre() -> Vector2:
	return position + size / 2.0


## Fade while MapMan's feet (`feet`, in the same screen space) are close.
func near_player(feet: Vector2, delta: float) -> void:
	if deck != null:
		return  # under the field, never in MapMan's way
	var d := feet - centre()
	var near := (
		absf(d.x) < RADIUS + FADE_SIDE and d.y > -RADIUS - FADE_ABOVE and d.y < RADIUS + FADE_BELOW
	)
	_fade = move_toward(_fade, FADED if near else 1.0, delta * 4.0)
	modulate.a = _fade


func ripple() -> void:
	_ripple = 0.0


func _process(delta: float) -> void:
	if _ripple >= 0.0:
		_ripple += delta / RIPPLE_SECONDS
		if _ripple >= 1.0:
			_ripple = -1.0
	if visible:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Both halves of the tap stop here: a release on the field pauses.
		accept_event()
		if event.pressed:
			recentre.emit()


func _has_point(point: Vector2) -> bool:
	# A round target, a little bigger than the rim for fingers.
	return point.distance_to(size / 2.0) <= RADIUS + PAD


func _draw() -> void:
	var c := size / 2.0
	var fast: float = Dev.t("fast_threshold")
	var scale := RADIUS / maxf(fast * 1.5, 0.01)
	var ink := Blueprint.INK
	draw_circle(c, RADIUS, Blueprint.STRIP)
	# The centre mark: broken lines through the middle, ticking out past the rim.
	var mark := Color(ink, 0.3)
	for i in 4:
		var dir := Vector2.RIGHT.rotated(i * PI / 2.0)
		draw_line(c + dir * 2.0, c + dir * RADIUS * 0.35, mark, 1.0, true)
		draw_line(c + dir * RADIUS * 0.55, c + dir * (RADIUS + PAD - 1.0), mark, 1.0, true)
	draw_arc(c, RADIUS, 0, TAU, 48, Color(ink, 0.66), 1.2, true)
	# Dashed: where he starts walking. Solid: where he runs.
	var start: float = Dev.t("tilt_threshold") * scale
	for i in DASHES:
		var a := TAU * i / DASHES
		draw_arc(c, start, a, a + TAU / DASHES * 0.55, 4, Color(ink, 0.75), 1.0, true)
	draw_arc(c, fast * scale, 0, TAU, 40, Color(ink, 0.8), 1.1, true)
	if _ripple >= 0.0:
		var r := lerpf(DOT, RADIUS + PAD, _ripple) if Blueprint.motion() else RADIUS
		draw_arc(c, r, 0, TAU, 40, Color(ink, 0.9 * (1.0 - _ripple)), 1.5, true)
	var p := steer * scale
	p = p.limit_length(RADIUS - DOT)
	var color := Blueprint.GOLD if pace == 2 else ink
	if pace == 0:
		draw_arc(c + p, DOT, 0, TAU, 16, Color(ink, 0.66), 1.2, true)
		return
	draw_line(c, c + p, color, 1.2, true)
	draw_circle(c + p, DOT, color)
