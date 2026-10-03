class_name TiltInput
extends RefCounted
## Turns device tilt, keys/gamepad, or a held touch into a steering vector.
## Port of shake.py plus the SimulatedTilt class from map_man.py.
##
## The vector is in screen terms: x > 0 means "go right", y > 0 means "go down".
## Its size uses the original's units (fractions of 1 g): 0.1 starts a move,
## above 0.2 moves at double speed.

## Flip these if tilting on a real device steers the wrong way.
const INVERT_X := false
const INVERT_Y := false
## Shake strength (in g of user acceleration) that frees MapMan from a sticky tile.
const SHAKE_THRESHOLD := 0.4
## What keys/gamepad count as: a firm tilt, so MapMan moves at full speed.
const KEY_TILT := 0.25

var screen_size := Vector2(667, 375)
var _neutral := Vector3.ZERO
var _has_neutral := false
var _touch_active := false
var _touch_pos := Vector2.ZERO
var _shake_key_latch := false


static func has_accelerometer() -> bool:
	return OS.has_feature("mobile") and Input.get_gravity().length() > 0.1


## Use the current device angle as "level". Called when each level starts,
## replacing the original's fixed sitting/standing offsets.
func calibrate() -> void:
	var g := Input.get_gravity()
	_has_neutral = g.length() > 0.1
	_neutral = g


func touch(pressed: bool, pos: Vector2) -> void:
	_touch_active = pressed
	_touch_pos = pos


func touch_steering_enabled() -> bool:
	return not has_accelerometer()


func get_vector() -> Vector2:
	var keys := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if keys.length() > 0.0:
		return keys.normalized() * KEY_TILT
	if has_accelerometer():
		return _tilt_vector()
	if _touch_active:
		return _touch_vector()
	return Vector2.ZERO


func _tilt_vector() -> Vector2:
	if not _has_neutral:
		calibrate()
	# Godot reports the reaction to gravity, rotated to the screen orientation,
	# with +x to the right of the screen and +y towards its top edge.
	var d := (Input.get_gravity() - _neutral) / 9.81
	var v := Vector2(-d.x, d.y)
	if INVERT_X:
		v.x = -v.x
	if INVERT_Y:
		v.y = -v.y
	return v


## Same zones as SimulatedTilt: the outer quarter of the screen is a firm tilt,
## the outer third a gentle one, the middle third does nothing.
func _touch_vector() -> Vector2:
	var strong := 0.5 * 2.0
	var gentle := 0.11 * 2.0
	var v := Vector2.ZERO
	var w := screen_size.x
	var h := screen_size.y
	if _touch_pos.x < w / 4.0: v.x = -strong
	elif _touch_pos.x < w / 3.0: v.x = -gentle
	elif _touch_pos.x > 3.0 * w / 4.0: v.x = strong
	elif _touch_pos.x > 2.0 * w / 3.0: v.x = gentle
	if _touch_pos.y < h / 4.0: v.y = -strong
	elif _touch_pos.y < h / 3.0: v.y = -gentle
	elif _touch_pos.y > 3.0 * h / 4.0: v.y = strong
	elif _touch_pos.y > 2.0 * h / 3.0: v.y = gentle
	return v


## True on the frame the player shakes the device (or presses the shake key).
func shook() -> bool:
	if Input.is_action_pressed("shake"):
		if not _shake_key_latch:
			_shake_key_latch = true
			return true
	else:
		_shake_key_latch = false
	if has_accelerometer():
		var user_accel := (Input.get_accelerometer() - Input.get_gravity()) / 9.81
		return user_accel.length() > SHAKE_THRESHOLD
	return false
