extends SceneTree
## Headless smoke test: plays the tutorial and every level by pressing the
## arrow-key actions along a shortest safe path, then checks the lose-life,
## game-over and pause flows.
##
##   godot --headless --path godot --script res://tests/autoplay_test.gd
##
## Options after "--":
##   --levels=10        stop after that many levels
##   --start=35         skip the tutorial and start at level 35
##   --only-levels      skip the lose-life, game-over and pause checks
##   --time-scale=1     play at real speed (default 3x), e.g. when recording
##                      with --write-movie for the playtester agent

const DIRS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
const ACTIONS := {
	Vector2i.RIGHT: "move_right",
	Vector2i.LEFT: "move_left",
	Vector2i.UP: "move_up",
	Vector2i.DOWN: "move_down",
}

var game
var failures: Array[String] = []
var max_levels := 100
var start_level := 0  # 0 = play the tutorial, then from level 1
var only_levels := false  # skip the lose-life / game-over / pause checks


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--levels="):
			max_levels = int(arg.split("=")[1])
		elif arg.begins_with("--start="):
			start_level = int(arg.split("=")[1])
		elif arg == "--only-levels":
			only_levels = true
		elif arg.begins_with("--time-scale="):
			Engine.time_scale = float(arg.split("=")[1])
	if Engine.time_scale == 1.0:
		Engine.time_scale = 3.0
	run.call_deferred()


func check(cond: bool, what: String) -> void:
	if not cond:
		failures.append(what)
		push_error("FAIL: " + what)


func frames(n := 1) -> void:
	for i in n:
		await process_frame


func wait_until(cond: Callable, timeout_frames := 3000) -> bool:
	for i in timeout_frames:
		if cond.call():
			return true
		await process_frame
	return false


func run() -> void:
	var save = root.get_node("Save")
	save.persist = false  # never touch the player's real progress
	var dev = root.get_node("Dev")
	dev.enabled = false  # play like a release build: no cheats, no dev overlay
	dev.persist = false
	save.checkpoints.clear()
	save.first_play = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	check(game.menus.current == "main", "main menu shows at startup")

	if start_level > 0:
		game.menus.close()
		game.new_game(start_level)
	else:
		# --- tutorial straight into the game ---
		game._on_menu_action("tutorial")
		check(game.tutorial and game.game_active, "tutorial starts")
		for i in game.tutorial_levels.size():
			var ok := await play_current_level()
			check(ok, "tutorial level %d completed" % (i + 1))
			if not ok:
				return finish()
		check(not game.tutorial and game.level == 1, "tutorial runs into level 1")

	# --- main levels ---
	var played := 0
	while played < max_levels:
		var lvl: int = game.level
		var score_before: int = game.score
		var ok := await play_current_level()
		check(ok, "level %d completed" % lvl)
		if not ok:
			return finish()
		if not await wait_until(func(): return game.menus.current in ["end_level", "completion"]):
			check(false, "score screen after level %d" % lvl)
			return finish()
		if game.menus.current == "completion":
			game._on_menu_action("completion done")
			check(game.menus.current == "congratulations", "congratulations after last level")
			break
		game._on_menu_action("next level")
		check(game.score > score_before, "score went up after level %d" % lvl)
		check(game.level == lvl + 1, "advanced past level %d" % lvl)
		played += 1
		if lvl % 10 == 0:
			print("  ...level %d done, score %d, lives %d" % [lvl, game.score, game.lives])

	if game.completed:
		# Past the last level: walk the ending map to MapWoman, who then leads
		# MapMan into the vortex and on to the completion scoring.
		var ok := await play_current_level()
		check(ok, "walked through the ending")
		check(
			await wait_until(func(): return game.menus.current == "completion"),
			"completion scoring after the ending"
		)
	if game.menus.current == "completion":
		game._on_menu_action("completion done")
		check(game.menus.current == "congratulations", "congratulations after last level")
		check(root.get_node("Save").has_completed, "completion saved")
		print("finished the game through the ending")
	print(
		(
			"played %d levels, score %d, checkpoints %s"
			% [played, game.score, str(root.get_node("Save").checkpoints.keys())]
		)
	)
	if game.game_active:
		game.game_over(false)

	if not only_levels:
		await test_lose_life_and_game_over()
		await test_pause()
	finish()


func test_lose_life_and_game_over() -> void:
	game._on_menu_action("play game")
	await wait_until(func(): return game._timer_running)
	# Let the clock run out three times.
	for life in range(3, 0, -1):
		await wait_until(func(): return game.dead, 6000)
		check(game.dead, "time running out kills MapMan (life %d)" % life)
		await wait_until(func(): return game.menus.visible, 600)
		if life > 1:
			check(game.menus.current == "lose_life", "lose-life menu shows")
			check(game.lives == life - 1, "a life is lost")
			game._on_menu_action("try again")
			await wait_until(func(): return game._timer_running)
		else:
			check(game.menus.current == "game_over", "game over after last life")
			check(not game.game_active, "game inactive after game over")
	game._on_menu_action("main menu")
	check(game.menus.current == "main", "back to main menu")


func test_pause() -> void:
	game._on_menu_action("play game")
	await wait_until(func(): return game._timer_running)
	await wait_until(func(): return game._seconds_remaining() <= 19)
	game.show_pause_menu()
	check(game.menus.current == "pause", "pause menu")
	var t: float = game._time_left
	await frames(60)
	check(is_equal_approx(t, game._time_left), "clock stops while paused")
	game._on_menu_action("unpause")
	await frames(30)
	check(game._time_left < t, "clock resumes after unpause")
	game.show_pause_menu()
	game._on_menu_action("confirm quit")
	game._on_menu_action("end game")
	check(game.menus.current == "main" and not game.game_active, "quit to main menu")


## Walk the current level to an exit. Returns false if it could not.
func play_current_level() -> bool:
	if not await wait_until(func(): return game.started() and not game.map.moving):
		push_error("level never started")
		return false
	var map: LevelMap = game.map
	# Collect any extra-time tiles first: some levels need them to survive
	# the time-loss tiles on the way to the exit.
	var path: Array[Vector2i] = []
	var pos := map.position_key
	if map.less_times.size() > 0:
		for key in map.more_times.keys():
			var leg := find_path(map, pos, [key])
			if not leg.is_empty():
				path.append_array(leg)
				pos = key
	var exits: Array = map.ends.map(func(t): return t.key)
	path.append_array(find_path(map, pos, exits))
	if path.is_empty():
		push_error("no path on level %d (tutorial=%s)" % [game.level, game.tutorial])
		return false
	var start_level: int = game.level
	var start_tutorial: bool = game.tutorial
	for target in path:
		var ok := await step_to(target)
		if not ok:
			push_error(
				(
					"stuck walking to %s on level %d (at %s, reverse=%s, stuck=%s, dead=%s)"
					% [target, game.level, map.position_key, game.reverse, game.stuck, game.dead]
				)
			)
			return false
		if game.dead:
			push_error("died on level %d at %s" % [game.level, map.position_key])
			return false
	for a in ACTIONS.values():
		Input.action_release(a)
	# Reaching the exit either opens the score menu or (tutorial) loads the next level.
	return await wait_until(
		func():
			return (
				game.menus.visible or game.level != start_level or game.tutorial != start_tutorial
			),
		600
	)


func step_to(target: Vector2i) -> bool:
	var map: LevelMap = game.map
	var from := map.position_key
	var actual := (target - from).sign()  # one step; a slide on ice carries further
	var dir := actual
	if game.reverse:
		dir = -dir
	var act: String = ACTIONS[dir]
	var lvl: int = game.level
	var tut: bool = game.tutorial
	for attempt in 600:
		# The solver is not clever about time puzzles, so the playthrough
		# keeps the clock topped up; the clock itself is tested separately.
		game._time_left = maxf(game._time_left, 10.0)
		if game.level != lvl or game.tutorial != tut or game.menus.visible:
			Input.action_release(act)
			return true
		if game.stuck:
			for a in ACTIONS.values():
				Input.action_release(a)
			Input.action_press("shake")
			await frames(2)
			Input.action_release("shake")
			await frames(2)
			continue
		for other in ACTIONS.values():
			if other != act:
				Input.action_release(other)
		Input.action_press(act)
		await process_frame
		if map.position_key == target and not map.moving:
			# Keep the key held: a following step the same way continues smoothly.
			return true
		if map.moving and map._move_to - map._move_from != actual:
			Input.action_release(act)
			return false
	Input.action_release(act)
	return false


## Breadth-first search over walkable tiles, never stepping on a death tile
## and avoiding time-loss tiles where another route exists.
func find_path(map: LevelMap, start: Vector2i, goals: Array) -> Array[Vector2i]:
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
				# A move is one step, or a slide across ice to where it stops.
				var visited: Array[Vector2i] = map.slide_path(cur, d)
				if (
					visited.is_empty()
					or visited.any(func(k: Vector2i) -> bool: return map.deaths.has(k))
				):
					continue
				var nxt: Vector2i = visited.back()
				if prev.has(nxt):
					continue
				if (
					avoid_time_loss
					and visited.any(func(k: Vector2i) -> bool: return map.less_times.has(k))
				):
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


func finish() -> void:
	Engine.time_scale = 1.0
	if failures.is_empty():
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		print("%d FAILURES:\n- %s" % [failures.size(), "\n- ".join(failures)])
		quit(1)
