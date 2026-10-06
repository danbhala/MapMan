extends "res://tools/tour.gd"
## Pictures of the portrait prototype (research/portrait):
##
##   env -u DISPLAY xvfb-run -a godot --path godot --rendering-driver opengl3 \
##       --resolution 1080x1920 --fixed-fps 30 --audio-driver Dummy \
##       --script res://tools/portrait_shots.gd -- <out dir> [level] [touch]

var out := "/tmp/pshots"


func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	say("saved " + name)


## Steps are in the map's directions; the keys steer on the screen.
func step_to(target: Vector2i) -> bool:
	var map = game.map
	var dir: Vector2i = target - map.position_key
	if game.reverse:
		dir = -dir
	dir = Portrait.screen_dir(dir)
	if not ACTIONS.has(dir):
		return false
	var act: String = ACTIONS[dir]
	for other in ACTIONS.values():
		if other != act:
			Input.action_release(other)
	Input.action_press(act)
	for i in 4 * FPS:
		await process_frame
		if map.position_key == target and not map.moving:
			return true
		if game.dead or game.menus.visible:
			return false
	return false


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var n := int(args[1]) if args.size() > 1 else 6
	seed(20261004)
	var save = root.get_node("Save")
	save.persist = false
	save.first_play = false
	save.worn = "classic"
	save.released.clear()
	save.seen.clear()
	save.controls = args[2] if args.size() > 2 else "tilt"
	save.tilt_gauge = true
	var dev = root.get_node("Dev")
	dev.enabled = false
	dev.persist = false
	game = load("res://scenes/main.tscn").instantiate()
	game.show_gauge_anyway = true
	root.add_child(game)
	await hold(1.5)
	await snap("01_menu")
	game.menus.close()
	game.new_game(n)
	await wait_until(func(): return game._timer_running)
	await hold(0.5)
	await snap("02_level_start")
	var route := safe_route(game.map)
	await walk(route.slice(0, route.size() / 2))
	await settle()
	await snap("03_mid_level")
	game.show_pause_menu()
	await hold(1.0)
	await snap("04_pause")
	game._on_menu_action("unpause")
	await hold(0.4)
	await walk(route.slice(route.size() / 2))
	await wait_until(func(): return game.menus.current == "end_level")
	await hold(3.0)
	await snap("05_clear")
	quit(0)
