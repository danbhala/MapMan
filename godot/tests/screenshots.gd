extends SceneTree
## Captures the key screens and, with --baseline, compares them to the
## committed reference images. Needs a real renderer (e.g. xvfb-run) and a
## fixed frame rate so every run draws exactly the same frames:
##
##   xvfb-run godot --path godot --rendering-driver opengl3 --resolution 1334x750 \
##       --fixed-fps 60 --audio-driver Dummy --script res://tests/screenshots.gd \
##       -- --out=/tmp/shots --baseline=res://tests/baseline
##
## --update-baseline writes the new images over the baseline instead.

## A pixel counts as changed when any channel moves by more than this (0-255).
const CHANNEL_TOLERANCE := 24
## A screen fails when more than this fraction of its pixels changed.
const MAX_CHANGED := 0.005

var out_dir := "user://screenshots"
var baseline_dir := ""
var update_baseline := false
var game
var failures: Array[String] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.split("=")[1]
		elif arg.begins_with("--baseline="):
			baseline_dir = arg.split("=")[1]
		elif arg == "--update-baseline":
			update_baseline = true
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
	if baseline_dir == "":
		print("saved ", name)
		return
	var base_path := baseline_dir.path_join(name + ".png")
	if update_baseline:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(baseline_dir))
		img.save_png(ProjectSettings.globalize_path(base_path))
		print("baseline updated: ", name)
		return
	var base := Image.load_from_file(base_path)
	if base == null:
		failures.append("%s: no baseline image" % name)
		return
	base.convert(Image.FORMAT_RGB8)
	if base.get_size() != img.get_size():
		failures.append("%s: size %s, baseline %s" % [name, img.get_size(), base.get_size()])
		return
	var diff := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGB8)
	var changed := 0
	for y in img.get_height():
		for x in img.get_width():
			var a := img.get_pixel(x, y)
			var b := base.get_pixel(x, y)
			var moved := maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
			if moved * 255.0 > CHANNEL_TOLERANCE:
				changed += 1
				diff.set_pixel(x, y, Color.RED)
			else:
				diff.set_pixel(x, y, a.darkened(0.7))
	var share := float(changed) / (img.get_width() * img.get_height())
	if share > MAX_CHANGED:
		diff.save_png(out_dir.path_join(name + "_diff.png"))
		failures.append(
			"%s: %.2f%% of pixels changed (see %s_diff.png)" % [name, share * 100.0, name]
		)
	print("%s: %.3f%% changed" % [name, share * 100.0])


func run() -> void:
	# Same starting state every run: fixed random tiles and a fresh save.
	seed(20261003)
	var save = root.get_node("Save")
	save.persist = false
	var dev = root.get_node("Dev")
	dev.enabled = false  # screenshots show the release build
	dev.persist = false
	save.highscore = 0
	save.checkpoints.clear()
	save.first_play = false

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

	if failures.is_empty():
		print("SCREENSHOTS OK")
		quit(0)
	else:
		print("SCREENSHOT CHANGES:\n- " + "\n- ".join(failures))
		quit(1)
