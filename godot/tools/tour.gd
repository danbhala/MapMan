extends SceneTree
## Records a video tour of MapMan for Movie Maker mode: the main menu, options
## (music off and on), the practice pages, a walk through level 1 with a pause,
## the level-clear sheet, then losing a life on level 2. Movie Maker draws
## every frame at a fixed rate, so each hold below is a frame count at FPS.
##
##   godot/tools/record_tour.sh [out_dir]      # records, then makes mp4 + gif
##
## or by hand (needs a display, e.g. under xvfb-run -a):
##
##   godot --path godot --rendering-driver opengl3 --resolution 1334x750 \
##       --fixed-fps 30 --audio-driver Dummy --write-movie /tmp/tour.avi \
##       --script res://tools/tour.gd
##
## Deterministic: a fixed seed, a fresh in-memory save (nothing is written to
## disk) and dev tools off, so two recordings of the same build are identical.
## The route through each level is found the way tests/autoplay_test.gd does.

const FPS := 30
## Give up (and still finish the movie) if the tour runs longer than this.
const MAX_SECONDS := 120
const DIRS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
const ACTIONS := {
	Vector2i.RIGHT: "move_right",
	Vector2i.LEFT: "move_left",
	Vector2i.UP: "move_up",
	Vector2i.DOWN: "move_down",
}
## Pretend progress so the practice grid has unlocked levels and bests to show.
const FURTHEST_LEVEL := 8
const BESTS := {1: {"time": 9, "stars": 0}, 2: {"time": 6, "stars": 2}, 3: {"time": 11, "stars": 1}}

var game  # the Main node; untyped because autoloads and game classes aren't identifiers here


func _initialize() -> void:
	run.call_deferred()
	watchdog.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


## Hold the current screen for about this many seconds (a frame count at FPS).
func hold(seconds: float) -> void:
	await frames(ceili(seconds * FPS))


func wait_until(cond: Callable, timeout_frames := 20 * FPS) -> bool:
	for i in timeout_frames:
		if cond.call():
			return true
		await process_frame
	push_warning("tour: gave up waiting after %d frames" % timeout_frames)
	return false


## Progress on stdout with the time in the video, to find each part of it.
func say(what: String) -> void:
	print("tour: %s at %.1f s" % [what, Engine.get_process_frames() / float(FPS)])


func watchdog() -> void:
	await frames(MAX_SECONDS * FPS)
	push_error("tour: still running after %d s, stopping the recording" % MAX_SECONDS)
	quit(1)


func run() -> void:
	seed(20261004)
	var save = root.get_node("Save")
	save.persist = false  # never touch the player's real progress
	save.highscore = 0
	save.first_play = false
	save.worn = "classic"
	save.released.clear()
	save.seen.clear()
	save.has_completed = false
	save.checkpoints.clear()
	save.music_on = true
	save.fx_on = true
	save.furthest_level = FURTHEST_LEVEL
	save.bests = BESTS.duplicate(true)
	var dev = root.get_node("Dev")
	dev.enabled = false  # the release build: no DEV button, no cheats
	dev.persist = false

	game = load("res://scenes/main.tscn").instantiate()
	if not game.has_method("_on_menu_action"):
		# The game's script failed to compile: the parse errors are above.
		push_error("tour: the game did not load, nothing to record")
		quit(1)
		return
	root.add_child(game)
	say("main menu")
	await hold(2.0)

	say("options")
	game._on_menu_action("options")
	await hold(1.0)
	game._on_menu_action("music off")
	await hold(0.8)
	game._on_menu_action("music on")
	await hold(0.8)
	game._on_menu_action("main menu")
	await hold(0.8)

	say("practice")
	game._on_menu_action("practice")
	await hold(1.2)
	game._on_menu_action("practice page 1")
	await hold(1.0)
	game._on_menu_action("practice page 0")
	await hold(0.8)
	game._on_menu_action("main menu")
	await hold(0.8)

	say("level 1")
	game._on_menu_action("play game")
	await wait_until(func(): return game._timer_running)
	await hold(0.5)
	var route := safe_route(game.map)
	var half := route.size() / 2
	await walk(route.slice(0, half))
	await settle()
	say("pause")
	game.show_pause_menu()
	await hold(1.5)
	game._on_menu_action("unpause")
	await hold(0.4)
	await walk(route.slice(half))
	await wait_until(func(): return game.menus.current == "end_level")
	say("level clear")
	await hold(3.0)
	game._on_menu_action("next level")

	say("level 2")
	await wait_until(func(): return game._timer_running)
	await hold(0.5)
	await lose_a_life()
	await wait_until(func(): return game.menus.current == "lose_life")
	say("life lost")
	await hold(2.0)
	game._on_menu_action("try again")
	await hold(1.0)
	say("done")
	quit(0)


## Lose a life on the current level: walk onto a death tile when the level has
## one, otherwise take a short walk (to a points tile if there is one nearby)
## and die where MapMan stands.
func lose_a_life() -> void:
	var map = game.map
	var path := find_path(map, map.position_key, map.deaths.keys())
	if not path.is_empty():
		await walk(path)
		return
	path = find_path(map, map.position_key, map.points.keys())
	if path.is_empty() or path.size() > 20:
		path = safe_route(map).slice(0, 6)
	await walk(path)
	await settle()
	await hold(0.6)
	if not game.dead:
		game.lose_life()


## Press the movement keys to walk MapMan along path, one tile at a time.
## Stops early if the level ends or MapMan dies.
func walk(path: Array) -> void:
	for target in path:
		if not await step_to(target):
			break
	release_all()


## Hold the key towards target until MapMan stands on it. The key stays held
## between steps the same way, so a straight run is one smooth walk.
func step_to(target: Vector2i) -> bool:
	var map = game.map
	var dir: Vector2i = target - map.position_key
	if game.reverse:
		dir = -dir
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


## Let go of the keys and wait for MapMan to finish the step he is on.
func settle() -> void:
	release_all()
	await wait_until(func(): return not game.map.moving, FPS)


## A safe route to an exit, as in tests/autoplay_test.gd: any extra-time tiles
## first when the level has time-loss tiles, never over a death tile.
func safe_route(map) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var pos: Vector2i = map.position_key
	if map.less_times.size() > 0:
		for key in map.more_times.keys():
			var leg := find_path(map, pos, [key])
			if not leg.is_empty():
				path.append_array(leg)
				pos = key
	var exits: Array = map.ends.map(func(t): return t.key)
	path.append_array(find_path(map, pos, exits))
	return path


## Breadth-first search over walkable tiles to the nearest goal, never stepping
## on a death tile (unless it is the goal) and avoiding time-loss tiles where
## another route exists.
func find_path(map, start: Vector2i, goals: Array) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	for avoid_time_loss in [true, false]:
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
				if prev.has(nxt) or not map.tiles.has(nxt):
					continue
				var tile = map.tiles[nxt]
				if tile.blank or (map.deaths.has(nxt) and nxt not in goals):
					continue
				if avoid_time_loss and map.less_times.has(nxt):
					continue
				prev[nxt] = cur
				queue.append(nxt)
		if goal != null:
			var cur: Vector2i = goal
			while cur != start:
				best.push_front(cur)
				cur = prev[cur]
			return best
	return best
