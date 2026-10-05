extends SceneTree
## Pictures of the spike tiles for review (not a test): tutorial lesson 9 with the
## spikes down, warning and up, and MapMan waiting for a gap.
##
##   xvfb-run godot --path godot --rendering-driver opengl3 --resolution 1334x750 \
##       --fixed-fps 60 --audio-driver Dummy --script res://tools/spikes_shots.gd \
##       -- --out=/tmp/shots

var out_dir := "user://spikes_shots"
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


## Let the beat run on to this phase of the `^` spikes.
func beat(phase: float) -> void:
	while game.map.spike_phase(game.map.spikes.keys()[0]) < phase:
		await process_frame


func run() -> void:
	seed(20261004)
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
	game.new_game(1, true)
	await frames(40)
	game.level = 9
	game.load_level()
	game.reset_all()
	await frames(60)
	await beat(0.2)
	await shot("s1_lesson9_spikes_down")
	await beat(0.62)
	await shot("s2_warning_poke")
	await beat(0.85)
	await shot("s3_spikes_up")
	await walk("move_left", 1)
	await beat(0.9)
	await shot("s4_waiting_for_the_gap")
	quit(0)
