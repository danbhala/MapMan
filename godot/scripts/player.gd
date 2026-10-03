class_name Player
extends Sprite2D
## MapMan himself. Port of player.py: one frame per 1/60 s, like the original.
## Also draws MapWoman (completion.py's MapWoman) with `art = "woman"`.

const FRAMES := 14
const DEATH_FRAMES := 21
const FPS := 60.0
const ASSET_SCALE := 1.0 / 3.0

## Art folder under res://assets/: "man" or "woman". Set before adding to the tree.
var art := "man"
var is_hidden := true

var _up_idle: Array[Texture2D] = []
var _down_idle: Array[Texture2D] = []
var _side_idle: Array[Texture2D] = []
var _idle: Array[Texture2D] = []
var _up: Array[Texture2D] = []
var _down: Array[Texture2D] = []
var _side: Array[Texture2D] = []
var _death: Array[Texture2D] = []

var _frames: Array[Texture2D] = []
var _frame := 0
var _frame_clock := 0.0
var _flip := false
var _dying := false


func _ready() -> void:
	var idle_dir := "res://assets/%s/idle/" % art
	_up_idle = [load(idle_dir + "back.png")]
	_down_idle = [load(idle_dir + "front.png")]
	_side_idle = [load(idle_dir + "side.png")]
	_idle = [load(idle_dir + "neutral.png")]
	_up = _load_frames("back")
	_down = _load_frames("forward")
	_side = _load_frames("side")
	if art == "man":  # MapWoman never dies
		for i in DEATH_FRAMES:
			var t: Texture2D = load("res://assets/man/death/death%02d.png" % i)
			_death.append(t)
			_death.append(t)  # the original shows each death frame twice

	centered = false
	# anchor (0.5, -0.05) in the original's y-up space: feet just above the tile centre
	offset = Vector2(-66.0, -240.0 * 1.05)
	z_index = 10
	_frames = _idle
	texture = _idle[0]
	vanish()


func _load_frames(tag: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in range(1, FRAMES + 1):
		out.append(load("res://assets/%s/frames/%s%02d.png" % [art, tag, i]))
	return out


func _face(frames: Array[Texture2D], flip := false) -> void:
	_dying = frames == _death
	_flip = flip
	_frames = frames
	_frame = 0
	_draw()


func face_death() -> void:
	_face(_death)


func face_up() -> void:
	_face(_up)


func face_down() -> void:
	_face(_down)


func face_left() -> void:
	_face(_side, true)


func face_right() -> void:
	_face(_side)


func face_up_idle() -> void:
	_face(_up_idle)


func face_down_idle() -> void:
	_face(_down_idle)


func face_left_idle() -> void:
	_face(_side_idle, true)


func face_right_idle() -> void:
	_face(_side_idle)


func face_idle() -> void:
	_face(_idle)


func face_direction(dir: Vector2i, walking: bool) -> void:
	if dir == Vector2i.ZERO:
		face_idle()
		return
	var frames: Array[Texture2D]
	if dir.x != 0:
		frames = _side if walking else _side_idle
	elif dir.y < 0:
		frames = _up if walking else _up_idle
	else:
		frames = _down if walking else _down_idle
	_face(frames, dir.x < 0)


func vanish() -> void:
	visible = false
	is_hidden = true


func show_player() -> void:
	is_hidden = false
	visible = true
	_draw()


func _draw() -> void:
	scale = Vector2(-ASSET_SCALE if _flip else ASSET_SCALE, ASSET_SCALE)
	texture = _frames[_frame]


## Move to a screen position and advance the animation by elapsed time.
func update_at(pos: Vector2, delta: float) -> void:
	position = pos
	_frame_clock += delta
	while _frame_clock >= 1.0 / FPS:
		_frame_clock -= 1.0 / FPS
		if _dying:
			_frame = mini(_frame + 1, _frames.size() - 1)
		else:
			_frame = (_frame + 1) % _frames.size()
	_draw()


func on_last_frame() -> bool:
	return _frame == _frames.size() - 1


## True once the death animation has played through.
func death_finished() -> bool:
	return _dying and on_last_frame()
