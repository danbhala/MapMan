extends SceneTree
## Pictures of the ice tile for review (not a test): its tutorial lesson as
## it loads, MapMan mid-slide, and where the ice leaves him.
##
##   xvfb-run godot --path godot --rendering-driver opengl3 --resolution 1334x750 \
##       --fixed-fps 60 --audio-driver Dummy --script res://tools/ice_shots.gd \
##       -- --out=/tmp/shots

var out_dir := "user://ice_shots"
var game


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.split("=")[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	run.call_deferred()


func frames(n := 1) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


## Hold a direction until MapMan has moved n tiles, then let go.
func walk(action: String, n: int) -> void:
	var start: int = game._moves
	var waited := 0
	Input.action_press(action)
	while game._moves < start + n and waited < 600:
		await process_frame
		waited += 1
	Input.action_release(action)


func run() -> void:
	seed(20261004)
	var save = root.get_node("Save")
	save.persist = false
	var dev = root.get_node("Dev")
	dev.enabled = false
	dev.persist = false
	save.worn = "classic"
	save.set_locale("en")
	save.has_completed = true
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(10)
	game.menus.close()
	game.new_game(1, true)
	await frames(40)
	game.level = 9  # the ice lesson, on offer once the game has been finished
	game.load_level()
	game.reset_all()
	await frames(60)
	await shot("i1_lesson_loaded")
	Input.action_press("move_left")
	await frames(16)
	Input.action_release("move_left")
	await frames(8)
	await shot("i2_mid_slide")
	await frames(40)
	await shot("i3_where_the_ice_leaves_him")
	quit(0)
