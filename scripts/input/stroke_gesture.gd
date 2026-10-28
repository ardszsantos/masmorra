extends Node
## Walking uses continuous samples. Abilities compare two released arrows.
signal direction_changed(direction: Vector2)
signal action_requested(trigger: StringName, direction: Vector2)
signal sustained_action_changed(trigger: StringName, value: float)
signal stroke_queued(direction: Vector2, duration: float)
signal gesture_completed(direction: Vector2, duration: float)
signal stroke_queue_cleared
signal gesture_rejected(reason: StringName)

@export_range(0.0, 60.0) var movement_deadzone: float = 14.0
@export_range(30.0, 240.0) var movement_anchor_radius: float = 90.0
@export_range(20.0, 240.0) var minimum_stroke_length: float = 70.0
@export_range(0.1, 3.0) var stroke_queue_duration: float = 1.0
@export_range(1.0, 60.0) var dash_angle_tolerance_degrees: float = 30.0
@export_range(0.2, 2.0) var completed_gesture_display_time: float = 0.8
@export_range(110.0, 150.0) var reverse_minimum_angle_degrees: float = 130.0
var _anchor := Vector2.ZERO
var _tracking: bool = false
var _points := PackedVector2Array()
var _queued_direction := Vector2.ZERO
var _queue_deadline: float = 0.0

func begin(position: Vector2) -> void:
	_reset_current_stroke()
	_expire_queue(Time.get_ticks_msec() / 1000.0)
	_tracking = true
	_anchor = position
	_points.append(position)

func sample(position: Vector2) -> void:
	if not _tracking:
		return
	if _points[-1].distance_to(position) >= 3.0:
		if _points.size() >= 512:
			_points.remove_at(0)
		_points.append(position)
	_update_movement(position)

func _update_movement(position: Vector2) -> void:
	var displacement := position - _anchor
	var distance := displacement.length()
	if distance > movement_anchor_radius:
		_anchor += displacement.normalized() * (distance - movement_anchor_radius)
		displacement = position - _anchor
		distance = displacement.length()
	if distance <= movement_deadzone:
		direction_changed.emit(Vector2.ZERO)
	else:
		direction_changed.emit(displacement.normalized())

func end(cancelled: bool = false) -> void:
	if not _tracking:
		return
	direction_changed.emit(Vector2.ZERO)
	sustained_action_changed.emit(&"circle", 0.0)
	var now := Time.get_ticks_msec() / 1000.0
	if cancelled:
		_clear_queue()
	elif _is_valid_line_stroke():
		_complete_line_stroke((_points[-1] - _points[0]).normalized(), now)
	_reset_current_stroke()

func _complete_line_stroke(direction: Vector2, now: float) -> void:
	_expire_queue(now)
	if _queued_direction.is_zero_approx():
		_queue(direction, now)
		return
	var angle := absf(rad_to_deg(_queued_direction.angle_to(direction)))
	_clear_queue(false)
	gesture_completed.emit(direction, completed_gesture_display_time)
	if angle <= dash_angle_tolerance_degrees:
		_emit_action(&"double_flick", direction)
	elif angle >= reverse_minimum_angle_degrees:
		_emit_action(&"book_bonk", direction)
	else:
		_emit_action(&"set_square", direction)

func _is_valid_line_stroke() -> bool:
	return _points.size() >= 2 and _points[0].distance_to(_points[-1]) >= minimum_stroke_length

func _queue(direction: Vector2, now: float) -> void:
	_queued_direction = direction
	_queue_deadline = now + stroke_queue_duration
	stroke_queued.emit(direction, stroke_queue_duration)

func _clear_queue(notify_visuals: bool = true) -> void:
	_queued_direction = Vector2.ZERO
	_queue_deadline = 0.0
	if notify_visuals:
		stroke_queue_cleared.emit()

func _expire_queue(now: float) -> void:
	if not _queued_direction.is_zero_approx() and now > _queue_deadline:
		_clear_queue()

func _emit_action(trigger: StringName, direction: Vector2) -> void:
	direction_changed.emit(Vector2.ZERO)
	action_requested.emit(trigger, direction)

func _reset_current_stroke() -> void:
	_tracking = false
	_points.clear()

func reset() -> void:
	_reset_current_stroke()
	_clear_queue()
	sustained_action_changed.emit(&"circle", 0.0)
	direction_changed.emit(Vector2.ZERO)

func _process(_delta: float) -> void:
	_expire_queue(Time.get_ticks_msec() / 1000.0)
