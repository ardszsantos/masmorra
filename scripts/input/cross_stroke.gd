extends RefCounted
## Continuous up-center-right-center-left-center-down-center gesture.

const NONE := 0
const ARM_COMPLETED := 1
const GESTURE_COMPLETED := 2
const ARM_RETURNED := 3
const GESTURE_CANCELLED := -1

var arm_length: float = 85.0
var return_radius: float = 42.0
var angle_tolerance_degrees: float = 50.0
var max_duration: float = 5.0
var last_arm_direction := Vector2.ZERO
var last_arm_position := Vector2.ZERO

var _origin := Vector2.ZERO
var _completed_arms := [false, false, false, false]
var _completed_count: int = 0
var _current_arm: int = -1
var _waiting_for_return: bool = false
var _started: float = 0.0

var _directions := [Vector2.UP, Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN]

func begin(position: Vector2, now: float) -> void:
	_origin = position
	_completed_arms = [false, false, false, false]
	_completed_count = 0
	_current_arm = -1
	_waiting_for_return = false
	_started = now
	last_arm_direction = Vector2.ZERO
	last_arm_position = position

func sample(position: Vector2, now: float) -> int:
	if now - _started > max_duration:
		var had_progress := _completed_count > 0 or _waiting_for_return
		begin(position, now)
		return GESTURE_CANCELLED if had_progress else NONE
	var offset := position - _origin
	if _waiting_for_return:
		if offset.length() <= return_radius:
			_waiting_for_return = false
			_completed_arms[_current_arm] = true
			_completed_count += 1
			_current_arm = -1
			if _completed_count >= _directions.size():
				return GESTURE_COMPLETED
			return ARM_RETURNED
	if offset.length() < arm_length:
		return NONE
	var heading := offset.normalized()
	var best_arm: int = -1
	var best_dot: float = cos(deg_to_rad(angle_tolerance_degrees))
	for index in range(_directions.size()):
		if _completed_arms[index]:
			continue
		var alignment: float = heading.dot(_directions[index])
		if alignment >= best_dot:
			best_dot = alignment
			best_arm = index
	if best_arm == -1:
		return NONE
	_current_arm = best_arm
	last_arm_direction = heading
	last_arm_position = position
	_waiting_for_return = true
	return ARM_COMPLETED

func has_progress() -> bool:
	return _completed_count > 0 or _waiting_for_return
