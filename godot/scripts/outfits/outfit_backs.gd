class_name OutfitBacks
extends RefCounted
## What a look hangs on his back, and draws in front of everything
## (docs/wardrobe). BACK parts (in Outfits.BACKS) are drawn behind him, and
## over his body when he walks away; they fade as he dies. FRONT parts are
## decoration (sparkles, a twinkle): only with pen.motion, and never dying.

const GOLD := Blueprint.GOLD
## Where the cape is tied on: the body's edge at this rest height.
const SHOULDERS := -51.0


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
		# MapWoman's (docs/wardrobe, "Her wardrobe").
		"mechanic":
			_wrench(pen)
		"rock_star":
			_guitar(pen)
		"aviator":
			_scarf(pen)
		"dragon":
			_wings(pen)
			_tail(pen)


static func _front(pen: OutfitPen, id: String) -> void:
	match id:
		"wizard":
			_sparkles(pen)
		"gold":
			_twinkles(pen)
		# MapWoman's (docs/wardrobe, "Her wardrobe").
		"storm":
			_sparks(pen)
		"beekeeper":
			_bees(pen)
		"disco":
			_glitter(pen)
		"platinum":
			_twinkles(pen)


## A cape from the shoulders, as wide as his back below them; walking, it
## streams out behind and ripples.
static func _cape(pen: OutfitPen, main: Color, edge: Color) -> void:
	var trail := pen.walking * 9.0
	var ripple := pen.walking if pen.motion else 0.0
	var wide := OutfitPen.BODY_HALF + 1.2
	var hem := PackedVector2Array()
	for i in 7:
		var k := i / 6.0
		var x := lerpf(wide, -wide - 1.0, k) - trail * (0.3 + 0.7 * k)
		var y := -13.0 + sin(k * PI * 3.0 + pen.phase * 2.0) * 1.6 * ripple - trail * 0.4 * k
		hem.append(pen.b(x, y))
	var at := pen.edges(SHOULDERS)
	var pts := pen.bp([Vector2(at.x - 0.6, SHOULDERS), Vector2(at.y + 0.6, SHOULDERS)])
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
	# On the head's rim, up and to the right, and on the body's left side.
	var rim := OutfitPen.HEAD_R * 0.97
	var spots: Array[Vector2] = [pen.h(rim * 0.67, -rim * 0.74), pen.b(-11.0, -40.0)]
	for k in 2:
		var glint := maxf(0.0, sin(pen.idle_clock * 2.4 + k * 2.6))
		if glint > 0.05:
			pen.star(spots[k], 4.4 * glint, Color(1, 1, 0.92), 4, 0.25)


# --- MapWoman's --------------------------------------------------------------------


## A spanner slung across her back, its jaws up over one shoulder.
static func _wrench(pen: OutfitPen) -> void:
	var steel := Color("#aab4c0")
	var shade := Color("#5f6b78")
	var low := pen.b(6.0, -40.0)
	var high := pen.b(-14.0, -66.0)
	pen.line(low, high, shade, 4.2)
	pen.line(low, high, steel, 2.8)
	var along := (high - low).normalized()
	var across := Vector2(-along.y, along.x)
	# The open jaw at the top.
	var head := high + along * 1.5
	pen.dot(head, 4.2, steel)
	pen.poly(
		PackedVector2Array(
			[
				head + across * 1.6,
				head + across * 1.6 + along * 5.0,
				head - across * 1.6 + along * 5.0,
				head - across * 1.6
			]
		),
		Blueprint.FIELD
	)
	pen.dot(low - along * 1.0, 2.6, steel)


## An electric guitar on her back: the neck up over one shoulder, the body
## out past her other side.
static func _guitar(pen: OutfitPen) -> void:
	var wood := Color("#b5171f")
	var dark := Color("#2b2b33")
	var body := OutfitPen.ellipse(Vector2(21.0, -30.0), 8.5, 5.8, 16, -0.9)
	pen.poly(pen.bp(body), wood)
	pen.outline(pen.bp(body), dark, 0.8)
	var low := pen.b(16.0, -35.0)
	var high := pen.b(-20.0, -66.0)
	pen.line(low, high, dark, 2.8)
	pen.line(low, high, Color("#8a7a5a"), 1.2)
	pen.poly(pen.bp(OutfitPen.rrect(Vector2(-21.5, -68.0), Vector2(2.0, 3.2), 0.8)), dark)
	for k in 3:
		pen.dot(high + Vector2(1.6, 2.0 * k - 1.0), 0.6, Color("#c0c6d0"))


## A white scarf from her neck, streaming out behind as she walks.
static func _scarf(pen: OutfitPen) -> void:
	var silk := Color("#f4f6f8")
	var trail := pen.walking * 10.0
	var ripple := pen.walking if pen.motion else 0.0
	var spine: Array[Vector2] = []
	for i in 6:
		var k := i / 5.0
		var x := -12.0 - k * (10.0 + trail)
		var y := (
			-50.0 + k * (12.0 - trail * 0.6) + sin(k * PI * 2.0 + pen.phase * 2.0) * 1.8 * ripple
		)
		spine.append(pen.b(x, y))
	var widths: Array[float] = [2.6, 2.6, 2.4, 2.2, 2.0, 1.6]
	var pts := OutfitPen.tapered(spine, widths)
	pen.poly(pts, silk)
	pen.outline(pts, Color("#aab4c0"), 0.6)


## Two wings from the shoulders, beating as she walks and breathing at rest.
static func _wings(pen: OutfitPen) -> void:
	var membrane := Color("#1f5e3a")
	var bone := Color("#164d2e")
	var flap := 0.0
	if pen.motion:
		flap = sin(pen.phase * 2.0) * pen.walking + sin(pen.idle_clock * 1.4) * 0.25
	var at := pen.edges(SHOULDERS)
	for side: float in [-1.0, 1.0]:
		var root := Vector2(at.y if side > 0.0 else at.x, SHOULDERS)
		var tip := Vector2(side * 36.0, -60.0 - flap * 7.0)
		var elbow := Vector2(side * 27.0, -58.0 - flap * 4.0)
		var wing := (
			pen
			. bp(
				[
					root,
					elbow,
					tip,
					Vector2(side * 33.0, -47.0 - flap * 3.0),
					Vector2(side * 28.0, -39.0 - flap * 1.5),
					Vector2(side * 21.0, -34.0),
				]
			)
		)
		pen.poly(wing, membrane)
		pen.polyline(pen.bp([root, elbow, tip]), bone, 1.4)
		pen.line(pen.b(elbow.x, elbow.y), pen.b(side * 28.0, -39.0 - flap * 1.5), bone, 1.0)


## A tail out behind her along the ground, with a spade at its tip.
static func _tail(pen: OutfitPen) -> void:
	var hide := Color("#237a48")
	var wag := sin(pen.phase * 2.0) * 2.0 * pen.walking if pen.motion else 0.0
	var spine: Array[Vector2] = [
		pen.b(-16.0, -28.0),
		pen.b(-25.0, -25.0 + wag * 0.5),
		pen.b(-32.0, -27.0 + wag),
		pen.b(-37.0, -31.0 + wag * 1.5),
	]
	var widths: Array[float] = [3.2, 2.6, 1.8, 0.8]
	pen.poly(OutfitPen.tapered(spine, widths), hide)
	var tip := spine[3]
	pen.poly(
		PackedVector2Array(
			[tip + Vector2(-3.0, -1.0), tip + Vector2(1.5, -3.6), tip + Vector2(1.5, 1.6)]
		),
		Color("#efe6c8")
	)


## Sparks that flicker round a storm cloud.
static func _sparks(pen: OutfitPen) -> void:
	var spots: Array[Vector2] = [pen.b(-19.0, -44.0), pen.b(20.0, -36.0), pen.h(12.0, -14.0)]
	for k in 3:
		var flash := maxf(0.0, sin(pen.idle_clock * 5.0 + k * 2.1) - 0.6) / 0.4
		if flash > 0.05:
			pen.star(spots[k], 3.2 * flash, Color("#ffd60a"), 4, 0.3)


## Three bees circling her head.
static func _bees(pen: OutfitPen) -> void:
	for k in 3:
		var a := pen.idle_clock * 1.6 + k * 2.1
		var at := pen.hc + Vector2(cos(a) * 24.0, -4.0 + sin(a) * 9.0 + sin(a * 5.0) * 1.5)
		pen.dot(at, 1.7, Color("#ffc300"))
		pen.line(at + Vector2(-0.4, -1.5), at + Vector2(-0.4, 1.5), Color("#1b1b1f"), 0.8)
		var beat := 0.6 + 0.4 * absf(sin(pen.idle_clock * 18.0 + k))
		pen.dot(at + Vector2(-0.8, -1.8 * beat), 0.9, Color(1, 1, 1, 0.8))
		pen.dot(at + Vector2(0.8, -1.8 * beat), 0.9, Color(1, 1, 1, 0.8))


## Glitter: sparkles of every colour flashing over a mirror ball and a
## silver suit.
static func _glitter(pen: OutfitPen) -> void:
	var spots: Array[Vector2] = [
		pen.h(-9.0, -8.0),
		pen.h(10.0, 5.0),
		pen.b(-13.0, -42.0),
		pen.b(9.0, -32.0),
		pen.b(16.0, -46.0)
	]
	var tints: Array[Color] = [Blueprint.PINK, Blueprint.MINT, GOLD, Color("#c8b6ff"), Color.WHITE]
	for k in 5:
		var glint := maxf(0.0, sin(pen.idle_clock * 3.2 + k * 1.3))
		if glint > 0.05:
			pen.star(spots[k], 3.4 * glint, tints[k], 4, 0.25)
