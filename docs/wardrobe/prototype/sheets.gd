extends SceneTree
## WARDROBE DESIGN PROTOTYPE - renders the contact sheets.
##
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --audio-driver Dummy \
##       --script "$PWD/docs/wardrobe/prototype/sheets.gd" -- --out=/tmp/wardrobe
##
## First checks that outfit "classic" draws exactly what Player draws.

const INK := Color.WHITE
const FAINT := Color(1, 1, 1, 0.66)
const PINK := Color("#ff9fb5")
const MINT := Color("#8be0c8")
const BLOCK := Vector2(260, 104)

var fig_script: Script
var cat: Script
var out_dir := "/tmp/wardrobe"
var failures := 0


class Paper:
	extends Node2D
	var size := Vector2(100, 100)
	var step := 50.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Blueprint.FIELD)
		var c := Color(1, 1, 1, 0.12)
		var x := 0.0
		while x <= size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), c, 1.0)
			x += step
		var y := 0.0
		while y <= size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), c, 1.0)
			y += step


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var dir: String = (get_script() as Script).resource_path.get_base_dir()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	fig_script = load(dir.path_join("outfit_figure.gd"))
	cat = load(dir.path_join("catalogue.gd"))
	DirAccess.make_dir_recursive_absolute(out_dir)
	await identity_check()
	await collection()
	var ids: Array = []
	for item in cat.ITEMS:
		ids.append(item[0])
	await poses("02_poses_1", ids.slice(0, 8), 1, 3)
	await poses("02_poses_2", ids.slice(8, 15), 2, 3)
	await poses("02_poses_3", ids.slice(15), 3, 3)
	var bench: Array = []
	for item in cat.BENCH:
		bench.append(item[0])
	await poses("03_bench", bench, 0, 0)
	await in_game()
	await catches()
	print("done, failures: ", failures)
	quit(1 if failures > 0 else 0)


# --- sheets ------------------------------------------------------------------


func new_sheet(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var paper := Paper.new()
	paper.size = Vector2(size)
	vp.add_child(paper)
	return vp


func save(vp: SubViewport, name: String) -> Image:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if name != "":
		img.save_png(out_dir.path_join(name + ".png"))
		print("saved ", name, " ", img.get_size())
	vp.queue_free()
	return img


func text(parent: Node, s: String, size: int, color: Color, pos: Vector2, weight := 500) -> Label:
	var l := Blueprint.label(parent, s, size, color, pos, weight)
	l.size = l.get_minimum_size()
	return l


## The drawing frame, the title and the title block in the bottom-right
## corner (the content must stop BLOCK.y + 30 above the bottom).
func frame(parent: Node, size: Vector2, title: String, subtitle: String, sheet: String) -> void:
	Blueprint.line(parent, Blueprint.box_points(Vector2(20, 20), size - Vector2(40, 40)), INK, 2.0)
	text(parent, title, 34, INK, Vector2(56, 40), 800)
	text(parent, subtitle, 17, FAINT, Vector2(58, 92))
	var at := size - Vector2(20, 20) - BLOCK
	Blueprint.line(parent, Blueprint.box_points(at, BLOCK), INK, 1.5)
	text(parent, "REV PROPOSAL\nSCALE 2:1\nSHEET " + sheet, 18, INK, at + Vector2(18, 12))


func figure(parent: Node, id: String, pos: Vector2, s: float, pose := "front") -> Node2D:
	var f: Node2D = fig_script.new()
	f.outfit = id
	f.position = pos
	f.scale = Vector2(s, s)
	parent.add_child(f)
	f.visible = true
	f.is_hidden = false
	cat.pose(f, pose)
	return f


func ellipse(parent: Node, at: Vector2, rx: float, ry: float, color := Color(1, 1, 1, 0.7)) -> void:
	Blueprint.line(parent, Blueprint.ellipse_points(at, rx, ry), color, 1.4)


func detail(item: Array) -> String:
	if item[3] == "START":
		return "ALWAYS  ·  AS HE IS"
	return "%s  ·  %s  ·  %s" % [cat.short_when(item[2]), item[3], item[4]]


## Outfit "classic" must draw what Player draws, pixel for pixel.
func identity_check() -> void:
	var poses: Array = cat.POSES
	var size := Vector2i(poses.size() * 170, 260)
	var images: Array[Image] = []
	for which in 2:
		var vp := new_sheet(size)
		for i in poses.size():
			var f: Node2D = Player.new() if which == 0 else fig_script.new()
			f.position = Vector2(85 + i * 170, 230)
			f.scale = Vector2(2.4, 2.4)
			vp.add_child(f)
			f.visible = true
			f.is_hidden = false
			cat.pose(f, poses[i])
		images.append(await save(vp, ""))
	var differ := 0
	for y in size.y:
		for x in size.x:
			if images[0].get_pixel(x, y) != images[1].get_pixel(x, y):
				differ += 1
	print("identity check: %d of %d pixels differ" % [differ, size.x * size.y])
	if differ > 0:
		failures += 1
		images[0].save_png(out_dir.path_join("identity_player.png"))
		images[1].save_png(out_dir.path_join("identity_outfit.png"))


## Every part of the collection, by tier, standing on the sheet.
func collection() -> void:
	var size := Vector2i(2100, 1580)
	var vp := new_sheet(size)
	frame(
		vp,
		Vector2(size),
		"MAPMAN  —  WARDROBE  —  THE COLLECTION",
		(
			"21 PARTS TO RELEASE  ·  ONE EVERY 5 LEVELS  ·  MAPWOMAN FOR FINISHING THE GAME"
			+ "  ·  WORN ONE AT A TIME"
		),
		"W-01"
	)
	var rows := [
		[
			"COMMON",
			"LEVELS 5–25",
			["classic", "party_hat", "signal_red", "bobble_hat", "racing_green", "shades"]
		],
		["UNCOMMON", "LEVELS 30–50", ["blueprint", "cowboy", "hard_hat", "top_hat", "neon"]],
		["RARE", "LEVELS 55–75", ["doctor", "pirate", "pumpkin", "skeleton", "explorer"]],
		[
			"EPIC +",
			"LEVELS 80–100\nAND THE END",
			["astronaut", "robot", "superhero", "wizard", "gold", "mapwoman"]
		],
	]
	for r in rows.size():
		var y0 := 150.0 + r * 320.0
		var tier: String = rows[r][0]
		var tier_colour: Color = cat.TIER_COLOURS.get(tier.trim_suffix(" +"), cat.TIER_COLOURS.EPIC)
		text(vp, tier, 24, tier_colour, Vector2(56, y0 + 110), 800)
		text(vp, rows[r][1], 16, FAINT, Vector2(58, y0 + 146))
		var ids: Array = rows[r][2]
		for c in ids.size():
			var item: Array = cat.find(ids[c])
			var x0 := 248.0 + c * 305.0
			var colour: Color = cat.TIER_COLOURS[item[3]]
			var box := Blueprint.box_points(Vector2(x0, y0), Vector2(290, 305))
			Blueprint.line(vp, box, Color(colour, 0.8), 1.5)
			var feet := Vector2(x0 + 145, y0 + 232)
			ellipse(vp, feet + Vector2(0, 2), 50, 12)
			figure(vp, item[0], feet, 2.0)
			text(vp, item[1], 22, INK, Vector2(x0 + 14, y0 + 250), 800)
			var tone: Color = FAINT if item[3] in ["COMMON", "START"] else colour
			text(vp, detail(item), 14, tone, Vector2(x0 + 14, y0 + 278))
	await save(vp, "01_collection")


## Each outfit in every pose the game puts him in.
func poses(name: String, ids: Array, page: int, pages: int) -> void:
	var cols: Array = cat.POSES
	var size := Vector2i(2000, 170 + ids.size() * 190 + 150)
	var vp := new_sheet(size)
	var title := "MAPMAN  —  WARDROBE  —  POSE CHECK  %d / %d" % [page, pages]
	var subtitle := (
		"EVERY PART FOLLOWS EVERY DIAL THE GAME TURNS: WALK, FACING, LOOKING AWAY,"
		+ " SQUASH, HOP, BLINK, SPIN, COBWEB, DEATH"
	)
	if page == 0:
		title = "MAPMAN  —  WARDROBE  —  THE BENCH"
		subtitle = "ALTERNATES TO SWAP IN, OR LATER REWARDS FOR FEATS  ·  SAME POSE CHECK"
	frame(vp, Vector2(size), title, subtitle, "W-%02d" % (page + 1 if page > 0 else 5))
	for i in cols.size():
		var l := text(vp, cat.POSE_NAMES[cols[i]], 16, FAINT, Vector2(0, 136), 700)
		l.position.x = 300 + i * 150 + 75 - l.size.x / 2.0
	for r in ids.size():
		var y0 := 170.0 + r * 190.0
		var item: Array = cat.find(ids[r])
		var colour: Color = cat.TIER_COLOURS[item[3]]
		Blueprint.rule(vp, y0, 50, size.x - 50, Color(1, 1, 1, 0.25))
		text(vp, item[1], 20, INK, Vector2(56, y0 + 68), 800)
		var when: String = (
			"ALWAYS" if item[3] == "START" else cat.short_when(item[2]) + " · " + item[3]
		)
		text(vp, when, 14, colour, Vector2(58, y0 + 98))
		for i in cols.size():
			figure(vp, ids[r], Vector2(300 + i * 150 + 75, y0 + 172), 1.45, cols[i])
	await save(vp, name)


## At the size they are played: real levels, real tiles, 2x the base screen
## like the baseline screenshots (the phone draws them sharper still).
func in_game() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	var panels := [
		[1, ["party_hat", "cowboy", "doctor", "pumpkin"]],
		[24, ["signal_red", "hard_hat", "skeleton", "astronaut"]],
		[49, ["blueprint", "top_hat", "explorer", "robot"]],
		[92, ["neon", "superhero", "wizard", "gold"]],
	]
	var size := Vector2i(1334 * 2 + 60, 1800)
	var vp := new_sheet(size)
	frame(
		vp,
		Vector2(size),
		"MAPMAN  —  WARDROBE  —  AT PLAYING SIZE",
		(
			"REAL LEVELS AND TILES AT 2× THE BASE SCREEN (AS THE BASELINE SCREENSHOTS)"
			+ "  ·  THE PHONE DRAWS ABOUT 3.8×"
		),
		"W-06"
	)
	for p in panels.size():
		var level: int = panels[p][0]
		var ids: Array = panels[p][1]
		var holder := Node2D.new()
		holder.position = Vector2(20 + (p % 2) * 1354, 140 + (p / 2) * 770)
		holder.scale = Vector2(2, 2)
		vp.add_child(holder)
		var clip := Paper.new()
		clip.size = Vector2(667, 375)
		clip.step = 25.0
		holder.add_child(clip)
		var map := LevelMap.new()
		holder.add_child(map)
		map.load_level(data.levels[level - 1], Vector2(667, 375))
		map._load_elapsed = map._load_time
		Blueprint.rect(holder, Color(0, 0, 0, 0.35), Vector2(12, 12), Vector2(643, 29))
		Blueprint.rect(holder, Color(0, 0, 0, 0.35), Vector2(12, 318), Vector2(643, 45))
		Blueprint.line(holder, Blueprint.frame_points(Vector2(667, 375)), INK, 1.5)
		text(holder, "SHEET %03d / 100" % level, 12, INK, Vector2(25, 19), 700)
		var names: Array[String] = []
		for id in ids:
			names.append(cat.find(id)[1])
		text(holder, ", ".join(names), 11, FAINT, Vector2(25, 333), 600)
		var rows: Array = data.levels[level - 1].rows
		var spots: Array[Vector2i] = []
		for r in rows.size():
			var row: String = rows[r]
			for c in row.length():
				if row[c] != " ":
					spots.append(Vector2i(c, r))
		var poses := ["walk_r", "front", "walk_l", "cheer"]
		for i in ids.size():
			var key: Vector2i = spots[int((i + 0.5) * spots.size() / ids.size())]
			var f := figure(holder, ids[i], Vector2.ZERO, 1.0, poses[i])
			f.position = map.tiles[key].position
	for i in 30:
		await process_frame
	await save(vp, "04_at_playing_size")


## What the first pose check caught, before and after the three rules.
func catches() -> void:
	var cards := [
		["wizard", "dead", "BEARD HANGS OUT OF THE DEAD BODY", "HEAD EXTRAS FADE AS HE DIES"],
		["pumpkin", "dead", "STEM POKES OUT OF THE DEAD BODY", "HEAD EXTRAS FADE AS HE DIES"],
		[
			"mapwoman",
			"dead",
			"MAPWOMAN'S BOW POKES OUT (SHE NEVER\nDIES TODAY, SO NOBODY HAS SEEN IT)",
			"HEAD EXTRAS FADE AS HE DIES"
		],
		["vampire", "dead", "COLLAR STICKS UP LIKE HORNS", "NECK PIECES FADE AS HE DIES"],
		["viking", "dead", "BRAIDS HANG BELOW THE GROUND", "HEAD EXTRAS FADE AS HE DIES"],
		["bee", "dead", "ANTENNAE STAY UP", "HEAD EXTRAS FADE AS HE DIES"],
		["doctor", "away", "COAT FRONT SEEN FROM BEHIND", "FRONT DETAILS HIDE, LIKE HIS EYES"],
		["cowboy", "away", "BANDANA SEEN FROM BEHIND", "FRONT DETAILS HIDE, LIKE HIS EYES"],
		[
			"superhero",
			"away",
			"WALKING AWAY, THE CAPE IS\nHIDDEN BEHIND HIM",
			"SEEN FROM BEHIND, A CAPE\nCOVERS HIS BACK"
		],
	]
	var size := Vector2i(2000, 170 + 3 * 430 + 150)
	var vp := new_sheet(size)
	frame(
		vp,
		Vector2(size),
		"MAPMAN  —  WARDROBE  —  CAUGHT BY THE POSE CHECK",
		"THE FIRST DRAFT, AND THE SAME FRAME WITH THE THREE RULES  ·  NONE OF THESE SHOW ON A STILL OF HIM STANDING",
		"W-07"
	)
	for k in cards.size():
		var card: Array = cards[k]
		var x0 := 50.0 + (k % 3) * 640.0
		var y0 := 150.0 + (k / 3) * 430.0
		Blueprint.line(
			vp, Blueprint.box_points(Vector2(x0, y0), Vector2(620, 410)), Color(1, 1, 1, 0.4), 1.2
		)
		var item: Array = cat.find(card[0])
		text(
			vp, item[1] + "  ·  " + cat.POSE_NAMES[card[1]], 18, INK, Vector2(x0 + 18, y0 + 14), 800
		)
		for side in 2:
			var cx := x0 + 160.0 + side * 300.0
			var colour := PINK if side == 0 else MINT
			var tag := "FIRST DRAFT" if side == 0 else "WITH THE RULES"
			var label := text(vp, tag, 14, colour, Vector2(0, y0 + 56), 700)
			label.position.x = cx - label.size.x / 2.0
			ellipse(vp, Vector2(cx, y0 + 288), 52, 13, Color(colour, 0.7))
			var f := figure(vp, card[0], Vector2(cx, y0 + 286), 2.0, card[1])
			f.rules = side == 1
		text(vp, "✗  " + card[2], 14, PINK, Vector2(x0 + 18, y0 + 318), 600)
		text(
			vp,
			"✓  " + card[3],
			14,
			MINT,
			Vector2(x0 + 18, y0 + 318 + (44 if "\n" in card[2] else 24)),
			600
		)
	await save(vp, "05_caught_by_the_pose_check")
