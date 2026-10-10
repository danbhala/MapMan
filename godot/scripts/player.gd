class_name Player
extends Node2D
## MapMan himself, drawn in code: a round head, a bell of a body and two legs,
## with eyes that look around and blink. With `art = "woman"` the same figure
## wears a bow and is MapWoman, who waits at the end of the game.
##
## The facing API is the one the sprite version had (face_*, vanish,
## show_player, update_at, death_finished). The dials the game and the menus
## turn are look, land(), cheer(), spin_around(), set_stuck() and face_death().
##
## He wears one look from the wardrobe at a time (`outfit`, docs/wardrobe).
## He is drawn in layers, back to front: back, legs, body, neck, head, eyes,
## face, hat, front. Outfits adds the look's parts to each; every part follows
## the same dials because it is drawn from the same pose (OutfitPen). Seen
## from behind, a cape covers his back and the face and front details go.
## Dying, the body swallows the head as ever, things sticking out of the head
## and neck fade first, and the hat flies off.

const HEAD_COLOR := Color("#dfe9ff")
const BODY_COLOR := Color.BLACK
const EYE_COLOR := Color("#4e8fb5")
const WEB_COLOR := Color(0.93, 0.95, 1.0)
## How long the death animation plays before the game moves on (the sprite
## version's 42 frames at 60 fps).
const DEATH_SECONDS := 0.7
## Feet stand this far above the tile's centre, like the sprite's anchor did.
const FEET_LIFT := 4.0
## Steps per second of walking, as a phase rate: the sprite's 14-frame walk
## took one tile (Main.STOP_TIME) at 60 frames a second.
const STRIDE := TAU * 60.0 / 14.0
## He is drawn with the sprite's proportions, measured off its 176x320
## frames (307.2 px tall there, 3.71 px to one of these units) and scaled to
## stand as tall as ever: 77 units from his feet to the top of his head.
const FIGURE_SCALE := 77.0 / 82.75
## The hips, hidden under the body's lip.
const HIP_Y := -24.12
const LEG_WIDTH := 5.1
const FOOT_R := 2.55
## A leg's pose is [hip x, foot x, foot y, bow]: it curves from the hip to
## the foot, bowing `bow` out from the hip's x at mid height. Standing, the
## legs hang straight, a little off centre, as the sprite drew them.
const IDLE_LEGS: Array = [[-5.6, -5.6, 4.04, 0.0], [6.5, 6.5, 4.04, 0.0]]
## The sprite's walks, a pose a frame, fitted to each of its frames: 14 side
## on (the leg on the other side reads the same table seven frames on) and
## 14 for each leg towards us (FRONT) and away (BACK).
const SIDE_STEPS: Array = [
	[-5.52, -5.52, 3.91, 0.00],
	[-5.66, -7.81, 2.96, 1.21],
	[-7.14, -10.64, 2.56, 1.89],
	[-4.98, -9.03, 1.48, 2.16],
	[-0.94, -6.33, 1.08, 3.50],
	[3.64, -0.94, 0.54, 1.08],
	[7.14, 4.18, 0.40, 1.08],
	[8.22, 7.95, 1.48, 0.54],
	[9.43, 12.93, 2.02, 1.35],
	[8.35, 10.37, 3.91, 0.81],
	[6.60, 6.74, 4.04, 0.27],
	[3.91, 3.91, 4.04, 0.54],
	[1.21, 1.48, 3.91, 0.27],
	[-2.29, -2.02, 3.91, 0.27],
]
const FRONT_LEFT: Array = [
	[-5.82, -5.28, 3.10, 0.00],
	[-5.68, -5.28, 1.21, 0.00],
	[-5.82, -5.28, -0.81, 0.13],
	[-5.82, -5.15, -2.96, 0.00],
	[-5.82, -4.88, -4.31, -0.27],
	[-5.82, -4.88, -5.52, -0.27],
	[-5.68, -5.01, -5.93, -0.40],
	[-5.68, -4.88, -6.47, -0.40],
	[-5.82, -5.28, -5.52, 0.00],
	[-5.68, -5.42, -3.91, 0.00],
	[-5.82, -5.28, -2.16, 0.00],
	[-5.82, -5.68, -0.00, 0.27],
	[-5.68, -5.68, 2.56, 0.00],
	[-5.82, -5.68, 3.91, 0.13],
]
const FRONT_RIGHT: Array = [
	[6.84, 6.30, -6.47, 0.54],
	[6.30, 6.17, -5.66, 0.27],
	[6.30, 5.77, -3.91, 0.27],
	[6.30, 6.04, -2.16, 0.27],
	[6.04, 6.17, -0.00, 0.27],
	[6.04, 6.17, 2.69, 0.00],
	[6.04, 6.17, 4.04, 0.27],
	[6.30, 6.17, 3.23, 0.27],
	[6.44, 5.90, 1.35, 0.27],
	[6.30, 6.04, -0.81, 0.27],
	[6.30, 6.04, -2.96, 0.13],
	[6.44, 5.77, -4.31, 1.35],
	[6.84, 5.90, -5.52, 0.67],
	[6.84, 6.17, -5.93, 0.54],
]
const BACK_LEFT: Array = [
	[-5.82, -5.68, 3.91, 0.13],
	[-5.28, -5.68, 3.50, 0.40],
	[-5.28, -5.68, 1.88, 0.27],
	[-4.74, -5.68, -0.41, 0.13],
	[-4.74, -5.15, -2.96, 0.00],
	[-4.74, -4.88, -4.72, -0.13],
	[-4.07, -3.80, -5.93, 0.00],
	[-4.34, -4.34, -5.66, 0.13],
	[-4.61, -4.47, -3.77, 0.00],
	[-4.61, -4.47, -2.16, 0.00],
	[-4.74, -4.47, -0.27, -0.13],
	[-5.15, -4.88, 1.35, -0.13],
	[-5.28, -4.74, 2.56, 0.00],
	[-5.82, -5.68, 3.10, 0.13],
]
const BACK_RIGHT: Array = [
	[7.79, 7.52, -5.52, -0.13],
	[7.92, 7.65, -3.77, 0.27],
	[8.19, 7.65, -2.16, 0.00],
	[8.06, 7.65, -0.41, 0.27],
	[7.65, 7.11, 1.35, 0.27],
	[7.11, 6.71, 2.56, 0.54],
	[6.44, 6.44, 2.96, 0.13],
	[6.30, 6.44, 3.91, 0.13],
	[6.30, 6.71, 3.50, 0.00],
	[6.30, 6.84, 1.88, 0.00],
	[6.30, 7.38, -0.41, 0.27],
	[6.84, 7.38, -2.96, 0.13],
	[7.11, 7.38, -4.72, 0.40],
	[7.65, 7.38, -5.93, 0.13],
]
## How far the head rises (towards or away from us) or dips (side on) each
## step: the sprite's head moved, its body never did.
const HEAD_RISE: Array[float] = [
	0.0, 0.43, 1.32, 2.29, 1.32, 0.43, 0.0, 0.0, 0.43, 1.32, 2.29, 1.32, 0.43, 0.0
]
const HEAD_DIP: Array[float] = [
	0.0, 0.86, 1.72, 2.16, 1.72, 0.86, 0.4, 0.4, 0.86, 1.72, 2.16, 1.72, 0.86, 0.4
]

## "man" or "woman": whether the figure wears MapWoman's bow. Read each draw,
## so the ending can turn the figure waiting there into either.
var art := "man"
## The look he wears: a Wardrobe id ("classic" is plain MapMan).
var outfit := "classic":
	set(id):
		outfit = id
		queue_redraw()
var is_hidden := true

## Where the eyes (and a little of the head) point: -1..1 on each axis.
## Follows the facing unless `auto_look` is off; the menus drive it from tilt.
var look := Vector2.ZERO
var auto_look := true
## 0 standing .. 1 walking. Eases towards the facing's walk state.
var walking := 0.0
## 0 front or back on .. 1 side on: which of the sprite's walks his legs
## follow (_leg_pose()).
var side_on := 0.0
## Lands on a tile: a squash that springs back.
var squash := 0.0
## 0 free .. 1 wrapped in cobweb (a sticky tile).
var web := 0.0
## 0..1 while the cobweb flies off after a shake.
var shake_off := 0.0
var shake_x := 0.0
## 0 alive .. 1 swallowed by his own body (a death tile or the clock).
var dead := 0.0
## 0..1 for a full turn on the spot, when the controls reverse.
var spin := 0.0
## 0..1 wide-eyed, after a star or the exit.
var happy := 0.0
## -1 facing left (mirrored) .. 1 facing right.
var flip := 1.0

var _facing := Vector2i.ZERO  # ZERO is the neutral, front-on idle
var _walk_target := 0.0
var _look_target := Vector2.ZERO
var _hop := 0.0
## A jump when he is tapped on a menu: higher and longer than a hop, with a
## squash as he lands.
var _jump := 0.0
var _phase := 0.0
var _blink := 0.0
var _blink_clock := 0.0
var _next_blink := 2.0
var _dying := false
var _death_clock := 0.0
var _idle_clock := 0.0
var _death_tween: Tween
var _web_tween: Tween
var _pen := OutfitPen.new()


func _ready() -> void:
	z_index = 10
	_next_blink = randf_range(1.6, 4.0)
	vanish()


# --- facing (the sprite version's API) ----------------------------------------


func _face(dir: Vector2i, walk: bool) -> void:
	_dying = false
	_facing = dir
	_walk_target = 1.0 if walk else 0.0
	if dir.x != 0:
		_set_flip(1.0 if dir.x > 0 else -1.0)
		_look_target = Vector2(0.9, 0.0)
	elif dir.y < 0:
		_look_target = Vector2(0.0, -1.0)  # from behind: no face
	elif dir.y > 0:
		_look_target = Vector2(0.0, 0.3)
	else:
		_look_target = Vector2.ZERO
	queue_redraw()


func _set_flip(to: float) -> void:
	if is_equal_approx(flip, to):
		return
	if not Blueprint.motion() or not is_inside_tree():
		flip = to
		return
	create_tween().tween_property(self, "flip", to, 0.12)


func face_death() -> void:
	_dying = true
	_death_clock = 0.0
	_walk_target = 0.0
	squash = 1.0
	if Blueprint.motion() and is_inside_tree():
		_death_tween = create_tween()
		_death_tween.tween_property(self, "dead", 1.0, 0.4).set_delay(0.08)
	else:
		dead = 1.0
	queue_redraw()


## Back on his feet, free of cobweb and spin: for a new level or attempt.
func reset_pose() -> void:
	if _death_tween:
		_death_tween.kill()
		_death_tween = null
	if _web_tween:
		_web_tween.kill()
		_web_tween = null
	_dying = false
	dead = 0.0
	web = 0.0
	shake_off = 0.0
	shake_x = 0.0
	spin = 0.0
	squash = 0.0
	happy = 0.0
	_hop = 0.0
	_jump = 0.0
	queue_redraw()


func face_up() -> void:
	_face(Vector2i.UP, true)


func face_down() -> void:
	_face(Vector2i.DOWN, true)


func face_left() -> void:
	_face(Vector2i.LEFT, true)


func face_right() -> void:
	_face(Vector2i.RIGHT, true)


func face_up_idle() -> void:
	_face(Vector2i.UP, false)


func face_down_idle() -> void:
	_face(Vector2i.DOWN, false)


func face_left_idle() -> void:
	_face(Vector2i.LEFT, false)


func face_right_idle() -> void:
	_face(Vector2i.RIGHT, false)


func face_idle() -> void:
	_face(Vector2i.ZERO, false)


func face_direction(dir: Vector2i, walk: bool) -> void:
	_face(dir, walk)


## The way he faces, in screen directions; ZERO facing front, at rest.
func facing() -> Vector2i:
	return _facing


func vanish() -> void:
	visible = false
	is_hidden = true


func show_player() -> void:
	if is_hidden and Blueprint.motion() and is_inside_tree():
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	is_hidden = false
	visible = true
	queue_redraw()


# --- the dials ------------------------------------------------------------------


## Stepped onto a tile: a little squash that springs back.
func land() -> void:
	if Blueprint.motion():
		squash = 0.4


## A star, a life or the exit: wide eyes, and a hop unless motion is reduced.
func cheer() -> void:
	happy = 1.0
	if Blueprint.motion():
		_hop = 1.0


## Tapped on a menu: wide eyes and a jump (just the eyes with reduced motion).
func jump() -> void:
	happy = 1.0
	if Blueprint.motion() and _jump == 0.0:
		_jump = 1.0


## The controls reversed: a full turn on the spot.
func spin_around() -> void:
	if not Blueprint.motion() or not is_inside_tree():
		return
	spin = 0.0
	create_tween().tween_property(self, "spin", 1.0, 0.45).set_trans(Tween.TRANS_SINE)


## A sticky tile wraps him in cobweb; shaking it off sends the strands flying.
## A new web stops any shake-off still playing, so a tile two steps on wraps
## him again instead of being overwritten by the old tween.
func set_stuck(on: bool) -> void:
	if _web_tween:
		_web_tween.kill()
		_web_tween = null
	shake_x = 0.0
	if on:
		shake_off = 0.0
		if Blueprint.motion() and is_inside_tree():
			_web_tween = create_tween()
			_web_tween.tween_property(self, "web", 1.0, 0.45)
		else:
			web = 1.0
	elif web > 0.0:
		if Blueprint.motion() and is_inside_tree():
			_web_tween = create_tween().set_parallel()
			_web_tween.tween_method(
				func(k: float): shake_x = sin(k * 50.0) * 6.0 * (1.0 - k), 0.0, 1.0, 0.5
			)
			_web_tween.tween_property(self, "shake_off", 1.0, 0.5)
			_web_tween.tween_property(self, "web", 0.0, 0.5).set_delay(0.15)
		else:
			web = 0.0
			shake_off = 0.0
	queue_redraw()


## Move to a screen position and advance the animation by elapsed time.
func update_at(pos: Vector2, delta: float) -> void:
	position = pos
	tick(delta)


## Advance the animation by elapsed time without moving.
func tick(delta: float) -> void:
	walking = move_toward(walking, _walk_target, delta * 6.0)
	side_on = move_toward(side_on, 1.0 if _facing.x != 0 else 0.0, delta * 8.0)
	_phase += delta * STRIDE * walking
	_idle_clock += delta
	if auto_look:
		var target := _look_target
		if _walk_target == 0.0 and _facing == Vector2i.ZERO:
			target.x += sin(_idle_clock * 0.8) * 0.25  # glancing about while idle
		look = look.lerp(target, minf(1.0, delta * 6.0))
	_blink_clock += delta
	if _blink_clock > _next_blink:
		_blink_clock = 0.0
		_next_blink = randf_range(1.6, 4.0)
	_blink = clampf(1.0 - absf(_blink_clock - 0.08) / 0.08, 0.0, 1.0)
	squash = move_toward(squash, 0.0, delta * 3.0)
	happy = move_toward(happy, 0.0, delta * 0.8)
	_hop = move_toward(_hop, 0.0, delta * 4.0)
	if _jump > 0.0:
		_jump = move_toward(_jump, 0.0, delta * 2.2)
		if _jump == 0.0:
			squash = 0.7
	if _dying:
		_death_clock += delta
	queue_redraw()


## True once the death animation has played through.
func death_finished() -> bool:
	return _dying and _death_clock >= DEATH_SECONDS


# --- drawing --------------------------------------------------------------------


func _draw() -> void:
	_paint(false)


## The box he and his look cover in this pose, in his own units. Draws
## nothing, so it works outside _draw() and without a screen.
func measure() -> Rect2:
	return _paint(true)


## How tall he stands in look `id`, from his feet to the top of his head or
## hat, facing us: for the dimension line on the menus.
static func standing_height(id: String) -> float:
	var p := Player.new()
	p.outfit = id
	var box := p.measure()
	p.free()
	return -box.position.y - FEET_LIFT


func _paint(measuring: bool) -> Rect2:
	var fx := flip * cos(spin * TAU)
	# A landing hop or a jump; walking never moves the body.
	var bob := sin(_hop * PI) * 8.0 + sin(_jump * PI) * 24.0
	var sy := 1.0 - squash * 0.18
	var sx := 1.0 + squash * 0.18
	var pal := {"body": BODY_COLOR, "head": HEAD_COLOR, "eyes": EYE_COLOR}
	pal.merge(Outfits.palette(outfit), true)
	var body: Color = pal.body
	var origin := Vector2(shake_x, -FEET_LIFT)
	var mirror := Vector2(fx if absf(fx) > 0.05 else 0.05, 1.0) * FIGURE_SCALE
	# Dying, the legs draw up into the body, which settles on the ground, and
	# the head sinks into it, as the sprite's death frames did; the body is
	# drawn over the head to swallow it.
	var leg := 1.0 - dead
	var drop := dead * (OutfitPen.RISE - OutfitPen.HEM - OutfitPen.LIP)
	var sink := dead * 45.0
	# What sticks out of the head fades before the body takes it.
	var fade := clampf(1.0 - dead * 2.2, 0.0, 1.0)

	var pen := _pen
	pen.begin(self, measuring)
	pen.look = look
	pen.walking = walking
	pen.side_on = side_on
	pen.phase = _phase
	pen.idle_clock = _idle_clock
	pen.blink = _blink
	pen.happy = happy
	pen.squash = squash
	pen.dead = dead
	pen.bob = bob
	pen.sx = sx
	pen.sy = sy
	pen.drop = drop
	pen.motion = Blueprint.motion()
	pen.hips.clear()
	pen.knees.clear()
	pen.feet.clear()
	for i in 2:
		var pose := _leg_pose(i)
		var hip := pen.b(pose[0].x, pose[0].y)
		pen.hips.append(hip)
		pen.knees.append(hip + (pen.b(pose[1].x, pose[1].y) - hip) * leg)
		pen.feet.append(hip + (pen.b(pose[2].x, pose[2].y) - hip) * leg)
	var pts := pen.body_points()
	pen.body = pts
	var head_at := Vector2(
		look.x * 5.3, (-61.6 - OutfitPen.RISE - bob + _head_bob() - squash * 5.0) * sy
	)
	pen.hc = head_at + Vector2(0.0, sink)
	pen.hr = OutfitPen.HEAD_R * (1.0 - dead * 0.15)
	var has_back := Outfits.has_back(outfit)
	var behind := pen.from_behind()
	var woman := art == "woman" or outfit == "mapwoman"

	if has_back and (not behind or dead > 0.0):
		pen.set_frame(origin, 0.0, mirror)
		pen.alpha = 1.0 - dead
		Outfits.draw(pen, Outfits.Layer.BACK, outfit)
		pen.alpha = 1.0
	pen.set_frame(origin, 0.0, mirror)
	for i in 2:
		_draw_leg(i, pal)
	Outfits.draw(pen, Outfits.Layer.LEGS, outfit)
	pen.set_frame(origin, 0.0, mirror)
	if dead > 0.0:
		_draw_head(pal)  # swallowed whole
		if woman:
			_draw_bow(pen.hc + Vector2(-9.0, -11.0), Color(body, body.a * fade))
		pen.alpha = fade
		Outfits.draw(pen, Outfits.Layer.HEAD, outfit)
		pen.alpha = 1.0
		_draw_eyes(pal)
		pen.alpha = fade
		Outfits.draw(pen, Outfits.Layer.FACE, outfit)
		pen.alpha = 1.0
		_draw_body(pts, pal)
		Outfits.draw(pen, Outfits.Layer.BODY, outfit)
		pen.alpha = 1.0 - dead
		Outfits.draw(pen, Outfits.Layer.NECK, outfit)
		pen.alpha = 1.0
		_draw_hat_flying(head_at)
	else:
		# Seen from behind, the body is in front of the head, as the sprite
		# drew his back; otherwise the head is in front.
		if behind:
			_draw_head_and_hair(pal, woman, body)
		_draw_body(pts, pal)
		Outfits.draw(pen, Outfits.Layer.BODY, outfit)
		Outfits.draw(pen, Outfits.Layer.NECK, outfit)
		if has_back and behind:
			Outfits.draw(pen, Outfits.Layer.BACK, outfit)  # a cape covers his back
		if not behind:
			_draw_head_and_hair(pal, woman, body)
		_draw_eyes(pal)
		Outfits.draw(pen, Outfits.Layer.FACE, outfit)
		Outfits.draw(pen, Outfits.Layer.HAT, outfit)
	Outfits.draw(pen, Outfits.Layer.FRONT, outfit)
	if web > 0.02 and not measuring:
		_draw_web(origin)
	pen.set_frame(Vector2.ZERO, 0.0, Vector2.ONE)
	return pen.bounds


## Hip, knee and foot of leg i (0 the left, 1 the right, before mirroring)
## at rest: the sprite's walk for the way he faces (FRONT, BACK or SIDE
## tables), blended between its frames by the phase, and with his standing
## pose by `walking`.
func _leg_pose(i: int) -> Array[Vector2]:
	var u := fposmod(_phase / TAU, 1.0) * 14.0
	var facing_tables: Array = (
		[BACK_LEFT, BACK_RIGHT] if _pen.from_behind() else [FRONT_LEFT, FRONT_RIGHT]
	)
	var walk := _mix(_frame(facing_tables[i], u), _frame(SIDE_STEPS, u + 7.0 * i), side_on)
	var e := _mix(IDLE_LEGS[i], walk, walking)
	var hip := Vector2(e[0], HIP_Y)
	var foot := Vector2(e[1], e[2])
	var ctrl := Vector2(e[0] + e[3], (HIP_Y + e[2]) / 2.0)
	# The knee is the middle of the curve the hip, control and foot make.
	return [hip, hip * 0.25 + ctrl * 0.5 + foot * 0.25, foot]


## How much the head is above (negative) or below where it stands, walking:
## it nods twice a walk cycle, up towards or away from us, down side on.
func _head_bob() -> float:
	var u := fposmod(_phase / TAU, 1.0) * 14.0
	return lerpf(-_keyframe(HEAD_RISE, u), _keyframe(HEAD_DIP, u), side_on) * walking


## A looping table of values, one a frame, read at frame `u` (blended).
static func _keyframe(keys: Array[float], u: float) -> float:
	var i := floori(u) % keys.size()
	return lerpf(keys[i], keys[(i + 1) % keys.size()], u - floorf(u))


## A looping table of poses (lists of numbers), read at frame `u` (blended).
static func _frame(poses: Array, u: float) -> Array:
	var i := floori(u) % poses.size()
	return _mix(poses[i], poses[(i + 1) % poses.size()], u - floorf(u))


static func _mix(a: Array, b: Array, t: float) -> Array:
	var out := []
	for k in a.size():
		out.append(lerpf(a[k], b[k], t))
	return out


func _draw_leg(i: int, pal: Dictionary) -> void:
	var legs: Color = pal.get("legs", pal.body)
	var foot := _pen.feet[i]
	if pal.has("glow"):
		_pen.leg_line(i, 0.0, 1.0, Color(pal.glow, 0.35), LEG_WIDTH + 4.0)
		_pen.dot(foot, FOOT_R + 2.0, Color(pal.glow, 0.35))
	if pal.has("leg_outline"):
		_pen.leg_line(i, 0.0, 1.0, pal.leg_outline, LEG_WIDTH + 2.0)
		_pen.dot(foot, FOOT_R + 1.0, pal.leg_outline)
		_pen.leg_line(i, 0.0, 1.0, legs, LEG_WIDTH - 1.0)
		_pen.dot(foot, FOOT_R - 0.5, legs)
	else:
		_pen.leg_line(i, 0.0, 1.0, legs, LEG_WIDTH)
		_pen.dot(foot, FOOT_R, legs)


func _draw_body(pts: PackedVector2Array, pal: Dictionary) -> void:
	if pal.has("glow"):
		_pen.outline(pts, Color(pal.glow, 0.3), 6.0)
	_pen.poly(pts, pal.body)
	if pal.has("outline"):
		_pen.outline(pts, pal.outline, 1.4)
	if pal.has("glow"):
		_pen.outline(pts, pal.glow, 1.3)


## The head, MapWoman's bow and the look's head layer.
func _draw_head_and_hair(pal: Dictionary, woman: bool, body: Color) -> void:
	_draw_head(pal)
	if woman:
		_draw_bow(_pen.hc + Vector2(-9.0, -11.0), body)
	Outfits.draw(_pen, Outfits.Layer.HEAD, outfit)


func _draw_head(pal: Dictionary) -> void:
	if Outfits.head_shape(_pen, outfit, pal.head):
		return
	var hc := _pen.hc
	var r := _pen.hr
	if pal.has("head_glow"):
		_pen.arc(hc, r + 0.6, 0.0, TAU, Color(pal.head_glow, 0.3), 4.5)
	_pen.dot(hc, r, pal.head)
	if pal.has("head_outline"):
		_pen.arc(hc, r, 0.0, TAU, pal.head_outline, 1.3)
	if pal.has("head_glow"):
		_pen.arc(hc, r, 0.0, TAU, pal.head_glow, 1.1)


func _draw_eyes(pal: Dictionary) -> void:
	if not Outfits.eyes(_pen, outfit, pal.eyes):
		_pen.classic_eyes(pal.eyes)


func _draw_bow(at: Vector2, color: Color) -> void:
	for side: float in [-1.0, 1.0]:
		var loop := PackedVector2Array()
		for k in 14:
			var a := TAU * k / 14.0
			loop.append(at + Vector2(side * 5.0 + cos(a) * 5.0, sin(a) * 3.2).rotated(-0.5))
		_pen.poly(loop, color)
	_pen.dot(at, 2.2, color)


## The hat leaves his head as he dies, from where the head was before it
## sank: up, back and turning, fading out. Worked out from `dead`, so nothing
## is left to reset.
func _draw_hat_flying(head_at: Vector2) -> void:
	if dead >= 0.98:
		return
	var pen := _pen
	var keep := pen.hc
	pen.hc = head_at
	var pivot := head_at + Vector2(0.0, -OutfitPen.HEAD_R)
	var lift := Vector2(-dead * 9.0, -dead * 30.0)
	pen.hat_xf = (
		Transform2D(0.0, pivot + lift)
		* Transform2D(-dead * 1.3, Vector2.ZERO)
		* Transform2D(0.0, -pivot)
	)
	pen.alpha = clampf(1.0 - dead * 1.1, 0.0, 1.0)
	Outfits.draw(pen, Outfits.Layer.HAT, outfit)
	pen.alpha = 1.0
	pen.hat_xf = Transform2D.IDENTITY
	pen.hc = keep


## Cobweb strands anchored on him; shaken, they fly outwards and fade.
func _draw_web(origin: Vector2) -> void:
	draw_set_transform(origin, 0.0, Vector2.ONE)
	var wc := Vector2(0, -46)
	var wcol := Color(WEB_COLOR, web * (1.0 - shake_off) * 0.9)
	for i in 9:
		var a := TAU * i / 9.0 - 0.3
		var reach := 30.0 * web + shake_off * 40.0
		var drift := Vector2(cos(a), sin(a)) * shake_off * 30.0
		draw_line(
			wc + drift,
			wc + Vector2(cos(a) * reach * 1.1, sin(a) * reach * 1.3) + drift,
			wcol,
			1.0,
			true
		)
	for r: float in [10.0, 19.0, 27.0]:
		var ring := PackedVector2Array()
		for i in 19:
			var a := TAU * i / 18.0
			var rr := r * web + shake_off * 12.0
			ring.append(wc + Vector2(cos(a) * rr * 1.1, sin(a) * rr * 1.3 + sin(a * 4.5) * 1.2))
		draw_polyline(ring, wcol, 0.9, true)
