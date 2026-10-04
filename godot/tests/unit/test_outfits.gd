extends GutTest
## The looks MapMan wears (docs/wardrobe, "Rules for future sessions"): every
## look draws in every pose the game puts him in, stays inside the size
## budget, reads on the blue paper and on a white tile, and loses its hat as
## he dies. The poses are the pose check's (tools/wardrobe_sheets.gd), whose
## sheets show what these numbers can't: look at them too.

const Sheets := preload("res://tools/wardrobe_sheets.gd")
## The paper, and a tile on it (white at 80% over the paper).
const PAPER := Blueprint.FIELD
const TILE := Color("#d0d9e4")
## How far a look may reach from the tile's centre: up, and to either side.
const MAX_UP := 110.0
const MAX_SIDE := 42.0


func before_all() -> void:
	Save.persist = false
	Dev.persist = false
	Dev.enabled = false


func before_each() -> void:
	Save.reduce_motion = false


func after_each() -> void:
	Save.reduce_motion = false


## MapMan in look `id`, in one of the pose check's poses.
func _wearing(id: String, which := "front") -> Player:
	var p := Player.new()
	p.outfit = id
	add_child_autofree(p)
	p.visible = true
	p.is_hidden = false
	Sheets.pose(p, which)
	return p


## The looks that put something in the HAT layer.
func _hat_looks() -> Array[String]:
	var out: Array[String] = []
	for id in Wardrobe.ids():
		var pen := OutfitPen.new()
		pen.begin(null, true)
		Outfits.draw(pen, Outfits.Layer.HAT, id)
		if pen.bounds.has_area():
			out.append(id)
	return out


## WCAG relative luminance.
func _luminance(c: Color) -> float:
	var lin: Array[float] = []
	for v: float in [c.r, c.g, c.b]:
		lin.append(v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


## WCAG contrast ratio, 1 (none) to 21.
func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func test_every_look_draws_in_every_pose() -> void:
	var drawn := {}
	var players: Array[Player] = []
	var names: Array[String] = []
	for id in Wardrobe.ids():
		for which in Sheets.POSES:
			var p := _wearing(id, which)
			p.draw.connect(func() -> void: drawn[p] = true)
			p.queue_redraw()
			players.append(p)
			names.append("%s %s" % [id, which])
	# _draw() runs in headless runs too; a script error in it fails the test.
	await wait_process_frames(2)
	for i in players.size():
		assert_true(drawn.has(players[i]), names[i] + ": drawn")
		assert_true(players[i].measure().has_area(), names[i] + ": measured")


func test_every_look_stays_inside_the_size_budget() -> void:
	for id in Wardrobe.ids():
		for which in Sheets.POSES:
			var p := _wearing(id, which)
			p._hop = 0.0  # a hop lifts all of him alike
			var box := p.measure()
			var what := "%s %s" % [id, which]
			assert_lte(maxf(-box.position.x, box.end.x), MAX_SIDE, what + ": to the side")
			# Dying, the hat flies off upwards: out of the budget, on its way out.
			if which != "dying":
				assert_gte(box.position.y, -MAX_UP, what + ": upwards")


func test_classic_is_as_tall_as_ever_and_a_hat_makes_him_taller() -> void:
	assert_eq(Player.standing_height("classic"), 77.0, "the menus' old HERO_HEIGHT")
	var hats := _hat_looks()
	assert_has(hats, "party_hat")
	for id in hats:
		assert_gt(Player.standing_height(id), 77.0, id)


func test_every_look_reads_on_the_paper_and_on_a_tile() -> void:
	for id in Wardrobe.ids():
		var pal := Outfits.palette(id)
		var body: Color = pal.get("body", Player.BODY_COLOR)
		var legs: Color = pal.get("legs", body)
		# An outline or a glow can carry either, if it reads itself.
		var body_edge: Color = pal.get("outline", pal.get("glow", body))
		var leg_edge: Color = pal.get("leg_outline", pal.get("glow", legs))
		var on_paper := maxf(_contrast(body, PAPER), _contrast(body_edge, PAPER))
		var on_tile := maxf(_contrast(legs, TILE), _contrast(leg_edge, TILE))
		assert_gte(on_paper, 1.8, id + ": the body on the paper")
		assert_gte(on_tile, 2.5, id + ": the legs on a tile")


func test_the_wardrobe_palettes_are_its_own() -> void:
	for id: String in Outfits.PALETTES:
		assert_true(Wardrobe.is_look(id), id + " is in the wardrobe")
	for id: String in Outfits.BACKS:
		assert_true(Wardrobe.is_look(id), id + " is in the wardrobe")


func test_a_hat_flies_off_as_he_dies() -> void:
	var classic := _wearing("classic")
	classic.dead = 0.98
	var swallowed := classic.measure()
	for id in _hat_looks():
		var p := _wearing(id)
		var standing := p.measure()
		# Early in the death the hat is lifting off: higher than on his head.
		p.dead = 0.3
		var flying := p.measure()
		assert_lt(flying.position.y, standing.position.y, id + ": lifts off his head first")
		p.dead = 0.98
		var dying := p.measure()
		assert_gt(dying.position.y, standing.position.y, id + ": lower once he is swallowed")
		# Nothing of the hat is left above him: no higher than Classic, give or
		# take an outline round the body (a back part is measured as it fades).
		if not Outfits.has_back(id):
			assert_gte(dying.position.y, swallowed.position.y - 1.0, id + ": the hat has gone")


func test_sparkles_need_decorative_motion() -> void:
	var p := _wearing("wizard", "walk_r")
	var sparkling := p.measure()
	Save.reduce_motion = true
	var still := p.measure()
	assert_lt(sparkling.position.x, still.position.x - 5.0, "sparkles trail behind him")
