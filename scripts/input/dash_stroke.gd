extends RefCounted

var stroke_length: float = 70.0
var return_radius: float = 24.0
var lateral_tolerance: float = 22.0
var max_duration: float = 1.4
var _origin := Vector2.ZERO
var _heading := Vector2.ZERO
var _phase: int = 0
var _started: float = 0.0

func begin(position: Vector2, now: float) -> void:
	_origin = position
	_heading = Vector2.ZERO
	_phase = 0
	_started = now

func sample(position: Vector2, now: float) -> Vector2:
	if now - _started > max_duration:
		begin(position, now)
	var offset := position - _origin
	if _phase == 0:
		if offset.length() >= stroke_length:
			_heading = offset.normalized()
			_phase = 1
	elif absf(offset.cross(_heading)) > lateral_tolerance:
		begin(position, now)
	elif _phase == 1 and offset.length() <= return_radius:
		_phase = 2
	elif _phase == 2 and offset.dot(_heading) >= stroke_length:
		return _heading
	return Vector2.ZERO
