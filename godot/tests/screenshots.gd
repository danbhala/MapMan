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
	# Classic, and an empty wardrobe: level 10's clear releases its look.
	save.worn = "classic"
	save.released.clear()
	save.seen.clear()
	# No best-run ghosts: a level cleared for one screen would walk beside
	# MapMan in the next (and draw on the random numbers).
	save.ghosts.clear()
	save.ghost_on = false
	save.set_locale("en")  # the baselines are English, whatever the machine's

	save.tilt_gauge = true
	save.controls = "tilt"
	save.tilt_sensitivity = 1

	game = load("res://scenes/main.tscn").instantiate()
	# The tilt gauge only shows on phones; draw it here so the shots match them.
	game.show_gauge_anyway = true
	root.add_child(game)
	await frames(70)
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
	await frames(70)
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

	# Stuck in a cobweb, then the tiles hidden.
	game.stuck = true
	game.set_background()
	game.set_controls_message()
	await frames(40)
	await shot("15_stuck")
	game.stuck = false
	game.map.hide_tiles()
	game._flash("_last_hide")
	game.set_background()
	game.set_controls_message()
	await frames(40)
	game._flash("_last_hide")  # the flash is wall-clock timed: keep it on a slow runner
	game.set_controls_message()
	await frames(1)
	await shot("16_tiles_hidden")
	game.map.unhide_tiles()
	game._flash("_last_hide")
	game.set_background()
	game.set_controls_message()
	await frames(40)

	game.advance_level(false)
	await frames(200)  # the inspection table counts up, then PASSED lands
	await shot("08_level_clear")
	game._on_menu_action("next level")

	game.level = 3
	game.tutorial = true
	game.load_level()
	game.reset_all()
	game.hud.show_stats(false)
	game.hud.show_level(true)  # as new_game() does for the tutorial
	await frames(60)
	await shot("09_tutorial")

	# Losing a life with lives to spare, then the last one.
	game.tutorial = false
	game.lives = 2
	game.lose_life()
	await frames(90)
	await shot("17_lose_life")
	game._on_menu_action("try again")
	while not game._timer_running:
		await process_frame
	game.lives = 1
	game.lose_life()
	await frames(90)
	await shot("10_game_over")

	# The ending after the last level: MapWoman waits by the vortex...
	game.menus.close()
	game.new_game(game.levels.size())
	game.end_of_level_points = 0
	game.next_level()
	while not game.started():
		await process_frame
	await frames(30)
	await shot("11_ending")

	# ...and they meet when MapMan reaches her.
	game.map.position_key = Vector2i(3, 8)
	await frames(30)
	await shot("12_ending_meeting")

	game.game_over(false)
	game._on_menu_action("options")
	await frames(70)
	await shot("13_options")

	# Practice: levels reached so far, with bests on some of them.
	save.furthest_level = 23
	save.bests = {21: {"time": 7, "stars": 1}, 22: {"time": 12, "stars": 0}}
	game._on_menu_action("practice")
	await frames(90)
	await shot("14_practice")

	# The remaining sheets: checkpoints, confirm quit, first run.
	save.checkpoints = {10: 120, 30: 400}
	game._on_menu_action("main menu")
	game._on_menu_action("restart from checkpoint")
	await frames(80)
	await shot("18_checkpoints")
	game._on_menu_action("main menu")
	game._on_menu_action("play game")
	while not game._timer_running:
		await process_frame
	game.show_pause_menu()
	game._on_menu_action("confirm quit")
	await frames(70)
	await shot("19_confirm_quit")
	game._on_menu_action("end game")
	save.first_play = true
	game._on_menu_action("play from start")
	await frames(70)
	await shot("20_first_play")

	# Other languages: a mirrored Arabic sheet, Japanese and Russian text, and
	# the HUD's notes in Arabic during play.
	save.set_locale("ar")
	save.new_lessons = true  # the NEW tag on TUTORIAL, mirrored (set by the ending above)
	game._on_menu_action("main menu")
	await frames(70)
	await shot("21_main_menu_ar")
	save.set_locale("ja")
	game._on_menu_action("options")
	await frames(70)
	await shot("22_options_ja")
	save.set_locale("ru")
	game._on_menu_action("main menu")
	game._on_menu_action("play game")
	while not game._timer_running:
		await process_frame
	game.level = 10
	game.load_level()
	game.reset_all()
	while not game._timer_running:
		await process_frame
	game.advance_level(true)
	await frames(200)
	await shot("23_level_clear_ru")
	game._on_menu_action("next level")
	save.set_locale("ar")
	game.load_level()
	game.reset_all()
	while not game._timer_running:
		await process_frame
	game.reverse = true
	game.vanish = 3
	game.set_background()
	game.set_controls_message()
	await frames(2)
	await shot("24_playing_ar")

	# The wardrobe as docs/wardrobe/sheets/menu_2_wardrobe.png has it: the
	# looks up to level 45 released, the last of them not seen yet, the
	# cowboy worn.
	save.set_locale("en")
	var looks: Array = Wardrobe.ids().slice(1, 10)
	save.released.assign(looks)
	save.seen.assign(looks.slice(0, looks.size() - 1))
	save.worn = "cowboy"
	game._on_menu_action("main menu")
	game._on_menu_action("wardrobe")
	await frames(100)  # 22 cells cascade in, then WORN lands
	await shot("25_wardrobe")

	game._on_menu_action("main menu")
	game._on_menu_action("options")
	game._on_menu_action("controls")
	await frames(70)
	await shot("26_controls")

	# Steering with the touch stick: the thumb held left, past the solid ring.
	game._on_menu_action("controls touch")
	game._on_menu_action("main menu")
	game._on_menu_action("play game")
	while not game._timer_running:
		await process_frame
	game.tilt.stick_press(Vector2(150, 230))
	game.tilt.stick_drag(Vector2(110, 236))
	await frames(20)
	await shot("27_touch_stick")
	game.tilt.stick_release()
	save.controls = "tilt"
	game.steering.apply()
	save.set_locale("")

	# Revision B: its row on the main menu once the game has been finished,
	# and sheet 16 again in the Redline look, mirrored with its new tiles.
	save.has_completed = true
	game._on_menu_action("main menu")
	await frames(70)
	await shot("28_main_menu_rev_b")
	game.revision_b.start(16)
	while not game._timer_running:
		await process_frame
	await frames(20)
	await shot("29_rev_b_playing")
	game.show_pause_menu()
	await frames(70)
	await shot("30_rev_b_pause")
	game._on_menu_action("end game")
	save.has_completed = false

	if failures.is_empty():
		print("SCREENSHOTS OK")
		quit(0)
	else:
		print("SCREENSHOT CHANGES:\n- " + "\n- ".join(failures))
		quit(1)
