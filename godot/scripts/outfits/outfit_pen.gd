class_name OutfitPen
extends RefCounted
## What MapMan and his outfit draw with (docs/wardrobe): his pose this frame,
## and drawing calls that follow it. Player fills in the pose at the top of
## each draw, then every layer goes through here: the figure, then the parts
## of the look he wears.
##
## Parts never use screen positions. A point of the body is given at rest
## (b(): no bob, squash or death drop), a point of the head relative to its
## centre (h(): it sinks and shrinks as he dies), a point of a hat relative to
## the head centre too (t(): it rides the head and flies off as he dies).
##
## Measuring draws nothing and grows `bounds` instead, in his node's units, so
## tests can check a look's size without a screen.

## The body at rest: a bell from its hem at y -26 up to -60, 21.9 either
## side, measured off the original sprite (81 px of 162 wide, 137 px tall on
## its 176x320 frames, 3.71 px to one of these units).
const HEM := -26.0
const BODY_TOP := -60.0
const BODY_HALF := 21.9
## The bell is a touch fuller than a half-ellipse: its width follows
## sqrt(1 - k^DOME) up its height, which fits the sprite to within a pixel.
const DOME := 2.1
## Below the hem the bell rounds off, bulging this far down in the middle.
const LIP := 3.9
## The sprite's head: 54 px across its 308.8 px height.
const HEAD_R := 14.55
## Rest points stand this much higher on his legs than their numbers say:
## the sprite's legs were longer than the first drawn figure's.
const RISE := 6.6
## How wide the soft line round a filled shape's edge is: a hairline, so the
## line's own antialiasing softens the edge without the shape growing.
const EDGE := 0.02
## Drawing calls get coordinates this many times finer, and the frame scales
## them back down. Godot's antialiasing blurs about one unit of the
## coordinates it is given, so at his own units it smeared edges over the
## four or so phone pixels a unit covers in the game; at a quarter unit it is
## about one pixel.
const FINE := 4.0

var canvas: CanvasItem
var measuring := false
## What has been drawn so far (measuring only).
var bounds := Rect2()

# The pose, set by Player before each draw.
var look := Vector2.ZERO
var walking := 0.0
## 0 front or back on .. 1 side on: his back is a little slimmer side on.
var side_on := 0.0
var phase := 0.0
var idle_clock := 0.0
var blink := 0.0
var happy := 0.0
var squash := 0.0
var dead := 0.0
var bob := 0.0
var sx := 1.0
var sy := 1.0
var drop := 0.0
## The head's centre and radius this frame.
var hc := Vector2.ZERO
var hr := HEAD_R
var hips: Array[Vector2] = []
var knees: Array[Vector2] = []
var feet: Array[Vector2] = []
## The body outline this frame.
var body := PackedVector2Array()
## Decorative motion (a flutter, a sparkle) is allowed: Blueprint.motion().
var motion := true

## Every colour is multiplied by this: a hat flying off, a cape fading.
var alpha := 1.0
## Where hat points go: nowhere special, or flying off as he dies.
var hat_xf := Transform2D.IDENTITY
## Expressions (a prototype): how the head tilts (radians, + clockwise), where
## the eyes look beyond `look` (in units), how far each upper lid has come
## down (x left eye, y right, 0..1), the lids' slant (+ sad, outer corners
## down; - cross, inner corners down), how much each eye has closed into a
## smiling arch (0..1), and each eye's size.
var roll := 0.0
var gaze := Vector2.ZERO
var lid := Vector2.ZERO
var lid_tilt := 0.0
var smile := Vector2.ZERO
## How far the lower lids have come up, flat (0..1): a squint.
var lower := 0.0
var eye_size := Vector2.ONE

var _xf := Transform2D.IDENTITY
var _measured := false


func begin(on: CanvasItem, measure: bool) -> void:
	canvas = on
	measuring = measure
	bounds = Rect2()
	_measured = false
	alpha = 1.0
	hat_xf = Transform2D.IDENTITY
	roll = 0.0
	gaze = Vector2.ZERO
	lid = Vector2.ZERO
	lid_tilt = 0.0
	smile = Vector2.ZERO
	lower = 0.0
	eye_size = Vector2.ONE


## draw_set_transform(), remembered so measuring sees the same transform.
func set_frame(origin: Vector2, rotation: float, scale: Vector2) -> void:
	# The transform draw_set_transform() builds: rotated, then scaled.
	var c := cos(rotation)
	var s := sin(rotation)
	_xf = Transform2D(Vector2(c * scale.x, s * scale.y), Vector2(-s * scale.x, c * scale.y), origin)
	if not measuring:
		canvas.draw_set_transform(origin, rotation, scale / FINE)


# --- the pose -------------------------------------------------------------------


## A point of the body at rest, moved to the pose.
func b(x: float, y: float) -> Vector2:
	return Vector2(x * sx, (y - RISE - bob) * sy + drop)


## A point down leg i (0 the left, 1 the right), from the hip (t 0) through
## the knee (0.5) to the foot (1). Legs bend in a smooth curve.
func leg(i: int, t: float) -> Vector2:
	# A quadratic curve through the knee: its control point overshoots it.
	var ctrl := knees[i] * 2.0 - (hips[i] + feet[i]) * 0.5
	return hips[i].lerp(ctrl, t).lerp(ctrl.lerp(feet[i], t), t)


## Leg i from t0 to t1 (see leg()), as a curve `width` wide.
func leg_line(i: int, t0: float, t1: float, c: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for k in 7:
		pts.append(leg(i, lerpf(t0, t1, k / 6.0)))
	polyline(pts, c, width)


## b() for a list of rest points.
func bp(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v: Vector2 in pts:
		out.append(b(v.x, v.y))
	return out


## A point relative to the head's centre, sinking and shrinking with it.
func h(x: float, y: float) -> Vector2:
	return hc + (Vector2(x, y) * (hr / HEAD_R)).rotated(roll)


## A point of a hat, relative to the head's centre.
func t(v: Vector2) -> Vector2:
	return hat_xf * (hc + v)


## Where an eye is (side -1 or 1): where the sprite put them, 6.6 either side
## of the head's centre and 4 below it, sliding a little with the look.
func eye(side: float) -> Vector2:
	return hc + (Vector2(side * 6.6 + look.x * 2.0, 4.05 + look.y * 0.5) + gaze).rotated(roll)


## How open the eyes are: blinking shuts them, happiness widens them. With a
## side, that eye's lid and smile close it too (a wink).
func eye_open(side := 0.0) -> float:
	var open := maxf(1.0 - blink, 0.12) * (1.0 + happy * 0.3)
	if side != 0.0:
		var k := 0 if side < 0.0 else 1
		open *= maxf(1.0 - maxf(lid[k] * 0.85, smile[k] * 0.8), 0.12)
	return open


## Walking away from us: no face, no front-only details.
func from_behind() -> bool:
	return look.y <= -0.6


## Front-only details (lapels, a bow tie) show.
func front() -> bool:
	return not from_behind()


# --- drawing --------------------------------------------------------------------


func col(c: Color) -> Color:
	return Color(c.r, c.g, c.b, c.a * alpha)


func poly(pts: PackedVector2Array, c: Color) -> void:
	if measuring:
		_grow(pts, 0.0)
		return
	var fine := _fine(pts)
	canvas.draw_colored_polygon(fine, col(c))
	# Filled polygons have hard, stepped edges; a thin antialiased line round
	# the edge softens them like the legs (lines) and dots.
	fine.append(fine[0])
	canvas.draw_polyline(fine, col(c), EDGE * FINE, true)


## A closed outline.
func outline(pts: PackedVector2Array, c: Color, width: float) -> void:
	if pts.is_empty():
		return
	var closed := pts.duplicate()
	closed.append(pts[0])
	polyline(closed, c, width)


func polyline(pts: PackedVector2Array, c: Color, width: float) -> void:
	if measuring:
		_grow(pts, width / 2.0)
		return
	canvas.draw_polyline(_fine(pts), col(c), width * FINE, true)


func line(from: Vector2, to: Vector2, c: Color, width: float) -> void:
	if measuring:
		_grow(PackedVector2Array([from, to]), width / 2.0)
		return
	canvas.draw_line(from * FINE, to * FINE, col(c), width * FINE, true)


func dot(at: Vector2, radius: float, c: Color) -> void:
	if measuring:
		_grow(PackedVector2Array([at]), radius)
		return
	canvas.draw_circle(at * FINE, radius * FINE, col(c), true, -1.0, true)


func arc(centre: Vector2, radius: float, from: float, to: float, c: Color, width: float) -> void:
	if measuring:
		_grow(PackedVector2Array([centre]), radius + width / 2.0)
		return
	canvas.draw_arc(centre * FINE, radius * FINE, from, to, 48, col(c), width * FINE, true)


## The two classic eyes, as Player has always drawn them.
func classic_eyes(c: Color) -> void:
	if from_behind():
		return
	for side: float in [-1.0, 1.0]:
		poly(eye_shape(side, 2.0), c)


## Eye `side` (-1 left, 1 right) as an outline, `r` its radius when wide
## open: blinking squashes it, the upper lid cuts it flat (slanting with
## lid_tilt), a smile bends it into an arch, and it turns with the head.
func eye_shape(side: float, r: float) -> PackedVector2Array:
	var k := 0 if side < 0.0 else 1
	var e := eye(side)
	r *= eye_size[k]
	var open := maxf(1.0 - blink, 0.12) * (1.0 + happy * 0.3)
	var hgt := r * open
	var sm := clampf(smile[k], 0.0, 1.0)
	var arch := r * 0.42  # how thick a fully smiling eye's arch is
	var n := 20
	var tops := PackedVector2Array()
	var bottoms := PackedVector2Array()
	for i in n + 1:
		var u := -cos(PI * i / n)  # bunched at the corners, where it curves
		var x := u * r
		var round := sqrt(maxf(1.0 - u * u, 0.0))
		var top := -hgt * round
		var bottom := hgt * round
		# The upper lid: down by lid[k] of the eye's height, slanting.
		var lid_y := -hgt + 2.0 * hgt * lid[k] + lid_tilt * u * side * hgt * 0.55
		top = maxf(top, lid_y)
		# A smile: the lower edge rises into an arch `arch` thick.
		var inner := r - arch
		var arch_y := -sqrt(maxf(inner * inner - x * x, 0.0)) * open + arch * 0.15
		bottom = minf(bottom, hgt - 2.0 * hgt * lower * 0.5)
		bottom = lerpf(bottom, maxf(arch_y, top + arch * 0.5 * open), sm)
		bottom = maxf(bottom, top + 0.12 * r)
		tops.append(Vector2(x, top))
		bottoms.append(Vector2(x, bottom))
	var pts := PackedVector2Array()
	for v in tops:
		pts.append(e + v.rotated(roll))
	for i in range(n, -1, -1):
		pts.append(e + bottoms[i].rotated(roll))
	return pts


## The body between rest heights y0 (higher up) and y1, edge to edge.
func band(y0: float, y1: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 7:
		var y := lerpf(y0, y1, i / 6.0)
		pts.append(b(edges(y).x, y))
	for i in 7:
		var y := lerpf(y1, y0, i / 6.0)
		pts.append(b(edges(y).y, y))
	poly(pts, c)


## The body from x0 to x1 at rest, from its top edge down to the hem.
func stripe(x0: float, x1: float, c: Color) -> void:
	var pts := PackedVector2Array([b(x0, HEM)])
	for i in 6:
		var x := lerpf(x0, x1, i / 5.0)
		pts.append(b(x, top_at(x)))
	pts.append(b(x1, HEM))
	poly(pts, c)


func star(at: Vector2, radius: float, c: Color, points := 5, inner := 0.45) -> void:
	if radius < 0.2:
		return
	poly(star_points(at, radius, points, inner), c)


## An arc as a polyline (it can sit anywhere, and fades like the rest).
func arc_line(
	centre: Vector2, radius: float, from: float, to: float, c: Color, width: float
) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := lerpf(from, to, i / 8.0)
		pts.append(centre + Vector2(cos(a), sin(a)) * radius)
	polyline(pts, c, width)


## A centre line: long dash, gap, dot, gap, as drawings mark an axis.
func dash_dot(from: Vector2, to: Vector2, c: Color, width: float) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var d := (to - from) / length
	var pattern: Array[float] = [5.0, 1.6, 1.0, 1.6]
	var pos := 0.0
	var k := 0
	while pos < length:
		var seg := pattern[k % 4]
		if k % 2 == 0:
			line(from + d * pos, from + d * minf(pos + seg, length), c, width)
		pos += seg
		k += 1


# --- hats: points relative to the head's centre, through hat_xf ------------------


func hat_poly(offsets: PackedVector2Array, c: Color) -> void:
	poly(_hat_points(offsets), c)


func hat_outline(offsets: PackedVector2Array, c: Color, width: float) -> void:
	outline(_hat_points(offsets), c, width)


func hat_polyline(offsets: PackedVector2Array, c: Color, width: float) -> void:
	polyline(_hat_points(offsets), c, width)


func hat_line(from: Vector2, to: Vector2, c: Color, width: float) -> void:
	line(t(from), t(to), c, width)


func hat_dot(at: Vector2, radius: float, c: Color) -> void:
	dot(t(at), radius, c)


func hat_star(at: Vector2, radius: float, c: Color) -> void:
	hat_poly(star_points(at, radius), c)


func _hat_points(offsets: PackedVector2Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for v in offsets:
		pts.append(t(v))
	return pts


# --- shapes -------------------------------------------------------------------------


## The body's outline at rest: the bell, then its rounded lip below the hem.
func body_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 25:
		var a := PI * i / 24.0
		var y := dome_top(cos(a) * BODY_HALF)
		pts.append(b(cos(a) * BODY_HALF + (back_inset(y) if a > PI / 2.0 else 0.0), y))
	for i in range(1, 24):
		var a := PI * i / 24.0
		pts.append(b(-cos(a) * BODY_HALF, HEM + sin(a) * LIP))
	return pts


## Side on, the sprite drew his back (the left side before mirroring) a
## little straighter: its edge sits this far in from the bell's at rest
## height y, most of the way up, nothing at the hem.
func back_inset(y: float) -> float:
	var k := clampf((HEM - y) / (HEM - BODY_TOP), 0.0, 1.0)
	return 1.75 * pow(sin(k * PI / 2.0), 2.0) * side_on


## The body's edge at rest height y: x of the left (back) and right edges.
func edges(y: float) -> Vector2:
	var w := dome_w(y)
	return Vector2(-w + back_inset(y), w)


## The body's top edge at rest x this frame (the back may be inset).
func top_at(x: float) -> float:
	if x >= 0.0 or side_on <= 0.0:
		return dome_top(x)
	# The back edge rises inwards, so the height where it passes x is found
	# by halving: between the hem (far out) and the top (at the centre).
	var lo := HEM
	var hi := BODY_TOP
	for _i in 24:
		var mid := (lo + hi) / 2.0
		if edges(mid).x < x:
			lo = mid
		else:
			hi = mid
	return (lo + hi) / 2.0


## Half the body's width at rest height y.
static func dome_w(y: float) -> float:
	var k := clampf((HEM - y) / (HEM - BODY_TOP), 0.0, 1.0)
	return BODY_HALF * sqrt(1.0 - pow(k, DOME))


## The body's top edge at rest x.
static func dome_top(x: float) -> float:
	var k := clampf(x / BODY_HALF, -1.0, 1.0)
	return HEM - (HEM - BODY_TOP) * pow(1.0 - k * k, 1.0 / DOME)


## A star's points, `inner` the ratio of the inner radius to the outer.
static func star_points(
	at: Vector2, radius: float, points := 5, inner := 0.45
) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r := radius if i % 2 == 0 else radius * inner
		var a := -PI / 2.0 + PI * i / points
		pts.append(at + Vector2(cos(a), sin(a)) * r)
	return pts


static func ellipse(c: Vector2, rx: float, ry: float, n := 20, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


## A rectangle with rounded corners, `half` its half-size.
static func rrect(c: Vector2, half: Vector2, radius: float, n := 4) -> PackedVector2Array:
	var r := minf(radius, minf(half.x, half.y))
	var corners: Array[Vector2] = [
		Vector2(half.x - r, -half.y + r),
		Vector2(half.x - r, half.y - r),
		Vector2(-half.x + r, half.y - r),
		Vector2(-half.x + r, -half.y + r),
	]
	var pts := PackedVector2Array()
	for k in 4:
		for i in n + 1:
			var a := -PI / 2.0 + PI / 2.0 * k + PI / 2.0 * i / n
			pts.append(c + corners[k] + Vector2(cos(a), sin(a)) * r)
	return pts


## A shape tapering along a curve, `widths` either side of each spine point:
## a horn, a bent hat.
static func tapered(spine: Array[Vector2], widths: Array[float]) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n := spine.size()
	for i in n:
		var d: Vector2
		if i == 0:
			d = spine[1] - spine[0]
		elif i == n - 1:
			d = spine[i] - spine[i - 1]
		else:
			d = spine[i + 1] - spine[i - 1]
		var normal := Vector2(-d.y, d.x).normalized()
		left.append(spine[i] + normal * widths[i])
		right.append(spine[i] - normal * widths[i])
	var out := left.duplicate()
	if widths[n - 1] > 0.0:
		out.append(right[n - 1])  # a blunt end; a pointed one shares its tip
	for i in range(n - 2, -1, -1):
		out.append(right[i])
	return out


## The band of a circle of radius r between heights y0 and y1 above its centre.
static func chord_band(r: float, y0: float, y1: float) -> PackedVector2Array:
	var w0 := sqrt(maxf(r * r - y0 * y0, 0.0))
	var w1 := sqrt(maxf(r * r - y1 * y1, 0.0))
	return PackedVector2Array(
		[Vector2(-w0, y0), Vector2(w0, y0), Vector2(w1, y1), Vector2(-w1, y1)]
	)


## Points turned by `angle` about `pivot`.
static func rotated(pts: Array, pivot: Vector2, angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v: Vector2 in pts:
		out.append(pivot + (v - pivot).rotated(angle))
	return out


static func _fine(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] * FINE
	return out


func _grow(pts: PackedVector2Array, pad: float) -> void:
	if alpha <= 0.0:
		return  # faded right out: not part of what is seen
	var reach := _xf.get_scale().abs() * pad  # a round end grows with the frame
	for p in pts:
		var at := _xf * p
		var box := Rect2(at - reach, reach * 2.0)
		bounds = box if not _measured else bounds.merge(box)
		_measured = true
