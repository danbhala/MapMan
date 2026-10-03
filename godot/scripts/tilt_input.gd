class_name TiltInput
extends RefCounted
## Turns device tilt, keys/gamepad, or a held touch into a steering vector.
## Port of shake.py plus the SimulatedTilt class from map_man.py.
##
## The vector is in screen terms: x > 0 means "go right", y > 0 means "go down".
## Its size uses the original's units (fractions of 1 g): 0.1 starts a move,
## above 0.2 moves at double speed.

## Inverting the axes and the shake strength needed to get unstuck are tuned
## in the dev menu (Dev.tuning); their defaults live in dev.gd.
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
	var v := steer_from_gravity(Input.get_gravity(), _neutral)
	if Dev.t("invert_x"):
		v.x = -v.x
	if Dev.t("invert_y"):
		v.y = -v.y
	return v


## How far the device is tipped from `neutral`, as a steering vector.
##
## Godot reports gravity pointing at the ground, already rotated to the
## screen: +x towards the screen's right edge, +y towards its top edge, +z out
## of the screen. Tipping the right edge down goes right; tipping the top edge
## down goes up (-y on screen).
##
## Tilt is measured as rotation away from `neutral`, not as the change in the
## raw x/y components: held upright, gravity.y is already at -1 g and can't
## fall any further, so leaning the top edge towards you never read as "down".
## Each value is the sine of the tilt angle (in g, like the original).
static func steer_from_gravity(gravity: Vector3, neutral: Vector3) -> Vector2:
	if gravity.length() < 0.1 or neutral.length() < 0.1:
		return Vector2.ZERO
	var g := gravity.normalized()
	var n := neutral.normalized()
	# Gravity moves along `right` when the right edge tips down, and along
	# `up` when the top edge tips down (rotation about the screen's x axis).
	var up := Vector3.RIGHT.cross(n)
	if up.length() < 0.3:
		# Held in portrait: the screen's x axis points at the ground, so fall
		# back to the plain component change.
		var d := g - n
		return Vector2(d.x, -d.y)
	up = up.normalized()
	var right := n.cross(up)
	return Vector2(g.dot(right), -g.dot(up))


## Same zones as SimulatedTilt: the outer quarter of the screen is a firm tilt,
## the outer third a gentle one, the middle third does nothing.
func _touch_vector() -> Vector2:
	var strong := 0.5 * 2.0
	var gentle := 0.11 * 2.0
	var v := Vector2.ZERO
	var w := screen_size.x
	var h := screen_size.y
	if _touch_pos.x < w / 4.0:
		v.x = -strong
	elif _touch_pos.x < w / 3.0:
		v.x = -gentle
	elif _touch_pos.x > 3.0 * w / 4.0:
		v.x = strong
	elif _touch_pos.x > 2.0 * w / 3.0:
		v.x = gentle
	if _touch_pos.y < h / 4.0:
		v.y = -strong
	elif _touch_pos.y < h / 3.0:
		v.y = -gentle
	elif _touch_pos.y > 3.0 * h / 4.0:
		v.y = strong
	elif _touch_pos.y > 2.0 * h / 3.0:
		v.y = gentle
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
		return shake_strength() > Dev.t("shake_threshold")
	return false


## How hard the device is being shaken right now, in g, gravity excluded.
func shake_strength() -> float:
	if not has_accelerometer():
		return 0.0
	return ((Input.get_accelerometer() - Input.get_gravity()) / 9.81).length()
