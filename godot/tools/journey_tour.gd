extends SceneTree
## Records a journey (research prototype) for Movie Maker mode: sheet A with
## its locked door, out to the right into sheet B (study it, hide it, cross on
## the bridges), up into sheet C for the key, back down through B while it is
## still hidden (one wrong step, to show where a lost life restarts), then
## back to A to open the door.
##
##   godot --path godot --rendering-driver opengl3 --resolution 1334x750 \
##       --fixed-fps 30 --audio-driver Dummy --write-movie /tmp/journey.avi \
##       --script res://tools/journey_tour.gd

const FPS := 30
const MAX_SECONDS := 150
const DIRS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
const ACTIONS := {
	Vector2i.RIGHT: "move_right",
	Vector2i.LEFT: "move_left",
	Vector2i.UP: "move_up",
	Vector2i.DOWN: "move_down",
}
## Set SHOTS to a folder to save a still at each beat as well.
var shots := OS.get_environment("SHOTS")
var game


func _initialize() -> void:
	run.call_deferred()
	watchdog.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func hold(seconds: float) -> void:
	await frames(ceili(seconds * FPS))


func wait_until(cond: Callable, timeout_frames := 20 * FPS) -> bool:
	for i in timeout_frames:
		if cond.call():
			return true
		await process_frame
	push_warning("journey tour: gave up waiting")
	return false


func say(what: String) -> void:
	print("journey: %s at %.1f s" % [what, Engine.get_process_frames() / float(FPS)])


func shot(name: String) -> void:
	say(name)
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, name])


func watchdog() -> void:
	await frames(MAX_SECONDS * FPS)
	push_error("journey tour: still running, stopping")
	quit(1)


func run() -> void:
	seed(20261004)
	var save = root.get_node("Save")
	save.persist = false
	save.highscore = 0
	save.first_play = false
	save.worn = "classic"
	save.released.clear()
	save.seen.clear()
	save.checkpoints.clear()
	var dev = root.get_node("Dev")
	dev.enabled = false
	dev.persist = false

	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await hold(0.5)
	game.start_journey(0)
	await wait_until(func(): return game._timer_running)
	say("sheet A")
	await hold(1.5)
	await shot("01_sheet_a")
	var map = game.map
	if OS.get_environment("OVERVIEW") != "":
		await overview(map)
		return
	var door: Vector2i = map.doors.keys()[0]
	var key: Vector2i = map.keys.keys()[0]

	# Try the door first: locked.
	await walk(find_path(map, map.position_key, [door + Vector2i.RIGHT]))
	await bump(Vector2i.LEFT)
	await shot("02_locked")
	await hold(0.6)

	# Out to the right.
	var b_entry := Vector2i(15, 12)
	await walk(find_path(map, map.position_key, [b_entry]))
	await settle()
	say("sheet B")
	await hold(1.8)  # studying it
	await shot("03_sheet_b_study")
	await walk([b_entry + Vector2i.RIGHT])  # the hide tile
	await settle()
	await hold(1.0)
	await shot("04_sheet_b_hidden")

	# Across B from memory and up into C.
	var c_entry := Vector2i(25, 7)
	await walk(find_path(map, map.position_key, [c_entry]))
	await settle()
	say("sheet C")
	await hold(1.0)
	await shot("05_sheet_c")
	await walk(find_path(map, map.position_key, [key]))
	await settle()
	await hold(0.4)
	await shot("06_key")
	await hold(0.8)

	# Back down into B, still hidden, and one wrong step.
	await walk(find_path(map, map.position_key, [Vector2i(25, 8)]))
	await settle()
	await hold(1.0)
	await shot("07_back_in_b")
	await walk(find_path(map, map.position_key, [Vector2i(23, 14)]))
	await settle()
	await walk([Vector2i(24, 14)])  # a death tile where a bridge should be
	await wait_until(func(): return game.menus.current == "lose_life")
	say("life lost")
	await hold(1.6)
	await shot("08_life_lost")
	game._on_menu_action("try again")
	await wait_until(func(): return game._timer_running)
	await hold(0.8)
	await shot("09_restart_at_entry")

	# Through B again and home to the door.
	await walk(find_path(map, map.position_key, [door]))
	await settle()
	await shot("10_door_open")
	await walk(find_path(map, map.position_key, map.ends.map(func(t): return t.key)))
	await wait_until(func(): return game.journey_done)
	say("journey clear")
	await hold(2.5)
	await shot("11_clear")
	say("done")
	quit(0)


func bump(dir: Vector2i) -> void:
	Input.action_press(ACTIONS[dir])
	await hold(0.9)
	release_all()


func walk(path: Array) -> void:
	for target in path:
		if not await step_to(target):
			break
	release_all()


func step_to(target: Vector2i) -> bool:
	var map = game.map
	var dir: Vector2i = target - map.position_key
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


func release_all() -> void:
	for a in ACTIONS.values():
		Input.action_release(a)


func settle() -> void:
	release_all()
	await wait_until(func(): return not game.map.moving, FPS)


## Breadth-first over walkable tiles, never onto a death tile (unless it is
## the goal), through a locked door only with the key.
func find_path(map, start: Vector2i, goals: Array) -> Array[Vector2i]:
	var prev := {start: start}
	var queue: Array[Vector2i] = [start]
	var goal = null
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur in goals:
			goal = cur
			break
		for d in DIRS:
			var nxt: Vector2i = cur + d
			if prev.has(nxt) or not map.tiles.has(nxt) or map.tiles[nxt].blank:
				continue
			if map.deaths.has(nxt) and nxt not in goals:
				continue
			if map.doors.get(nxt, false) and map.carrying == 0:
				continue
			prev[nxt] = cur
			queue.append(nxt)
	var path: Array[Vector2i] = []
	if goal == null:
		push_warning("journey tour: no path to %s" % [goals])
		return path
	var cur: Vector2i = goal
	while cur != start:
		path.push_front(cur)
		cur = prev[cur]
	return path


## A still of the whole journey at once, every room shown, for explaining it.
func overview(map) -> void:
	game.player.modulate.a = 0.0
	game._key_plan.visible = false
	map.window.clip_contents = false
	map.window.position = Vector2.ZERO
	map.scale = Vector2(0.62, 0.62)
	var r: Rect2 = Rect2()
	var first := true
	for t in map.tiles.values():
		if t.blank:
			continue
		if first:
			r = Rect2(t.position, Vector2.ZERO)
			first = false
		r = r.expand(t.position)
	map.position = Vector2(333, 200) - r.get_center() * 0.62
	await hold(1.0)
	await shot("00_overview")
	quit(0)
