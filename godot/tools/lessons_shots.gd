extends SceneTree
## Pictures for review (not a test): the main menu with NEW on TUTORIAL and
## the game-complete sheet's note, as the first finish leaves them.
##
##   xvfb-run godot --path godot --rendering-driver opengl3 --resolution 1334x750 \
##       --fixed-fps 60 --audio-driver Dummy --script res://tools/lessons_shots.gd \
##       -- --out=/tmp/shots

var out_dir := "user://lessons_shots"
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


func run() -> void:
	seed(20261005)
	var save = root.get_node("Save")
	save.persist = false
	var dev = root.get_node("Dev")
	dev.enabled = false
	dev.persist = false
	save.worn = "classic"
	save.set_locale("en")
	save.first_play = false
	save.has_completed = true
	save.new_lessons = true
	save.highscore = 1842
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(10)
	game.show_start_menu()
	await frames(70)
	await shot("l1_main_menu_new_tag")
	game.menus.close()
	game.menus.show_game_complete(1842, 100, 100, true)
	await frames(220)
	await shot("l2_game_complete_note")
	quit(0)
