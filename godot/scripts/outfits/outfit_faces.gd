class_name OutfitFaces
extends RefCounted
## What a look does to his head and face (docs/wardrobe): HEAD-layer parts
## over the head (points through pen.h(), which sink and shrink with it),
## replacement eyes, and FACE-layer parts over the eyes. Nothing in the face
## shows from behind. Replacement eyes still blink, look about and widen when
## he is happy (pen.eye(), pen.eye_open()). While he dies, these layers fade
## out before the body swallows the head (Player sets pen.alpha).

const DARK := Color("#1b1b1f")
const BRASS := Color("#d4a017")
const BONE := Color("#efe8d6")
const SKY := Color("#4cc9f0")
const GUNMETAL := Color("#3d4652")
const GLOW := Color("#ffd23f")


static func draw(pen: OutfitPen, layer: Outfits.Layer, id: String) -> void:
	if layer == Outfits.Layer.FACE and pen.from_behind():
		return
	match layer:
		Outfits.Layer.HEAD:
			_head(pen, id)
		Outfits.Layer.FACE:
			_face(pen, id)


## The head in another shape; false keeps the round one. A shape must still
## shrink inside the dead body (README rule 9).
static func head_shape(pen: OutfitPen, id: String, colour: Color) -> bool:
	match id:
		"robot":
			var k := _box_scale(pen)
			var box := OutfitPen.rrect(pen.hc, Vector2(14.2, 14.2) * k, 5.0 * k)
			pen.poly(box, colour)
			pen.outline(box, GUNMETAL, 1.2)
			return true
	return false


## Eyes of another kind; false keeps the classic ones.
static func eyes(pen: OutfitPen, id: String, colour: Color) -> bool:
	match id:
		"superhero":
			_mask(pen)
			pen.classic_eyes(colour)
		"pumpkin":
			_pumpkin_face(pen)
		"skeleton":
			_skull_face(pen)
		"robot":
			_robot_face(pen)
		_:
			return false
	return true


static func _head(pen: OutfitPen, id: String) -> void:
	match id:
		"blueprint":
			var c := Color(1, 1, 1, 0.55)
			pen.dash_dot(pen.h(-19, 0), pen.h(19, 0), c, 0.8)
			pen.dash_dot(pen.h(0, -19), pen.h(0, 19), c, 0.8)
		"pumpkin":
			_pumpkin_head(pen)
		"robot":
			_robot_head(pen)
		"gold":
			pen.arc_line(pen.hc, pen.hr * 0.7, 3.5, 4.4, Color(1, 1, 1, 0.55), 2.2)


static func _face(pen: OutfitPen, id: String) -> void:
	match id:
		"shades":
			_shades(pen)
		"top_hat":
			_monocle(pen)
		"pirate":
			_eye_patch(pen)
		"wizard":
			_beard(pen, Color("#f1f1f1"), Color("#9aa5b1"))


## Sunglasses: two dark lenses on the eyes, a bridge and the arms.
static func _shades(pen: OutfitPen) -> void:
	var lens := Color("#15171c")
	var e: Array[Vector2] = [pen.eye(-1.0), pen.eye(1.0)]
	for i in 2:
		var c := e[i] + Vector2(0, -0.2)
		pen.poly(OutfitPen.rrect(c, Vector2(4.7, 3.3), 1.6), lens)
		pen.line(c + Vector2(-2.7, -1.5), c + Vector2(-0.5, -2.1), Color(1, 1, 1, 0.55), 1.0)
	pen.line(e[0] + Vector2(4.2, -1.4), e[1] + Vector2(-4.2, -1.4), lens, 1.4)
	pen.line(e[0] + Vector2(-4.5, -1.4), pen.hc + Vector2(-14.3, -3.0), lens, 1.2)
	pen.line(e[1] + Vector2(4.5, -1.4), pen.hc + Vector2(14.3, -3.0), lens, 1.2)


## A domino mask under the eyes; seen from behind, its band.
static func _mask(pen: OutfitPen) -> void:
	if pen.from_behind():
		pen.poly(OutfitPen.rrect(pen.h(0, 0.8), Vector2(14.8, 2.4), 1.0), DARK)
		return
	var lx := pen.look.x * 3.5
	var ly := pen.look.y * 2.5
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
		shape.append(pen.h(v.x + lx, v.y + 1.0 + ly))
	pen.poly(shape, DARK)


## A gold-rimmed monocle on one eye, on a chain to his collar.
static func _monocle(pen: OutfitPen) -> void:
	var e := pen.eye(1.0)
	pen.arc(e, 3.9, 0.0, TAU, BRASS, 1.1)
	if pen.dead == 0.0:
		var chain := PackedVector2Array(
			[e + Vector2(2.8, 2.8), e + Vector2(4.2, 9.0), pen.b(10.0, -45.0)]
		)
		pen.polyline(chain, BRASS, 0.7)


## A patch over one eye, tied round his head.
static func _eye_patch(pen: OutfitPen) -> void:
	var e := pen.eye(1.0)
	pen.poly(OutfitPen.ellipse(e, 3.9, 3.5), DARK)
	pen.line(e + Vector2(-2.6, -2.6), pen.hc + Vector2(-11.5, -10.0), DARK, 1.1)
	pen.line(e + Vector2(2.9, -1.6), pen.hc + Vector2(14.4, -3.0), DARK, 1.1)


## A long white beard and a moustache; the beard's tip lags as he turns.
static func _beard(pen: OutfitPen, c: Color, edge: Color) -> void:
	var lx := pen.look.x * 3.0
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
		beard.append(pen.h(v.x + lx * (1.0 - v.y / 40.0), v.y))
	pen.poly(beard, c)
	pen.outline(beard, edge, 0.8)
	for side: float in [-1.0, 1.0]:
		var m := OutfitPen.ellipse(pen.h(side * 3.6 + lx, 6.6), 4.4, 1.9, 14, side * 0.3)
		pen.poly(m, c)
		pen.outline(m, edge, 0.7)


## A pumpkin's ribs, its stem and a curl of vine.
static func _pumpkin_head(pen: OutfitPen) -> void:
	var rib := Color("#c95f0e")
	for rx: float in [5.5, 11.0]:
		for side: float in [-1.0, 1.0]:
			var groove := PackedVector2Array()
			for i in 13:
				var a := lerpf(-PI / 2.0, PI / 2.0, i / 12.0)
				groove.append(pen.h(side * cos(a) * rx, sin(a) * 14.4))
			pen.polyline(groove, rib, 1.1)
	var green := Color("#3d7a3a")
	pen.poly(
		PackedVector2Array(
			[pen.h(-2.3, -14.0), pen.h(2.3, -14.0), pen.h(3.4, -20.4), pen.h(0.6, -21.2)]
		),
		green
	)
	var curl := PackedVector2Array(
		[pen.h(2.6, -18.6), pen.h(6.2, -21.2), pen.h(8.0, -18.6), pen.h(6.3, -16.8)]
	)
	pen.polyline(curl, green, 1.0)


## A jack-o'-lantern's carved face, lit from inside: its eyes blink and look.
static func _pumpkin_face(pen: OutfitPen) -> void:
	if pen.from_behind():
		return
	var open := pen.eye_open()
	for side: float in [-1.0, 1.0]:
		var e := pen.eye(side)
		pen.poly(
			PackedVector2Array(
				[
					e + Vector2(-3.4, 2.3 * open),
					e + Vector2(3.4, 2.3 * open),
					e + Vector2(0.5 * side, -3.0 * open)
				]
			),
			GLOW
		)
	var lx := pen.look.x * 3.0
	pen.poly(PackedVector2Array([pen.h(lx - 1.6, 6.8), pen.h(lx + 1.6, 6.8), pen.h(lx, 4.4)]), GLOW)
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
		mouth.append(pen.h(v.x + lx * 0.8, v.y))
	pen.poly(mouth, GLOW)


## A skull's eye sockets (they still blink), nose and teeth.
static func _skull_face(pen: OutfitPen) -> void:
	if pen.from_behind():
		return
	var dark := Color("#1b1b22")
	var open := maxf(1.0 - pen.blink, 0.15) * (1.0 + pen.happy * 0.2)
	for side: float in [-1.0, 1.0]:
		var e := pen.eye(side) + Vector2(0, -0.3)
		pen.poly(OutfitPen.ellipse(e, 3.5, 3.9 * open, 16), dark)
		if open > 0.5:
			pen.dot(e + Vector2(-1.0, -1.2), 0.7, Color.WHITE)
	var lx := pen.look.x * 3.5
	pen.poly(PackedVector2Array([pen.h(lx - 1.6, 7.0), pen.h(lx + 1.6, 7.0), pen.h(lx, 4.0)]), dark)
	pen.line(pen.h(lx * 0.8 - 6.0, 10.5), pen.h(lx * 0.8 + 6.0, 10.5), dark, 3.4)
	for x: float in [-4.4, -1.5, 1.5, 4.4]:
		pen.line(pen.h(lx * 0.8 + x, 9.3), pen.h(lx * 0.8 + x, 11.7), BONE, 2.1)


## How big the robot's box head is: it shrinks faster than a round head as
## he dies, so its corners stay inside the dead body.
static func _box_scale(pen: OutfitPen) -> float:
	return pen.hr / OutfitPen.HEAD_R * (1.0 - pen.dead * 0.3)


## The robot head's rivets, ear bolts and antenna.
static func _robot_head(pen: OutfitPen) -> void:
	var k := _box_scale(pen)
	for c: Vector2 in [
		Vector2(-10.5, -10.5), Vector2(10.5, -10.5), Vector2(-10.5, 10.5), Vector2(10.5, 10.5)
	]:
		pen.dot(pen.hc + c * k, 1.1, Color("#6b7685"))
	for side: float in [-1.0, 1.0]:
		var bolt := OutfitPen.rrect(
			pen.hc + Vector2(side * 15.4, 0) * k, Vector2(1.6, 4.2) * k, 0.8
		)
		pen.poly(bolt, GUNMETAL)
	pen.line(pen.hc + Vector2(0, -14.2) * k, pen.hc + Vector2(0, -21.0) * k, GUNMETAL, 1.4)
	pen.dot(pen.hc + Vector2(0, -22.6) * k, 2.5 * k, Color("#ef476f"))


## LED eyes that blink and look, and a mouth grille.
static func _robot_face(pen: OutfitPen) -> void:
	if pen.from_behind():
		return
	var open := pen.eye_open()
	for side: float in [-1.0, 1.0]:
		var e := pen.eye(side)
		pen.poly(OutfitPen.rrect(e, Vector2(4.3, 2.8 * open + 0.6), 1.5), Color(SKY, 0.3))
		pen.poly(OutfitPen.rrect(e, Vector2(3.2, 1.9 * open + 0.2), 1.0), SKY)
	var lx := pen.look.x * 3.0
	for y: float in [7.6, 9.6, 11.6]:
		pen.line(pen.h(lx - 5.0, y), pen.h(lx + 5.0, y), GUNMETAL, 0.9)
