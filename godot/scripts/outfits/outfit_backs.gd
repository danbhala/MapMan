class_name OutfitBacks
extends RefCounted
## What a look hangs on his back, and draws in front of everything
## (docs/wardrobe). BACK parts (in Outfits.BACKS) are drawn behind him, and
## over his body when he walks away; they fade as he dies. FRONT parts are
## decoration (sparkles, a twinkle): only with pen.motion, and never dying.

const GOLD := Color("#ffd166")


static func draw(pen: OutfitPen, layer: Outfits.Layer, id: String) -> void:
	match layer:
		Outfits.Layer.BACK:
			_back(pen, id)


static func _back(pen: OutfitPen, id: String) -> void:
	match id:
		"superhero":
			_cape(pen, Color("#ffb703"), Color("#e09200"))


## A cape from the shoulders; walking, it streams out behind and ripples.
static func _cape(pen: OutfitPen, main: Color, edge: Color) -> void:
	var trail := pen.walking * 9.0
	var ripple := pen.walking if pen.motion else 0.0
	var hem := PackedVector2Array()
	for i in 7:
		var k := i / 6.0
		var x := lerpf(19.0, -21.0, k) - trail * (0.3 + 0.7 * k)
		var y := -13.0 + sin(k * PI * 3.0 + pen.phase * 2.0) * 1.6 * ripple - trail * 0.4 * k
		hem.append(pen.b(x, y))
	var pts := pen.bp([Vector2(-10.5, -51.0), Vector2(10.5, -51.0)])
	pts.append_array(hem)
	pen.poly(pts, main)
	pen.polyline(hem, edge, 1.6)
