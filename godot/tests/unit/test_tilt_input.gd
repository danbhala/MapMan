extends GutTest
## Tilt steering from gravity, measured against the calibrated "level" angle.

const G := 9.81
## How the phone is held when a level starts, as the top edge's angle above
## flat: from tipped slightly away, through flat and upright, to leaning past
## upright towards the player.
const HOLDS: Array[float] = [
	-15.0, 0.0, 15.0, 30.0, 45.0, 60.0, 75.0, 85.0, 88.0, 90.0, 92.0, 100.0
]
## How far the player leans from that hold, in degrees.
const LEANS: Array[float] = [3.0, 6.0, 10.0, 15.0, 20.0, 30.0]


## Gravity with the top edge raised `deg` above flat (0 flat, 90 upright) and
## then the right edge lowered by `roll` degrees.
func _gravity(deg: float, roll := 0.0) -> Vector3:
	var p := deg_to_rad(deg)
	var n := Vector3(0, -sin(p), -cos(p))
	var r := deg_to_rad(roll)
	return (n * cos(r) + Vector3.RIGHT * sin(r)) * G


func _steer(deg: float, neutral_deg: float, roll := 0.0) -> Vector2:
	return TiltInput.steer_from_gravity(_gravity(deg, roll), _gravity(neutral_deg))


func _label(hold: float, lean: float) -> String:
	return "held at %d deg, lean %+d deg" % [hold, lean]


func test_level_is_still() -> void:
	for hold in HOLDS:
		assert_almost_eq(_steer(hold, hold), Vector2.ZERO, Vector2(0.001, 0.001), _label(hold, 0))


func test_up_and_down_at_every_hold() -> void:
	# Top edge up (towards the player when upright) goes down, top edge down
	# goes up, by the sine of the lean, with no sideways drift.
	for hold in HOLDS:
		for lean in LEANS:
			var want := sin(deg_to_rad(lean))
			var down := _steer(hold + lean, hold)
			var up := _steer(hold - lean, hold)
			assert_almost_eq(down.y, want, 0.001, _label(hold, lean))
			assert_almost_eq(up.y, -want, 0.001, _label(hold, -lean))
			assert_almost_eq(down.x, 0.0, 0.001, _label(hold, lean))
			assert_almost_eq(up.x, 0.0, 0.001, _label(hold, -lean))


func test_left_and_right_at_every_hold() -> void:
	for hold in HOLDS:
		for lean in LEANS:
			var want := sin(deg_to_rad(lean))
			var right := _steer(hold, hold, lean)
			var left := _steer(hold, hold, -lean)
			assert_almost_eq(right.x, want, 0.001, _label(hold, lean) + " right")
			assert_almost_eq(left.x, -want, 0.001, _label(hold, -lean) + " left")
			assert_almost_eq(right.y, 0.0, 0.001, _label(hold, lean) + " right")
			assert_almost_eq(left.y, 0.0, 0.001, _label(hold, -lean) + " left")


func test_diagonal_at_every_hold() -> void:
	# Leaning both ways at once steers both ways, each with the right sign.
	for hold in HOLDS:
		for lean in [-15.0, 15.0]:
			for roll in [-15.0, 15.0]:
				var v := _steer(hold + lean, hold, roll)
				var tag := _label(hold, lean) + " roll %+d" % roll
				assert_eq(signf(v.y), signf(lean), tag)
				assert_eq(signf(v.x), signf(roll), tag)
				assert_gt(absf(v.x), 0.2, tag)
				assert_gt(absf(v.y), 0.2, tag)


func test_thresholds_need_the_same_lean_at_every_hold() -> void:
	# The original's 0.1 g start and 0.2 g fast thresholds are about 5.7 and
	# 11.5 degrees of lean, however the phone is held.
	var start: float = Dev.DEFAULT_TUNING.tilt_threshold
	var fast: float = Dev.DEFAULT_TUNING.fast_threshold
	for hold in HOLDS:
		for sgn in [-1.0, 1.0]:
			var tag := _label(hold, sgn * 5)
			assert_lt(absf(_steer(hold + sgn * 5.0, hold).y), start, tag + " stays")
			assert_lt(absf(_steer(hold, hold, sgn * 5.0).x), start, tag + " stays")
			assert_gt(absf(_steer(hold + sgn * 6.0, hold).y), start, tag + " moves")
			assert_gt(absf(_steer(hold, hold, sgn * 6.0).x), start, tag + " moves")
			assert_lt(absf(_steer(hold + sgn * 11.0, hold).y), fast, tag + " not fast")
			assert_gt(absf(_steer(hold + sgn * 12.0, hold).y), fast, tag + " fast")


func test_flat_matches_old_steering() -> void:
	# Held flat, small leans read as they did before (the raw gravity change).
	for lean in LEANS:
		for roll in [-lean, 0.0, lean]:
			var g := _gravity(lean, roll)
			var n := _gravity(0)
			var d := (g - n) / G
			var v := TiltInput.steer_from_gravity(g, n)
			assert_almost_eq(v.x, d.x, 0.02, _label(0, lean) + " roll %+d" % roll)
			assert_almost_eq(v.y, -d.y, 0.02, _label(0, lean) + " roll %+d" % roll)


func test_screenshot_hold_goes_down() -> void:
	# The dev gauge read gravity -0.4 -9.8 +0.1 when down didn't work.
	# Leaning the top edge towards the player turns gravity out of the screen
	# (+z), which is a negative rotation about the screen's x axis.
	var n := Vector3(-0.4, -9.8, 0.1)
	var down := TiltInput.steer_from_gravity(n.rotated(Vector3.RIGHT, deg_to_rad(-10)), n)
	var up := TiltInput.steer_from_gravity(n.rotated(Vector3.RIGHT, deg_to_rad(10)), n)
	assert_gt(down.y, 0.15)
	assert_lt(up.y, -0.15)


func test_portrait_and_missing_gravity_do_not_break() -> void:
	# Held in portrait the screen's x axis points at the ground; with no
	# sensor reading there's nothing to steer by.
	var side := Vector3(-G, 0, 0)
	assert_eq(TiltInput.steer_from_gravity(side, side), Vector2.ZERO)
	var v := TiltInput.steer_from_gravity(side.rotated(Vector3.FORWARD, 0.2), side)
	assert_true(v.is_finite())
	assert_eq(TiltInput.steer_from_gravity(Vector3.ZERO, side), Vector2.ZERO)
	assert_eq(TiltInput.steer_from_gravity(side, Vector3.ZERO), Vector2.ZERO)
