extends SceneTree
## The wardrobe's pose check (docs/wardrobe): every look worn by the real
## Player, in every pose the game puts him in, on contact sheets to look at
## before calling a look done. Run it through tools/wardrobe_sheets.sh, or:
##
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --audio-driver Dummy \
##       --script res://tools/wardrobe_sheets.gd -- --out=/tmp/mapman-wardrobe
##
## Writes 01_collection.png (the looks by tier), 02_poses_1..3.png (every look
## in the 11 poses) and 04_at_playing_size.png (real levels at the baselines'
## 2x) into --out, named like the design sheets in docs/wardrobe/sheets.
## tests/unit/test_outfits.gd puts him in the same poses (POSES, pose()).

## The poses the game puts him in: the pose check's columns.
const POSES: Array[String] = [
	"front", "walk_r", "walk_l", "away", "land", "cheer", "blink", "spin", "stuck", "dying", "dead"
]
const POSE_NAMES := {
	"front": "FRONT",
	"walk_r": "WALK →",
	"walk_l": "WALK ←",
	"away": "AWAY",
	"land": "LAND",
	"cheer": "CHEER",
	"blink": "BLINK",
	"spin": "SPIN",
	"stuck": "COBWEB",
	"dying": "DYING",
	"dead": "DEAD",
}
## The collection's rows: the tiers in each, and its name.
const ROWS := [
	[["start", "common"], "COMMON"],
	[["uncommon"], "UNCOMMON"],
	[["rare"], "RARE"],
	[["epic", "legendary", "special"], "EPIC +"],
]
## Her collection's rows: MapWoman herself heads the first.
const ROWS_HERS := [
	[["special", "common"], "COMMON"],
	[["uncommon"], "UNCOMMON"],
	[["rare"], "RARE"],
	[["epic", "legendary"], "EPIC +"],
]
## The design sheets' title block.
const BLOCK := Vector2(260, 104)
## Levels for the playing-size sheet, and the looks walking about on each.
const PANELS := [
	[1, ["party_hat", "cowboy", "doctor", "pumpkin"]],
	[24, ["signal_red", "hard_hat", "skeleton", "astronaut"]],
	[49, ["blueprint", "top_hat", "explorer", "robot"]],
	[92, ["neon", "superhero", "wizard", "gold"]],
	[15, ["sky_blue", "sunflower", "footballer", "chef"]],
	[66, ["knight", "aviator", "dragon", "platinum"]],
]

var out_dir := "user://wardrobe_sheets"


## Blue drawing paper with its grid.
class Paper:
	extends Node2D
	var size := Vector2(100, 100)
	var step := 50.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Blueprint.FIELD)
		var x := 0.0
		while x <= size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), Blueprint.GRID, 1.0)
			x += step
		var y := 0.0
		while y <= size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), Blueprint.GRID, 1.0)
			y += step


## Sets his dials to one of POSES, the way the game would leave them.
static func pose(p: Player, which: String) -> void:
	p.auto_look = false
	p.look = Vector2(0.15, 0.1)
	match which:
		"walk_r", "walk_l":
			p.flip = 1.0 if which == "walk_r" else -1.0
			p.look = Vector2(0.9, 0.0)
			p.walking = 1.0
			p.side_on = 1.0
			p._phase = 1.25
		"away":
			p.look = Vector2(0.0, -1.0)
			p.walking = 1.0
			p._phase = 0.5
		"land":
			p.squash = 0.4
			p.look = Vector2(0.3, 0.2)
		"cheer":
			p.happy = 1.0
			p._hop = 0.5
			p.look = Vector2(0.0, 0.1)
		"blink":
			p._blink = 1.0
		"spin":
			p.spin = 0.2
		"stuck":
			p.web = 1.0
		"dying":
			p.dead = 0.45
			p.squash = 0.45
			p.look = Vector2.ZERO
		"dead":
			p.dead = 1.0
			p.look = Vector2.ZERO
	p._idle_clock = 0.55
	p.queue_redraw()


## The ids in a collection row (ROWS) of `looks`, in release order.
static func row_ids(tiers: Array, looks: Array) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in looks:
		if entry.tier in tiers:
			out.append(entry.id)
	return out


## The levels a collection row's looks come at: "5–25", "80–100 + THE END".
static func row_levels(tiers: Array, looks: Array) -> String:
	var first := Wardrobe.THE_END
	var last := 0
	var at_the_end := false
	for entry: Dictionary in looks:
		var level: int = entry.level
		if entry.tier not in tiers or level == 0:
			continue
		if level == Wardrobe.THE_END:
			at_the_end = true
			continue
		first = mini(first, level)
		last = maxi(last, level)
	return "%d–%d%s" % [first, last, " + THE END" if at_the_end else ""]


## When a look comes, short: "LV 35", "THE END", "ALWAYS"; "035-B" for hers.
static func when(entry: Dictionary) -> String:
	if entry.level == 0:
		return "ALWAYS"
	if entry.level == Wardrobe.THE_END:
		return "THE END"
	if Wardrobe.is_hers(entry.id):
		return "%03d-B" % entry.level
	return "LV %d" % entry.level


## "LV 35 · UNCOMMON", or "ALWAYS" for Classic.
static func detail(entry: Dictionary, gap := " · ") -> String:
	var tier: String = Wardrobe.TIERS[entry.tier]
	return when(entry) if tier == "" else when(entry) + gap + tier


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	run.call_deferred()


func run() -> void:
	seed(20261004)  # the same blank tiles every run
	TranslationServer.set_locale("en")
	var save = root.get_node_or_null("Save")
	if save != null:
		save.persist = false  # never touch real progress
		save.reduce_motion = false  # decorative motion (sparkles, twinkles) shows
	await collection(
		"01_collection",
		"THE COLLECTION",
		(
			"%d LOOKS TO RELEASE  ·  ONE EVERY 5 LEVELS  ·  MAPWOMAN FOR FINISHING THE GAME"
			% (Wardrobe.LOOKS.size() - 1)
		),
		Wardrobe.LOOKS,
		ROWS,
		"W-01"
	)
	await collection(
		"01_collection_hers",
		"HER COLLECTION",
		"%d LOOKS OF MAPWOMAN'S OWN  ·  ONE EVERY 5 SHEETS OF REVISION B" % Wardrobe.HERS.size(),
		Wardrobe.her_list(),
		ROWS_HERS,
		"W-01B"
	)
	var ids := Wardrobe.ids()
	var his := Wardrobe.LOOKS.size()
	await poses("02_poses_1", ids.slice(0, 8), 1, 6)
	await poses("02_poses_2", ids.slice(8, 15), 2, 6)
	await poses("02_poses_3", ids.slice(15, his), 3, 6)
	await poses("02_poses_4", ids.slice(his, his + 7), 4, 6)
	await poses("02_poses_5", ids.slice(his + 7, his + 14), 5, 6)
	await poses("02_poses_6", ids.slice(his + 14), 6, 6)
	await in_game()
	print("done")
	quit()


# --- sheets ---------------------------------------------------------------------


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


func save_sheet(vp: SubViewport, file_name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out_dir.path_join(file_name + ".png"))
	print("saved ", file_name, " ", img.get_size())
	vp.queue_free()


func text(parent: Node, s: String, size: int, color: Color, pos: Vector2, weight := 500) -> Label:
	var l := Blueprint.label(parent, s, size, color, pos, weight)
	l.size = l.get_minimum_size()
	return l


## The drawing frame, the title and the title block in the bottom-right
## corner (content stops BLOCK.y + 30 above the bottom).
func frame(parent: Node, size: Vector2, title: String, subtitle: String, sheet: String) -> void:
	var ink := Blueprint.INK
	Blueprint.line(parent, Blueprint.box_points(Vector2(20, 20), size - Vector2(40, 40)), ink, 2.0)
	text(parent, "MAPMAN  —  WARDROBE  —  " + title, 34, ink, Vector2(56, 40), 800)
	text(parent, subtitle, 17, Blueprint.FAINT, Vector2(58, 92))
	var at := size - Vector2(20, 20) - BLOCK
	Blueprint.line(parent, Blueprint.box_points(at, BLOCK), ink, 1.5)
	text(parent, "SCALE 2:1\nSHEET " + sheet, 18, ink, at + Vector2(18, 24))


## MapMan in look `id`, standing at `pos` in one of POSES.
func figure(parent: Node, id: String, pos: Vector2, s: float, which := "front") -> Player:
	var p := Player.new()
	p.outfit = id
	p.position = pos
	p.scale = Vector2(s, s)
	parent.add_child(p)
	p.visible = true  # at once: show_player() would fade him in
	p.is_hidden = false
	pose(p, which)
	return p


func ellipse(parent: Node, at: Vector2, rx: float, ry: float, color := Color(1, 1, 1, 0.7)) -> void:
	Blueprint.line(parent, Blueprint.ellipse_points(at, rx, ry), color, 1.4)


## Every look of `looks`, by tier (`rows`), standing on the sheet.
func collection(
	file_name: String, title: String, subtitle: String, looks: Array, rows: Array, sheet: String
) -> void:
	var size := Vector2i(2100, 1580)
	var vp := new_sheet(size)
	frame(vp, Vector2(size), title, subtitle + "  ·  WORN ONE AT A TIME", sheet)
	var hers: bool = looks[0].id == "mapwoman"
	for r in rows.size():
		var tiers: Array = rows[r][0]
		var y0 := 150.0 + r * 320.0
		# Classic and MapWoman head no row.
		var main: String = tiers[1] if tiers[0] in ["start", "special"] else tiers[0]
		text(vp, rows[r][1], 24, Wardrobe.TIER_COLOURS[main], Vector2(56, y0 + 110), 800)
		var levels := row_levels(tiers, looks).replace(" + ", "\nAND ")
		var word := "SHEETS " if hers else "LEVELS "
		text(vp, word + levels, 16, Blueprint.FAINT, Vector2(58, y0 + 146))
		var ids := row_ids(tiers, looks)
		for c in ids.size():
			var entry := Wardrobe.look(ids[c])
			var colour: Color = Wardrobe.TIER_COLOURS[entry.tier]
			var x0 := 248.0 + c * 305.0
			var box := Blueprint.box_points(Vector2(x0, y0), Vector2(290, 305))
			Blueprint.line(vp, box, Color(colour, 0.8), 1.5)
			var feet := Vector2(x0 + 145, y0 + 232)
			ellipse(vp, feet + Vector2(0, 2), 50, 12)
			figure(vp, entry.id, feet, 2.0)
			text(vp, entry.name, 22, Blueprint.INK, Vector2(x0 + 14, y0 + 250), 800)
			var tone: Color = Blueprint.FAINT if entry.tier in ["common", "start"] else colour
			text(vp, detail(entry, "  ·  "), 14, tone, Vector2(x0 + 14, y0 + 278))
	await save_sheet(vp, file_name)


## Each look in every pose the game puts him in.
func poses(file_name: String, ids: Array, page: int, pages: int) -> void:
	var size := Vector2i(2000, 170 + ids.size() * 190 + 150)
	var vp := new_sheet(size)
	frame(
		vp,
		Vector2(size),
		"POSE CHECK  %d / %d" % [page, pages],
		(
			"EVERY PART FOLLOWS EVERY DIAL THE GAME TURNS: WALK, FACING, LOOKING AWAY,"
			+ " SQUASH, HOP, BLINK, SPIN, COBWEB, DEATH"
		),
		"W-%02d" % (page + 1)
	)
	for i in POSES.size():
		var l := text(vp, POSE_NAMES[POSES[i]], 16, Blueprint.FAINT, Vector2(0, 136), 700)
		l.position.x = 300 + i * 150 + 75 - l.size.x / 2.0
	for r in ids.size():
		var y0 := 170.0 + r * 190.0
		var entry := Wardrobe.look(ids[r])
		Blueprint.rule(vp, y0, 50, size.x - 50, Color(1, 1, 1, 0.25))
		text(vp, entry.name, 20, Blueprint.INK, Vector2(56, y0 + 68), 800)
		text(vp, detail(entry), 14, Wardrobe.TIER_COLOURS[entry.tier], Vector2(58, y0 + 98))
		for i in POSES.size():
			figure(vp, entry.id, Vector2(300 + i * 150 + 75, y0 + 172), 1.45, POSES[i])
	await save_sheet(vp, file_name)


## At the size they are played: real levels and tiles at 2x the base screen,
## like the baseline screenshots (the phone draws them sharper still).
func in_game() -> void:
	var data: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/levels.json")
	)
	var size := Vector2i(1334 * 2 + 60, 140 + 770 * 3 + 120)
	var vp := new_sheet(size)
	frame(
		vp,
		Vector2(size),
		"AT PLAYING SIZE",
		(
			"REAL LEVELS AND TILES AT 2× THE BASE SCREEN (AS THE BASELINE SCREENSHOTS)"
			+ "  ·  THE PHONE DRAWS ABOUT 3.8×"
		),
		"W-06"
	)
	var walks: Array[String] = ["walk_r", "front", "walk_l", "cheer"]
	for p in PANELS.size():
		var level: int = PANELS[p][0]
		var ids: Array = PANELS[p][1]
		var holder := Node2D.new()
		@warning_ignore("integer_division")
		holder.position = Vector2(20 + (p % 2) * 1354, 140 + (p / 2) * 770)
		holder.scale = Vector2(2, 2)
		vp.add_child(holder)
		var paper := Paper.new()
		paper.size = Vector2(667, 375)
		paper.step = Blueprint.GRID_STEP
		holder.add_child(paper)
		var map := LevelMap.new()
		holder.add_child(map)
		var level_data: Dictionary = data.levels[level - 1]
		map.load_level(level_data, Vector2(667, 375))
		map._load_elapsed = map._load_time
		Blueprint.rect(holder, Blueprint.STRIP, Vector2(12, 12), Vector2(643, 29))
		Blueprint.rect(holder, Blueprint.STRIP, Vector2(12, 318), Vector2(643, 45))
		Blueprint.line(holder, Blueprint.frame_points(Vector2(667, 375)), Blueprint.INK, 1.5)
		text(holder, "SHEET %03d / 100" % level, 12, Blueprint.INK, Vector2(25, 19), 700)
		var names: Array[String] = []
		for id: String in ids:
			names.append(Wardrobe.look(id).name)
		text(holder, ", ".join(names), 11, Blueprint.FAINT, Vector2(25, 333), 600)
		var spots: Array[Vector2i] = []
		var rows: Array = level_data.rows
		for r in rows.size():
			var row: String = rows[r]
			for c in row.length():
				if row[c] != " ":
					spots.append(Vector2i(c, r))
		for i in ids.size():
			var key := spots[int((i + 0.5) * spots.size() / ids.size())]
			var f := figure(holder, ids[i], Vector2.ZERO, 1.0, walks[i])
			f.position = map.tiles[key].position
	for i in 30:
		await process_frame  # the tiles settle in
	await save_sheet(vp, "04_at_playing_size")
