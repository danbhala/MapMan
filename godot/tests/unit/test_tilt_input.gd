extends GutTest
## Tilt steering from gravity, measured against the calibrated "level" angle.

const G := 9.81


## Gravity with the top edge raised `deg` above flat (0 flat, 90 upright) and
## then the right edge lowered by `roll` degrees.
func _gravity(deg: float, roll := 0.0) -> Vector3:
	var p := deg_to_rad(deg)
	var n := Vector3(0, -sin(p), -cos(p))
	var r := deg_to_rad(roll)
	return (n * cos(r) + Vector3.RIGHT * sin(r)) * G


func _steer(deg: float, neutral_deg: float, roll := 0.0) -> Vector2:
	return TiltInput.steer_from_gravity(_gravity(deg, roll), _gravity(neutral_deg))


func test_level_is_still() -> void:
	for n in [0.0, 45.0, 88.0]:
		assert_almost_eq(_steer(n, n), Vector2.ZERO, Vector2(0.001, 0.001))


func test_flat_matches_original_directions() -> void:
	# Top edge down (raised -10) goes up; top edge up goes down.
	assert_lt(_steer(-10, 0).y, -0.1)
	assert_gt(_steer(10, 0).y, 0.1)


func test_upright_can_go_down_and_up() -> void:
	# Held almost upright: leaning the top edge towards you goes down,
	# leaning it back goes up, both by about the same amount.
	var down := _steer(98, 88)
	var up := _steer(78, 88)
	assert_gt(down.y, 0.1, "lean top edge towards you goes down")
	assert_lt(up.y, -0.1, "lean top edge away goes up")
	assert_almost_eq(down.y, -up.y, 0.01)


func test_upright_left_and_right() -> void:
	assert_gt(_steer(88, 88, 10).x, 0.1)
	assert_lt(_steer(88, 88, -10).x, -0.1)
	assert_almost_eq(_steer(88, 88, 10).y, 0.0, 0.02)


func test_angle_not_component_size() -> void:
	# The same 10-degree lean reads the same at any holding angle.
	for n in [0.0, 30.0, 60.0, 88.0]:
		assert_almost_eq(_steer(n + 10, n).y, sin(deg_to_rad(10)), 0.001)
