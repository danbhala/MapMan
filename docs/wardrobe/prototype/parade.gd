extends SceneTree
## WARDROBE DESIGN PROTOTYPE - the animated contact sheet: every outfit put
## through the moves the game makes, through Player's own API (face_*,
## land, cheer, spin_around, set_stuck, face_death, reset_pose, update_at).
##
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --audio-driver Dummy \
##       --resolution 1920x1080 --fixed-fps 30 --write-movie /tmp/parade.avi \
##       --script "$PWD/docs/wardrobe/prototype/parade.gd"

const INK := Color.WHITE
const FAINT := Color(1, 1, 1, 0.66)
const SIZE := Vector2(1920, 1080)
const SCALE := 1.55
const PACE := 45.0  # pixels a second while walking
## [seconds, step, caption]
const STEPS := [
	[0.0, "idle", "STANDING  ·  LOOKING ABOUT"],
	[2.0, "walk_right", "WALKING"],
	[3.6, "stop_right", "LANDING ON A TILE"],
	[4.2, "walk_left", "WALKING THE OTHER WAY  ·  MIRRORED"],
	[7.4, "stop_left", "LANDING ON A TILE"],
	[8.0, "walk_right", "WALKING"],
	[9.6, "up", "WALKING AWAY  ·  NO FACE, NO FRONT DETAILS"],
	[11.4, "down", "WALKING TOWARDS YOU"],
	[12.6, "idle", "STANDING"],
	[12.9, "cheer", "A STAR  ·  HOP"],
	[14.1, "spin", "CONTROLS REVERSED  ·  SPIN"],
	[15.1, "stuck", "STICKY TILE  ·  COBWEB"],
	[16.7, "shake", "SHAKE TO RELEASE"],
	[17.7, "death", "DEATH TILE  ·  THE HAT FLIES OFF"],
	[19.3, "rework", "BACK ON THE START TILE"],
	[20.3, "cheer", "OFF AGAIN"],
	[21.6, "end", ""],
]

var fig_script: Script
var cat: Script
var figures: Array[Node2D] = []
var homes: Array[Vector2] = []
var offsets: Array[float] = []
var velocity := 0.0
var clock := 0.0
var next_step := 0
var caption: Label


class Paper:
	extends Node2D
	var size := Vector2(100, 100)
	var step := 48.0

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
	seed(7)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var dir: String = (get_script() as Script).resource_path.get_base_dir()
	fig_script = load(dir.path_join("outfit_figure.gd"))
	cat = load(dir.path_join("catalogue.gd"))
	build.call_deferred()


func text(parent: Node, s: String, size: int, color: Color, pos: Vector2, weight := 500) -> Label:
	var l := Blueprint.label(parent, s, size, color, pos, weight)
	l.size = l.get_minimum_size()
	return l


func build() -> void:
	var paper := Paper.new()
	paper.size = SIZE
	root.add_child(paper)
	Blueprint.line(root, Blueprint.box_points(Vector2(16, 16), SIZE - Vector2(32, 32)), INK, 2.0)
	text(root, "MAPMAN  —  WARDROBE  —  EVERY PART, EVERY MOVE", 30, INK, Vector2(44, 32), 800)
	caption = text(root, "", 26, Color("#ffd166"), Vector2(1100, 34), 800)
	var rows := [
		[
			"COMMON",
			"LV 5–25",
			["classic", "party_hat", "signal_red", "bobble_hat", "racing_green", "shades"]
		],
		["UNCOMMON", "LV 30–50", ["blueprint", "cowboy", "hard_hat", "top_hat", "neon"]],
		["RARE", "LV 55–75", ["doctor", "pirate", "pumpkin", "skeleton", "explorer"]],
		[
			"EPIC +",
			"LV 80–100\n+ THE END",
			["astronaut", "robot", "superhero", "wizard", "gold", "mapwoman"]
		],
	]
	for r in rows.size():
		var top := 96.0 + r * 241.0
		var tier: String = rows[r][0]
		var colour: Color = cat.TIER_COLOURS.get(tier.trim_suffix(" +"), cat.TIER_COLOURS.EPIC)
		text(root, tier, 20, colour, Vector2(44, top + 92), 800)
		text(root, rows[r][1], 14, FAINT, Vector2(46, top + 122))
		Blueprint.rule(root, top, 40, SIZE.x - 40, Color(1, 1, 1, 0.18))
		var ids: Array = rows[r][2]
		for c in ids.size():
			var item: Array = cat.find(ids[c])
			var cx := 236.0 + c * 278.0 + 139.0
			var feet := Vector2(cx, top + 176)
			Blueprint.line(
				root,
				Blueprint.ellipse_points(feet + Vector2(0, 2), 96, 9),
				Color(1, 1, 1, 0.3),
				1.0
			)
			var name := text(root, item[1], 16, INK, Vector2(0, top + 196), 800)
			name.position.x = cx - name.size.x / 2.0
			var f: Node2D = fig_script.new()
			f.outfit = item[0]
			f.scale = Vector2(SCALE, SCALE)
			root.add_child(f)
			f.position = feet
			f.show_player()
			f.face_idle()
			figures.append(f)
			homes.append(feet)
			offsets.append(0.0)


func _process(delta: float) -> bool:
	if figures.is_empty():
		return false
	clock += delta
	while next_step < STEPS.size() and clock >= STEPS[next_step][0]:
		var step: Array = STEPS[next_step]
		next_step += 1
		if step[1] == "end":
			return true
		act(step[1])
		caption.text = step[2]
		caption.size = caption.get_minimum_size()
		caption.position.x = SIZE.x - 44 - caption.size.x
	for i in figures.size():
		offsets[i] += velocity * delta
		figures[i].update_at(homes[i] + Vector2(offsets[i], 0), delta)
	return false


func act(step: String) -> void:
	for f in figures:
		match step:
			"idle":
				velocity = 0.0
				f.face_idle()
			"walk_right":
				velocity = PACE
				f.face_right()
			"walk_left":
				velocity = -PACE
				f.face_left()
			"stop_right":
				velocity = 0.0
				f.face_right_idle()
				f.land()
			"stop_left":
				velocity = 0.0
				f.face_left_idle()
				f.land()
			"up":
				velocity = 0.0
				f.face_up()
			"down":
				f.face_down()
			"cheer":
				f.face_idle()
				f.cheer()
			"spin":
				f.spin_around()
			"stuck":
				f.set_stuck(true)
			"shake":
				f.set_stuck(false)
			"death":
				f.face_death()
			"rework":
				f.reset_pose()
				f.vanish()
				f.show_player()
				f.face_idle()
