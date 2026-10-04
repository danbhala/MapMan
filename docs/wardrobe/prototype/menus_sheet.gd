extends SceneTree
## WARDROBE DESIGN PROTOTYPE - puts the four menu mockups (ui.gd) on one sheet.
##
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --audio-driver Dummy \
##       --script "$PWD/docs/wardrobe/prototype/menus_sheet.gd" \
##       -- --out=/tmp/wardrobe     (reads the menu_*.png shots from there)

const SHOTS := [
	["menu_1_main", "1  ·  MAIN MENU: A WAY IN UNDER MAPMAN, WEARING HIS PICK"],
	[
		"menu_2_wardrobe",
		"2  ·  SHEET 001-D: EVERY PART IN RELEASE ORDER, LOCKED ONES IN HIDDEN LINES"
	],
	["menu_3_level_clear", "3  ·  FIRST CLEAR OF A 5TH LEVEL: A RELEASE SLIP ON THE INSPECTION"],
	["menu_4_the_end", "4  ·  THE END: MAPWOMAN JOINS THE WARDROBE"],
]
const SCALE := 0.62

var out_dir := "/tmp/wardrobe"


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	var shot_size := Vector2(1650, 750) * SCALE
	var size := Vector2i(int(shot_size.x * 2 + 120), int(shot_size.y * 2 + 300))
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	Blueprint.rect(vp, Blueprint.FIELD, Vector2.ZERO, Vector2(size))
	Blueprint.line(
		vp, Blueprint.box_points(Vector2(20, 20), Vector2(size) - Vector2(40, 40)), Color.WHITE, 2.0
	)
	var title := Blueprint.label(
		vp, "MAPMAN  —  WARDROBE  —  IN THE MENUS", 34, Color.WHITE, Vector2(56, 40), 800
	)
	title.size = title.get_minimum_size()
	var sub := (
		Blueprint
		. label(
			vp,
			"THE GAME'S OWN SHEETS, AT THE ONEPLUS 12'S SHAPE (2.2:1)  ·  TEN LOOKS RELEASED, THE COWBOY WORN",
			17,
			Color(1, 1, 1, 0.66),
			Vector2(58, 92)
		)
	)
	sub.size = sub.get_minimum_size()
	for i in SHOTS.size():
		var img := Image.load_from_file(out_dir.path_join(SHOTS[i][0] + ".png"))
		var tex := ImageTexture.create_from_image(img)
		var at := Vector2(40 + (i % 2) * (shot_size.x + 40), 150 + (i / 2) * (shot_size.y + 70))
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.position = at
		r.size = shot_size
		vp.add_child(r)
		var cap := Blueprint.label(
			vp, SHOTS[i][1], 16, Color("#ffd166"), at + Vector2(0, shot_size.y + 12), 700
		)
		cap.size = cap.get_minimum_size()
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var out := vp.get_texture().get_image()
	out.convert(Image.FORMAT_RGB8)
	out.save_png(out_dir.path_join("06_in_the_menus.png"))
	print("saved 06_in_the_menus ", out.get_size())
	quit()
