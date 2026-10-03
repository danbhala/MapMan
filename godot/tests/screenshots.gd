extends SceneTree
## Captures screenshots of key screens (needs a real renderer, e.g. xvfb-run).
##
##   xvfb-run godot --path godot --rendering-driver opengl3 --script res://tests/screenshots.gd -- --out=/tmp/shots

var out_dir := "user://screenshots"
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
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(40)
	await shot("01_main_menu")

	game._on_menu_action("play game")
	await frames(20)
	await shot("02_level1_loading")
	while not game._timer_running:
		await process_frame
	await frames(30)
	await shot("03_level1_playing")

	Input.action_press("move_left")
	await frames(12)
	await shot("04_walking")
	Input.action_release("move_left")

	game.show_pause_menu()
	await frames(30)
	await shot("05_pause")
	game._on_menu_action("unpause")

	# A busier level with effect tiles, and the checkpoint flag.
	game.level = 10
	game.load_level()
	game.reset_all()
	while not game._timer_running:
		await process_frame
	await frames(20)
	await shot("06_level10_checkpoint")

	game.reverse = true
	game.vanish = 3
	game.set_background()
	game.set_controls_message()
	await frames(2)
	await shot("07_effects_bar")
	game.reverse = false
	game.vanish = 0

	game.advance_level(false)
	await frames(80)
	await shot("08_level_clear")
	game._on_menu_action("next level")

	game.level = 3
	game.tutorial = true
	game.load_level()
	game.reset_all()
	game.hud.show_stats(false)
	await frames(60)
	await shot("09_tutorial")

	game.tutorial = false
	game.lives = 1
	game.lose_life()
	await frames(90)
	await shot("10_game_over")
	quit(0)
