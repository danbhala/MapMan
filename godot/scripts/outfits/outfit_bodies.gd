class_name OutfitBodies
extends RefCounted
## What a look puts on his legs, body and neck (docs/wardrobe). Body points
## are given at rest through pen.b() / pen.bp() / pen.band() / pen.stripe():
## the bell runs from its hem at y -26 up to -56, 18 either side, and the head
## covers it above about -47. Front-only details check pen.front(). Neck
## pieces fade as he dies (Player sets pen.alpha).

const CREAM := Color("#f4ecd8")


static func draw(pen: OutfitPen, layer: Outfits.Layer, id: String) -> void:
	match layer:
		Outfits.Layer.BODY:
			_body(pen, id)
		Outfits.Layer.NECK:
			_neck(pen, id)


static func _body(pen: OutfitPen, id: String) -> void:
	var s := pen.look.x * 2.0  # front details turn with his face
	match id:
		"racing_green":
			pen.stripe(-4.8 + s, -1.8 + s, CREAM)
			pen.stripe(1.8 + s, 4.8 + s, CREAM)


static func _neck(pen: OutfitPen, id: String) -> void:
	match id:
		"cowboy":
			if pen.front():
				_bandana(pen, Color("#c1121f"))


## A spotted neckerchief, knotted behind, its point under his chin.
static func _bandana(pen: OutfitPen, c: Color) -> void:
	pen.poly(pen.bp([Vector2(-11.5, -50.5), Vector2(11.5, -50.5), Vector2(1.0, -37.0)]), c)
	for d: Vector2 in [
		Vector2(-5, -47.4),
		Vector2(4, -46.2),
		Vector2(0.5, -42),
		Vector2(-8, -49.4),
		Vector2(7, -49.2)
	]:
		pen.dot(pen.b(d.x, d.y), 0.8, Color(1, 1, 1, 0.85))
