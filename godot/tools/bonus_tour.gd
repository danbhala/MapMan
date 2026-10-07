extends SceneTree
## Records the bonus roll (research prototype) for Movie Maker mode: a bot
## that follows the stars along whichever lane it is on, shakes off the
## cobweb and reaches the finish. With RUN=caught it dawdles in the cobweb
## instead and gets rolled up.
##
##   godot --path godot --rendering-driver opengl3 --resolution 1334x750 \
##       --fixed-fps 30 --audio-driver Dummy --write-movie /tmp/bonus.avi \
##       --script res://tools/bonus_tour.gd

const FPS := 30
const MAX_SECONDS := 150
const DIRS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
const ACTIONS := {
	Vector2i.RIGHT: "move_right",
	Vector2i.LEFT: "move_left",
	Vector2i.UP: "move_up",
	Vector2i.DOWN: "move_down",
}
var shots := OS.get_environment("SHOTS")
var caught := OS.get_environment("RUN") == "caught"
var game


func _initialize() -> void:
	run.call_deferred()
	watchdog.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await process_frame


func hold(seconds: float) -> void:
	await frames(ceili(seconds * FPS))


func say(what: String) -> void:
	print("bonus: %s at %.1f s" % [what, Engine.get_process_frames() / float(FPS)])


func shot(name: String) -> void:
	say(name)
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, name])


func watchdog() -> void:
	await frames(MAX_SECONDS * FPS)
	push_error("bonus tour: still running, stopping")
	quit(1)


func run() -> void:
	seed(20261007)
	var save = root.get_node("Save")
	save.persist = false
	save.first_play = false
	save.worn = "classic"
	save.released.clear()
	save.seen.clear()
	var dev = root.get_node("Dev")
	dev.enabled = false
	dev.persist = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await hold(0.3)
	game.start_bonus()
	var map = game.map
	await hold(1.0)
	await shot("b01_start")
	var shot_at := {
		20: "b02_top_lane", 40: "b03_cobweb", 56: "b04_zigzag", 68: "b05_reverse", 92: "b06_life"
	}
	while not game.journey_done and not game.dead:
		var x: int = map.position_key.x
		for k in shot_at.keys():
			if x >= k:
				await shot(shot_at[k])
				shot_at.erase(k)
		if game.stuck:
			release_all()
			if caught:
				await shot("c01_stuck")
				await hold(6.0)
				break
			await hold(0.5)
			Input.action_press("shake")
			await frames(2)
			Input.action_release("shake")
			continue
		var path := next_leg(map)
		if path.is_empty():
			await frames(1)
			continue
		await step_to(path[0])
	release_all()
	await wait_done()
	await hold(0.6)
	await shot("c02_rolled_up" if caught else "b07_finish")
	await hold(2.5)
	say("done")
	quit(0)


func wait_done() -> void:
	for i in 10 * FPS:
		if game.journey_done:
			return
		await process_frame


## Toward the nearest star that doesn't need a detour; else the finish.
func next_leg(map) -> Array[Vector2i]:
	var dist := bfs(map, map.position_key)
	var best = null
	var wanted := {}
	for k in map.points.keys():
		wanted[k] = map.points[k]
	for k in map.lives.keys():
		wanted[k] = map.lives[k]
	for k: Vector2i in wanted.keys():
		if not wanted[k] or not dist.has(k) or k.x < map.position_key.x:
			continue
		if dist[k][0] > (k.x - map.position_key.x) + 4:
			continue
		if best == null or dist[k][0] < dist[best][0]:
			best = k
	if best == null:
		best = map.ends[0].key
		if not dist.has(best):
			return []
	var path: Array[Vector2i] = []
	var cur: Vector2i = best
	while cur != map.position_key:
		path.push_front(cur)
		cur = dist[cur][1]
	return path


func bfs(map, start: Vector2i) -> Dictionary:
	var out := {start: [0, start]}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in DIRS:
			var n: Vector2i = cur + d
			if out.has(n) or not map.tiles.has(n) or map.tiles[n].blank or map.deaths.has(n):
				continue
			out[n] = [out[cur][0] + 1, cur]
			queue.append(n)
	return out


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
	for i in 8 * FPS:
		await process_frame
		if map.position_key == target and not map.moving:
			return true
		if game.dead or game.journey_done or game.stuck:
			return false
	return false


func release_all() -> void:
	for a in ACTIONS.values():
		Input.action_release(a)
