class_name OutfitFaces
extends RefCounted
## What a look does to his head and face (docs/wardrobe): HEAD-layer parts
## over the head (points through pen.h(), which sink and shrink with it),
## replacement eyes, and FACE-layer parts over the eyes. Nothing in the face
## shows from behind. Replacement eyes still blink, look about and widen when
## he is happy (pen.eye(), pen.eye_open()). While he dies, these layers fade
## out before the body swallows the head (Player sets pen.alpha).

const DARK := Color("#1b1b1f")


static func draw(pen: OutfitPen, layer: Outfits.Layer, id: String) -> void:
	if layer == Outfits.Layer.FACE and pen.from_behind():
		return
	match layer:
		Outfits.Layer.FACE:
			_face(pen, id)


## The head in another shape; false keeps the round one.
static func head_shape(_pen: OutfitPen, _id: String, _colour: Color) -> bool:
	return false


## Eyes of another kind; false keeps the classic ones.
static func eyes(pen: OutfitPen, id: String, colour: Color) -> bool:
	match id:
		"superhero":
			_mask(pen)
			pen.classic_eyes(colour)
			return true
	return false


static func _face(pen: OutfitPen, id: String) -> void:
	match id:
		"shades":
			_shades(pen)


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
