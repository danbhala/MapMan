extends SceneTree
## Expressions (a prototype): MapMan's face and body acting out a feeling, a
## cell each, on blueprint paper. Every cell loops the same few seconds, so
## the video can be watched as a contact sheet. Record it in Movie Maker mode
## (needs a display, e.g. under xvfb-run -a):
##
##   godot --path godot --rendering-driver opengl3 --audio-driver Dummy \
##       --resolution 1920x1080 --fixed-fps 30 --write-movie /tmp/faces.avi \
##       --script res://tools/expressions_sheet.gd
##
## or a still of each cell at its peak with `-- --still=/tmp/faces.png`, and
## the cells worn in a look with `-- --look=<id>`.

const Sheets := preload("res://tools/wardrobe_sheets.gd")
const SIZE := Vector2(1920, 1080)
const COLS := 4
const PERIOD := 4.0
const LOOPS := 3
## [id, name, note, peak (seconds into the loop, for the still)]
const CELLS := [
	["blink", "BLINK", "as he is now", 1.05],
	["wink", "WINK", "one eye shuts in a smile", 1.6],
	["squint", "SQUINT", "suspicious, eyes sliding", 1.3],
	["happy", "HAPPY", "smiling eyes, a little hop", 2.4],
	["sad", "SAD", "head down, looking at his feet", 2.0],
	["surprised", "SURPRISED", "eyes pop, a jolt", 1.2],
	["sleepy", "SLEEPY", "nodding off, waking with a start", 1.5],
	["determined", "DETERMINED", "lids down, a stamp", 1.25],
	["scared", "SCARED", "wide, darting, trembling", 1.0],
	["dizzy", "DIZZY", "after a spin, eyes rolling", 1.7],
	["curious", "CURIOUS", "head tilted, one eye wider", 1.8],
	["proud", "PROUD", "chin up, eyes half shut", 1.8],
]

## A close-up of the head beside each figure, like a drawing's detail view.
const DETAIL_R := 112.0
const DETAIL_SCALE := 6.4
const BODY_SCALE := 2.5

## Where his head's centre stands above his feet, in his units.
const HEAD_Y := (61.6 + 6.6) * Player.FIGURE_SCALE + 4.0

var figures: Array[Player] = []
var closeups: Array[Player] = []
var centres: Array[Vector2] = []
var homes: Array[Vector2] = []
var clock := 0.0
var still := ""
var look_id := "classic"
var frames := 0


func _initialize() -> void:
	seed(11)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--still="):
			still = arg.trim_prefix("--still=")
		elif arg.begins_with("--look="):
			look_id = arg.trim_prefix("--look=")
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
		save.reduce_motion = false
	var paper := Sheets.Paper.new()
	paper.size = SIZE
	paper.step = 48.0
	root.add_child(paper)
	var ink := Blueprint.INK
	Blueprint.line(root, Blueprint.box_points(Vector2(16, 16), SIZE - Vector2(32, 32)), ink, 2.0)
	var title := "MAPMAN  —  EXPRESSIONS  —  SHEET 1"
	if look_id != "classic":
		title += "  ·  " + Wardrobe.look(look_id).name
	text(root, title, 30, ink, Vector2(44, 32), 800)
	var rows := ceili(CELLS.size() / float(COLS))
	var cell := Vector2((SIZE.x - 80) / COLS, (SIZE.y - 110) / rows)
	for i in CELLS.size():
		var at := Vector2(40 + (i % COLS) * cell.x, 92 + (i / COLS) * cell.y)
		if i % COLS > 0:
			Blueprint.line(
				root,
				PackedVector2Array([at + Vector2(0, 14), at + Vector2(0, cell.y - 14)]),
				Color(1, 1, 1, 0.18),
				1.0
			)
		if i >= COLS:
			Blueprint.rule(root, at.y, at.x + 14, at.x + cell.x - 14, Color(1, 1, 1, 0.18))
		var cx := at.x + cell.x / 2.0
		var feet := Vector2(at.x + 118, at.y + cell.y - 58)
		var shadow := Blueprint.ellipse_points(feet + Vector2(0, 2), 62, 6)
		Blueprint.line(root, shadow, Color(1, 1, 1, 0.3), 1.0)
		var label := text(root, CELLS[i][1], 22, ink, Vector2(0, feet.y + 12), 800)
		label.position.x = cx - label.size.x / 2.0
		var note := text(root, CELLS[i][2], 15, Blueprint.FAINT, Vector2(0, feet.y + 38))
		note.position.x = cx - note.size.x / 2.0
		var num := text(root, "%02d" % (i + 1), 14, Blueprint.FAINT, at + Vector2(14, 10), 800)
		num.position = at + Vector2(14, 10)
		# The detail: a circle on the head, a leader to a close-up of it.
		var head := feet + Vector2(0, -HEAD_Y * BODY_SCALE)
		var centre := Vector2(at.x + cell.x - DETAIL_R - 22, at.y + 18 + DETAIL_R)
		var dir := (centre - head).normalized()
		Blueprint.line(
			root,
			PackedVector2Array([head + dir * 21.0, centre - dir * DETAIL_R]),
			Color(1, 1, 1, 0.45),
			1.0
		)
		var window := Polygon2D.new()
		window.polygon = Blueprint.ellipse_points(centre, DETAIL_R, DETAIL_R, 96)
		window.color = Blueprint.FIELD
		window.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		root.add_child(window)
		var edge := Blueprint.ellipse_points(centre, DETAIL_R, DETAIL_R, 96)
		edge.append(edge[0])
		Blueprint.line(root, edge, ink, 1.5)
		var tag := text(root, "DETAIL " + "ABCDEFGHIJKL"[i], 12, Blueprint.FAINT, Vector2.ZERO, 800)
		tag.position = centre + Vector2(-tag.size.x / 2.0, DETAIL_R + 4)
		var close := Player.new()
		close.outfit = look_id
		close.scale = Vector2(DETAIL_SCALE, DETAIL_SCALE)
		window.add_child(close)
		close.position = centre + Vector2(0, HEAD_Y * DETAIL_SCALE)
		close.show_player()
		close.z_index = 0  # inside the window, which clips it
		close.face_idle()
		close.auto_look = false
		closeups.append(close)
		centres.append(centre)
		var f := Player.new()
		f.outfit = look_id
		f.scale = Vector2(BODY_SCALE, BODY_SCALE)
		root.add_child(f)
		f.position = feet
		f.show_player()
		f.face_idle()
		f.auto_look = false
		figures.append(f)
		homes.append(feet)


func _process(delta: float) -> bool:
	if figures.is_empty():
		return false
	frames += 1
	if not still.is_empty():
		for i in figures.size():
			act(figures[i], CELLS[i][0], CELLS[i][3], 1.0 / 30.0)
			act(closeups[i], CELLS[i][0], CELLS[i][3], 1.0 / 30.0)
			follow(i)
		if frames > 3:
			root.get_texture().get_image().save_png(still)
			print("saved ", still)
			return true
		return false
	clock += delta
	if clock >= PERIOD * LOOPS:
		print("expressions done at %.1f s" % clock)
		return true
	var t := fposmod(clock, PERIOD)
	for i in figures.size():
		act(figures[i], CELLS[i][0], t, delta)
		act(closeups[i], CELLS[i][0], t, delta)
		follow(i)
	return false


## Keeps close-up i on his head, most of the way: a hop or a nod still shows.
func follow(i: int) -> void:
	var p := closeups[i]
	p.position = centres[i] + Vector2(0, HEAD_Y * DETAIL_SCALE)
	p.measure()
	var fx := p.flip * cos(p.spin * TAU)
	var head: Vector2 = (
		Vector2(p.shake_x, -Player.FEET_LIFT) + p._pen.hc * Vector2(fx, 1.0) * Player.FIGURE_SCALE
	)
	var rest := Vector2(0, -HEAD_Y)
	p.position -= (head - rest) * DETAIL_SCALE * 0.8


# --- timing helpers ---------------------------------------------------------------


static func ramp(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)


## 0 before `start`, up to 1 over `rise`, held for `hold`, back to 0 over `fall`.
static func pulse(x: float, start: float, rise: float, hold: float, fall: float) -> float:
	return (
		ramp(start, start + rise, x)
		* (1.0 - ramp(start + rise + hold, start + rise + hold + fall, x))
	)


## A blink starting at `at`: shut and open again over `length` seconds.
static func blink_at(x: float, at: float, length := 0.16) -> float:
	return clampf(1.0 - absf(x - at - length / 2.0) / (length / 2.0), 0.0, 1.0)


## A hop starting at `at`, `length` long, as Player's _hop dial (1 .. 0).
static func hop_at(x: float, at: float, length: float) -> float:
	if x < at or x > at + length:
		return 0.0
	return 1.0 - (x - at) / length


## Tiny, never-still drift, so nobody stands machine-perfect.
static func drift(x: float, offset: float) -> Vector2:
	return Vector2(
		sin(x * 1.7 + offset) * 0.06 + sin(x * 4.3 + offset * 2.0) * 0.025,
		sin(x * 1.3 + offset * 3.0) * 0.04
	)


# --- the expressions --------------------------------------------------------------


## Sets every dial for expression `id` at `t` seconds into its loop.
func act(p: Player, id: String, t: float, delta: float) -> void:
	p.tick(delta)
	p.head_roll = 0.0
	p.head_drop = 0.0
	p.gaze = Vector2.ZERO
	p.lid = Vector2.ZERO
	p.lid_tilt = 0.0
	p.smile = Vector2.ZERO
	p.lower = 0.0
	p.eye_size = Vector2.ONE
	p.squash = 0.0
	p._hop = 0.0
	p._jump = 0.0
	p._blink = 0.0
	p.happy = 0.0
	p.spin = 0.0
	p.shake_x = 0.0
	p.look = Vector2(0.1, 0.1) + drift(t, float(id.hash() % 100))
	match id:
		"blink":
			p.look.x += sin(t * TAU / PERIOD) * 0.35
			p._blink = maxf(blink_at(t, 1.0), maxf(blink_at(t, 2.9), blink_at(t, 3.15)))
		"wink":
			var w := pulse(t, 1.2, 0.14, 0.75, 0.2)
			var lean := pulse(t, 0.9, 0.35, 1.0, 0.45)
			p.look = Vector2(0.3, 0.15) + drift(t, 3.0)
			p.head_roll = 0.13 * lean
			p.smile = Vector2(0.0, w)
			p.lower = 0.2 * w
			p.squash = 0.12 * pulse(t, 1.15, 0.08, 0.0, 0.3)
			p._blink = blink_at(t, 3.4)
		"squint":
			var s := pulse(t, 0.3, 0.45, 2.6, 0.4)
			p.lid = Vector2(0.38, 0.38) * s
			p.lower = 0.55 * s
			var slide := ramp(0.7, 1.0, t) - 2.0 * ramp(1.7, 2.0, t) + ramp(2.7, 3.0, t)
			p.look = Vector2(0.15 + slide * 0.75, 0.1) + drift(t, 5.0) * 0.5
			p.head_roll = -0.07 * s
		"happy":
			var h := pulse(t, 0.4, 0.25, 2.7, 0.3)
			p.smile = Vector2(h, h)
			p.look = Vector2(0.0, 0.05) + drift(t, 7.0)
			p._hop = maxf(hop_at(t, 0.9, 0.42), hop_at(t, 1.45, 0.42))
			p.squash = 0.35 * (pulse(t, 1.32, 0.02, 0.0, 0.25) + pulse(t, 1.87, 0.02, 0.0, 0.3))
			p.head_roll = 0.08 * sin(t * 5.0) * h
		"sad":
			var s := pulse(t, 0.4, 1.0, 1.7, 0.7)
			p.head_drop = 5.5 * s
			p.look = Vector2(0.1 - 0.15 * s, 0.1 + 0.9 * s) + drift(t, 9.0) * 0.4
			p.gaze = Vector2(0.0, 2.6 * s)
			p.lid = Vector2(0.38, 0.38) * s
			p.lid_tilt = 0.95 * s
			p.head_roll = 0.1 * s
			p.squash = 0.14 * s
			p._blink = blink_at(t, 2.3, 0.5)
		"surprised":
			var pop := pulse(t, 0.8, 0.07, 1.4, 0.6)
			p.eye_size = Vector2.ONE * (1.0 + 0.6 * pop)
			p.look = Vector2(0.0, 0.0) + drift(t, 11.0) * 0.3
			p._hop = hop_at(t, 0.8, 0.3)
			p.squash = 0.3 * pulse(t, 1.08, 0.02, 0.0, 0.25)
			p._blink = maxf(blink_at(t, 2.45, 0.14), blink_at(t, 2.68, 0.14))
		"sleepy":
			var down := ramp(0.2, 2.35, t) * (1.0 - ramp(2.4, 2.5, t))
			var snap := pulse(t, 2.4, 0.06, 0.3, 0.5)
			p.lid = Vector2.ONE * (0.25 + 0.72 * down) * (1.0 - snap)
			p.lid.x += 0.05 * down
			p.head_drop = 4.5 * down
			p.head_roll = 0.16 * down
			p.look = Vector2(0.05, 0.1 + 0.6 * down) + drift(t, 13.0) * 0.3
			p.eye_size = Vector2.ONE * (1.0 + 0.3 * snap)
			p._hop = hop_at(t, 2.4, 0.25)
			p.lid = p.lid.lerp(Vector2(0.3, 0.32), ramp(3.0, 3.9, t))
		"determined":
			var d := pulse(t, 0.25, 0.35, 3.0, 0.3)
			p.lid = Vector2(0.32, 0.32) * d
			p.lid_tilt = -1.0 * d
			p.look = Vector2(0.0, 0.15) + drift(t, 15.0) * 0.3
			p.squash = 0.35 * (pulse(t, 1.2, 0.03, 0.0, 0.3) + pulse(t, 2.1, 0.03, 0.0, 0.3))
			p.head_drop = 1.2 * d
		"scared":
			var s := pulse(t, 0.2, 0.15, 3.2, 0.4)
			p.eye_size = Vector2.ONE * (1.0 + 0.3 * s)
			p.lid_tilt = 0.7 * s
			var dart := [-0.85, 0.8, -0.6, 0.9, -0.9, 0.2]
			var k := clampi(int((t - 0.3) / 0.5), 0, dart.size() - 1)
			p.look = Vector2(lerpf(0.1, dart[k], s), 0.05) + drift(t, 17.0) * 0.3
			p.shake_x = sin(t * 70.0) * 0.9 * s
			p.head_drop = 2.0 * s
			p.squash = 0.12 * s
		"dizzy":
			p.spin = ramp(0.0, 0.6, t) if t < 0.6 else 0.0
			var w := pulse(t, 0.55, 0.2, 2.6, 0.6)
			var a := t * 9.0
			p.gaze = Vector2(cos(a), sin(a)) * 1.4 * w
			p.lid = Vector2(0.2, 0.25) * w
			p.head_roll = sin(t * 3.4) * 0.16 * w
			p.shake_x = sin(t * 3.4 - 0.6) * 3.0 * w
			p.look = Vector2(0.0, 0.05)
		"curious":
			var c := pulse(t, 0.4, 0.5, 2.3, 0.5)
			p.head_roll = 0.3 * c
			p.eye_size = Vector2(1.0 + 0.25 * c, 1.0 - 0.1 * c)
			p.lid = Vector2(0.0, 0.18 * c)
			p.look = Vector2(0.1 + 0.4 * c, 0.1 - 0.25 * c) + drift(t, 19.0)
			p._blink = blink_at(t, 2.2)
		"proud":
			var pr := pulse(t, 0.4, 0.55, 2.4, 0.5)
			p.lid = Vector2(0.55, 0.55) * pr
			p.smile = Vector2(0.25, 0.25) * pr
			p.look = Vector2(0.1 - 0.1 * pr, 0.1 - 0.4 * pr) + drift(t, 21.0) * 0.4
			p.gaze = Vector2(0.0, -1.4 * pr)
			p.head_drop = -2.0 * pr
			p.head_roll = -0.06 * pr + sin(t * 2.2) * 0.03 * pr
	p.queue_redraw()
