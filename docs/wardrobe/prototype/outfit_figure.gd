extends Player
## WARDROBE DESIGN PROTOTYPE - not loaded by the game.
##
## MapMan drawn in layers, so an outfit can add to each one, with the pose
## maths of Player._draw() unchanged: every dial the game turns (look, walk,
## squash, hop, spin, cobweb, death) moves the outfit with him. With outfit
## "classic" this draws exactly what Player draws (sheets.gd checks that).
##
## Layers, back to front: back (capes; over the body when seen from behind),
## legs, body, neck, head, eyes, face, hat, front. Dying, the body and neck
## draw over the head, eyes and face (he is swallowed whole, as before) and
## the hat flies off.

const CREAM := Color("#f4ecd8")
const BONE := Color("#efe8d6")
const STEEL := Color("#a9b4c2")
const GUNMETAL := Color("#3d4652")
const SKY := Color("#4cc9f0")
const MAGENTA := Color("#f72585")
const GOLD := Color("#ffd166")
const RED := Color("#d62828")
const FIELD := Color("#16407a")
const DARK := Color("#1b1b1f")

## Colour roles an outfit changes: body, head, eyes, legs (default: body),
## outline (around the body), leg_outline, head_outline, leg_glow.
const PALETTES := {
	"signal_red": {"body": Color("#e0453a")},
	"racing_green": {"body": Color("#1f7a4f")},
	"blueprint":
	{
		"body": FIELD,
		"head": FIELD,
		"eyes": Color.WHITE,
		"outline": Color.WHITE,
		"head_outline": Color.WHITE,
		"leg_outline": Color.WHITE,
	},
	"hard_hat": {"body": Color("#ff7a1a"), "legs": Color("#1b263b")},
	"neon":
	{
		"body": Color("#0b1020"),
		"eyes": MAGENTA,
		"leg_glow": Color(0.3, 0.79, 0.94, 0.35),
	},
	"doctor": {"body": Color("#f2f5f9"), "legs": Color("#178f82"), "outline": Color("#2c3e50")},
	"explorer": {"body": Color("#8c7248"), "legs": Color("#6b5636")},
	"astronaut":
	{
		"body": Color("#eef2f7"),
		"legs": Color("#eef2f7"),
		"outline": Color("#34495e"),
		"leg_outline": Color("#34495e"),
	},
	"pumpkin": {"head": Color("#f4831f")},
	"skeleton": {"head": BONE},
	"robot": {"body": Color("#6c7a89"), "head": STEEL, "legs": GUNMETAL},
	"superhero": {"body": Color("#d62828"), "eyes": Color.WHITE},
	"wizard": {"body": Color("#9d4edd")},
	"gold":
	{
		"body": Color("#d9a521"),
		"head": Color("#f2cd5c"),
		"eyes": Color("#6b4a06"),
		"outline": Color("#8a6512"),
		"leg_outline": Color("#8a6512"),
		"head_outline": Color("#b8860b"),
	},
	"ninja": {"body": Color("#1b1b22"), "head": Color("#1b1b22")},
	"vampire": {"eyes": Color("#d00000")},
	"king": {"body": Color("#d62828"), "legs": Color("#5c0f12")},
	"bee": {"body": Color("#ffcc00"), "legs": DARK},
}
## Outfits with something on his back (a cape, a map roll, wings).
const BACKS := ["superhero", "explorer", "bee"]

var outfit := "classic":
	set(id):
		outfit = id
		art = "woman" if id == "mapwoman" else "man"
		queue_redraw()

# The pose of the frame being drawn, set at the top of _draw().
var _pal := {}
var _hc := Vector2.ZERO
var _hr := 15.0
var _bob := 0.0
var _sy := 1.0
var _sx := 1.0
var _drop := 0.0
var _origin := Vector2.ZERO
var _mirror := Vector2.ONE
var _lean := 0.0
var _hips: Array[Vector2] = []
var _feet: Array[Vector2] = []
var _body_pts := PackedVector2Array()
## Every part colour is multiplied by this: a flying hat and a cape fade.
var _alpha := 1.0
## Where a hat is drawn: identity, or flying off as he dies.
var _hat_xf := Transform2D.IDENTITY
## The three rules the first pose check called for (off only to show why):
## front-only details hide when he walks away, like his eyes; anything that
## sticks out of his head fades while the body swallows it; neck pieces fade
## as he dies. A cape covers his back when seen from behind.
var rules := true


## Front-only details (a coat's lapels, a bow tie) are not seen from behind.
func _front() -> bool:
	return not rules or not _from_behind()


## Parts that stick out of the head (a beard, a stem, antennae) fade in the
## first half of the death, before the head is inside the body.
func _extra_alpha() -> float:
	return 1.0 if not rules else clampf(1.0 - dead * 2.2, 0.0, 1.0)


func _palette() -> Dictionary:
	var pal := {"body": BODY_COLOR, "head": HEAD_COLOR, "eyes": EYE_COLOR}
	pal.merge(PALETTES.get(outfit, {}), true)
	if not pal.has("legs"):
		pal["legs"] = pal["body"]
	return pal


func _draw() -> void:
	if outfit == "locked":
		_draw_locked()
		return
	var fx := flip * cos(spin * TAU)
	var bob := absf(sin(_phase)) * 2.5 * walking + sin(_hop * PI) * 8.0
	var sy := 1.0 - squash * 0.18
	var sx := 1.0 + squash * 0.18
	var swing := sin(_phase) * 0.5 * walking
	var lean := (look.x * 0.05 + walking * 0.08) * signf(fx)
	_pal = _palette()
	var body: Color = _pal.body
	var head: Color = _pal.head
	var eyes: Color = _pal.eyes
	var origin := Vector2(shake_x, -FEET_LIFT)
	var mirror := Vector2(fx if absf(fx) > 0.05 else 0.05, 1.0)
	var leg := 1.0 - dead
	var drop := dead * 26.0
	var sink := dead * 47.0
	_bob = bob
	_sy = sy
	_sx = sx
	_drop = drop
	_origin = origin
	_mirror = mirror
	_lean = lean
	_alpha = 1.0
	_hat_xf = Transform2D.IDENTITY
	_hips.clear()
	_feet.clear()
	for side: float in [-1.0, 1.0]:
		var a := swing * side
		var hip := Vector2(side * 5.0, (-27.0 - bob) * sy + drop)
		_hips.append(hip)
		_feet.append(hip + Vector2(sin(a) * 22.0, cos(a) * 27.0 * sy) * leg)
	var pts := PackedVector2Array()
	for i in 25:
		var ang := PI * i / 24.0
		pts.append(Vector2(cos(ang) * 18.0 * sx, (-26.0 - bob - sin(ang) * 30.0) * sy + drop))
	pts.append(Vector2(-18.0 * sx, (-26.0 - bob) * sy + drop))
	_body_pts = pts
	_hc = Vector2(look.x * 3.0, (-62.0 - bob - squash * 5.0) * sy + sink)
	_hr = 15.0 * (1.0 - dead * 0.15) if dead > 0.0 else 15.0
	var has_back := outfit in BACKS
	var behind := _from_behind()

	if has_back and (not behind or dead > 0.0 or not rules):
		draw_set_transform(origin, lean, mirror)
		_alpha = 1.0 - dead
		_layer_back()
		_alpha = 1.0
	draw_set_transform(origin, 0.0, mirror)
	for i in 2:
		_draw_leg(_hips[i], _feet[i])
	_layer_legs()
	draw_set_transform(origin, lean, mirror)
	if dead > 0.0:
		_draw_head_shape(_hc, _hr, head)
		if art == "woman":
			_draw_bow(_hc + Vector2(-9.0, -11.0), Color(body, body.a * _extra_alpha()))
		_alpha = _extra_alpha()
		_layer_head()
		_alpha = 1.0
		_draw_face_eyes(_hc, eyes)
		_alpha = _extra_alpha()
		_layer_face()
		_alpha = 1.0
		_draw_body_shape(pts, body)
		_layer_body()
		_alpha = 1.0 - dead if rules else 1.0
		_layer_neck()
		_alpha = 1.0
		_draw_hat_flying()
	else:
		_draw_body_shape(pts, body)
		_layer_body()
		_layer_neck()
		if has_back and behind and rules:
			_layer_back()  # seen from behind, the cape covers his back
		_draw_head_shape(_hc, 15.0, head)
		if art == "woman":
			_draw_bow(_hc + Vector2(-9.0, -11.0), body)
		_layer_head()
		_draw_face_eyes(_hc, eyes)
		_layer_face()
		_layer_hat()
	_layer_front()
	if web > 0.02:
		_draw_web(origin)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- the base shapes, with the outfit's colours ------------------------------


func _draw_leg(hip: Vector2, foot: Vector2) -> void:
	if _pal.has("leg_glow"):
		draw_line(hip, foot, _pal.leg_glow, 8.5, true)
	if _pal.has("leg_outline"):
		draw_line(hip, foot, _pal.leg_outline, 6.6, true)
		draw_line(hip, foot, _pal.legs, 3.6, true)
	else:
		draw_line(hip, foot, _pal.legs, 4.5, true)


func _draw_body_shape(pts: PackedVector2Array, body: Color) -> void:
	if outfit == "neon":
		_outline(pts, Color(SKY, 0.3), 6.0)
	draw_colored_polygon(pts, body)
	if _pal.has("outline"):
		_outline(pts, _pal.outline, 1.4)
	if outfit == "neon":
		_outline(pts, SKY, 1.3)


func _draw_head_shape(hc: Vector2, r: float, head: Color) -> void:
	if outfit == "robot":
		var k := r / 15.0 * (1.0 - dead * 0.3)
		var box := _rrect(hc, Vector2(14.2, 14.2) * k, 5.0 * k)
		draw_colored_polygon(box, head)
		_outline(box, GUNMETAL, 1.2)
		return
	if outfit == "neon":
		draw_arc(hc, r + 0.6, 0.0, TAU, 48, Color(MAGENTA, 0.3), 4.5, true)
	draw_circle(hc, r, head)
	if _pal.has("head_outline"):
		draw_arc(hc, r, 0.0, TAU, 48, _pal.head_outline, 1.3, true)
	if outfit == "neon":
		draw_arc(hc, r, 0.0, TAU, 48, MAGENTA, 1.1, true)


func _draw_face_eyes(hc: Vector2, eyes: Color) -> void:
	match outfit:
		"pumpkin":
			_pumpkin_face()
		"skeleton":
			_skull_face()
		"robot":
			_robot_face()
		"superhero":
			_mask()
			_draw_eyes(hc, eyes)
		_:
			_draw_eyes(hc, eyes)


## The hat leaves the head as he dies: up, back and spinning, fading out.
func _draw_hat_flying() -> void:
	if dead >= 0.98:
		return
	var keep := _hc
	_hc = Vector2(look.x * 3.0, (-62.0 - _bob - squash * 5.0) * _sy)
	var pivot := _hc + Vector2(0.0, -15.0)
	var lift := Vector2(-dead * 9.0, -dead * 30.0)
	_hat_xf = (
		Transform2D(0.0, pivot + lift)
		* Transform2D(-dead * 1.3, Vector2.ZERO)
		* Transform2D(0.0, -pivot)
	)
	_alpha = clampf(1.0 - dead * 1.1, 0.0, 1.0)
	_layer_hat()
	_alpha = 1.0
	_hat_xf = Transform2D.IDENTITY
	_hc = keep


## Seen from behind (walking away): no face, as Player draws it.
func _from_behind() -> bool:
	return look.y <= -0.6


## Where an eye is, as Player._draw_eyes() puts it.
func _eye(side: float) -> Vector2:
	return _hc + Vector2(side * 5.5 + look.x * 3.5, 1.0 + look.y * 2.5)


func _eye_open() -> float:
	return maxf(1.0 - _blink, 0.12) * (1.0 + happy * 0.3)


# --- the layers -----------------------------------------------------------------


func _layer_back() -> void:
	match outfit:
		"superhero":
			_cape(Color("#ffb703"), Color("#e09200"))
		"explorer":
			_map_roll()
		"bee":
			_wings()


func _layer_legs() -> void:
	match outfit:
		"skeleton":
			for i in 2:
				var a := _hips[i].lerp(_feet[i], 0.07)
				var b := _hips[i].lerp(_feet[i], 0.93)
				_line(a, b, BONE, 1.5)
				if dead < 0.8:
					_dot(a, 1.3, BONE)
					_dot(b, 1.3, BONE)
		"explorer":
			_boots(Color("#3b2a1a"), 5.6)
		"astronaut":
			_boots(Color("#8395a7"), 5.0)
		"superhero":
			_boots(DARK, 5.2)
		"robot":
			for i in 2:
				_line(_hips[i].lerp(_feet[i], 0.1), _hips[i].lerp(_feet[i], 0.9), STEEL, 1.4)


func _layer_body() -> void:
	var s := look.x * 2.0
	match outfit:
		"racing_green":
			_stripe(-4.8 + s, -1.8 + s, CREAM)
			_stripe(1.8 + s, 4.8 + s, CREAM)
		"blueprint":
			_dash_dot(_b(s, -54.0), _b(s, -27.0), Color(1, 1, 1, 0.8), 0.9)
		"hard_hat":
			if _front():
				_poly(_bp([Vector2(-7 + s, -53), Vector2(s, -40), Vector2(7 + s, -53)]), DARK)
			_band(-39.5, -36.5, Color("#e3e9f0"))
			_band(-32.5, -29.5, Color("#e3e9f0"))
		"doctor":
			if _front():
				_doctor_coat(s)
			else:
				_line(_b(0, -52), _b(0, -26.6), Color("#8a9bb0"), 0.9)  # the back seam
		"pirate":
			for y0: float in [-49.5, -43.5, -37.5, -31.5]:
				_band(y0, y0 + 2.8, Color("#eeeeee"))
			_band(-28.4, -26.0, Color("#b5171f"))
		"skeleton":
			_ribcage(s * 0.7)
		"explorer":
			var k := Color("#5e4b2c")
			for side: float in [-1.0, 1.0] if _front() else []:
				var x0 := side * 6.0 + s
				var pocket := [
					Vector2(x0 - 3.2, -42), Vector2(x0 + 3.2, -42), Vector2(x0 + 3.2, -37.5)
				]
				pocket.append(Vector2(x0 - 3.2, -37.5))
				_outline(_bp(pocket), k, 0.9)
		"astronaut":
			if _front():
				_poly(_bp(_rrect(Vector2(s, -37), Vector2(6.2, 3.9), 1.2)), Color("#3d5a80"))
				_dot(_b(s - 3.0, -37), 1.2, Color("#ef476f"))
				_dot(_b(s, -37), 1.2, GOLD)
				_dot(_b(s + 3.0, -37), 1.2, Color("#8be0c8"))
			_band(-29.6, -27.4, Color("#c4ccd6"))
		"robot":
			if _front():
				_poly(_bp(_rrect(Vector2(s, -37), Vector2(7.0, 4.6), 1.2)), Color("#aab6c3"))
				_dot(_b(s - 3.0, -37), 2.2, GUNMETAL)
				_line(_b(s - 3.0, -37), _b(s - 1.6, -38.8), Color.WHITE, 0.8)
				_dot(_b(s + 2.6, -38.6), 1.0, Color("#ef476f"))
				_dot(_b(s + 5.0, -38.6), 1.0, Color("#8be0c8"))
				_line(_b(s + 1.4, -35.3), _b(s + 5.6, -35.3), GUNMETAL, 0.9)
			for x: float in [-14.0, -7.0, 0.0, 7.0, 14.0]:
				_dot(_b(x, -28.4), 0.9, Color("#4d5866"))
		"superhero":
			if _front():
				_star(_b(s, -38.5), 5.6, GOLD)
			_band(-29.2, -27.0, GOLD)
		"wizard":
			for p: Vector2 in [
				Vector2(-9, -37), Vector2(7, -31.5), Vector2(10.5, -41.5), Vector2(-3, -30)
			]:
				_star(_b(p.x, p.y), 1.9, GOLD, 4, 0.35)
			_band(-28.4, -26.0, GOLD)
		"gold":
			var shine := PackedVector2Array()
			for i in 7:
				var ang := lerpf(PI * 0.6, PI * 0.86, i / 6.0)
				shine.append(_b(cos(ang) * 13.0, -26.0 - sin(ang) * 25.0))
			draw_polyline(shine, _col(Color(1, 1, 1, 0.45)), 2.4, true)
		"chef":
			if _front():
				_apron()
		"king":
			_band(-30.4, -26.0, Color.WHITE)
			for x: float in [-12.0, -4.0, 4.0, 12.0]:
				_poly(
					_bp([Vector2(x, -29.4), Vector2(x - 0.9, -27.4), Vector2(x + 0.9, -27.4)]), DARK
				)
		"bee":
			_band(-47.0, -43.5, DARK)
			_band(-39.5, -36.0, DARK)
			_band(-32.0, -28.5, DARK)
			_poly(_bp([Vector2(-15, -27.4), Vector2(-21.5, -25.4), Vector2(-15.5, -25.6)]), DARK)
		"ninja":
			_band(-29.6, -26.6, RED)


func _layer_neck() -> void:
	match outfit:
		"cowboy":
			if _front():
				_bandana(Color("#c1121f"))
		"top_hat":
			if _front():
				_bow_tie(Color("#c1121f"))
		"doctor":
			if _front():
				_stethoscope()
		"explorer":
			if _front():
				_compass()
		"astronaut":
			var ring := _bp([Vector2(-12.5, -49), Vector2(12.5, -49), Vector2(11.5, -44.6)])
			ring.append(_b(-11.5, -44.6))
			_poly(ring, Color("#9aa8b8"))
			_outline(ring, Color("#34495e"), 0.9)
		"chef":
			if _front():
				_neckerchief()
		"vampire":
			_vampire_collar()
		"king":
			var collar := _bp([Vector2(-13, -50.5), Vector2(13, -50.5), Vector2(12, -44.5)])
			collar.append(_b(-12, -44.5))
			_poly(collar, Color.WHITE)
			for x: float in [-8.0, 0.0, 8.0]:
				_dot(_b(x, -46.6), 0.8, DARK)
		"graduate":
			if _front():
				_poly(
					_bp([Vector2(-6.5, -49.5), Vector2(0, -44), Vector2(6.5, -49.5)]), Color.WHITE
				)
		"ninja":
			_ninja_tails()


func _layer_head() -> void:
	match outfit:
		"blueprint":
			var c := Color(1, 1, 1, 0.55)
			_dash_dot(_h(-19, 0), _h(19, 0), c, 0.8)
			_dash_dot(_h(0, -19), _h(0, 19), c, 0.8)
		"pumpkin":
			_pumpkin_head()
		"robot":
			_robot_head()
		"gold":
			_arc_pts(_hc, _hr * 0.7, 3.5, 4.4, Color(1, 1, 1, 0.55), 2.2)
		"ninja":
			if not _from_behind():
				var band := _rrect(
					_hc + Vector2(look.x * 3.0, 1.0 + look.y * 2.5), Vector2(11.5, 3.8), 3.0
				)
				_poly(band, HEAD_COLOR)
			_poly(_rrect(_h(0, -7.6), Vector2(15.0, 1.7) * (_hr / 15.0), 0.8), RED)
		"vampire":
			_vampire_hair()
		"bee":
			for side: float in [-1.0, 1.0]:
				var stalk := PackedVector2Array(
					[_h(side * 4.0, -13.5), _h(side * 6.5, -20.0), _h(side * 9.5, -24.5)]
				)
				draw_polyline(stalk, _col(DARK), 1.3, true)
				_dot(_h(side * 9.5, -24.5), 2.2, DARK)


func _layer_face() -> void:
	if _from_behind():
		return
	match outfit:
		"shades":
			_shades()
		"top_hat":
			var e := _eye(1.0)
			draw_arc(e, 3.9, 0.0, TAU, 24, _col(Color("#d4a017")), 1.1, true)
			if dead == 0.0:
				var chain := PackedVector2Array([e + Vector2(2.8, 2.8), e + Vector2(4.2, 9.0)])
				chain.append(_b(10.0, -45.0))
				draw_polyline(chain, _col(Color("#d4a017")), 0.7, true)
		"pirate":
			var e := _eye(1.0)
			_poly(_ellipse(e, 3.9, 3.5), DARK)
			_line(e + Vector2(-2.6, -2.6), _hc + Vector2(-11.5, -10.0), DARK, 1.1)
			_line(e + Vector2(2.9, -1.6), _hc + Vector2(14.4, -3.0), DARK, 1.1)
		"wizard":
			_beard(Color("#f1f1f1"), Color("#9aa5b1"))
		"vampire":
			var lx := look.x * 3.0
			_line(_h(-4.2 + lx, 8.4), _h(4.2 + lx, 8.4), DARK, 0.9)
			for side: float in [-1.0, 1.0]:
				var f := _h(side * 2.6 + lx, 8.4)
				_poly(
					PackedVector2Array(
						[f + Vector2(-1.1, 0), f + Vector2(1.1, 0), f + Vector2(0, 2.8)]
					),
					Color.WHITE
				)
		"viking":
			_viking_beard()


func _layer_hat() -> void:
	match outfit:
		"party_hat":
			_party_hat()
		"bobble_hat":
			_bobble_hat()
		"cowboy":
			_cowboy_hat()
		"hard_hat":
			_hard_hat()
		"top_hat":
			_top_hat()
		"doctor":
			_head_mirror()
		"pirate":
			_tricorn()
		"explorer":
			_pith_helmet()
		"astronaut":
			_bubble()
		"wizard":
			_wizard_hat()
		"chef":
			_toque()
		"viking":
			_viking_helmet()
		"king":
			_crown()
		"propeller":
			_propeller_cap()
		"graduate":
			_mortarboard()


func _layer_front() -> void:
	match outfit:
		"wizard":
			if walking > 0.05 and dead == 0.0 and Blueprint.motion():
				draw_set_transform(_origin, 0.0, _mirror)
				for k in 3:
					var t := fposmod(_phase * 0.32 + k / 3.0, 1.0)
					var p := Vector2(
						-15.0 - t * 22.0, -30.0 - t * 8.0 + sin(t * 9.0 + k * 2.0) * 5.0
					)
					_star(p, (1.0 - t) * 3.4 * walking, GOLD, 4, 0.3)
		"gold":
			if dead == 0.0:
				for k in 2:
					var s := maxf(0.0, sin(_idle_clock * 2.4 + k * 2.6))
					if s > 0.05:
						var at: Vector2 = [_h(10.0, -11.0), _b(-11.0, -40.0)][k]
						_star(at, 4.4 * s, Color(1, 1, 0.92), 4, 0.25)


# --- parts ------------------------------------------------------------------------


func _party_hat() -> void:
	var base := Vector2(0, -12.0)
	var apex := base + Vector2(0, -25.0).rotated(-0.18)
	var l := base + Vector2(-9.6, 0)
	var r := base + Vector2(9.6, 0)
	_hat_poly(PackedVector2Array([l, apex, r]), Color("#ff9fb5"))
	for t: float in [0.12, 0.42, 0.7]:
		var band := PackedVector2Array(
			[
				l.lerp(apex, t),
				l.lerp(apex, t + 0.12),
				r.lerp(apex, t + 0.28),
				r.lerp(apex, t + 0.16)
			]
		)
		_hat_poly(band, GOLD)
	_hat_dot(apex, 3.8, Color.WHITE)
	for k in 6:
		_hat_dot(apex + Vector2.from_angle(TAU * k / 6.0) * 3.2, 1.6, Color.WHITE)


func _bobble_hat() -> void:
	var main := Color("#2a9d8f")
	var r := 16.3
	var dome := PackedVector2Array()
	var a0 := PI + asin(5.0 / r)
	var a1 := TAU - asin(5.0 / r)
	for i in 17:
		var a := lerpf(a0, a1, i / 16.0)
		dome.append(Vector2(cos(a) * r, sin(a) * r))
	_hat_poly(dome, main)
	_hat_poly(_chord_band(r, -14.0, -11.2), CREAM)
	_hat_poly(_rrect(Vector2(0, -6.8), Vector2(16.9, 3.0), 2.2), CREAM)
	for i in 10:
		var x := -14.4 + i * 3.2
		_hat_line(Vector2(x, -9.0), Vector2(x, -4.6), Color("#d8c9a6"), 1.0)
	var pom := Vector2(0, -20.6)
	_hat_dot(pom, 5.2, CREAM)
	for k in 7:
		_hat_dot(pom + Vector2.from_angle(TAU * k / 7.0 + 0.3) * 4.4, 2.3, CREAM)


func _cowboy_hat() -> void:
	var felt := Color("#a0672f")
	var dark := Color("#5c3a1a")
	var crown := PackedVector2Array(
		[
			Vector2(-11, -11.0),
			Vector2(-11.8, -20.5),
			Vector2(-9.0, -27.0),
			Vector2(-3.5, -25.8),
			Vector2(0, -24.0),
			Vector2(3.5, -25.8),
			Vector2(9.0, -27.0),
			Vector2(11.8, -20.5),
			Vector2(11, -11.0),
		]
	)
	_hat_poly(crown, felt)
	_hat_poly(
		PackedVector2Array(
			[Vector2(-11.2, -11), Vector2(-11.5, -15), Vector2(11.5, -15), Vector2(11.2, -11)]
		),
		dark
	)
	_hat_line(Vector2(0, -24.0), Vector2(0, -18.0), Color(dark, 0.6), 1.0)
	var brim := PackedVector2Array(
		[
			Vector2(-25, -15.5),
			Vector2(-21, -12.6),
			Vector2(-14, -11.4),
			Vector2(0, -11.0),
			Vector2(14, -11.4),
			Vector2(21, -12.6),
			Vector2(25, -15.5),
			Vector2(24, -13.0),
			Vector2(20, -9.8),
			Vector2(13, -8.4),
			Vector2(0, -8.0),
			Vector2(-13, -8.4),
			Vector2(-20, -9.8),
			Vector2(-24, -13.0),
		]
	)
	_hat_poly(brim, felt)
	_hat_outline(brim, dark, 0.9)


func _bandana(c: Color) -> void:
	_poly(_bp([Vector2(-11.5, -50.5), Vector2(11.5, -50.5), Vector2(1.0, -37.0)]), c)
	for d: Vector2 in [
		Vector2(-5, -47.4),
		Vector2(4, -46.2),
		Vector2(0.5, -42),
		Vector2(-8, -49.4),
		Vector2(7, -49.2)
	]:
		_dot(_b(d.x, d.y), 0.8, Color(1, 1, 1, 0.85))


func _hard_hat() -> void:
	var dome := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI + 0.12, TAU - 0.12, i / 16.0)
		dome.append(Vector2(cos(a) * 15.8, -5.0 + sin(a) * 16.1))
	_hat_poly(dome, Color("#ffc300"))
	_hat_poly(_rrect(Vector2(0, -12.8), Vector2(2.3, 7.6), 1.6), Color("#ffd75e"))
	_hat_outline(dome, Color("#8a6d00"), 0.9)
	var brim := _rrect(Vector2(look.x * 2.5, -5.6), Vector2(19.2, 1.9), 1.6)
	_hat_poly(brim, Color("#e0aa00"))
	_hat_outline(brim, Color("#8a6d00"), 0.8)


func _top_hat() -> void:
	var tilt := -0.07
	var pivot := Vector2(0, -11.0)
	var crown := _rot(
		[Vector2(-10.5, -11.5), Vector2(-11.6, -34), Vector2(11.6, -34), Vector2(10.5, -11.5)],
		pivot,
		tilt
	)
	_hat_poly(crown, Color("#16161c"))
	var band := _rot(
		[Vector2(-10.6, -12.6), Vector2(-10.9, -17.4), Vector2(10.9, -17.4), Vector2(10.6, -12.6)],
		pivot,
		tilt
	)
	_hat_poly(band, Color("#8d1b2e"))
	var top := PackedVector2Array()
	for v in _ellipse(Vector2(0, -34), 11.6, 1.9, 16):
		top.append(pivot + (v - pivot).rotated(tilt))
	_hat_poly(top, Color("#2b2b36"))
	var sheen := _rot([Vector2(-7.4, -31), Vector2(-7.0, -19.5)], pivot, tilt)
	_hat_line(sheen[0], sheen[1], Color(1, 1, 1, 0.22), 1.6)
	var brim := PackedVector2Array()
	for v in _rrect(Vector2(0, -11.0), Vector2(17.5, 1.9), 1.7):
		brim.append(pivot + (v - pivot).rotated(tilt))
	_hat_poly(brim, Color("#16161c"))
	_hat_outline(brim, Color(1, 1, 1, 0.18), 0.8)


func _bow_tie(c: Color) -> void:
	_poly(_bp([Vector2(0, -44), Vector2(-7.5, -47.8), Vector2(-7.5, -40.2)]), c)
	_poly(_bp([Vector2(0, -44), Vector2(7.5, -47.8), Vector2(7.5, -40.2)]), c)
	_poly(_bp(_rrect(Vector2(0, -44), Vector2(1.9, 2.3), 0.8)), c.darkened(0.25))


func _shades() -> void:
	var lens := Color("#15171c")
	var e: Array[Vector2] = [_eye(-1.0), _eye(1.0)]
	for i in 2:
		var c := e[i] + Vector2(0, -0.2)
		_poly(_rrect(c, Vector2(4.7, 3.3), 1.6), lens)
		_line(c + Vector2(-2.7, -1.5), c + Vector2(-0.5, -2.1), Color(1, 1, 1, 0.55), 1.0)
	_line(e[0] + Vector2(4.2, -1.4), e[1] + Vector2(-4.2, -1.4), lens, 1.4)
	_line(e[0] + Vector2(-4.5, -1.4), _hc + Vector2(-14.3, -3.0), lens, 1.2)
	_line(e[1] + Vector2(4.5, -1.4), _hc + Vector2(14.3, -3.0), lens, 1.2)


func _doctor_coat(s: float) -> void:
	var grey := Color("#8a9bb0")
	var teal := Color("#178f82")
	_poly(_bp([Vector2(-7.5 + s, -53), Vector2(s, -37.5), Vector2(7.5 + s, -53)]), teal)
	_line(_b(-7.5 + s, -53), _b(s, -37.5), grey, 1.0)
	_line(_b(7.5 + s, -53), _b(s, -37.5), grey, 1.0)
	_line(_b(s, -37.5), _b(s, -26.6), grey, 0.9)
	for y: float in [-33.5, -29.5]:
		_dot(_b(1.7 + s, y), 0.8, grey)
	var pocket := _bp(
		[
			Vector2(-14 + s, -40),
			Vector2(-8.5 + s, -40),
			Vector2(-8.5 + s, -35.5),
			Vector2(-14 + s, -35.5)
		]
	)
	_outline(pocket, grey, 0.9)
	_line(_b(-12.2 + s, -42.6), _b(-12.2 + s, -38.8), Color("#3a86ff"), 1.3)


func _stethoscope() -> void:
	var tube := Color("#4b5563")
	var left := _bp(
		[
			Vector2(-8, -49),
			Vector2(-9, -44),
			Vector2(-7, -39.5),
			Vector2(-3, -37.4),
			Vector2(2.2, -37.6)
		]
	)
	draw_polyline(left, _col(tube), 1.3, true)
	var right := _bp([Vector2(8, -49), Vector2(7.6, -44), Vector2(5.2, -39.4)])
	draw_polyline(right, _col(tube), 1.3, true)
	var piece := _b(4.4, -37.2)
	_dot(piece, 2.7, tube)
	_dot(piece, 1.9, Color("#cfd8e3"))


func _head_mirror() -> void:
	var band := PackedVector2Array(
		[
			Vector2(-14.8, -5.6),
			Vector2(-7, -8.3),
			Vector2(0, -8.9),
			Vector2(7, -8.3),
			Vector2(14.8, -5.6)
		]
	)
	_hat_polyline(band, Color("#4b5563"), 1.7)
	if _from_behind():
		return
	var c := Vector2(4.6, -9.6)
	_hat_dot(c, 6.4, Color("#8a99a8"))
	_hat_dot(c, 5.5, Color("#dfe6ee"))
	_hat_dot(c, 1.2, Color("#4b5563"))
	_hat_line(c + Vector2(-3.2, -2.2), c + Vector2(-1.2, -3.6), Color.WHITE, 1.1)


func _tricorn() -> void:
	var shape := PackedVector2Array(
		[
			Vector2(-22, -16.5),
			Vector2(-13, -24.5),
			Vector2(0, -27.5),
			Vector2(13, -24.5),
			Vector2(22, -16.5),
			Vector2(14, -11.5),
			Vector2(0, -7.0),
			Vector2(-14, -11.5),
		]
	)
	_hat_poly(shape, DARK)
	var trim := PackedVector2Array(
		[
			Vector2(22, -16.5),
			Vector2(14, -11.5),
			Vector2(0, -7.0),
			Vector2(-14, -11.5),
			Vector2(-22, -16.5)
		]
	)
	_hat_polyline(trim, Color("#d4a017"), 1.5)
	_hat_line(Vector2(-13, -24.5), Vector2(-22, -16.5), Color("#d4a017"), 1.0)
	_hat_line(Vector2(13, -24.5), Vector2(22, -16.5), Color("#d4a017"), 1.0)


func _pumpkin_head() -> void:
	var rib := Color("#c95f0e")
	for rx: float in [5.5, 11.0]:
		for side: float in [-1.0, 1.0]:
			var groove := PackedVector2Array()
			for i in 13:
				var a := lerpf(-PI / 2.0, PI / 2.0, i / 12.0)
				groove.append(_h(side * cos(a) * rx, sin(a) * 14.4))
			draw_polyline(groove, _col(rib), 1.1, true)
	var green := Color("#3d7a3a")
	_poly(
		PackedVector2Array([_h(-2.3, -14.0), _h(2.3, -14.0), _h(3.4, -20.4), _h(0.6, -21.2)]), green
	)
	var curl := PackedVector2Array([_h(2.6, -18.6), _h(6.2, -21.2), _h(8.0, -18.6), _h(6.3, -16.8)])
	draw_polyline(curl, _col(green), 1.0, true)


func _pumpkin_face() -> void:
	if _from_behind():
		return
	var glow := Color("#ffd23f")
	var open := _eye_open()
	for side: float in [-1.0, 1.0]:
		var e := _eye(side)
		_poly(
			PackedVector2Array(
				[
					e + Vector2(-3.4, 2.3 * open),
					e + Vector2(3.4, 2.3 * open),
					e + Vector2(0.5 * side, -3.0 * open)
				]
			),
			glow
		)
	var lx := look.x * 3.0
	_poly(PackedVector2Array([_h(lx - 1.6, 6.8), _h(lx + 1.6, 6.8), _h(lx, 4.4)]), glow)
	var mouth := PackedVector2Array()
	for v: Vector2 in [
		Vector2(-8.5, 8.0),
		Vector2(-5.5, 10.0),
		Vector2(-3, 8.6),
		Vector2(0, 10.8),
		Vector2(3, 8.6),
		Vector2(5.5, 10.0),
		Vector2(8.5, 8.0),
		Vector2(6, 12.4),
		Vector2(2.5, 13.3),
		Vector2(-2.5, 13.3),
		Vector2(-6, 12.4),
	]:
		mouth.append(_h(v.x + lx * 0.8, v.y))
	_poly(mouth, glow)


func _ribcage(s: float) -> void:
	_line(_b(s, -50), _b(s, -30), BONE, 1.8)
	for k in 4:
		var y := -46.5 + k * 4.4
		var w := _dome_w(y) - 3.6
		for side: float in [-1.0, 1.0]:
			var rib := _bp(
				[
					Vector2(s + side * 1.0, y),
					Vector2(s + side * w * 0.55, y + 0.4),
					Vector2(s + side * w, y + 2.6)
				]
			)
			draw_polyline(rib, _col(BONE), 1.4, true)
	for side: float in [-1.0, 1.0]:
		_poly(_bp(_ellipse(Vector2(s + side * 3.3, -29.0), 3.1, 2.1, 12)), BONE)


func _skull_face() -> void:
	if _from_behind():
		return
	var dark := Color("#1b1b22")
	var open := maxf(1.0 - _blink, 0.15) * (1.0 + happy * 0.2)
	for side: float in [-1.0, 1.0]:
		var e := _eye(side) + Vector2(0, -0.3)
		_poly(_ellipse(e, 3.5, 3.9 * open, 16), dark)
		if open > 0.5:
			_dot(e + Vector2(-1.0, -1.2), 0.7, Color.WHITE)
	var lx := look.x * 3.5
	_poly(PackedVector2Array([_h(lx - 1.6, 7.0), _h(lx + 1.6, 7.0), _h(lx, 4.0)]), dark)
	_line(_h(lx * 0.8 - 6.0, 10.5), _h(lx * 0.8 + 6.0, 10.5), dark, 3.4)
	for x: float in [-4.4, -1.5, 1.5, 4.4]:
		_line(_h(lx * 0.8 + x, 9.3), _h(lx * 0.8 + x, 11.7), BONE, 2.1)


func _boots(c: Color, w: float) -> void:
	for i in 2:
		_line(_hips[i].lerp(_feet[i], 0.72), _feet[i], c, w)


func _map_roll() -> void:
	var a := _b(-5.5, -42.0)
	var b := _b(-15.5, -69.0)
	_line(a, b, Color("#d9c79a"), 6.4)
	_line(a, b, Color("#efe2c0"), 4.6)
	_dot(b, 3.2, Color("#d9c79a"))
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var c := a.lerp(b, 0.7)
	_line(c - n * 3.3, c + n * 3.3, Color("#c1121f"), 1.8)


func _compass() -> void:
	var s := look.x * 2.0
	var cord := Color("#3b2a1a")
	_line(_b(-7, -49.5), _b(s - 1.6, -38.8), cord, 0.9)
	_line(_b(7, -49.5), _b(s + 1.6, -38.8), cord, 0.9)
	var c := _b(s, -36.0)
	_dot(c, 3.9, Color("#d4a017"))
	_dot(c, 2.8, CREAM)
	_line(c + Vector2(0.8, -2.0), c, Color("#c1121f"), 1.1)
	_line(c, c + Vector2(-0.8, 2.0), DARK, 1.1)


func _pith_helmet() -> void:
	var light := Color("#e3d3a6")
	var mid := Color("#c8b48a")
	var dark := Color("#8d7a52")
	var brim := _ellipse(Vector2(0, -8.0), 21.5, 4.0, 24)
	_hat_poly(brim, mid)
	_hat_outline(brim, dark, 0.8)
	var dome := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI, TAU, i / 16.0)
		dome.append(Vector2(cos(a) * 14.0, -8.5 + sin(a) * 15.0))
	_hat_poly(dome, light)
	_hat_outline(dome, dark, 0.8)
	_hat_poly(
		PackedVector2Array(
			[Vector2(-14, -8.5), Vector2(-13.6, -12.0), Vector2(13.6, -12.0), Vector2(14, -8.5)]
		),
		dark
	)
	_hat_dot(Vector2(0, -23.4), 1.8, dark)


func _bubble() -> void:
	var c := Vector2(0, -1.5)
	var glass := _ellipse(c, 20.5, 20.5, 40)
	_hat_poly(glass, Color(0.78, 0.9, 1.0, 0.16))
	_hat_outline(_ellipse(c, 21.5, 21.5, 40), Color("#2b3a4f"), 0.9)
	_hat_outline(glass, Color(1, 1, 1, 0.85), 1.6)
	var hi := PackedVector2Array()
	for i in 9:
		var a := lerpf(3.55, 4.35, i / 8.0)
		hi.append(c + Vector2(cos(a), sin(a)) * 16.5)
	_hat_polyline(hi, Color(1, 1, 1, 0.75), 2.2)
	_hat_dot(c + Vector2.from_angle(4.62) * 16.5, 1.1, Color.WHITE)


func _robot_head() -> void:
	var k := _hr / 15.0 * (1.0 - dead * 0.3)
	for c: Vector2 in [
		Vector2(-10.5, -10.5), Vector2(10.5, -10.5), Vector2(-10.5, 10.5), Vector2(10.5, 10.5)
	]:
		_dot(_hc + c * k, 1.1, Color("#6b7685"))
	for side: float in [-1.0, 1.0]:
		_poly(_rrect(_hc + Vector2(side * 15.4, 0) * k, Vector2(1.6, 4.2) * k, 0.8), GUNMETAL)
	_line(_hc + Vector2(0, -14.2) * k, _hc + Vector2(0, -21.0) * k, GUNMETAL, 1.4)
	_dot(_hc + Vector2(0, -22.6) * k, 2.5 * k, Color("#ef476f"))


func _robot_face() -> void:
	if _from_behind():
		return
	var open := _eye_open()
	for side: float in [-1.0, 1.0]:
		var e := _eye(side)
		_poly(_rrect(e, Vector2(4.3, 2.8 * open + 0.6), 1.5), Color(SKY, 0.3))
		_poly(_rrect(e, Vector2(3.2, 1.9 * open + 0.2), 1.0), SKY)
	var lx := look.x * 3.0
	for y: float in [7.6, 9.6, 11.6]:
		_line(_h(lx - 5.0, y), _h(lx + 5.0, y), GUNMETAL, 0.9)


func _cape(main: Color, edge: Color) -> void:
	var trail := walking * 9.0
	var hem := PackedVector2Array()
	for i in 7:
		var t := i / 6.0
		var x := lerpf(19.0, -21.0, t) - trail * (0.3 + 0.7 * t)
		var y := -13.0 + sin(t * PI * 3.0 + _phase * 2.0) * 1.6 * walking - trail * 0.4 * t
		hem.append(_b(x, y))
	var pts := _bp([Vector2(-10.5, -51.0), Vector2(10.5, -51.0)])
	pts.append_array(hem)
	_poly(pts, main)
	draw_polyline(hem, _col(edge), 1.6, true)


func _mask() -> void:
	var dark := Color("#1b1b1f")
	var lx := look.x * 3.5
	var ly := look.y * 2.5
	if _from_behind():
		_poly(_rrect(_h(0, 0.8), Vector2(14.8, 2.4), 1.0), dark)
		return
	var shape := PackedVector2Array()
	for v: Vector2 in [
		Vector2(-13.6, -2.4),
		Vector2(-7, -4.4),
		Vector2(0, -2.2),
		Vector2(7, -4.4),
		Vector2(13.6, -2.4),
		Vector2(12, 4.2),
		Vector2(6, 5.8),
		Vector2(0, 3.2),
		Vector2(-6, 5.8),
		Vector2(-12, 4.2),
	]:
		shape.append(_h(v.x + lx, v.y + 1.0 + ly))
	_poly(shape, dark)


func _wizard_hat() -> void:
	_hat_poly(_ellipse(Vector2(0, -9.6), 21.0, 3.7, 24), Color("#6a2bb0"))
	var spine: Array[Vector2] = [
		Vector2(0, -10),
		Vector2(-0.6, -19),
		Vector2(-3.2, -27.6),
		Vector2(-8.6, -33.6),
		Vector2(-15.6, -35.6)
	]
	var widths: Array[float] = [12.6, 9.0, 5.8, 2.8, 0.0]
	_hat_poly(_tapered(spine, widths), Color("#8e3fd1"))
	_hat_poly(
		PackedVector2Array(
			[
				Vector2(-12.6, -10.2),
				Vector2(-11.6, -13.8),
				Vector2(11.6, -13.8),
				Vector2(12.6, -10.2)
			]
		),
		GOLD
	)
	_hat_star(Vector2(3.6, -20.4), 2.4)
	_hat_star(Vector2(-4.2, -27.0), 1.8)
	_hat_dot(Vector2(-1.4, -16.8), 2.6, GOLD)
	_hat_dot(Vector2(-0.4, -17.6), 2.3, Color("#8e3fd1"))


func _beard(c: Color, line: Color) -> void:
	var lx := look.x * 3.0
	var beard := PackedVector2Array()
	for v: Vector2 in [
		Vector2(-11.6, 2.5),
		Vector2(-12.6, 8.0),
		Vector2(-10.6, 15.0),
		Vector2(-7.0, 21.0),
		Vector2(-3.0, 26.5),
		Vector2(0.0, 30.0),
		Vector2(3.0, 26.5),
		Vector2(7.0, 21.0),
		Vector2(10.6, 15.0),
		Vector2(12.6, 8.0),
		Vector2(11.6, 2.5),
		Vector2(7.0, 6.6),
		Vector2(3.0, 7.6),
		Vector2(0.0, 6.8),
		Vector2(-3.0, 7.6),
		Vector2(-7.0, 6.6),
	]:
		beard.append(_h(v.x + lx * (1.0 - v.y / 40.0), v.y))
	_poly(beard, c)
	_outline(beard, line, 0.8)
	for side: float in [-1.0, 1.0]:
		var m := _ellipse(_h(side * 3.6 + lx, 6.6), 4.4, 1.9, 14, side * 0.3)
		_poly(m, c)
		_outline(m, line, 0.7)


func _toque() -> void:
	var white := Color("#f7f7f7")
	var grey := Color("#aeb8c2")
	var puffs: Array[Vector3] = [
		Vector3(-8.0, -21.0, 7.2), Vector3(8.0, -21.0, 7.2), Vector3(0.0, -25.5, 8.4)
	]
	for p in puffs:
		_hat_dot(Vector2(p.x, p.y), p.z + 0.9, grey)
	_hat_poly(_rrect(Vector2(0, -16.5), Vector2(12.0, 6.0), 1.0), grey)
	for p in puffs:
		_hat_dot(Vector2(p.x, p.y), p.z, white)
	_hat_poly(_rrect(Vector2(0, -16.5), Vector2(11.1, 6.0), 1.0), white)
	for x: float in [-5.0, 0.0, 5.0]:
		_hat_line(Vector2(x, -21.0), Vector2(x, -14.6), grey, 0.8)
	var band := _rrect(Vector2(0, -11.4), Vector2(12.6, 3.2), 1.2)
	_hat_poly(band, white)
	_hat_outline(band, grey, 0.8)


func _neckerchief() -> void:
	var red := Color("#d62828")
	_poly(_bp([Vector2(-9, -49.6), Vector2(9, -49.6), Vector2(8, -46.4), Vector2(-8, -46.4)]), red)
	_poly(_bp([Vector2(3.0, -46.6), Vector2(7.0, -40.4), Vector2(8.8, -42.0)]), red)
	_poly(_bp([Vector2(3.0, -46.6), Vector2(2.4, -40.0), Vector2(4.6, -40.4)]), red)
	_dot(_b(3.6, -46.6), 2.2, red.darkened(0.2))


func _apron() -> void:
	var grey := Color("#aeb8c2")
	var apron := _bp(
		[
			Vector2(-10, -41),
			Vector2(10, -41),
			Vector2(15.5, -30),
			Vector2(16.8, -26.3),
			Vector2(-16.8, -26.3),
			Vector2(-15.5, -30),
		]
	)
	_poly(apron, Color("#f7f7f7"))
	_outline(apron, grey, 0.8)
	_line(_b(-10, -41), _b(-6, -50), Color("#f7f7f7"), 1.2)
	_line(_b(10, -41), _b(6, -50), Color("#f7f7f7"), 1.2)


func _viking_helmet() -> void:
	var steel := Color("#9aa5b1")
	var dark := Color("#5b6573")
	var horn := Color("#f1e3c8")
	for side: float in [-1.0, 1.0]:
		var spine: Array[Vector2] = [
			Vector2(side * 11.5, -9.5),
			Vector2(side * 18.0, -13.5),
			Vector2(side * 22.6, -20.0),
			Vector2(side * 24.6, -27.4),
		]
		var widths: Array[float] = [3.8, 3.0, 2.0, 0.0]
		var shape := _tapered(spine, widths)
		_hat_poly(shape, horn)
		_hat_outline(shape, Color("#b39d74"), 0.8)
	var dome := PackedVector2Array()
	var r := 15.9
	for i in 17:
		var a := lerpf(PI + 0.22, TAU - 0.22, i / 16.0)
		dome.append(Vector2(cos(a) * r, -1.0 + sin(a) * r))
	_hat_poly(dome, steel)
	_hat_poly(_rrect(Vector2(0, -5.2), Vector2(16.0, 2.0), 1.0), dark)
	if not _from_behind():
		_hat_poly(_rrect(Vector2(look.x * 3.5, 0.6), Vector2(1.7, 5.6), 0.8), dark)
	for x: float in [-11.0, -5.5, 5.5, 11.0]:
		_hat_dot(Vector2(x, -5.2), 0.8, Color("#c8d0d9"))


func _viking_beard() -> void:
	var ginger := Color("#d9822b")
	var lx := look.x * 3.0
	var beard := PackedVector2Array()
	for v: Vector2 in [
		Vector2(-11.4, 3.0),
		Vector2(-12.0, 9.0),
		Vector2(-8.5, 14.6),
		Vector2(-4.0, 17.0),
		Vector2(0.0, 17.6),
		Vector2(4.0, 17.0),
		Vector2(8.5, 14.6),
		Vector2(12.0, 9.0),
		Vector2(11.4, 3.0),
		Vector2(6.0, 7.2),
		Vector2(0.0, 6.4),
		Vector2(-6.0, 7.2),
	]:
		beard.append(_h(v.x + lx, v.y))
	_poly(beard, ginger)
	for side: float in [-1.0, 1.0]:
		var top := _h(side * 3.4 + lx, 16.0)
		var bottom := _h(side * 3.8 + lx, 25.0)
		_line(top, bottom, ginger, 3.2)
		_dot(bottom, 1.7, Color("#8d5524"))
	for side: float in [-1.0, 1.0]:
		_poly(_ellipse(_h(side * 3.8 + lx, 6.4), 4.6, 1.9, 14, side * 0.32), ginger.darkened(0.12))


func _vampire_collar() -> void:
	for side: float in [-1.0, 1.0]:
		var outer := _bp(
			[
				Vector2(side * 6.0, -48.0),
				Vector2(side * 14.6, -48.6),
				Vector2(side * 21.6, -69.0),
				Vector2(side * 16.8, -66.0),
				Vector2(side * 9.0, -55.0),
			]
		)
		_poly(outer, Color("#111111"))
		var inner := _bp(
			[
				Vector2(side * 8.6, -49.6),
				Vector2(side * 13.8, -50.2),
				Vector2(side * 19.4, -65.6),
				Vector2(side * 15.6, -63.4),
				Vector2(side * 10.2, -55.6),
			]
		)
		_poly(inner, Color("#9d0208"))


func _vampire_hair() -> void:
	var hair := PackedVector2Array()
	var r := 15.7
	for i in 15:
		var a := lerpf(PI + 0.42, TAU - 0.42, i / 14.0)
		hair.append(_h(cos(a) * r, sin(a) * r))
	for v: Vector2 in [
		Vector2(8.6, -6.8),
		Vector2(3.6, -8.2),
		Vector2(0.0, -3.6),
		Vector2(-3.6, -8.2),
		Vector2(-8.6, -6.8)
	]:
		hair.append(_h(v.x, v.y))
	_poly(hair, Color("#121212"))
	_arc_pts(_hc + Vector2(-2.0, -1.0), _hr * 0.78, 3.7, 4.3, Color(1, 1, 1, 0.22), 1.4)


func _ninja_tails() -> void:
	var red := RED
	var trail := walking * 6.0
	var flap := sin(_phase * 2.0) * 2.0 * walking
	var knot := _h(-14.4, -7.0)
	_poly(
		PackedVector2Array(
			[
				knot,
				knot + Vector2(-10.0 - trail, -2.0 + flap),
				knot + Vector2(-9.0 - trail, 1.2 + flap)
			]
		),
		red
	)
	_poly(
		PackedVector2Array(
			[
				knot,
				knot + Vector2(-8.0 - trail, 4.0 - flap),
				knot + Vector2(-6.0 - trail, 6.4 - flap)
			]
		),
		red
	)
	_dot(knot, 2.0, red.darkened(0.2))


func _crown() -> void:
	var gold := Color("#e9b308")
	var edge := Color("#8a6512")
	var shape := PackedVector2Array(
		[
			Vector2(-12.5, -8.6),
			Vector2(-12.5, -14),
			Vector2(-10, -21),
			Vector2(-7.5, -14.5),
			Vector2(-5, -23),
			Vector2(-2.5, -14.5),
			Vector2(0, -25),
			Vector2(2.5, -14.5),
			Vector2(5, -23),
			Vector2(7.5, -14.5),
			Vector2(10, -21),
			Vector2(12.5, -14),
			Vector2(12.5, -8.6),
		]
	)
	_hat_poly(shape, gold)
	_hat_outline(shape, edge, 0.9)
	for p: Vector2 in [
		Vector2(-10, -21), Vector2(-5, -23), Vector2(0, -25), Vector2(5, -23), Vector2(10, -21)
	]:
		_hat_dot(p, 1.6, Color("#fff1a8"))
	_hat_dot(Vector2(-6, -11.3), 1.5, Color("#d62828"))
	_hat_dot(Vector2(0, -11.3), 1.5, Color("#3a86ff"))
	_hat_dot(Vector2(6, -11.3), 1.5, Color("#d62828"))


func _propeller_cap() -> void:
	var colours: Array[Color] = [
		Color("#e63946"), Color("#ffd166"), Color("#3a86ff"), Color("#2a9d8f")
	]
	var a0 := PI + 0.3
	var a1 := TAU - 0.3
	var c := Vector2(0, -4.5)
	for k in 4:
		var wedge := PackedVector2Array([c])
		for i in 5:
			var a := lerpf(a0, a1, (k + i / 4.0) / 4.0)
			wedge.append(c + Vector2(cos(a), sin(a)) * 15.9)
		_hat_poly(wedge, colours[k])
	_hat_poly(_rrect(Vector2(look.x * 5.0, -5.4), Vector2(7.0, 1.6), 1.0), Color("#e63946"))
	_hat_line(Vector2(0, -20.0), Vector2(0, -24.6), DARK, 1.4)
	var spin_a := _phase * 2.2 + _idle_clock * 3.0 if Blueprint.motion() else 0.6
	var half := 9.5 * absf(cos(spin_a))
	if half > 0.6:
		_hat_poly(_ellipse(Vector2(half / 2.0, -25.0), half / 2.0, 1.7, 14), Color("#e63946"))
		_hat_poly(_ellipse(Vector2(-half / 2.0, -25.0), half / 2.0, 1.7, 14), Color("#3a86ff"))
	_hat_dot(Vector2(0, -25.0), 1.5, DARK)


func _wings() -> void:
	var flap := sin(_phase * 7.0 + _idle_clock * 9.0) * 0.35 if Blueprint.motion() else 0.0
	for k in 2:
		var base := _b(-8.0 - k * 1.5, -49.0 + k * 2.5)
		var ang := -0.9 + k * 0.45 + flap
		var wing := _ellipse(base + Vector2(-7.5, -5.5).rotated(ang + 0.9), 8.2, 4.3, 18, ang)
		_poly(wing, Color(1, 1, 1, 0.55))
		_outline(wing, Color(1, 1, 1, 0.9), 0.8)


func _mortarboard() -> void:
	var navy := Color("#1b2a49")
	var cap := PackedVector2Array()
	for i in 13:
		var a := lerpf(PI + 0.5, TAU - 0.5, i / 12.0)
		cap.append(Vector2(cos(a) * 15.7, sin(a) * 15.7))
	_hat_poly(cap, navy)
	var board := PackedVector2Array(
		[Vector2(-18.5, -15.5), Vector2(0, -21.5), Vector2(18.5, -15.5), Vector2(0, -9.8)]
	)
	_hat_poly(board, navy)
	_hat_outline(board, Color("#3b5b92"), 0.9)
	var swing := sin(_phase) * walking * 2.5
	_hat_polyline(
		PackedVector2Array([Vector2(0, -15.6), Vector2(14.0, -15.2), Vector2(14.5 + swing, -6.0)]),
		GOLD,
		0.9
	)
	_hat_poly(
		PackedVector2Array(
			[
				Vector2(13.2 + swing, -6.6),
				Vector2(15.8 + swing, -6.6),
				Vector2(16.4 + swing, -1.4),
				Vector2(12.6 + swing, -1.4)
			]
		),
		GOLD
	)
	_hat_dot(Vector2(0, -15.6), 1.3, GOLD)


func _hat_star(at: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		var a := -PI / 2.0 + PI * i / 5.0
		pts.append(at + Vector2(cos(a), sin(a)) * rr)
	_hat_poly(pts, GOLD)


# --- the phantom of a locked part: hidden lines and a question mark ------------


func _draw_locked() -> void:
	var c := Color(1, 1, 1, 0.55)
	var origin := Vector2(0, -FEET_LIFT)
	draw_set_transform(origin, 0.0, Vector2.ONE)
	for side: float in [-1.0, 1.0]:
		_dashed(Vector2(side * 5.0, -27.0), Vector2(side * 5.0, 0.0), c, 1.2)
	var body := PackedVector2Array()
	for i in 25:
		var ang := PI * i / 24.0
		body.append(Vector2(cos(ang) * 18.0, -26.0 - sin(ang) * 30.0))
	body.append(Vector2(-18.0, -26.0))
	body.append(Vector2(18.0, -26.0))
	for i in body.size() - 1:
		_dashed(body[i], body[i + 1], c, 1.2)
	var head := Vector2(0, -62)
	draw_circle(head, 15.0, Blueprint.FIELD)
	for i in 24:
		if i % 2 == 0:
			draw_arc(head, 15.0, TAU * i / 24.0, TAU * (i + 1) / 24.0, 4, c, 1.2, true)
	var font := Blueprint.mono(800)
	draw_string(font, head + Vector2(-6.4, 7.6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- drawing helpers ----------------------------------------------------------------


func _col(c: Color) -> Color:
	return Color(c.r, c.g, c.b, c.a * _alpha)


func _poly(pts: PackedVector2Array, c: Color) -> void:
	draw_colored_polygon(pts, _col(c))


func _outline(pts: PackedVector2Array, c: Color, w: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, _col(c), w, true)


func _line(a: Vector2, b: Vector2, c: Color, w: float) -> void:
	draw_line(a, b, _col(c), w, true)


func _dot(p: Vector2, r: float, c: Color) -> void:
	draw_circle(p, r, _col(c))


func _arc_pts(c: Vector2, r: float, a0: float, a1: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := lerpf(a0, a1, i / 8.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, _col(col), w, true)


func _dashed(a: Vector2, b: Vector2, c: Color, w: float) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var d := (b - a) / length
	var pos := 0.0
	while pos < length:
		_line(a + d * pos, a + d * minf(pos + 3.0, length), c, w)
		pos += 5.0


func _dash_dot(a: Vector2, b: Vector2, c: Color, w: float) -> void:
	var length := a.distance_to(b)
	var d := (b - a) / length
	var pattern: Array[float] = [5.0, 1.6, 1.0, 1.6]
	var pos := 0.0
	var k := 0
	while pos < length:
		var seg := pattern[k % 4]
		if k % 2 == 0:
			_line(a + d * pos, a + d * minf(pos + seg, length), c, w)
		pos += seg
		k += 1


func _star(c: Vector2, r: float, color: Color, points := 5, inner := 0.45) -> void:
	if r < 0.2:
		return
	var pts := PackedVector2Array()
	for i in points * 2:
		var rr := r if i % 2 == 0 else r * inner
		var a := -PI / 2.0 + PI * i / points
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	_poly(pts, color)


## A point of the body at rest (no bob, squash or death) moved to the pose.
func _b(x: float, y: float) -> Vector2:
	return Vector2(x * _sx, (y - _bob) * _sy + _drop)


func _bp(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v: Vector2 in pts:
		out.append(_b(v.x, v.y))
	return out


## A point relative to the head centre, shrinking with the head as he dies.
func _h(x: float, y: float) -> Vector2:
	return _hc + Vector2(x, y) * (_hr / 15.0)


func _hat_poly(offsets: PackedVector2Array, c: Color) -> void:
	var pts := PackedVector2Array()
	for v in offsets:
		pts.append(_hat_xf * (_hc + v))
	_poly(pts, c)


func _hat_outline(offsets: PackedVector2Array, c: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for v in offsets:
		pts.append(_hat_xf * (_hc + v))
	_outline(pts, c, w)


func _hat_polyline(offsets: PackedVector2Array, c: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for v in offsets:
		pts.append(_hat_xf * (_hc + v))
	draw_polyline(pts, _col(c), w, true)


func _hat_line(a: Vector2, b: Vector2, c: Color, w: float) -> void:
	_line(_hat_xf * (_hc + a), _hat_xf * (_hc + b), c, w)


func _hat_dot(v: Vector2, r: float, c: Color) -> void:
	_dot(_hat_xf * (_hc + v), r, c)


func _rot(pts: Array, pivot: Vector2, angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v: Vector2 in pts:
		out.append(pivot + (v - pivot).rotated(angle))
	return out


## Half the body's width at rest height y (-56 at the top .. -26 at the hem).
static func _dome_w(y: float) -> float:
	var k := clampf((-26.0 - y) / 30.0, 0.0, 1.0)
	return 18.0 * sqrt(1.0 - k * k)


static func _dome_top(x: float) -> float:
	var k := clampf(x / 18.0, -1.0, 1.0)
	return -26.0 - 30.0 * sqrt(1.0 - k * k)


## The body between rest heights y0 (higher up) and y1, edge to edge.
func _band(y0: float, y1: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 7:
		var y := lerpf(y0, y1, i / 6.0)
		pts.append(_b(-_dome_w(y), y))
	for i in 7:
		var y := lerpf(y1, y0, i / 6.0)
		pts.append(_b(_dome_w(y), y))
	_poly(pts, c)


## A vertical stripe of the body from x0 to x1, from its top edge to the hem.
func _stripe(x0: float, x1: float, c: Color) -> void:
	var pts := PackedVector2Array([_b(x0, -26.0)])
	for i in 6:
		var x := lerpf(x0, x1, i / 5.0)
		pts.append(_b(x, _dome_top(x)))
	pts.append(_b(x1, -26.0))
	_poly(pts, c)


## The band of a circle of radius r between heights y0 and y1 (both above centre).
static func _chord_band(r: float, y0: float, y1: float) -> PackedVector2Array:
	var w0 := sqrt(r * r - y0 * y0)
	var w1 := sqrt(r * r - y1 * y1)
	return PackedVector2Array(
		[Vector2(-w0, y0), Vector2(w0, y0), Vector2(w1, y1), Vector2(-w1, y1)]
	)


static func _ellipse(c: Vector2, rx: float, ry: float, n := 20, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


static func _rrect(c: Vector2, half: Vector2, r: float, n := 4) -> PackedVector2Array:
	var pts := PackedVector2Array()
	r = minf(r, minf(half.x, half.y))
	var corners: Array[Vector2] = [
		Vector2(half.x - r, -half.y + r),
		Vector2(half.x - r, half.y - r),
		Vector2(-half.x + r, half.y - r),
		Vector2(-half.x + r, -half.y + r),
	]
	for k in 4:
		for i in n + 1:
			var a := -PI / 2.0 + PI / 2.0 * k + PI / 2.0 * i / n
			pts.append(c + corners[k] + Vector2(cos(a), sin(a)) * r)
	return pts


## A shape that tapers along a curve: a horn, a bent hat.
static func _tapered(spine: Array[Vector2], widths: Array[float]) -> PackedVector2Array:
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
		var nrm := Vector2(-d.y, d.x).normalized()
		left.append(spine[i] + nrm * widths[i])
		right.append(spine[i] - nrm * widths[i])
	var out := left.duplicate()
	for i in range(n - 2, -1, -1):
		out.append(right[i])
	return out
