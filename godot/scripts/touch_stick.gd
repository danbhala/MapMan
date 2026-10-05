class_name TouchStick
extends Control
## The floating touch stick (Options "CONTROLS": DRAG TO MOVE). It appears
## where a finger lands on the field and follows that finger's drag until it
## lifts. Drawn like the tilt gauge, larger: inside the dashed ring MapMan
## stays put, past it he walks, past the solid ring (the knob turns gold) he
## runs. Not in the original. Only draws; main.gd feeds it the touch through
## TiltInput, so a quick tap without a drag still pauses.

## Radius of the rim; the rim is 1.5 × the full-speed tilt, like the gauge's.
const RADIUS := 46.0
const PAD := 8.0
const KNOB := 11.0
const DASHES := 24
## How long it takes to fade out after the finger lifts.
const FADE_SECONDS := 0.15

## Where the finger landed and the knob's offset from it (TiltInput).
var origin := Vector2.ZERO
var knob := Vector2.ZERO
## What the stick does now: 0 MapMan stays put, 1 walks, 2 runs.
var pace := 0
## The finger is down.
var held := false

var _alpha := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if held:
		_alpha = 1.0
	elif _alpha > 0.0:
		_alpha = maxf(_alpha - delta / FADE_SECONDS, 0.0) if Blueprint.motion() else 0.0
	if visible:
		queue_redraw()


## Shown at all right now (held, or fading out).
func showing() -> bool:
	return held or _alpha > 0.0


func _draw() -> void:
	if not showing():
		return
	var c := origin
	var ink := Color(Blueprint.INK, _alpha)
	var fast: float = Dev.t("fast_threshold")
	var scale := RADIUS / maxf(fast * 1.5, 0.01)
	draw_circle(c, RADIUS, Color(Blueprint.STRIP, Blueprint.STRIP.a * _alpha))
	# The centre mark, ticking out past the rim, as on the gauge.
	var mark := Color(ink, 0.3 * _alpha)
	for i in 4:
		var dir := Vector2.RIGHT.rotated(i * PI / 2.0)
		draw_line(c + dir * 3.0, c + dir * RADIUS * 0.3, mark, 1.0, true)
		draw_line(c + dir * RADIUS * 0.5, c + dir * (RADIUS + PAD), mark, 1.0, true)
	draw_arc(c, RADIUS, 0, TAU, 64, Color(ink, 0.8 * _alpha), 1.6, true)
	var start: float = Dev.t("tilt_threshold") * scale
	for i in DASHES:
		var a := TAU * i / DASHES
		draw_arc(c, start, a, a + TAU / DASHES * 0.55, 4, Color(ink, 0.8 * _alpha), 1.2, true)
	var run := Blueprint.GOLD if pace == 2 else Blueprint.INK
	draw_arc(c, fast * scale, 0, TAU, 56, Color(run, 0.85 * _alpha), 1.4, true)
	var p := c + knob
	if pace == 0:
		draw_circle(p, KNOB, Color(Blueprint.INK, 0.12 * _alpha))
		draw_arc(p, KNOB, 0, TAU, 32, Color(ink, 0.8 * _alpha), 1.4, true)
		return
	var color := Color(run, _alpha)
	draw_line(c, p, color, 2.0, true)
	draw_circle(p, KNOB, color)
	draw_arc(p, KNOB, 0, TAU, 32, Color(Blueprint.FIELD, 0.6 * _alpha), 1.0, true)
