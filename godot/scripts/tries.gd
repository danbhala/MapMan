class_name Tries
extends Node
## Every try at the level being played (RunRecord), for the level clear's
## replay: the one going now and its run clock, which only runs while the
## level is being played, and the ones before it at the same level. Keeps the
## level's best-run ghost beside the try, and the replay while it plays.

## The most tries at one level kept (the latest).
const MAX := 60

var list: Array[RunRecord] = []
## The level the tries are at; a try at another level starts the list afresh.
var level := 0
## The try going now, or null between tries.
var run: RunRecord
var clock := 0.0
## The level's best run walking beside the try (made only when a level has
## one: a Player draws on the random numbers).
var ghost: BestGhost
## The level clear's replay while it plays.
var replay: Replay


## A try at `at_level` begins in `look` (a Wardrobe id), its clock at zero,
## with the level's best run beside it when the ghost is on. Level 0 is one
## from the drafting table, which has no ghost.
func begin(at_level: int, look := "classic") -> void:
	if at_level != level:
		list.clear()
		level = at_level
	run = RunRecord.new()
	run.outfit = look
	clock = 0.0
	var best: RunRecord = null
	if Save.ghost_on and level > 0 and Save.ghosts.has(level):
		best = RunRecord.decode(Save.ghosts[level])
	if best and ghost == null:
		ghost = BestGhost.new()
		add_child(ghost)
	if ghost:
		ghost.start(best, look)


## The level has been played for `delta` more: the clock runs, the ghost walks.
func tick(map: LevelMap, delta: float) -> void:
	clock += delta
	if ghost:
		ghost.follow(map, clock, delta)


## A step from now, in screen directions (the way he went), as in Main.move().
func step(dir: Vector2i, seconds: float) -> void:
	if run:
		run.add_step(clock, dir, seconds)


## The try ends ("win", "death", "timeout"; "" drops it unfinished) and joins
## the list; returns it, or null when none was going.
func end(how: String, time_left: float) -> RunRecord:
	if ghost:
		ghost.stop()
	var r := run
	run = null
	if r == null or how == "":
		return null
	r.finish(clock, how, time_left)
	list.append(r)
	if list.size() > MAX:
		list.pop_front()
	return r


func clear() -> void:
	list.clear()
	run = null


## Whether the level clear of `at_level` can offer a replay: the latest try
## won it, on foot (a level can't be won without a step, but tests skip them).
func replayable(at_level: int) -> bool:
	if list.is_empty() or level != at_level:
		return false
	return list[-1].won() and list[-1].step_count() > 0


## Plays every try on `map` (the level loaded or loading); `finished` fires
## when it is over or tapped away.
func play(map: LevelMap) -> Replay:
	replay = Replay.new()
	add_child(replay)
	var n := list.size()
	replay.setup(map, list, tr("REPLAY — LEVEL %d") % level, tr_n("%d TRY", "%d TRIES", n) % n)
	return replay


## Ends the replay; false if none was playing.
func stop_replay() -> bool:
	if replay == null:
		return false
	replay.queue_free()
	replay = null
	return true
