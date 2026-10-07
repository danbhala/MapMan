class_name OutfitBodies
extends RefCounted
## What a look puts on his legs, body and neck (docs/wardrobe). Leg parts
## follow the curve of each leg (pen.leg(), pen.leg_line()). Body points are
## given at rest through pen.b() / pen.bp() / pen.band() / pen.stripe(): the
## bell runs from its hem at y -26 up to -60, 22 either side, rounding off
## below the hem, and the head covers it above about -47.
## Front-only details check pen.front(), and turn with his face (look.x), as
## do the neck pieces, which hang under his chin.
## Neck pieces fade as he dies (Player sets pen.alpha).

const CREAM := Color("#f4ecd8")
const DARK := Color("#1b1b1f")
const GOLD := Blueprint.GOLD
const BONE := Color("#efe8d6")
const STEEL := Color("#a9b4c2")
const GUNMETAL := Color("#3d4652")
const COAT_LINE := Color("#8a9bb0")
const RED := Color("#c1121f")
const BRASS := Color("#d4a017")


static func draw(pen: OutfitPen, layer: Outfits.Layer, id: String) -> void:
	match layer:
		Outfits.Layer.LEGS:
			_legs(pen, id)
		Outfits.Layer.BODY:
			_body(pen, id)
		Outfits.Layer.NECK:
			_neck(pen, id)


static func _legs(pen: OutfitPen, id: String) -> void:
	match id:
		"skeleton":
			_leg_bones(pen)
		"explorer":
			_boots(pen, Color("#3b2a1a"), 5.6)
		"astronaut":
			_boots(pen, Color("#8395a7"), 5.0)
		"superhero":
			_boots(pen, DARK, 5.2)
		"robot":
			for i in 2:
				pen.leg_line(i, 0.1, 0.9, STEEL, 1.4)
		# MapWoman's (docs/wardrobe, "Her wardrobe").
		"footballer":
			for i in 2:
				pen.leg_line(i, 0.58, 0.8, Color("#1f7a4f"), 4.4)
				pen.leg_line(i, 0.66, 0.72, Color("#f2f5f9"), 4.4)
		"chef":
			_check_legs(pen)
		"mechanic":
			_boots(pen, Color("#3b2a1a"), 5.6)
		"knight":
			for i in 2:
				pen.leg_line(i, 0.3, 0.42, STEEL, 4.4)
				pen.leg_line(i, 0.56, 0.68, STEEL, 4.4)
		"aviator":
			_boots(pen, Color("#2b1d12"), 5.4)
		"disco":
			_boots(pen, Color("#ef476f"), 6.0)


static func _body(pen: OutfitPen, id: String) -> void:
	var s := pen.look.x * 2.0  # front details turn with his face
	match id:
		"racing_green":
			pen.stripe(-4.8 + s, -1.8 + s, CREAM)
			pen.stripe(1.8 + s, 4.8 + s, CREAM)
		"blueprint":
			pen.dash_dot(pen.b(s, -54.0), pen.b(s, -27.0), Color(1, 1, 1, 0.8), 0.9)
		"hard_hat":
			_vest(pen, s)
		"doctor":
			if pen.front():
				_doctor_coat(pen, s)
			else:
				pen.line(pen.b(0, -52), pen.b(0, -26.6), COAT_LINE, 0.9)  # the back seam
		"pirate":
			for y: float in [-49.5, -43.5, -37.5, -31.5]:
				pen.band(y, y + 2.8, Color("#eeeeee"))
			_hem_band(pen, 2.4, Color("#b5171f"))  # the sash
		"skeleton":
			_ribcage(pen, s * 0.7)
		"explorer":
			_pockets(pen, s)
		"astronaut":
			_suit_panel(pen, s)
		"robot":
			_robot_panel(pen, s)
		"superhero":
			if pen.front():
				pen.star(pen.b(s, -38.5), 5.6, GOLD)
			pen.band(-29.2, -27.0, GOLD)
		"wizard":
			for p: Vector2 in [
				Vector2(-9, -37), Vector2(7, -31.5), Vector2(10.5, -41.5), Vector2(-3, -30)
			]:
				pen.star(pen.b(p.x, p.y), 1.9, GOLD, 4, 0.35)
			_hem_band(pen, 2.4, GOLD)
		"gold":
			_shine(pen)
		# MapWoman's (docs/wardrobe, "Her wardrobe").
		"sunflower":
			if pen.front():
				_sunflower(pen, s)
		"footballer":
			pen.stripe(-13.0 + s, -8.0 + s, Color("#1f7a4f"))
			pen.stripe(-2.5 + s, 2.5 + s, Color("#1f7a4f"))
			pen.stripe(8.0 + s, 13.0 + s, Color("#1f7a4f"))
		"firefighter":
			_turnout_coat(pen, s)
		"detective":
			_tweed(pen)
		"storm":
			if pen.front():
				_bolt(pen, s)
		"surgeon":
			if pen.front():
				_scrub_pocket(pen, s)
		"mechanic":
			_bib(pen, s)
		"rock_star":
			_jacket(pen, s)
		"sea_captain":
			if pen.front():
				_brass_buttons(pen, s)
		"knight":
			_plates(pen, s)
		"dragon":
			_scales(pen)
		"platinum":
			_shine(pen)


static func _neck(pen: OutfitPen, id: String) -> void:
	var s := pen.look.x * 2.0  # under his chin, which turns with his face
	match id:
		"shades":
			if pen.front():
				_sax(pen, s)
		"cowboy":
			if pen.front():
				_bandana(pen, RED, s)
		"top_hat":
			if pen.front():
				_bow_tie(pen, RED, s)
		"doctor":
			if pen.front():
				_stethoscope(pen, s)
		"explorer":
			if pen.front():
				_compass(pen)
		"astronaut":
			var ring := pen.bp(
				[
					Vector2(-12.5, -49),
					Vector2(12.5, -49),
					Vector2(11.5, -44.6),
					Vector2(-11.5, -44.6)
				]
			)
			pen.poly(ring, Color("#9aa8b8"))
			pen.outline(ring, Color("#34495e"), 0.9)
		# MapWoman's (docs/wardrobe, "Her wardrobe").
		"footballer":
			if pen.front():
				_collar(pen, Color("#1f7a4f"), s)
		"chef":
			if pen.front():
				_bandana(pen, RED, s)
		"detective":
			if pen.front():
				_magnifier(pen, s)
		"surgeon":
			if pen.front():
				_collar(pen, Color("#1b6b62"), s)
		"aviator":
			_fur_collar(pen, s)


# --- legs -----------------------------------------------------------------------


## Boots: the bottom of each leg, a little wider.
static func _boots(pen: OutfitPen, c: Color, width: float) -> void:
	for i in 2:
		pen.leg_line(i, 0.72, 1.0, c, width)
		pen.dot(pen.feet[i], width / 2.0, c)


## A bone down each leg, knobbed at both ends until they draw up into him.
static func _leg_bones(pen: OutfitPen) -> void:
	for i in 2:
		var top := pen.leg(i, 0.07)
		var bottom := pen.leg(i, 0.93)
		pen.leg_line(i, 0.07, 0.93, BONE, 1.5)
		if pen.dead < 0.8:
			pen.dot(top, 1.3, BONE)
			pen.dot(bottom, 1.3, BONE)


# --- bodies ---------------------------------------------------------------------


## A hi-vis vest: an open front and two reflective bands.
static func _vest(pen: OutfitPen, s: float) -> void:
	if pen.front():
		pen.poly(pen.bp([Vector2(-7 + s, -53), Vector2(s, -40), Vector2(7 + s, -53)]), DARK)
	pen.band(-39.5, -36.5, Color("#e3e9f0"))
	pen.band(-32.5, -29.5, Color("#e3e9f0"))


## A white coat: an open neck over scrubs, buttons, a pocket with a pen.
static func _doctor_coat(pen: OutfitPen, s: float) -> void:
	pen.poly(
		pen.bp([Vector2(-7.5 + s, -53), Vector2(s, -37.5), Vector2(7.5 + s, -53)]), Color("#178f82")
	)
	pen.line(pen.b(-7.5 + s, -53), pen.b(s, -37.5), COAT_LINE, 1.0)
	pen.line(pen.b(7.5 + s, -53), pen.b(s, -37.5), COAT_LINE, 1.0)
	pen.line(pen.b(s, -37.5), pen.b(s, -26.6), COAT_LINE, 0.9)
	for y: float in [-33.5, -29.5]:
		pen.dot(pen.b(1.7 + s, y), 0.8, COAT_LINE)
	var pocket := pen.bp(
		[
			Vector2(-14 + s, -40),
			Vector2(-8.5 + s, -40),
			Vector2(-8.5 + s, -35.5),
			Vector2(-14 + s, -35.5)
		]
	)
	pen.outline(pocket, COAT_LINE, 0.9)
	pen.line(pen.b(-12.2 + s, -42.6), pen.b(-12.2 + s, -38.8), Color("#3a86ff"), 1.3)


## A spine, four pairs of ribs and a pelvis, all round him.
static func _ribcage(pen: OutfitPen, s: float) -> void:
	pen.line(pen.b(s, -50), pen.b(s, -30), BONE, 1.8)
	for k in 4:
		var y := -46.5 + k * 4.4
		var w := OutfitPen.dome_w(y) - 3.6
		for side: float in [-1.0, 1.0]:
			var rib := pen.bp(
				[
					Vector2(s + side * 1.0, y),
					Vector2(s + side * w * 0.55, y + 0.4),
					Vector2(s + side * w, y + 2.6)
				]
			)
			pen.polyline(rib, BONE, 1.4)
	for side: float in [-1.0, 1.0]:
		pen.poly(pen.bp(OutfitPen.ellipse(Vector2(s + side * 3.3, -29.0), 3.1, 2.1, 12)), BONE)


## Two breast pockets on a field jacket.
static func _pockets(pen: OutfitPen, s: float) -> void:
	if not pen.front():
		return
	for side: float in [-1.0, 1.0]:
		var x := side * 6.0 + s
		var pocket := pen.bp(
			[
				Vector2(x - 3.2, -42),
				Vector2(x + 3.2, -42),
				Vector2(x + 3.2, -37.5),
				Vector2(x - 3.2, -37.5)
			]
		)
		pen.outline(pocket, Color("#5e4b2c"), 0.9)


## A spacesuit's chest panel of lights, and its belt.
static func _suit_panel(pen: OutfitPen, s: float) -> void:
	if pen.front():
		pen.poly(pen.bp(OutfitPen.rrect(Vector2(s, -37), Vector2(6.2, 3.9), 1.2)), Color("#3d5a80"))
		pen.dot(pen.b(s - 3.0, -37), 1.2, Color("#ef476f"))
		pen.dot(pen.b(s, -37), 1.2, GOLD)
		pen.dot(pen.b(s + 3.0, -37), 1.2, Blueprint.MINT)
	pen.band(-29.6, -27.4, Color("#c4ccd6"))


## A robot's chest panel (a dial, two lights, a slot) and a row of rivets.
static func _robot_panel(pen: OutfitPen, s: float) -> void:
	if pen.front():
		pen.poly(pen.bp(OutfitPen.rrect(Vector2(s, -37), Vector2(7.0, 4.6), 1.2)), Color("#aab6c3"))
		pen.dot(pen.b(s - 3.0, -37), 2.2, GUNMETAL)
		pen.line(pen.b(s - 3.0, -37), pen.b(s - 1.6, -38.8), Color.WHITE, 0.8)
		pen.dot(pen.b(s + 2.6, -38.6), 1.0, Color("#ef476f"))
		pen.dot(pen.b(s + 5.0, -38.6), 1.0, Blueprint.MINT)
		pen.line(pen.b(s + 1.4, -35.3), pen.b(s + 5.6, -35.3), GUNMETAL, 0.9)
	for x: float in [-14.0, -7.0, 0.0, 7.0, 14.0]:
		pen.dot(pen.b(x, -28.4), 0.9, Color("#4d5866"))


## A band along the body's bottom edge, `thick` high, following its lip.
static func _hem_band(pen: OutfitPen, thick: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var a := PI * i / 24.0
		var x := -cos(a) * OutfitPen.BODY_HALF
		pts.append(pen.b(x, OutfitPen.HEM + sin(a) * OutfitPen.LIP - thick))
	for i in range(24, -1, -1):
		var a := PI * i / 24.0
		var x := -cos(a) * OutfitPen.BODY_HALF
		pts.append(pen.b(x, OutfitPen.HEM + sin(a) * OutfitPen.LIP))
	pen.poly(pts, c)


## The light catching one shoulder of a gold body: an arc about 7/10 of the
## way out and up the bell.
static func _shine(pen: OutfitPen) -> void:
	var shine := PackedVector2Array()
	var rx := OutfitPen.BODY_HALF * 0.72
	var ry := (OutfitPen.HEM - OutfitPen.BODY_TOP) * 0.83
	for i in 7:
		var a := lerpf(PI * 0.6, PI * 0.86, i / 6.0)
		shine.append(pen.b(cos(a) * rx, OutfitPen.HEM - sin(a) * ry))
	pen.polyline(shine, Color(1, 1, 1, 0.45), 2.4)


# --- necks ----------------------------------------------------------------------


## A spotted neckerchief, knotted behind, its point under his chin.
static func _bandana(pen: OutfitPen, c: Color, s: float) -> void:
	pen.poly(
		pen.bp([Vector2(-11.5 + s, -50.5), Vector2(11.5 + s, -50.5), Vector2(1.0 + s, -37.0)]), c
	)
	for d: Vector2 in [
		Vector2(-5, -47.4),
		Vector2(4, -46.2),
		Vector2(0.5, -42),
		Vector2(-8, -49.4),
		Vector2(7, -49.2)
	]:
		pen.dot(pen.b(d.x + s, d.y), 0.8, Color(1, 1, 1, 0.85))


## A bow tie under his chin.
static func _bow_tie(pen: OutfitPen, c: Color, s: float) -> void:
	pen.poly(pen.bp([Vector2(s, -44), Vector2(s - 7.5, -47.8), Vector2(s - 7.5, -40.2)]), c)
	pen.poly(pen.bp([Vector2(s, -44), Vector2(s + 7.5, -47.8), Vector2(s + 7.5, -40.2)]), c)
	pen.poly(pen.bp(OutfitPen.rrect(Vector2(s, -44), Vector2(1.9, 2.3), 0.8)), c.darkened(0.25))


## A stethoscope round his neck, its chest piece hanging in front.
static func _stethoscope(pen: OutfitPen, s: float) -> void:
	var tube := Color("#4b5563")
	var left := pen.bp(
		[
			Vector2(s - 8, -49),
			Vector2(s - 9, -44),
			Vector2(s - 7, -39.5),
			Vector2(s - 3, -37.4),
			Vector2(s + 2.2, -37.6)
		]
	)
	pen.polyline(left, tube, 1.3)
	pen.polyline(
		pen.bp([Vector2(s + 8, -49), Vector2(s + 7.6, -44), Vector2(s + 5.2, -39.4)]), tube, 1.3
	)
	var piece := pen.b(s + 4.4, -37.2)
	pen.dot(piece, 2.7, tube)
	pen.dot(piece, 1.9, Color("#cfd8e3"))


## A brass compass on a cord; it turns with his face.
static func _compass(pen: OutfitPen) -> void:
	var s := pen.look.x * 2.0
	var cord := Color("#3b2a1a")
	pen.line(pen.b(s - 7, -49.5), pen.b(s - 1.6, -38.8), cord, 0.9)
	pen.line(pen.b(s + 7, -49.5), pen.b(s + 1.6, -38.8), cord, 0.9)
	var c := pen.b(s, -36.0)
	pen.dot(c, 3.9, BRASS)
	pen.dot(c, 2.8, CREAM)
	pen.line(c + Vector2(0.8, -2.0), c, RED, 1.1)
	pen.line(c, c + Vector2(-0.8, 2.0), DARK, 1.1)


## A gold saxophone on a strap: crook under his chin, body down his front,
## the bell turning up by his hip. As he dies it slips off the strap and
## topples to the ground beside him, fading with the neck pieces, so it never
## sits over the body that swallows him.
static func _sax(pen: OutfitPen, s: float) -> void:
	var brass := Color("#e0a82e")
	var shade := Color("#9c6b12")
	var spine: Array[Vector2] = [
		Vector2(s - 2.0, -47.5),
		Vector2(s + 3.0, -46.0),
		Vector2(s + 5.0, -42.0),
		Vector2(s + 6.0, -35.0),
		Vector2(s + 7.0, -30.0),
		Vector2(s + 10.0, -27.6),
		Vector2(s + 13.6, -29.4),
		Vector2(s + 14.6, -34.0),
	]
	var widths: Array[float] = [0.8, 1.0, 1.4, 1.9, 2.4, 2.7, 3.0, 3.4]
	var fall := clampf(pen.dead / 0.5, 0.0, 1.0)
	fall = fall * fall * (3.0 - 2.0 * fall)
	var pivot := Vector2(s + 10.0, -27.6)
	var tube := _fallen(pen, OutfitPen.tapered(spine, widths), pivot, fall)
	pen.poly(tube, brass)
	pen.outline(tube, shade, 0.7)
	var bell := _fallen(
		pen, OutfitPen.ellipse(Vector2(s + 14.8, -35.0), 4.6, 1.6, 16, -0.12), pivot, fall
	)
	pen.poly(bell, Color("#f2c75c"))
	pen.outline(bell, shade, 0.7)
	for y: float in [-40.0, -37.0, -34.0, -31.5]:
		var key := _fallen(pen, [Vector2(s + 3.4 + (y + 46.0) * 0.17, y)], pivot, fall)
		pen.dot(key[0], 0.9, Color("#fff1c4"))


## Rest points of something slipping off him as he dies (`fall` 0 to 1):
## tipped over about `pivot` as it slides from his front to the ground by
## his right foot, where it lies clear of the body that swallows him.
static func _fallen(pen: OutfitPen, pts: Array, pivot: Vector2, fall: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var ground := pen.feet[1] + Vector2(20.0, -1.5)
	for v: Vector2 in pts:
		var r := (v - pivot).rotated(-1.35 * fall)
		var on_him := pen.b(pivot.x + r.x, pivot.y + r.y)
		out.append(on_him.lerp(ground + r, fall))
	return out


# --- MapWoman's --------------------------------------------------------------------


## A chef's check trousers: light squares down each dark leg.
static func _check_legs(pen: OutfitPen) -> void:
	for i in 2:
		for k in 4:
			var t0 := 0.08 + k * 0.22
			pen.leg_line(i, t0, t0 + 0.09, Color("#d9d9d9"), 1.6)


## A sunflower on the front of her: a brown heart ringed with petals, and a
## leaf on its stalk.
static func _sunflower(pen: OutfitPen, s: float) -> void:
	var c := Vector2(s + 5.0, -41.0)
	var stalk := pen.bp([Vector2(s + 5.0, -38.5), Vector2(s + 4.0, -28.0)])
	pen.polyline(stalk, Color("#2f5d34"), 1.2)
	pen.poly(
		pen.bp(OutfitPen.ellipse(Vector2(s + 1.0, -32.5), 3.2, 1.5, 12, -0.6)), Color("#3f8a46")
	)
	for i in 8:
		var a := TAU * i / 8.0
		var petal := OutfitPen.ellipse(c + Vector2(cos(a), sin(a)) * 4.6, 2.6, 1.3, 10, a)
		pen.poly(pen.bp(petal), Color("#ffb703"))
	pen.dot(pen.b(c.x, c.y), 2.6, Color("#5a3a1a"))


## A turnout coat's two reflective bands, each with a bright stripe through
## it, and its clasps down the front.
static func _turnout_coat(pen: OutfitPen, s: float) -> void:
	for y: float in [-40.5, -32.5]:
		pen.band(y, y + 3.6, Color("#e3e9f0"))
		pen.band(y + 1.2, y + 2.4, Color("#c8f04a"))
	if pen.front():
		for y: float in [-47.0, -44.0]:
			pen.line(pen.b(s - 2.0, y), pen.b(s + 2.0, y), DARK, 1.2)


## A tweed check all round a jacket: faint lines both ways.
static func _tweed(pen: OutfitPen) -> void:
	var thread := Color(0.2, 0.15, 0.08, 0.35)
	for k in 5:
		var y := -52.0 + k * 5.0
		var w := OutfitPen.dome_w(y) - 0.4
		pen.line(pen.b(-w, y), pen.b(w, y), thread, 0.7)
	for x: float in [-15.0, -10.0, -5.0, 0.0, 5.0, 10.0, 15.0]:
		pen.line(pen.b(x, OutfitPen.dome_top(x) + 0.4), pen.b(x, OutfitPen.HEM), thread, 0.7)


## A lightning bolt down her front.
static func _bolt(pen: OutfitPen, s: float) -> void:
	var bolt := (
		pen
		. bp(
			[
				Vector2(s + 3.0, -52.0),
				Vector2(s - 4.0, -40.5),
				Vector2(s + 0.5, -40.5),
				Vector2(s - 3.0, -29.5),
				Vector2(s + 5.0, -43.0),
				Vector2(s + 0.5, -43.0),
				Vector2(s + 6.5, -52.0),
			]
		)
	)
	pen.poly(bolt, Color("#ffd60a"))


## A scrub top's pocket, with a pen in it.
static func _scrub_pocket(pen: OutfitPen, s: float) -> void:
	var pocket := pen.bp(
		[
			Vector2(-14 + s, -40),
			Vector2(-8.5 + s, -40),
			Vector2(-8.5 + s, -35.5),
			Vector2(-14 + s, -35.5)
		]
	)
	pen.outline(pocket, Color("#1b6b62"), 0.9)
	pen.line(pen.b(-12.2 + s, -42.6), pen.b(-12.2 + s, -38.8), Color("#f4f6f8"), 1.3)


## Overalls: a bib on the chest with straps up over the shoulders, and a
## pocket on the bib.
static func _bib(pen: OutfitPen, s: float) -> void:
	var denim := Color("#2a4f8a")
	var stitch := Color("#d8b25a")
	for side: float in [-1.0, 1.0]:
		var x := side * 6.0
		pen.line(pen.b(x + s * 0.5, OutfitPen.dome_top(x) + 0.4), pen.b(x + s, -44.0), denim, 2.6)
	if not pen.front():
		return
	var bib := pen.bp(OutfitPen.rrect(Vector2(s, -39.0), Vector2(7.0, 5.0), 1.2))
	pen.poly(bib, denim)
	pen.outline(bib, stitch, 0.7)
	var pocket := pen.bp(OutfitPen.rrect(Vector2(s, -38.0), Vector2(3.4, 2.4), 0.8))
	pen.outline(pocket, stitch, 0.7)
	for side: float in [-1.0, 1.0]:
		pen.dot(pen.b(s + side * 5.4, -43.0), 1.0, stitch)


## A leather jacket: an open front, studs along the shoulders, a belt.
static func _jacket(pen: OutfitPen, s: float) -> void:
	var lining := Color("#5a1f2a")
	var stud := Color("#c0c6d0")
	if pen.front():
		pen.poly(pen.bp([Vector2(-7 + s, -53), Vector2(s, -39), Vector2(7 + s, -53)]), lining)
		pen.line(pen.b(-7 + s, -53), pen.b(s, -39), stud, 0.8)
		pen.line(pen.b(7 + s, -53), pen.b(s, -39), stud, 0.8)
		pen.line(pen.b(s, -39), pen.b(s, -27), stud, 0.8)
	for x: float in [-16.0, -12.5, -9.0, 9.0, 12.5, 16.0]:
		pen.dot(pen.b(x, OutfitPen.dome_top(x) + 2.2), 0.9, stud)
	pen.band(-30.4, -28.2, Color("#2b2b33"))
	pen.poly(pen.bp(OutfitPen.rrect(Vector2(s, -29.3), Vector2(2.2, 1.6), 0.5)), stud)


## Two rows of brass buttons down a captain's jacket.
static func _brass_buttons(pen: OutfitPen, s: float) -> void:
	for side: float in [-1.0, 1.0]:
		for y: float in [-45.0, -39.5, -34.0]:
			pen.dot(pen.b(s + side * 4.0, y), 1.1, BRASS)
	pen.line(pen.b(s, -47.0), pen.b(s, -30.0), Color("#15294f"), 0.8)


## Armour plates: darker bands round the body, with rivets.
static func _plates(pen: OutfitPen, s: float) -> void:
	var dark := Color("#7b8794")
	for y: float in [-44.0, -36.0]:
		pen.band(y, y + 1.4, dark)
	for y: float in [-42.0, -34.0]:
		var w := OutfitPen.dome_w(y) - 3.0
		for k in 5:
			pen.dot(pen.b(lerpf(-w, w, k / 4.0), y), 0.8, dark)
	if pen.front():
		pen.line(pen.b(s, -52.0), pen.b(s, -28.0), dark, 1.0)


## Scales down her body: rows of little arcs, offset row by row.
static func _scales(pen: OutfitPen) -> void:
	var scale := Color("#3fae6e")
	for k in 6:
		var y := -51.0 + k * 4.6
		var w := OutfitPen.dome_w(y) - 2.4
		var x := -w + (2.3 if k % 2 == 1 else 0.0)
		while x <= w:
			pen.arc_line(pen.b(x, y), 2.2, PI, TAU, scale, 0.8)
			x += 4.6


## A V collar under her chin.
static func _collar(pen: OutfitPen, c: Color, s: float) -> void:
	var v := pen.bp([Vector2(-6.5 + s, -52.5), Vector2(s, -45.5), Vector2(6.5 + s, -52.5)])
	pen.polyline(v, c, 1.6)


## A magnifying glass on a cord, hanging in front.
static func _magnifier(pen: OutfitPen, s: float) -> void:
	var cord := Color("#3b2a1a")
	pen.line(pen.b(s - 7, -49.5), pen.b(s - 1.0, -41.0), cord, 0.9)
	pen.line(pen.b(s + 7, -49.5), pen.b(s + 1.0, -41.0), cord, 0.9)
	var c := pen.b(s, -37.0)
	pen.line(pen.b(s, -41.0), c + Vector2(0, -3.2), cord, 1.4)
	pen.dot(c, 3.6, BRASS)
	pen.dot(c, 2.6, Color(0.75, 0.9, 1.0, 0.55))
	pen.line(c + Vector2(-1.6, -1.2), c + Vector2(-0.4, -1.8), Color(1, 1, 1, 0.7), 0.8)


## A fluffy fur collar round the neck of a flying jacket.
static func _fur_collar(pen: OutfitPen, s: float) -> void:
	var fur := Color("#efe3c6")
	for k in 9:
		var x := -11.0 + k * 2.75
		var y := -49.5 + absf(x) * 0.25 - (1.5 if k % 2 == 0 else 0.0)
		pen.dot(pen.b(x + s * 0.5, y), 2.3, fur)
