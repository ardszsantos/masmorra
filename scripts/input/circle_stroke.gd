extends RefCounted

var required_rotation_degrees: float = 540.0
var minimum_path_length: float = 180.0
var start_rotation_degrees: float = 360.0
var _last := Vector2.ZERO
var _heading := Vector2.ZERO
var _rotation: float = 0.0
var _distance: float = 0.0

func begin(position: Vector2) -> void:
	_last = position
	_heading = Vector2.ZERO
	_rotation = 0.0
	_distance = 0.0

func sample(position: Vector2) -> float:
	var offset := position - _last
	if offset.length() < 10.0:
		return 0.0
	var heading := offset.normalized()
	var turning: bool = false
	if not _heading.is_zero_approx():
		var turn := _heading.angle_to(heading)
		if absf(turn) > deg_to_rad(60.0) or (_rotation * turn < 0.0 and absf(turn) > deg_to_rad(12.0)):
			_rotation = 0.0
			_distance = 0.0
		else:
			_rotation += turn
			turning = absf(turn) >= deg_to_rad(1.0)
	_distance += offset.length()
	_last = position
	_heading = heading
	if turning and absf(_rotation) >= deg_to_rad(start_rotation_degrees) and _distance >= minimum_path_length:
		var progress := inverse_lerp(start_rotation_degrees, required_rotation_degrees, absf(rad_to_deg(_rotation)))
		return signf(_rotation) * lerpf(0.2, 1.0, clampf(progress, 0.0, 1.0))
	return 0.0
