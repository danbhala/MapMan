extends SceneTree
## Pictures of the assists for review (not a test): the pencil marks on level
## 55 after two lives lost, the route sketch on 58 after four, and the
## lost-life sheet offering the skip.
##
##   xvfb-run godot --path godot --rendering-driver opengl3 --resolution 1334x750 \
##       --fixed-fps 60 --audio-driver Dummy --script res://tools/assist_shots.gd \
##       -- --out=/tmp/shots

var out_dir := "user://assist_shots"
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


func lose(n: int) -> void:
	for i in n:
		game.lose_life()
		game.dead = false
		game.menus.close()
		game.reset_all(false)
	while not game._timer_running:
		await process_frame


func run() -> void:
	seed(20261003)
	var save = root.get_node("Save")
	save.persist = false
	var dev = root.get_node("Dev")
	dev.enabled = false
	dev.persist = false
	save.worn = "classic"
	save.set_locale("en")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(10)
	game.menus.close()
	game.new_game(55)
	while not game._timer_running:
		await process_frame
	# Step onto the hide tile: every death tile folds away.
	Input.action_press("move_left")
	await frames(20)
	Input.action_release("move_left")
	await frames(40)
	await shot("a1_level55_hidden")
	await lose(2)
	Input.action_press("move_left")
	await frames(20)
	Input.action_release("move_left")
	await frames(40)
	await shot("a2_level55_pencil_marks")
	game.lose_life()
	await frames(100)
	await shot("a3_lose_life_marks_note")
	game.dead = false
	game.menus.close()
	game.level = 58
	game.load_level()
	game.losses[58] = 4
	game.reset_all()
	await frames(50)
	await shot("a4_level58_route_sketch")
	game.losses[58] = 6
	game.lose_life()
	await frames(100)
	await shot("a5_lose_life_skip")
	game._on_menu_action("skip sheet")
	await frames(60)
	await shot("a6_after_skip")
	quit(0)
