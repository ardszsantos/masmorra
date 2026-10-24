extends Node
## Receives raw normalized stick samples; knows nothing about equipped abilities.

signal action_requested(trigger: StringName, direction: Vector2)

@export_range(0.01, 1.0) var pull_threshold: float = 0.65
@export_range(0.0, 0.5) var center_threshold: float = 0.2
@export_range(0.05, 1.0) var max_interval: float = 0.35
@export_range(0.0, 180.0) var angle_tolerance_degrees: float = 30.0

var _first_direction := Vector2.ZERO
var _first_time: float = 0.0
var _armed: bool = true


func sample(direction: Vector2) -> void:
	feed_sample(direction, Time.get_ticks_usec() / 1000000.0)


func feed_sample(direction: Vector2, time_seconds: float) -> void:
	if time_seconds - _first_time > max_interval:
		_first_direction = Vector2.ZERO
	if direction.length() <= center_threshold:
		_armed = true
		return
	if not _armed or direction.length() < pull_threshold:
		return
	_armed = false
	var heading: Vector2 = direction.normalized()
	if not _first_direction.is_zero_approx():
		if _first_direction.dot(heading) >= cos(deg_to_rad(angle_tolerance_degrees)):
			_first_direction = Vector2.ZERO
			action_requested.emit(&"double_flick", heading)
			return
	_first_direction = heading
	_first_time = time_seconds


func reset() -> void:
	_first_direction = Vector2.ZERO
	_first_time = 0.0
	_armed = true
