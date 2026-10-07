extends SceneTree
## A video tour of MapMan's expressions (a prototype) in the real game: the
## menus (a wink when tapped, dozing off, lying down asleep, woken by a shake
## or a tap), the start of a level, tiles he reacts to, the flag and the
## level clear, a lost life and the clock running out. A caption names each.
##
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1334x750 \
##       --fixed-fps 30 --audio-driver Dummy --write-movie /tmp/faces_tour.avi \
##       --script res://tools/expressions_tour.gd

const FPS := 30
const MAX_SECONDS := 400
const DIRS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
const ACTIONS := {
	Vector2i.RIGHT: "move_right",
	Vector2i.LEFT: "move_left",
	Vector2i.UP: "move_up",
	Vector2i.DOWN: "move_down",
}

var game
var caption: Label
var strip: ColorRect
## Captions drawn in the game; off when they are added below the video
## afterwards from the printed times.
var on_screen := false


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
	push_warning("faces tour: gave up waiting after %d frames" % timeout_frames)
	return false


func watchdog() -> void:
	await frames(MAX_SECONDS * FPS)
	push_error("faces tour: still running after %d s" % MAX_SECONDS)
	quit(1)


## The caption along the bottom of the video, "" to hide it.
func say(text: String) -> void:
	print("faces tour: %s at %.1f s" % [text, Engine.get_process_frames() / float(FPS)])
	if not on_screen:
		return
	caption.text = text
	caption.size = caption.get_minimum_size()
	var size := root.get_visible_rect().size
	caption.position = Vector2((size.x - caption.size.x) / 2.0, size.y - caption.size.y - 8)
	strip.visible = text != ""
	strip.position = Vector2(0, caption.position.y - 5)
	strip.size = Vector2(size.x, caption.size.y + 10)


func run() -> void:
	seed(20261006)
	var save = root.get_node("Save")
	save.persist = false
	save.highscore = 0
	save.first_play = false
	save.worn = "classic"
	save.released.clear()
	save.seen.clear()
	save.has_completed = false
	save.checkpoints.clear()
	save.music_on = false
	save.furthest_level = 40
	var dev = root.get_node("Dev")
	dev.enabled = false
	dev.persist = false

	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	strip = ColorRect.new()
	strip.color = Color(0.03, 0.08, 0.18, 0.82)
	layer.add_child(strip)
	caption = Blueprint.label(layer, "", 13, Blueprint.GOLD, Vector2.ZERO, 800)
	await hold(0.5)

	# --- the menus ---------------------------------------------------------
	say("MAIN MENU  ·  TAP HIM: A JUMP AND A WINK")
	await hold(1.5)
	await poke()
	await hold(2.5)
	say("15 SECONDS WITH NO TOUCH: HE NODS OFF")
	game.menus._idle = 13.5
	await hold(7.0)
	say("30 SECONDS: HE LIES DOWN AND SLEEPS")
	game.menus._idle = 29.5
	await hold(6.0)
	say("SHAKE THE PHONE: AWAKE WITH A START")
	await shake()
	await hold(3.0)
	say("ASLEEP AGAIN, THEN A TAP ON A MENU ITEM WAKES HIM")
	game.menus._idle = 29.5
	await hold(4.0)
	tap_empty()
	game._on_menu_action("options")
	say("...AND HE ARRIVES ON THE NEXT SHEET STILL WAKING UP")
	await hold(3.0)
	game._on_menu_action("main menu")
	await hold(1.0)

	# --- level 1: off he goes, the flag, the level clear --------------------
	say("A LEVEL STARTS: DETERMINED")
	game._on_menu_action("play game")
	await wait_until(func(): return game._timer_running)
	await hold(1.5)
	say("")
	await walk(safe_route(game.map))
	say("AT THE FLAG, NO LIVES LOST: PROUD")
	await wait_until(func(): return game.menus.current == "end_level")
	say("THE LEVEL CLEAR, A CLEAN RUN: HAPPY")
	await hold(6.0)

	# --- tiles he reacts to ----------------------------------------------------
	await play_level(2)
	say("A STAR ON THE WAY")
	await through(game.map.points.keys(), 0)
	say("")
	await walk(safe_route(game.map))
	say("AT THE FLAG, NO LIVES LOST: PROUD")
	await wait_until(func(): return game.menus.current == "end_level")
	say("THE LEVEL CLEAR, CLEAN AND A STAR: PROUD")
	await hold(6.0)

	await play_level(3)
	say("A STICKY TILE: SQUINTING (THE TILE HOLDS HIM, AS ALWAYS, UNTIL A SHAKE)")
	await through(game.map.stickies.keys(), 0)
	await hold(1.5)
	say("SHAKEN FREE, AND STRAIGHT ON")
	await shake()
	await walk(safe_route(game.map).slice(0, 6))
	await settle()

	await play_level(5)
	say("CONTROLS REVERSED: A SPIN AND DIZZY EYES, WALKING RIGHT ON")
	await through(game.map.reverses.keys(), 7)
	await settle()

	await play_level(4)
	say("AN UNHIDE TILE CHANGES THE MAP: CURIOUS, WITHOUT BREAKING STRIDE")
	await through(game.map.unhides.keys(), 8)
	await settle()

	await play_level(62)
	say("+5 S: A WINK...")
	await through(game.map.more_times.keys(), 0)
	say("...THEN A FLIP TILE MID-WINK: THE WINK MELTS INTO DIZZY")
	await through(game.map.reverses.keys(), 0)
	say("ANOTHER +5 S WHILE DIZZY: THE WINK WAITS ITS TURN")
	var far: Array = game.map.more_times.keys().filter(
		func(k): return k.x > game.map.position_key.x
	)
	await through(far, 0)
	await settle()
	await hold(1.0)

	await play_level(35)
	say("-5 S: A GASP, STILL WALKING")
	await through(game.map.less_times.keys(), 0)
	say("THE CLOCK RUNNING OUT: SCARED")
	game._time_left = 3.6
	await walk(find_path(game.map, game.map.position_key, [game.map.start_position]))
	say("OUT OF TIME, A LIFE LOST: HEAD DOWN, LOOKING AT HIS FEET")
	await wait_until(func(): return game.menus.current == "lose_life")
	await hold(4.0)

	# --- a hard level: scared at the start, a death tile, a sad clear ------------
	game._on_menu_action("main menu")
	await hold(0.5)
	say("A HARD LEVEL (LOTS OF DEATH TILES): SCARED")
	await play_level(24)
	await hold(1.8)
	say("A DEATH TILE: A GASP AS HE GOES")
	await walk_to(game.map.deaths.keys())
	await wait_until(func(): return game.menus.current == "lose_life")
	say("LOST A LIFE: HEAD DOWN")
	await hold(3.5)
	game._on_menu_action("try again")
	await wait_until(func(): return game._timer_running)
	say("")
	await hold(0.5)
	await walk(safe_route(game.map))
	say("AT THE FLAG AFTER LOSING A LIFE: HAPPY")
	await wait_until(func(): return game.menus.current == "end_level")
	say("THE LEVEL CLEAR AFTER LOSING A LIFE: SAD")
	await hold(6.0)
	say("")
	await hold(0.5)
	print("faces tour: done")
	quit(0)


## Starts main-game level n from the menus.
func play_level(n: int) -> void:
	game.menus.close()
	game.new_game(n)
	await wait_until(func(): return game._timer_running)
	await hold(1.2)


## Taps MapMan on the sheet.
func poke() -> void:
	var hero: Player = game.menus._hero
	var at := hero.get_global_transform() * Vector2(0, -40)
	game.menus._poke(at)
	await hold(0.1)


## A tap somewhere on the sheet that isn't him.
func tap_empty() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(30, 30)
	Input.parse_input_event(ev)


## A shake of the phone: the shake action, held a moment.
func shake() -> void:
	var ev := InputEventAction.new()
	ev.action = "shake"
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.action_press("shake")
	await hold(0.2)
	Input.action_release("shake")


## Walks to the nearest of `goals` and on towards the exit for `after`
## more steps, never letting go of the controls in between.
func through(goals: Array, after: int) -> void:
	await walk(find_path(game.map, game.map.position_key, goals), false)
	if after > 0:
		await walk(safe_route(game.map).slice(0, after), false)


func walk_to(goals: Array) -> void:
	await walk(find_path(game.map, game.map.position_key, goals))
	await settle()


func walk(path: Array, let_go := true) -> void:
	for target in path:
		if not await step_to(target):
			break
	if let_go:
		release_all()


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


func settle() -> void:
	release_all()
	await wait_until(func(): return not game.map.moving, FPS)


func safe_route(map) -> Array[Vector2i]:
	var exits: Array = map.ends.map(func(t): return t.key)
	return find_path(map, map.position_key, exits)


## Breadth-first over walkable tiles to the nearest goal, never over a death
## tile unless it is the goal.
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
			if prev.has(nxt) or not map.tiles.has(nxt):
				continue
			var tile = map.tiles[nxt]
			if tile.blank or (map.deaths.has(nxt) and nxt not in goals):
				continue
			if map.less_times.has(nxt) and nxt not in goals:
				continue
			prev[nxt] = cur
			queue.append(nxt)
	var path: Array[Vector2i] = []
	if goal == null:
		return path
	var c: Vector2i = goal
	while c != start:
		path.push_front(c)
		c = prev[c]
	return path
