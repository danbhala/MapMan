class_name Tries
extends RefCounted
## Every try at the level being played (RunRecord), for the level clear's
## replay: the one going now and its run clock, which only runs while the
## level is being played, and the ones before it at the same level.

## The most tries at one level kept (the latest).
const MAX := 60

var list: Array[RunRecord] = []
## The level the tries are at; a try at another level starts the list afresh.
var level := 0
## The try going now, or null between tries.
var run: RunRecord
var clock := 0.0


## A try at `at_level` begins, its clock at zero.
func begin(at_level: int) -> void:
	if at_level != level:
		list.clear()
		level = at_level
	run = RunRecord.new()
	clock = 0.0


## A step from now, in screen directions (the way he went), as in Main.move().
func step(dir: Vector2i, seconds: float) -> void:
	if run:
		run.add_step(clock, dir, seconds)


## The try ends ("win", "death", "timeout"; "" drops it unfinished) and joins
## the list; returns it, or null when none was going.
func end(how: String, time_left: float) -> RunRecord:
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
