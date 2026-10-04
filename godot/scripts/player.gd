class_name Player
extends Node2D
## MapMan himself, drawn in code: a round head, a bell of a body and two legs,
## with eyes that look around and blink. With `art = "woman"` the same figure
## wears a bow and is MapWoman, who waits at the end of the game.
##
## The facing API is the one the sprite version had (face_*, vanish,
## show_player, update_at, death_finished). The dials the game and the menus
## turn are look, land(), cheer(), spin_around(), set_stuck() and face_death().

const HEAD_COLOR := Color("#dfe9ff")
const BODY_COLOR := Color.BLACK
const EYE_COLOR := Color("#4e8fb5")
const WEB_COLOR := Color(0.93, 0.95, 1.0)
## How long the death animation plays before the game moves on (the sprite
## version's 42 frames at 60 fps).
const DEATH_SECONDS := 0.7
## Feet stand this far above the tile's centre, like the sprite's anchor did.
const FEET_LIFT := 4.0
## Steps per second of walking, as a phase rate.
const STRIDE := 9.0

## "man" or "woman". Set before adding to the tree.
var art := "man"
var is_hidden := true

## Where the eyes (and a little of the head) point: -1..1 on each axis.
## Follows the facing unless `auto_look` is off; the menus drive it from tilt.
var look := Vector2.ZERO
var auto_look := true
## 0 standing .. 1 walking. Eases towards the facing's walk state.
var walking := 0.0
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
var _phase := 0.0
var _blink := 0.0
var _blink_clock := 0.0
var _next_blink := 2.0
var _dying := false
var _death_clock := 0.0
var _idle_clock := 0.0
var _death_tween: Tween


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
	_dying = false
	dead = 0.0
	web = 0.0
	shake_off = 0.0
	shake_x = 0.0
	spin = 0.0
	squash = 0.0
	happy = 0.0
	_hop = 0.0
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
	squash = 0.4


## A star, a life or the exit: wide eyes and a hop.
func cheer() -> void:
	happy = 1.0
	_hop = 1.0


## The controls reversed: a full turn on the spot.
func spin_around() -> void:
	if not Blueprint.motion() or not is_inside_tree():
		return
	spin = 0.0
	create_tween().tween_property(self, "spin", 1.0, 0.45).set_trans(Tween.TRANS_SINE)


## A sticky tile wraps him in cobweb; shaking it off sends the strands flying.
func set_stuck(on: bool) -> void:
	if on:
		shake_off = 0.0
		if Blueprint.motion() and is_inside_tree():
			create_tween().tween_property(self, "web", 1.0, 0.45)
		else:
			web = 1.0
	elif web > 0.0:
		if Blueprint.motion() and is_inside_tree():
			var tw := create_tween().set_parallel()
			tw.tween_method(
				func(k: float): shake_x = sin(k * 50.0) * 6.0 * (1.0 - k), 0.0, 1.0, 0.5
			)
			tw.tween_property(self, "shake_off", 1.0, 0.5)
			tw.tween_property(self, "web", 0.0, 0.5).set_delay(0.15)
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
	if _dying:
		_death_clock += delta
	queue_redraw()


## True once the death animation has played through.
func death_finished() -> bool:
	return _dying and _death_clock >= DEATH_SECONDS


# --- drawing --------------------------------------------------------------------


func _draw() -> void:
	var fx := flip * cos(spin * TAU)
	var bob := absf(sin(_phase)) * 2.5 * walking + sin(_hop * PI) * 8.0
	var sy := 1.0 - squash * 0.18
	var sx := 1.0 + squash * 0.18
	var swing := sin(_phase) * 0.5 * walking
	var lean := (look.x * 0.05 + walking * 0.08) * signf(fx)
	var body := BODY_COLOR
	var head := HEAD_COLOR
	var eyes := EYE_COLOR
	var origin := Vector2(shake_x, -FEET_LIFT)
	var mirror := Vector2(fx if absf(fx) > 0.05 else 0.05, 1.0)
	# Dying, the legs draw up into the body, which settles on the ground, and
	# the head sinks into it, as the sprite's death frames did; the body is
	# drawn over the head to swallow it.
	var leg := 1.0 - dead
	var drop := dead * 26.0
	var sink := dead * 47.0

	draw_set_transform(origin, 0.0, mirror)
	for side: float in [-1.0, 1.0]:
		var a := swing * side
		var hip := Vector2(side * 5.0, (-27.0 - bob) * sy + drop)
		var foot := hip + Vector2(sin(a) * 22.0, cos(a) * 27.0 * sy) * leg
		draw_line(hip, foot, body, 4.5, true)
	var pts := PackedVector2Array()
	for i in 25:
		var ang := PI * i / 24.0
		pts.append(Vector2(cos(ang) * 18.0 * sx, (-26.0 - bob - sin(ang) * 30.0) * sy + drop))
	pts.append(Vector2(-18.0 * sx, (-26.0 - bob) * sy + drop))
	draw_set_transform(origin, lean, mirror)
	var hc := Vector2(look.x * 3.0, (-62.0 - bob - squash * 5.0) * sy + sink)
	if dead > 0.0:
		draw_circle(hc, 15.0, head)
		if art == "woman":
			_draw_bow(hc + Vector2(-9.0, -11.0), body)
		_draw_eyes(hc, eyes)
		draw_colored_polygon(pts, body)
	else:
		draw_colored_polygon(pts, body)
		draw_circle(hc, 15.0, head)
		if art == "woman":
			_draw_bow(hc + Vector2(-9.0, -11.0), body)
		_draw_eyes(hc, eyes)
	if web > 0.02:
		_draw_web(origin)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_eyes(hc: Vector2, eyes: Color) -> void:
	if look.y <= -0.6:  # seen from behind there is no face
		return
	var open := maxf(1.0 - _blink, 0.12) * (1.0 + happy * 0.3)
	for side: float in [-1.0, 1.0]:
		var e := hc + Vector2(side * 5.5 + look.x * 3.5, 1.0 + look.y * 2.5)
		var eye := PackedVector2Array()
		for k in 12:
			var ea := TAU * k / 12.0
			eye.append(e + Vector2(cos(ea) * 2.4, sin(ea) * 2.4 * open))
		draw_colored_polygon(eye, eyes)


func _draw_bow(at: Vector2, color: Color) -> void:
	for side: float in [-1.0, 1.0]:
		var loop := PackedVector2Array()
		for k in 14:
			var a := TAU * k / 14.0
			loop.append(at + Vector2(side * 5.0 + cos(a) * 5.0, sin(a) * 3.2).rotated(-0.5))
		draw_colored_polygon(loop, color)
	draw_circle(at, 2.2, color)


## Cobweb strands anchored on him; shaken, they fly outwards and fade.
func _draw_web(origin: Vector2) -> void:
	draw_set_transform(origin, 0.0, Vector2.ONE)
	var wc := Vector2(0, -40)
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
