class_name OutfitHats
extends RefCounted
## Hats and helmets (docs/wardrobe), in the HAT layer. Every point goes
## through pen.t() (the hat_* calls), relative to the head's centre: the hat
## rides the head, and flies off and fades as he dies. The head's top is at
## y -OutfitPen.HEAD_R (14.55); keep within the size budget (test_outfits.gd).

const PINK := Blueprint.PINK
const GOLD := Blueprint.GOLD
const CREAM := Color("#f4ecd8")
const DARK := Color("#1b1b1f")
const BRASS := Color("#d4a017")
const IRON := Color("#4b5563")


static func draw(pen: OutfitPen, id: String) -> void:
	match id:
		"party_hat":
			_party_hat(pen)
		"bobble_hat":
			_bobble_hat(pen)
		"cowboy":
			_cowboy_hat(pen)
		"hard_hat":
			_hard_hat(pen)
		"top_hat":
			_top_hat(pen)
		"doctor":
			_head_mirror(pen)
		"pirate":
			_tricorn(pen)
		"explorer":
			_pith_helmet(pen)
		"astronaut":
			_bubble(pen)
		"wizard":
			_wizard_hat(pen)
		"racing_green":
			_race_helmet(pen)
		# MapWoman's (docs/wardrobe, "Her wardrobe").
		"beret":
			_beret(pen)
		"chef":
			_toque(pen)
		"firefighter":
			_fire_helmet(pen)
		"detective":
			_deerstalker(pen)
		"surgeon":
			_scrub_cap(pen)
		"mechanic":
			_backwards_cap(pen)
		"beekeeper":
			_veil_hat(pen)
		"sea_captain":
			_peaked_cap(pen)
		"knight":
			_great_helm(pen)
		"aviator":
			_flying_cap(pen)
		"dragon":
			_dragon_hood(pen)


## A striped cone with a pom-pom, a little askew.
static func _party_hat(pen: OutfitPen) -> void:
	var base := Vector2(0, -12.0)
	var apex := base + Vector2(0, -25.0).rotated(-0.18)
	var l := base + Vector2(-9.6, 0)
	var r := base + Vector2(9.6, 0)
	pen.hat_poly(PackedVector2Array([l, apex, r]), PINK)
	for k: float in [0.12, 0.42, 0.7]:
		var band := PackedVector2Array(
			[
				l.lerp(apex, k),
				l.lerp(apex, k + 0.12),
				r.lerp(apex, k + 0.28),
				r.lerp(apex, k + 0.16)
			]
		)
		pen.hat_poly(band, GOLD)
	pen.hat_dot(apex, 3.8, Color.WHITE)
	for i in 6:
		pen.hat_dot(apex + Vector2.from_angle(TAU * i / 6.0) * 3.2, 1.6, Color.WHITE)


## A knitted hat with a ribbed cuff, a stripe and a pom-pom.
static func _bobble_hat(pen: OutfitPen) -> void:
	var r := 16.3
	var a0 := PI + asin(5.0 / r)
	var a1 := TAU - asin(5.0 / r)
	var dome := PackedVector2Array()
	for i in 17:
		var a := lerpf(a0, a1, i / 16.0)
		dome.append(Vector2(cos(a) * r, sin(a) * r))
	pen.hat_poly(dome, Color("#2a9d8f"))
	pen.hat_poly(OutfitPen.chord_band(r, -14.0, -11.2), CREAM)
	pen.hat_poly(OutfitPen.rrect(Vector2(0, -6.8), Vector2(16.9, 3.0), 2.2), CREAM)
	for i in 10:
		var x := -14.4 + i * 3.2
		pen.hat_line(Vector2(x, -9.0), Vector2(x, -4.6), Color("#d8c9a6"), 1.0)
	var pom := Vector2(0, -20.6)
	pen.hat_dot(pom, 5.2, CREAM)
	for i in 7:
		pen.hat_dot(pom + Vector2.from_angle(TAU * i / 7.0 + 0.3) * 4.4, 2.3, CREAM)


## A creased felt crown with a band, on a brim that curls up at the sides.
static func _cowboy_hat(pen: OutfitPen) -> void:
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
	pen.hat_poly(crown, felt)
	pen.hat_poly(
		PackedVector2Array(
			[Vector2(-11.2, -11), Vector2(-11.5, -15), Vector2(11.5, -15), Vector2(11.2, -11)]
		),
		dark
	)
	pen.hat_line(Vector2(0, -24.0), Vector2(0, -18.0), Color(dark, 0.6), 1.0)
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
	pen.hat_poly(brim, felt)
	pen.hat_outline(brim, dark, 0.9)


## A yellow safety helmet with a ridge; its peak turns with his face.
static func _hard_hat(pen: OutfitPen) -> void:
	var edge := Color("#8a6d00")
	var dome := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI + 0.12, TAU - 0.12, i / 16.0)
		dome.append(Vector2(cos(a) * 15.8, -5.0 + sin(a) * 16.1))
	pen.hat_poly(dome, Color("#ffc300"))
	pen.hat_poly(OutfitPen.rrect(Vector2(0, -12.8), Vector2(2.3, 7.6), 1.6), Color("#ffd75e"))
	pen.hat_outline(dome, edge, 0.9)
	var brim := OutfitPen.rrect(Vector2(pen.look.x * 2.5, -5.6), Vector2(19.2, 1.9), 1.6)
	pen.hat_poly(brim, Color("#e0aa00"))
	pen.hat_outline(brim, edge, 0.8)


## A tall black hat with a red band, tipped back a little.
static func _top_hat(pen: OutfitPen) -> void:
	var black := Color("#16161c")
	var tilt := -0.07
	var pivot := Vector2(0, -11.0)
	var crown := OutfitPen.rotated(
		[Vector2(-10.5, -11.5), Vector2(-11.6, -34), Vector2(11.6, -34), Vector2(10.5, -11.5)],
		pivot,
		tilt
	)
	pen.hat_poly(crown, black)
	var band := OutfitPen.rotated(
		[Vector2(-10.6, -12.6), Vector2(-10.9, -17.4), Vector2(10.9, -17.4), Vector2(10.6, -12.6)],
		pivot,
		tilt
	)
	pen.hat_poly(band, Color("#8d1b2e"))
	var top := OutfitPen.rotated(OutfitPen.ellipse(Vector2(0, -34), 11.6, 1.9, 16), pivot, tilt)
	pen.hat_poly(top, Color("#2b2b36"))
	var sheen := OutfitPen.rotated([Vector2(-7.4, -31), Vector2(-7.0, -19.5)], pivot, tilt)
	pen.hat_line(sheen[0], sheen[1], Color(1, 1, 1, 0.22), 1.6)
	var brim := OutfitPen.rotated(
		OutfitPen.rrect(Vector2(0, -11.0), Vector2(17.5, 1.9), 1.7), pivot, tilt
	)
	pen.hat_poly(brim, black)
	pen.hat_outline(brim, Color(1, 1, 1, 0.18), 0.8)


## A doctor's head mirror on a band round his head; from behind, the band.
static func _head_mirror(pen: OutfitPen) -> void:
	# The band's ends sit on the head's edge, just inside it: at its height
	# the head is narrower than at the centre.
	var ends_y := -5.6
	var ends_x := sqrt(OutfitPen.HEAD_R * OutfitPen.HEAD_R - ends_y * ends_y) - 0.6
	var band := PackedVector2Array(
		[
			Vector2(-ends_x, ends_y),
			Vector2(-7, -8.3),
			Vector2(0, -8.9),
			Vector2(7, -8.3),
			Vector2(ends_x, ends_y)
		]
	)
	pen.hat_polyline(band, IRON, 1.7)
	if pen.from_behind():
		return
	var c := Vector2(4.6, -9.6)
	pen.hat_dot(c, 6.4, Color("#8a99a8"))
	pen.hat_dot(c, 5.5, Color("#dfe6ee"))
	pen.hat_dot(c, 1.2, IRON)
	pen.hat_line(c + Vector2(-3.2, -2.2), c + Vector2(-1.2, -3.6), Color.WHITE, 1.1)


## A pirate's three-cornered hat with gold trim.
static func _tricorn(pen: OutfitPen) -> void:
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
	pen.hat_poly(shape, DARK)
	var trim := PackedVector2Array(
		[
			Vector2(22, -16.5),
			Vector2(14, -11.5),
			Vector2(0, -7.0),
			Vector2(-14, -11.5),
			Vector2(-22, -16.5)
		]
	)
	pen.hat_polyline(trim, BRASS, 1.5)
	pen.hat_line(Vector2(-13, -24.5), Vector2(-22, -16.5), BRASS, 1.0)
	pen.hat_line(Vector2(13, -24.5), Vector2(22, -16.5), BRASS, 1.0)


## A pith helmet: a domed crown with a band and a button, on a wide brim.
static func _pith_helmet(pen: OutfitPen) -> void:
	var light := Color("#e3d3a6")
	var dark := Color("#8d7a52")
	var brim := OutfitPen.ellipse(Vector2(0, -8.0), 21.5, 4.0, 24)
	pen.hat_poly(brim, Color("#c8b48a"))
	pen.hat_outline(brim, dark, 0.8)
	var dome := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI, TAU, i / 16.0)
		dome.append(Vector2(cos(a) * 14.0, -8.5 + sin(a) * 15.0))
	pen.hat_poly(dome, light)
	pen.hat_outline(dome, dark, 0.8)
	pen.hat_poly(
		PackedVector2Array(
			[Vector2(-14, -8.5), Vector2(-13.6, -12.0), Vector2(13.6, -12.0), Vector2(14, -8.5)]
		),
		dark
	)
	pen.hat_dot(Vector2(0, -23.4), 1.8, dark)


## A glass helmet round his whole head, with a shine on it.
static func _bubble(pen: OutfitPen) -> void:
	var c := Vector2(0, -1.5)
	var glass := OutfitPen.ellipse(c, 20.5, 20.5, 40)
	pen.hat_poly(glass, Color(0.78, 0.9, 1.0, 0.16))
	pen.hat_outline(OutfitPen.ellipse(c, 21.5, 21.5, 40), Color("#2b3a4f"), 0.9)
	pen.hat_outline(glass, Color(1, 1, 1, 0.85), 1.6)
	var shine := PackedVector2Array()
	for i in 9:
		var a := lerpf(3.55, 4.35, i / 8.0)
		shine.append(c + Vector2(cos(a), sin(a)) * 16.5)
	pen.hat_polyline(shine, Color(1, 1, 1, 0.75), 2.2)
	pen.hat_dot(c + Vector2.from_angle(4.62) * 16.5, 1.1, Color.WHITE)


## A tall pointed hat, bent over at the tip, with stars and a moon.
static func _wizard_hat(pen: OutfitPen) -> void:
	var purple := Color("#8e3fd1")
	pen.hat_poly(OutfitPen.ellipse(Vector2(0, -9.6), 21.0, 3.7, 24), Color("#6a2bb0"))
	var spine: Array[Vector2] = [
		Vector2(0, -10),
		Vector2(-0.6, -19),
		Vector2(-3.2, -27.6),
		Vector2(-8.6, -33.6),
		Vector2(-15.6, -35.6)
	]
	var widths: Array[float] = [12.6, 9.0, 5.8, 2.8, 0.0]
	pen.hat_poly(OutfitPen.tapered(spine, widths), purple)
	pen.hat_poly(
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
	pen.hat_star(Vector2(3.6, -20.4), 2.4, GOLD)
	pen.hat_star(Vector2(-4.2, -27.0), 1.8, GOLD)
	# A crescent moon: a gold disc with a purple one over most of it.
	pen.hat_dot(Vector2(-1.4, -16.8), 2.6, GOLD)
	pen.hat_dot(Vector2(-0.4, -17.6), 2.3, purple)


## A racing driver's helmet: a white shell down to his cheeks, a green
## stripe over the top, and the dark visor flipped up so his eyes show.
static func _race_helmet(pen: OutfitPen) -> void:
	var shell := Color("#f4f6f8")
	var edge := Color("#56606b")
	var green := Color("#1f7a4f")
	var r := 17.0
	var pts := PackedVector2Array()
	# Round over the top, then straight down the sides to the cheeks.
	pts.append(Vector2(-r + 0.6, 9.0))
	for i in 19:
		var a := lerpf(PI, TAU, i / 18.0)
		pts.append(Vector2(cos(a) * r, -1.0 + sin(a) * (r + 0.5)))
	pts.append(Vector2(r - 0.6, 9.0))
	if pen.front():  # the opening for his face
		pts.append(Vector2(r - 3.2, 9.6))
		pts.append(Vector2(r - 3.6, 0.0))
		pts.append(Vector2(-r + 3.6, 0.0))
		pts.append(Vector2(-r + 3.2, 9.6))
	else:
		pts.append(Vector2(0, 11.0))
	pen.hat_poly(pts, shell)
	# The stripe, front to back over the crown.
	pen.hat_poly(
		PackedVector2Array(
			[Vector2(-3.4, -18.2), Vector2(3.4, -18.2), Vector2(3.0, -6.2), Vector2(-3.0, -6.2)]
		),
		green
	)
	pen.hat_outline(pts, edge, 0.9)
	if not pen.front():
		return
	# The visor, up on his forehead, with a shine.
	var visor := OutfitPen.rrect(Vector2(pen.look.x * 1.5, -4.0), Vector2(12.6, 3.0), 2.4)
	pen.hat_poly(visor, Color("#20242b"))
	pen.hat_line(Vector2(-8.5, -5.4), Vector2(-3.0, -5.6), Color(1, 1, 1, 0.5), 1.0)


# --- MapWoman's --------------------------------------------------------------------


## A soft beret, pulled down over one side, with its stalk on top.
static func _beret(pen: OutfitPen) -> void:
	var wool := Color("#b5172f")
	var shade := Color("#7d0f20")
	var pivot := Vector2(0, -11.0)
	# The crown: a full disc, wider than the head, flopped to the left.
	var crown := OutfitPen.rotated(
		OutfitPen.ellipse(Vector2(-3.0, -14.5), 17.5, 6.2, 24), pivot, -0.22
	)
	pen.hat_poly(crown, wool)
	# The band, round the head where it sits.
	var band := OutfitPen.rotated(
		OutfitPen.chord_band(OutfitPen.HEAD_R + 0.8, -12.8, -9.0), pivot, -0.22
	)
	pen.hat_poly(band, shade)
	var stalk := OutfitPen.rotated([Vector2(-3.0, -20.2), Vector2(-2.4, -24.0)], pivot, -0.22)
	pen.hat_line(stalk[0], stalk[1], shade, 1.4)
	pen.hat_dot(stalk[1], 1.1, shade)


## A chef's toque: a pleated band, puffed out on top.
static func _toque(pen: OutfitPen) -> void:
	var white := Color("#fbfbfb")
	var edge := Color("#b9b9b9")
	var band := OutfitPen.rrect(Vector2(0, -14.0), Vector2(11.6, 4.0), 1.4)
	var puff := PackedVector2Array()
	for i in 25:
		var a := lerpf(PI + 0.25, TAU - 0.25, i / 24.0)
		# Three bulges round the top.
		var r := 13.0 + 2.2 * absf(sin(a * 3.0))
		puff.append(Vector2(cos(a) * r, -18.0 + sin(a) * r))
	puff.append(Vector2(11.2, -17.0))
	puff.append(Vector2(-11.2, -17.0))
	pen.hat_poly(puff, white)
	pen.hat_outline(puff, edge, 0.8)
	pen.hat_poly(band, white)
	pen.hat_outline(band, edge, 0.8)
	for x: float in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		pen.hat_line(Vector2(x, -17.4), Vector2(x, -10.6), edge, 0.8)


## A fire helmet: a red dome, a long brim down at the back, a badge in front.
static func _fire_helmet(pen: OutfitPen) -> void:
	var red := Color("#c1121f")
	var dark := Color("#7a0b14")
	var dome := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI + 0.1, TAU - 0.1, i / 16.0)
		dome.append(Vector2(cos(a) * 15.6, -6.0 + sin(a) * 15.4))
	pen.hat_poly(dome, red)
	# A ridge over the crown.
	pen.hat_poly(OutfitPen.rrect(Vector2(0, -14.0), Vector2(2.4, 7.0), 1.4), Color("#e0303c"))
	pen.hat_outline(dome, dark, 0.9)
	# The brim, deeper behind his face than in front of it.
	var f := pen.look.x * 2.5
	var brim := PackedVector2Array(
		[
			Vector2(-21.0 + f, -4.0),
			Vector2(-16.0 + f, -7.2),
			Vector2(0.0, -7.6),
			Vector2(16.0 + f, -7.2),
			Vector2(21.0 + f, -4.0),
			Vector2(17.0 + f, -2.4),
			Vector2(0.0, -2.0),
			Vector2(-17.0 + f, -2.4),
		]
	)
	pen.hat_poly(brim, red)
	pen.hat_outline(brim, dark, 0.8)
	if pen.front():
		var badge := PackedVector2Array(
			[
				Vector2(f - 3.4, -17.5),
				Vector2(f + 3.4, -17.5),
				Vector2(f + 3.0, -11.5),
				Vector2(f, -9.6),
				Vector2(f - 3.0, -11.5),
			]
		)
		pen.hat_poly(badge, GOLD)
		pen.hat_outline(badge, dark, 0.6)


## A deerstalker: a tweed cap with a peak at the front and the back, and the
## ear flaps tied up on top.
static func _deerstalker(pen: OutfitPen) -> void:
	var tweed := Color("#8a6d4a")
	var dark := Color("#5a4530")
	var dome := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI, TAU, i / 16.0)
		dome.append(Vector2(cos(a) * 15.6, -7.0 + sin(a) * 13.4))
	pen.hat_poly(dome, tweed)
	# The check: a few lines across the crown.
	for k in 3:
		var y := -17.0 + k * 3.6
		var w := sqrt(maxf(15.6 * 15.6 - pow((y + 7.0) / 13.4 * 15.6, 2.0), 0.0)) - 1.0
		pen.hat_line(Vector2(-w, y), Vector2(w, y), Color(dark, 0.5), 0.7)
	for x: float in [-7.0, 0.0, 7.0]:
		pen.hat_line(Vector2(x, -20.2), Vector2(x, -8.0), Color(dark, 0.5), 0.7)
	pen.hat_outline(dome, dark, 0.9)
	# Two peaks, out either side.
	for side: float in [-1.0, 1.0]:
		var peak := PackedVector2Array(
			[
				Vector2(side * 14.0, -9.6),
				Vector2(side * 23.0, -8.0),
				Vector2(side * 22.0, -5.2),
				Vector2(side * 13.0, -6.6),
			]
		)
		pen.hat_poly(peak, tweed)
		pen.hat_outline(peak, dark, 0.8)
	# The flaps tied over the crown with a bow.
	pen.hat_poly(
		PackedVector2Array(
			[Vector2(-9.0, -14.5), Vector2(-4.5, -21.8), Vector2(0.0, -20.0), Vector2(-5.0, -13.0)]
		),
		dark
	)
	pen.hat_poly(
		PackedVector2Array(
			[Vector2(9.0, -14.5), Vector2(4.5, -21.8), Vector2(0.0, -20.0), Vector2(5.0, -13.0)]
		),
		dark
	)
	pen.hat_dot(Vector2(0.0, -20.4), 1.3, dark)


## A surgeon's cap: a soft cap down to the ears, tied at the back.
static func _scrub_cap(pen: OutfitPen) -> void:
	var cloth := Color("#1b6b62")
	var r := OutfitPen.HEAD_R + 1.2
	var cap := PackedVector2Array()
	for i in 19:
		var a := lerpf(PI + 0.4, TAU - 0.4, i / 18.0)
		cap.append(Vector2(cos(a) * r, -1.0 + sin(a) * r))
	pen.hat_poly(cap, cloth)
	pen.hat_polyline(
		PackedVector2Array([Vector2(-r + 0.4, -7.0), Vector2(0.0, -4.6), Vector2(r - 0.4, -7.0)]),
		Color("#2a9d8f"),
		1.6
	)
	# The ties, hanging behind.
	var back := -1.0 if pen.look.x >= 0.0 else 1.0
	pen.hat_line(Vector2(back * 13.0, -6.0), Vector2(back * 17.5, 2.0), cloth, 1.4)
	pen.hat_line(Vector2(back * 13.0, -6.0), Vector2(back * 14.5, 4.0), cloth, 1.4)


## A cap worn backwards: the dome, its button, the peak sticking up behind.
static func _backwards_cap(pen: OutfitPen) -> void:
	var red := Color("#c1121f")
	var dark := Color("#7a0b14")
	var r := 15.6
	var dome := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI + 0.15, TAU - 0.15, i / 16.0)
		dome.append(Vector2(cos(a) * r, -5.0 + sin(a) * r))
	# The peak, behind the head, pokes up over the dome on the far side.
	var back := -1.0 if pen.look.x >= 0.0 else 1.0
	var peak := PackedVector2Array(
		[
			Vector2(back * 6.0, -17.5),
			Vector2(back * 17.0, -24.0),
			Vector2(back * 21.0, -19.0),
			Vector2(back * 13.0, -12.0),
		]
	)
	pen.hat_poly(peak, dark)
	pen.hat_poly(dome, red)
	pen.hat_outline(dome, dark, 0.9)
	for k in 3:
		var a := lerpf(PI + 0.5, TAU - 0.5, k / 2.0)
		pen.hat_line(
			Vector2(0, -20.0), Vector2(cos(a) * r, -5.0 + sin(a) * r), Color(dark, 0.5), 0.7
		)
	pen.hat_dot(Vector2(0, -20.4), 1.4, dark)
	# The strap's opening at the back, seen from behind.
	if pen.from_behind():
		pen.hat_poly(OutfitPen.rrect(Vector2(0, -7.4), Vector2(3.6, 2.0), 1.0), Color("#f4ecd8"))


## A beekeeper's hat: a wide brim, a low crown, and the veil hanging from the
## brim round the face.
static func _veil_hat(pen: OutfitPen) -> void:
	var straw := Color("#e8d7a8")
	var edge := Color("#9c8a5c")
	var brim := OutfitPen.ellipse(Vector2(0, -10.0), 21.0, 3.8, 24)
	var veil := PackedVector2Array(
		[Vector2(-20.0, -10.0), Vector2(20.0, -10.0), Vector2(16.0, 12.0), Vector2(-16.0, 12.0)]
	)
	pen.hat_poly(veil, Color(0.1, 0.1, 0.15, 0.22))
	for k in 5:
		var x := -16.0 + k * 8.0
		pen.hat_line(Vector2(x * 1.2, -10.0), Vector2(x, 12.0), Color(0.1, 0.1, 0.15, 0.3), 0.6)
	for k in 3:
		var y := -4.0 + k * 7.0
		pen.hat_line(Vector2(-18.0, y), Vector2(18.0, y), Color(0.1, 0.1, 0.15, 0.3), 0.6)
	pen.hat_poly(brim, straw)
	pen.hat_outline(brim, edge, 0.8)
	var crown := PackedVector2Array()
	for i in 13:
		var a := lerpf(PI, TAU, i / 12.0)
		crown.append(Vector2(cos(a) * 13.0, -10.5 + sin(a) * 8.0))
	pen.hat_poly(crown, straw)
	pen.hat_outline(crown, edge, 0.8)
	pen.hat_poly(
		PackedVector2Array(
			[
				Vector2(-13.0, -10.5),
				Vector2(-12.6, -13.2),
				Vector2(12.6, -13.2),
				Vector2(13.0, -10.5)
			]
		),
		Color("#2b2b2b")
	)


## A captain's peaked cap: a white top, a dark band with a badge, a peak
## over the eyes.
static func _peaked_cap(pen: OutfitPen) -> void:
	var navy := Color("#15294f")
	var white := Color("#f4f6f8")
	var crown := PackedVector2Array()
	for i in 17:
		var a := lerpf(PI, TAU, i / 16.0)
		crown.append(Vector2(cos(a) * 16.6, -12.0 + sin(a) * 8.0))
	crown.append(Vector2(14.6, -9.0))
	crown.append(Vector2(-14.6, -9.0))
	pen.hat_poly(crown, white)
	pen.hat_outline(crown, Color("#8a93a3"), 0.8)
	var band := PackedVector2Array(
		[Vector2(-14.6, -9.0), Vector2(14.6, -9.0), Vector2(14.0, -5.0), Vector2(-14.0, -5.0)]
	)
	pen.hat_poly(band, navy)
	var f := pen.look.x * 2.5
	var peak := PackedVector2Array(
		[
			Vector2(-12.0 + f, -6.0),
			Vector2(12.0 + f, -6.0),
			Vector2(15.0 + f, -3.6),
			Vector2(11.0 + f, -1.8),
			Vector2(-11.0 + f, -1.8),
			Vector2(-15.0 + f, -3.6),
		]
	)
	pen.hat_poly(peak, Color("#0e1b36"))
	pen.hat_outline(peak, BRASS, 0.7)
	if pen.front():
		pen.hat_dot(Vector2(f, -11.6), 2.2, BRASS)
		pen.hat_line(Vector2(f - 5.0, -7.0), Vector2(f + 5.0, -7.0), BRASS, 1.0)


## A knight's helm: a steel shell to the cheeks, the visor up, and a red
## plume that sways as she walks.
static func _great_helm(pen: OutfitPen) -> void:
	var steel := Color("#b8c2cf")
	var edge := Color("#4b5563")
	var r := 17.0
	var pts := PackedVector2Array()
	pts.append(Vector2(-r + 0.6, 9.0))
	for i in 19:
		var a := lerpf(PI, TAU, i / 18.0)
		pts.append(Vector2(cos(a) * r, -1.0 + sin(a) * (r + 0.5)))
	pts.append(Vector2(r - 0.6, 9.0))
	if pen.front():
		pts.append(Vector2(r - 3.6, 9.6))
		pts.append(Vector2(r - 4.0, -0.4))
		pts.append(Vector2(-r + 4.0, -0.4))
		pts.append(Vector2(-r + 3.6, 9.6))
	else:
		pts.append(Vector2(0, 11.0))
	# The plume first, so it rises from behind the crown.
	var sway := 0.0
	if pen.motion:
		sway = sin(pen.phase * 2.0) * 2.4 * pen.walking + sin(pen.idle_clock * 1.6) * 0.8
	var spine: Array[Vector2] = [
		Vector2(0.0, -17.0),
		Vector2(-2.0 + sway * 0.3, -23.0),
		Vector2(-6.0 + sway * 0.7, -28.0),
		Vector2(-12.0 + sway, -31.0),
	]
	var widths: Array[float] = [1.6, 3.0, 3.4, 0.0]
	pen.hat_poly(OutfitPen.tapered(spine, widths), Color("#c1121f"))
	pen.hat_poly(pts, steel)
	pen.hat_outline(pts, edge, 0.9)
	pen.hat_line(Vector2(0, -17.5), Vector2(0, -8.0), edge, 1.0)
	if not pen.front():
		return
	# The visor, up on the brow, with its breathing slits.
	var visor := OutfitPen.rrect(Vector2(pen.look.x * 1.5, -4.6), Vector2(13.0, 3.2), 1.6)
	pen.hat_poly(visor, Color("#9aa5b4"))
	pen.hat_outline(visor, edge, 0.8)
	for x: float in [-6.0, -2.0, 2.0, 6.0]:
		pen.hat_line(
			Vector2(x + pen.look.x * 1.5, -6.4), Vector2(x + pen.look.x * 1.5, -2.8), edge, 0.8
		)


## A leather flying cap with ear flaps, the goggles pushed up on it.
static func _flying_cap(pen: OutfitPen) -> void:
	var leather := Color("#5e4027")
	var dark := Color("#3a2616")
	var r := OutfitPen.HEAD_R + 1.0
	var cap := PackedVector2Array()
	cap.append(Vector2(-r + 1.0, 8.0))
	for i in 19:
		var a := lerpf(PI, TAU, i / 18.0)
		cap.append(Vector2(cos(a) * r, -1.5 + sin(a) * r))
	cap.append(Vector2(r - 1.0, 8.0))
	if pen.front():
		cap.append(Vector2(r - 4.6, 8.0))
		cap.append(Vector2(r - 4.0, -4.0))
		cap.append(Vector2(-r + 4.0, -4.0))
		cap.append(Vector2(-r + 4.6, 8.0))
	else:
		cap.append(Vector2(0, 6.0))
	pen.hat_poly(cap, leather)
	pen.hat_outline(cap, dark, 0.8)
	pen.hat_line(Vector2(0, -16.0), Vector2(0, -8.0), dark, 0.8)
	# The strap round the cap, and the goggles on the brow.
	pen.hat_line(Vector2(-r + 1.0, -7.4), Vector2(r - 1.0, -7.4), dark, 2.0)
	if not pen.front():
		return
	for side: float in [-1.0, 1.0]:
		var c := Vector2(side * 5.8 + pen.look.x * 1.5, -8.6)
		pen.hat_dot(c, 3.9, BRASS)
		pen.hat_dot(c, 3.0, Color("#2b3a4f"))
		pen.hat_line(c + Vector2(-1.6, -1.2), c + Vector2(-0.4, -1.8), Color(1, 1, 1, 0.5), 0.8)


## A dragon's hood: green over the head to the cheeks, horns, and spines
## down the middle.
static func _dragon_hood(pen: OutfitPen) -> void:
	var hide := Color("#237a48")
	var dark := Color("#164d2e")
	var horn := Color("#efe6c8")
	var r := OutfitPen.HEAD_R + 1.4
	var hood := PackedVector2Array()
	hood.append(Vector2(-r + 1.0, 9.0))
	for i in 19:
		var a := lerpf(PI, TAU, i / 18.0)
		hood.append(Vector2(cos(a) * r, -0.5 + sin(a) * r))
	hood.append(Vector2(r - 1.0, 9.0))
	if pen.front():
		hood.append(Vector2(r - 4.4, 9.4))
		hood.append(Vector2(r - 4.6, -2.0))
		hood.append(Vector2(0.0, -6.0))
		hood.append(Vector2(-r + 4.6, -2.0))
		hood.append(Vector2(-r + 4.4, 9.4))
	else:
		hood.append(Vector2(0, 11.0))
	# The horns, behind the hood.
	for side: float in [-1.0, 1.0]:
		var spine: Array[Vector2] = [
			Vector2(side * 8.0, -11.0),
			Vector2(side * 11.5, -18.0),
			Vector2(side * 12.0, -25.0),
		]
		var widths: Array[float] = [3.0, 2.0, 0.0]
		pen.hat_poly(OutfitPen.tapered(spine, widths), horn)
	pen.hat_poly(hood, hide)
	pen.hat_outline(hood, dark, 0.9)
	# Spines down the crown.
	for k in 3:
		var y := -15.5 + k * 3.8
		var tip := Vector2(0.0, y - 4.2)
		pen.hat_poly(PackedVector2Array([Vector2(-1.8, y), Vector2(1.8, y), tip]), dark)
