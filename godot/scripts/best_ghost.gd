class_name BestGhost
extends Player
## The level's best run (a RunRecord from Save.ghosts), walked faintly beside
## MapMan on the same run clock, so the player can see if they're ahead.
## Gone once its run is over, at the exit.

## How faint he is.
const ALPHA := 0.35

var run: RunRecord
var _dir := Vector2i(9, 9)
var _moving := false


func _ready() -> void:
	super()
	z_index = 9  # behind MapMan (10)


## Walks `best` (null for none) from the next follow(), in the look he wore
## for it (`look` if the record has none the wardrobe knows).
func start(best: RunRecord, look: String) -> void:
	run = best
	outfit = best.outfit if best and Wardrobe.is_look(best.outfit) else look
	_dir = Vector2i(9, 9)
	vanish()


func stop() -> void:
	run = null
	vanish()


## Where the run had got to at `clock` on `map`.
func follow(map: LevelMap, clock: float, delta: float) -> void:
	if run == null:
		return
	var at := run.at(map.start_position, clock)
	if clock >= run.end_time or not map.tiles.has(at.key) or not map.tiles.has(at.next):
		stop()
		return
	if is_hidden:
		reset_pose()
		is_hidden = false
		visible = true
	var a: Vector2 = map.tiles[at.key].position
	update_at(a.lerp(map.tiles[at.next].position, at.share), delta)
	modulate.a = ALPHA
	if at.dir != _dir or at.moving != _moving:
		if at.dir == Vector2i.ZERO:
			face_idle()
		else:
			face_direction(at.dir, at.moving)
		_dir = at.dir
		_moving = at.moving
