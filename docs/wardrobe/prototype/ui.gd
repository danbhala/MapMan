extends SceneTree
## WARDROBE DESIGN PROTOTYPE - mockups of the wardrobe in the menus, built on
## the game's own sheets (Menus) with the proposed pieces added on top.
##
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --audio-driver Dummy \
##       --resolution 1650x750 --script "$PWD/docs/wardrobe/prototype/ui.gd" -- --out=/tmp/w
##
## 1650x750 is the OnePlus 12's shape (3168x1440) at the baselines' 2x scale.

const GOLD := Color("#ffd166")
const FAINT := Color(1, 1, 1, 0.66)
const INK := Color.WHITE
const HOVER := Color(1, 1, 1, 0.1)

var game
var fig_script: Script
var cat: Script
var out_dir := "/tmp/wardrobe"


func _initialize() -> void:
	run.call_deferred()


func frames(n := 1) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, " ", img.get_size())


func run() -> void:
	var dir: String = (get_script() as Script).resource_path.get_base_dir()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	fig_script = load(dir.path_join("outfit_figure.gd"))
	cat = load(dir.path_join("catalogue.gd"))
	seed(20261003)
	var save = root.get_node("Save")
	save.persist = false
	save.highscore = 1240
	save.checkpoints = {10: 120, 20: 260, 30: 410, 40: 560}
	save.first_play = false
	save.reduce_motion = true  # every sheet settles at once
	save.set_locale("en")
	var dev = root.get_node("Dev")
	dev.enabled = false
	dev.persist = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(10)
	await main_menu()
	await wardrobe()
	await level_clear()
	await congratulations()
	quit()


## Put an outfit on the hero of the open sheet (the menus keep driving him).
func wear(id: String) -> Node2D:
	var m = game.menus
	var old: Node2D = m._hero
	var f: Node2D = fig_script.new()
	f.outfit = id
	old.get_parent().add_child(f)
	f.position = old.position
	f.scale = old.scale
	f.auto_look = old.auto_look
	f.flip = old.flip
	f._facing = old._facing
	f._look_target = old._look_target
	f.look = old.look
	f.show_player()
	m._hero = f
	old.queue_free()
	return f


func label(
	parent: Node, text: String, size: int, color: Color, pos: Vector2, weight := 500
) -> Label:
	var l := Blueprint.label(parent, text, size, color, pos, weight)
	l.size = l.get_minimum_size()
	return l


## A small tag, like a stamp but the size of a note.
func tag(parent: Node, text: String, pos: Vector2, color := GOLD) -> void:
	var n := Node2D.new()
	n.position = pos
	n.rotation = Blueprint.STAMP_ROTATION
	parent.add_child(n)
	var l := label(n, text, 11, color, Vector2.ZERO, 800)
	Blueprint.line(
		n, Blueprint.box_points(Vector2(-5, -2), Vector2(l.size.x + 10, l.size.y + 4)), color, 1.2
	)


func small_figure(parent: Node, id: String, feet: Vector2, s: float, pose := "front") -> Node2D:
	var f: Node2D = fig_script.new()
	f.outfit = id
	parent.add_child(f)
	f.position = feet
	f.scale = Vector2(s, s)
	f.visible = true
	f.is_hidden = false
	cat.pose(f, pose)
	return f


## 001: the main menu as it is, MapMan in his cowboy hat, and a way in under him.
func main_menu() -> void:
	game.menus.show_main(1240, true, 100)
	wear("cowboy")
	var panel: Control = game.menus._panel
	var b := Blueprint.item(panel, "WARDROBE   10/22", Vector2(436, 252), Vector2(168, 44))
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag(panel, "NEW", Vector2(588, 242))
	await frames(40)
	await shot("menu_1_main")


## 001-D: every part in the order it is released; the hero wears the chosen one.
func wardrobe() -> void:
	var m = game.menus
	m._open("wardrobe", "001-D", "WARDROBE")
	var panel: Control = m._panel
	var reached := 47
	var worn := "cowboy"
	var fresh := ["top_hat"]
	label(panel, "NOTE: 10 OF 22 RELEASED  ·  TAP ONE TO WEAR IT", 10, FAINT, Vector2(40, 54))
	var items: Array = cat.ITEMS
	for i in items.size():
		var item: Array = items[i]
		var c := i % 6
		var r := i / 6
		var pos := Vector2(40 + c * 64, 72 + r * 57)
		var size := Vector2(60, 52)
		var open: bool = item[2] <= reached
		var colour: Color = cat.TIER_COLOURS[item[3]]
		if item[0] == worn:
			Blueprint.rect(panel, HOVER, pos + Vector2.ONE, size - Vector2(2, 2))
		if open:
			var width := 1.6 if item[0] == worn else 0.9
			Blueprint.line(panel, Blueprint.box_points(pos, size), Color(colour, 0.9), width)
			small_figure(panel, item[0], pos + Vector2(30, 40), 0.36)
		else:
			var dashed := Blueprint.box_points(pos, size)
			Blueprint.line(panel, dashed, Color(1, 1, 1, 0.3), 0.8)
			small_figure(panel, "locked", pos + Vector2(30, 40), 0.36)
		var when: String = "START" if item[2] == 0 else cat.short_when(item[2])
		var cap := label(panel, when, 9, FAINT if not open else INK, Vector2(0, pos.y + 40), 600)
		cap.position.x = pos.x + 30 - cap.size.x / 2.0
		if item[0] in fresh:
			var dot := Polygon2D.new()
			dot.polygon = Blueprint.ellipse_points(pos + Vector2(53, 7), 3, 3, 12)
			dot.color = GOLD
			panel.add_child(dot)
	m._return_item(306)
	# The chosen part, worn by the hero, dimensioned with his hat on.
	var at := Vector2(520, 230)
	Blueprint.line(panel, Blueprint.ellipse_points(at + Vector2(0, 2), 34, 12), INK, 1.2)
	var hero := small_figure(panel, worn, at, 1.2)
	hero.auto_look = false
	hero.look = Vector2(-0.4, 0.15)
	var top := at.y - 89.0 * 1.2
	var feet := at.y - 4.0 * 1.2
	var x := at.x + 50
	Blueprint.line(panel, PackedVector2Array([Vector2(x, top), Vector2(x, feet)]), FAINT)
	for y: float in [top, feet]:
		Blueprint.line(panel, PackedVector2Array([Vector2(x - 5, y), Vector2(x + 5, y)]), FAINT)
	label(panel, "107", 10, FAINT, Vector2(x + 8, (top + feet) / 2.0 - 7.0))
	label(panel, "COWBOY", 16, INK, Vector2(440, 62), 800)
	label(panel, "UNCOMMON  ·  RELEASED AT LEVEL 35", 10, FAINT, Vector2(441, 84))
	Blueprint.stamp(panel, "WORN", Vector2(446, 254), GOLD)
	await frames(40)
	await shot("menu_2_wardrobe")


## Level 35 cleared for the first time: a release slip under the inspection.
func level_clear() -> void:
	var m = game.menus
	m.show_end_level(1430, 10, 6, 2, false, 35, 13, false)
	wear("shades")
	m._hero.face_right_idle()
	var panel: Control = m._panel
	var at := Vector2(40, 288)
	Blueprint.rect(panel, Color(1, 0.82, 0.4, 0.08), at + Vector2.ONE, Vector2(378, 60))
	Blueprint.line(panel, Blueprint.box_points(at, Vector2(380, 62)), GOLD, 1.4)
	small_figure(panel, "cowboy", at + Vector2(36, 56), 0.56, "cheer")
	label(panel, "NEW PART RELEASED", 10, GOLD, at + Vector2(78, 6), 800)
	label(panel, "COWBOY  ·  UNCOMMON", 15, INK, at + Vector2(78, 20), 800)
	label(panel, "WEAR IT FROM THE WARDROBE ON SHEET 001", 10, FAINT, at + Vector2(78, 42))
	await frames(40)
	await shot("menu_3_level_clear")


## The end: MapWoman joins the wardrobe.
func congratulations() -> void:
	var m = game.menus
	m.show_congratulations(5230, true)
	var panel: Control = m._panel
	var at := Vector2(40, 244)
	Blueprint.rect(panel, Color(1, 0.82, 0.4, 0.08), at + Vector2.ONE, Vector2(378, 48))
	Blueprint.line(panel, Blueprint.box_points(at, Vector2(380, 50)), GOLD, 1.4)
	small_figure(panel, "mapwoman", at + Vector2(30, 46), 0.48, "cheer")
	label(panel, "MAPWOMAN JOINS THE WARDROBE", 13, GOLD, at + Vector2(64, 6), 800)
	label(panel, "PLAY AS HER: MAPMAN WAITS FOR YOU AT THE END", 10, FAINT, at + Vector2(64, 28))
	await frames(40)
	await shot("menu_4_the_end")
