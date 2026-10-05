class_name TiltInput
extends RefCounted
## Turns device tilt, keys/gamepad, the touch stick (TouchStick) or a held
## touch into a steering vector.
## Port of shake.py plus the SimulatedTilt class from map_man.py.
##
## The vector is in screen terms: x > 0 means "go right", y > 0 means "go down".
## Its size uses the original's units (fractions of 1 g): 0.1 starts a move,
## above 0.2 moves at double speed.

## Inverting the axes and the shake strength needed to get unstuck are tuned
## in the dev menu (Dev.tuning); their defaults live in dev.gd.
## What keys/gamepad count as: a firm tilt, so MapMan moves at full speed.
const KEY_TILT := 0.25
## After calibrating, keep averaging the device angle for this long so one
## shaky reading doesn't set "level" for the whole level.
const CALIBRATE_SECONDS := 0.25
## Readings further than this (in g) from the average so far are a deliberate
## lean, not hand tremor: they end the averaging instead of joining it. Capped
## at the start threshold so a lean that moves MapMan is never averaged in.
const CALIBRATE_SPREAD := 0.08
## Options "TILT SENSITIVITY": how much tilt each level needs to walk and run,
## as a multiple of the tuned thresholds (LOW, NORMAL, HIGH). The tilt is
## divided by it, so the thresholds, and the gauge's rings, stay put.
const SENSITIVITY: Array[float] = [1.5, 1.0, 0.7]

## Steer with the touch stick instead of the phone (Options "CONTROLS").
var stick := false
## Index into SENSITIVITY (Save.tilt_sensitivity).
var sensitivity := 1

var screen_size := Vector2(667, 375)
var _neutral := Vector3.ZERO
var _has_neutral := false
var _sum := Vector3.ZERO
var _calibrate_left := 0.0
var _touch_active := false
var _touch_pos := Vector2.ZERO
var _shake_key_latch := false
## The touch stick: held, where the finger landed, and where it is now.
var _stick_held := false
var _stick_origin := Vector2.ZERO
var _stick_at := Vector2.ZERO


static func has_accelerometer() -> bool:
	return OS.has_feature("mobile") and Input.get_gravity().length() > 0.1


## Use the current device angle as "level". Called when each level starts and
## when the game is unpaused, replacing the original's fixed sitting/standing
## offsets. Readings over the next CALIBRATE_SECONDS are averaged in.
func calibrate() -> void:
	calibrate_to(Input.get_gravity())


func calibrate_to(gravity: Vector3) -> void:
	_has_neutral = gravity.length() > 0.1
	_neutral = gravity.normalized() if _has_neutral else Vector3.ZERO
	_sum = _neutral
	_calibrate_left = CALIBRATE_SECONDS if _has_neutral else 0.0


## Call once per frame while playing.
func update(delta: float) -> void:
	if _calibrate_left > 0.0:
		sample(Input.get_gravity(), delta)


func sample(gravity: Vector3, delta: float) -> void:
	if _calibrate_left <= 0.0 or gravity.length() < 0.1:
		return
	var g := gravity.normalized()
	if (g - _neutral).length() > minf(CALIBRATE_SPREAD, Dev.t("tilt_threshold")):
		_calibrate_left = 0.0
		return
	_sum += g
	_neutral = _sum.normalized()
	_calibrate_left -= delta


func calibrating() -> bool:
	return _calibrate_left > 0.0


func touch(pressed: bool, pos: Vector2) -> void:
	_touch_active = pressed
	_touch_pos = pos


func touch_steering_enabled() -> bool:
	return not stick and not has_accelerometer()


## A finger landed (the stick appears under it), moved, or lifted.
func stick_press(pos: Vector2) -> void:
	_stick_held = true
	_stick_origin = pos
	_stick_at = pos


func stick_drag(pos: Vector2) -> void:
	if _stick_held:
		_stick_at = pos


func stick_release() -> void:
	_stick_held = false


func stick_held() -> bool:
	return _stick_held


func stick_origin() -> Vector2:
	return _stick_origin


## The knob's offset from the stick's centre, kept inside the rim.
func stick_offset() -> Vector2:
	return (_stick_at - _stick_origin).limit_length(TouchStick.RADIUS)


## The stick in tilt units, drawn like the gauge: its rim is 1.5 × the
## full-speed tilt, so its dashed and solid rings are where he walks and runs.
func stick_vector() -> Vector2:
	if not _stick_held:
		return Vector2.ZERO
	return stick_offset() / TouchStick.RADIUS * Dev.t("fast_threshold") * 1.5


func get_vector() -> Vector2:
	var keys := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if keys.length() > 0.0:
		return keys.normalized() * KEY_TILT
	if stick:
		return stick_vector()
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
	return sensitive(v)


## A tilt as the chosen sensitivity reads it: on HIGH the same tilt counts for
## more, so MapMan walks and runs with less of it.
func sensitive(tilt: Vector2) -> Vector2:
	return tilt / SENSITIVITY[clampi(sensitivity, 0, SENSITIVITY.size() - 1)]


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
