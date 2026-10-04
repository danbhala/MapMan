class_name OutfitHats
extends RefCounted
## Hats and helmets (docs/wardrobe), in the HAT layer. Every point goes
## through pen.t() (the hat_* calls), relative to the head's centre: the hat
## rides the head, and flies off and fades as he dies. The head's top is at
## y -15; keep within the size budget (test_outfits.gd).

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
	var band := PackedVector2Array(
		[
			Vector2(-14.8, -5.6),
			Vector2(-7, -8.3),
			Vector2(0, -8.9),
			Vector2(7, -8.3),
			Vector2(14.8, -5.6)
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
