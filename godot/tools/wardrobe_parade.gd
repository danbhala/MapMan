extends SceneTree
## The wardrobe's parade (docs/wardrobe): every look on the real Player, put
## through the moves the game makes, through his own API (face_*, land,
## cheer, spin_around, set_stuck, face_death, reset_pose, update_at), for
## Godot's Movie Maker mode. tools/wardrobe_sheets.sh --video records it and
## makes an mp4; by hand (needs a display, e.g. under xvfb-run -a):
##
##   godot --path godot --rendering-driver opengl3 --audio-driver Dummy \
##       --resolution 1920x1080 --fixed-fps 30 --write-movie /tmp/parade.avi \
##       --script res://tools/wardrobe_parade.gd
##
## Deterministic: a fixed seed and an in-memory save with decorative motion on.

const Sheets := preload("res://tools/wardrobe_sheets.gd")
const SIZE := Vector2(1920, 1080)
const SCALE := 1.55
## Pixels a second while walking.
const PACE := 45.0
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

var figures: Array[Player] = []
var homes: Array[Vector2] = []
var offsets: Array[float] = []
var velocity := 0.0
var clock := 0.0
var next_step := 0
var caption: Label


func _initialize() -> void:
	seed(7)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	build.call_deferred()


func text(parent: Node, s: String, size: int, color: Color, pos: Vector2, weight := 500) -> Label:
	var l := Blueprint.label(parent, s, size, color, pos, weight)
	l.size = l.get_minimum_size()
	return l


func build() -> void:
	TranslationServer.set_locale("en")
	var save = root.get_node_or_null("Save")
	if save != null:
		save.persist = false  # never touch real progress
		save.reduce_motion = false  # the cape ripples, the sparkles show
	var paper := Sheets.Paper.new()
	paper.size = SIZE
	paper.step = 48.0
	root.add_child(paper)
	var ink := Blueprint.INK
	Blueprint.line(root, Blueprint.box_points(Vector2(16, 16), SIZE - Vector2(32, 32)), ink, 2.0)
	text(root, "MAPMAN  —  WARDROBE  —  EVERY LOOK, EVERY MOVE", 30, ink, Vector2(44, 32), 800)
	caption = text(root, "", 26, Blueprint.GOLD, Vector2(1100, 34), 800)
	for r in Sheets.ROWS.size():
		var tiers: Array = Sheets.ROWS[r][0]
		var top := 96.0 + r * 241.0
		var main: String = tiers[1] if tiers[0] == "start" else tiers[0]
		text(root, Sheets.ROWS[r][1], 20, Wardrobe.TIER_COLOURS[main], Vector2(44, top + 92), 800)
		var levels := "LV " + Sheets.row_levels(tiers).replace(" + ", "\n+ ")
		text(root, levels, 14, Blueprint.FAINT, Vector2(46, top + 122))
		Blueprint.rule(root, top, 40, SIZE.x - 40, Color(1, 1, 1, 0.18))
		var ids := Sheets.row_ids(tiers)
		for c in ids.size():
			var cx := 236.0 + c * 278.0 + 139.0
			var feet := Vector2(cx, top + 176)
			var shadow := Blueprint.ellipse_points(feet + Vector2(0, 2), 96, 9)
			Blueprint.line(root, shadow, Color(1, 1, 1, 0.3), 1.0)
			var label := text(root, Wardrobe.look(ids[c]).name, 16, ink, Vector2(0, top + 196), 800)
			label.position.x = cx - label.size.x / 2.0
			var f := Player.new()
			f.outfit = ids[c]
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
			print("parade done at %.1f s" % clock)
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
	match step:
		"idle", "up", "stop_right", "stop_left":
			velocity = 0.0
		"walk_right":
			velocity = PACE
		"walk_left":
			velocity = -PACE
	for f in figures:
		match step:
			"idle":
				f.face_idle()
			"walk_right":
				f.face_right()
			"walk_left":
				f.face_left()
			"stop_right":
				f.face_right_idle()
				f.land()
			"stop_left":
				f.face_left_idle()
				f.land()
			"up":
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
