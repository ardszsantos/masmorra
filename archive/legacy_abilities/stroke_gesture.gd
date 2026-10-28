extends Node
## Walking uses continuous samples. Dash and slash compare the intent of two completed strokes.
signal direction_changed(direction: Vector2)
signal action_requested(trigger: StringName, direction: Vector2)
signal sustained_action_changed(trigger: StringName, value: float)
signal stroke_queued(direction: Vector2, duration: float)
signal gesture_completed(direction: Vector2, duration: float)
signal stroke_queue_cleared

@export_range(0.0, 60.0) var movement_deadzone: float = 14.0
@export_range(30.0, 240.0) var movement_anchor_radius: float = 90.0
@export_range(20.0, 240.0) var minimum_stroke_length: float = 70.0
@export_range(0.1, 3.0) var stroke_queue_duration: float = 1.0
@export_range(1.0, 60.0) var dash_angle_tolerance_degrees: float = 30.0
@export_range(0.2, 2.0) var completed_gesture_display_time: float = 0.8
@export var circle_rotation_degrees: float = 540.0
@export var circle_minimum_path: float = 80.0
@export var circle_start_degrees: float = 360.0
@export var circle_idle_timeout: float = 0.25
var _circle_idle: float = 0.0
var _last_position := Vector2.ZERO
var _circle := preload("res://archive/legacy_abilities/circle_stroke.gd").new()
var _anchor := Vector2.ZERO
var _tracking: bool = false
var _points := PackedVector2Array()
var _queued_direction := Vector2.ZERO
var _queue_deadline: float = 0.0
var _circle_was_active: bool = false

func begin(position: Vector2) -> void:
	_reset_current_stroke()
	_expire_queue(Time.get_ticks_msec() / 1000.0)
	_tracking = true
	_anchor = position
	_points.append(position)
	_circle.required_rotation_degrees = circle_rotation_degrees
	_circle.minimum_path_length = circle_minimum_path
	_circle.start_rotation_degrees = circle_start_degrees
	_circle.begin(position)
	_circle_was_active = false
	_last_position = position

func sample(position: Vector2) -> void:
	if not _tracking:
		return
	_last_position = position
	if _points[-1].distance_to(position) >= 3.0:
		if _points.size() >= 512:
			_points.remove_at(0)
		_points.append(position)
	_update_movement(position)
	var rotation := _circle.sample(position)
	if rotation != 0.0:
		_circle_was_active = true
		_circle_idle = circle_idle_timeout
		sustained_action_changed.emit(&"circle", rotation)
		return
	if _circle_idle > 0.0:
		return

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
	if not cancelled and not _circle_was_active and _is_valid_line_stroke():
		_complete_line_stroke((_points[-1] - _points[0]).normalized(), now)
	_reset_current_stroke()

func _complete_line_stroke(direction: Vector2, now: float) -> void:
	_expire_queue(now)
	if _queued_direction.is_zero_approx():
		_queue(direction, now)
		return
	var angle := absf(rad_to_deg(_queued_direction.angle_to(direction)))
	if angle <= dash_angle_tolerance_degrees:
		_clear_queue(false)
		gesture_completed.emit(direction, completed_gesture_display_time)
		_emit_action(&"double_flick", direction)
	else:
		_clear_queue(false)
		gesture_completed.emit(direction, completed_gesture_display_time)
		_emit_action(&"stroke_turn", direction)

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
	_circle_idle = 0.0

func reset() -> void:
	_reset_current_stroke()
	_clear_queue()
	sustained_action_changed.emit(&"circle", 0.0)
	direction_changed.emit(Vector2.ZERO)

func _process(delta: float) -> void:
	_expire_queue(Time.get_ticks_msec() / 1000.0)
	if _circle_idle <= 0.0:
		return
	_circle_idle = maxf(0.0, _circle_idle - delta)
	if _circle_idle == 0.0:
		_circle.begin(_last_position)
		sustained_action_changed.emit(&"circle", 0.0)
