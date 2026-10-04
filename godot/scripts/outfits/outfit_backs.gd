class_name OutfitBacks
extends RefCounted
## What a look hangs on his back, and draws in front of everything
## (docs/wardrobe). BACK parts (in Outfits.BACKS) are drawn behind him, and
## over his body when he walks away; they fade as he dies. FRONT parts are
## decoration (sparkles, a twinkle): only with pen.motion, and never dying.

const GOLD := Blueprint.GOLD


static func draw(pen: OutfitPen, layer: Outfits.Layer, id: String) -> void:
	match layer:
		Outfits.Layer.BACK:
			_back(pen, id)
		Outfits.Layer.FRONT:
			if pen.motion and pen.dead == 0.0:
				_front(pen, id)


static func _back(pen: OutfitPen, id: String) -> void:
	match id:
		"superhero":
			_cape(pen, Color("#ffb703"), Color("#e09200"))
		"explorer":
			_map_roll(pen)


static func _front(pen: OutfitPen, id: String) -> void:
	match id:
		"wizard":
			_sparkles(pen)
		"gold":
			_twinkles(pen)


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


## A rolled map slung across his back, tied with a red string.
static func _map_roll(pen: OutfitPen) -> void:
	var paper := Color("#efe2c0")
	var edge := Color("#d9c79a")
	var low := pen.b(-5.5, -42.0)
	var high := pen.b(-15.5, -69.0)
	pen.line(low, high, edge, 6.4)
	pen.line(low, high, paper, 4.6)
	pen.dot(high, 3.2, edge)
	var along := (high - low).normalized()
	var across := Vector2(-along.y, along.x)
	var tie := low.lerp(high, 0.7)
	pen.line(tie - across * 3.3, tie + across * 3.3, Color("#c1121f"), 1.8)


## Four-pointed sparkles left behind him as he walks, shrinking as they go.
static func _sparkles(pen: OutfitPen) -> void:
	if pen.walking <= 0.05:
		return
	for k in 3:
		var t := fposmod(pen.phase * 0.32 + k / 3.0, 1.0)
		var at := Vector2(-15.0 - t * 22.0, -30.0 - t * 8.0 + sin(t * 9.0 + k * 2.0) * 5.0)
		pen.star(at, (1.0 - t) * 3.4 * pen.walking, GOLD, 4, 0.3)


## Two glints that come and go, on his head and on his body.
static func _twinkles(pen: OutfitPen) -> void:
	var spots: Array[Vector2] = [pen.h(10.0, -11.0), pen.b(-11.0, -40.0)]
	for k in 2:
		var glint := maxf(0.0, sin(pen.idle_clock * 2.4 + k * 2.6))
		if glint > 0.05:
			pen.star(spots[k], 4.4 * glint, Color(1, 1, 0.92), 4, 0.25)
