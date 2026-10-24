extends Control

signal direction_changed(direction: Vector2)
signal stick_sampled(direction: Vector2)
signal interaction_ended

@export_range(20.0, 200.0) var radius: float = 90.0
@export_range(0.0, 0.9) var deadzone: float = 0.15
var touch_index: int = -1
var knob_offset := Vector2.ZERO
var center := Vector2.ZERO


func _ready() -> void:
	get_viewport().size_changed.connect(_reset)


func _draw() -> void:
	if touch_index == -1:
		return
	draw_circle(center, radius, Color(0.08, 0.1, 0.14, 0.55))
	draw_arc(center, radius, 0.0, TAU, 64, Color(1, 1, 1, 0.65), 3.0, true)
	draw_circle(center + knob_offset, 34.0, Color(0.85, 0.9, 1.0, 0.8))


func _input(event: InputEvent) -> void:
	# Keep ownership of this finger even when it moves over future UI controls.
	if touch_index == -1:
		return
	if event is InputEventScreenTouch:
		if event.index == touch_index and (not event.pressed or event.canceled):
			_reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_index:
		_update_direction(event.position)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# UI gets first refusal for new touches. Otherwise start anywhere on screen.
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and touch_index == -1:
			center = get_global_transform_with_canvas().affine_inverse() * event.position
			touch_index = event.index
			_update_direction(event.position)
			get_viewport().set_input_as_handled()


func _update_direction(viewport_position: Vector2) -> void:
	var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * viewport_position
	knob_offset = (local_position - center).limit_length(radius)
	var strength: float = knob_offset.length() / radius
	var direction := Vector2.ZERO
	if strength > deadzone:
		direction = knob_offset.normalized() * ((strength - deadzone) / (1.0 - deadzone))
	direction_changed.emit(direction)
	stick_sampled.emit(knob_offset / radius)
	queue_redraw()


func _reset() -> void:
	touch_index = -1
	knob_offset = Vector2.ZERO
	direction_changed.emit(Vector2.ZERO)
	interaction_ended.emit()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_reset()
