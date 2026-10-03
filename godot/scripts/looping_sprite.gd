class_name LoopingSprite
extends Sprite2D
## A looping frame animation at 60 fps: the ending's vortex and hearts.
## Port of completion.py's AnimatedBase.

const FPS := 60.0
const ASSET_SCALE := 1.0 / 3.0

var _frames: Array[Texture2D] = []
var _frame := 0
var _clock := 0.0


## tag: "vortex" or "hearts"; frames are res://assets/<tag>/<tag>00.png and on.
func _init(tag: String, count: int) -> void:
	for i in count:
		_frames.append(load("res://assets/%s/%s%02d.png" % [tag, tag, i]))
	texture = _frames[0]
	scale = Vector2(ASSET_SCALE, ASSET_SCALE)
	# The original anchors at (0.5, 0.35) in its y-up space: 35% up from the
	# bottom edge, which is 15% below the centre.
	offset = Vector2(0, -0.15 * texture.get_height())
	visible = false


func restart() -> void:
	_frame = 0
	_clock = 0.0
	texture = _frames[0]


func advance(delta: float) -> void:
	_clock += delta
	while _clock >= 1.0 / FPS:
		_clock -= 1.0 / FPS
		_frame = (_frame + 1) % _frames.size()
	texture = _frames[_frame]
