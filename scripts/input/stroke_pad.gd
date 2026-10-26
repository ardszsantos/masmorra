extends Control
## Owns one touch and draws its trail. Recognition lives in StrokeGesture.
signal stroke_started(position: Vector2)
signal stroke_sampled(position: Vector2)
signal stroke_ended(cancelled: bool)

@export var trail_color := Color(0.55, 0.85, 1.0, 0.95)
@export_range(1.0, 12.0) var trail_width: float = 4.0
@export_range(0.0, 5.0) var trail_hold_time: float = 1.5
@export_range(0.05, 3.0) var trail_lifetime: float = 0.8
@export_range(0.0, 2.0) var glow_strength: float = 1.0
@export_range(32, 2048) var max_points: int = 512
@export_range(0.0, 10.0) var smoothing_distance: float = 1.5
var _smoother := preload("res://scripts/input/stroke_smoother.gd").new()
var touch_index: int = -1
var _points := PackedVector2Array()
var _ages := PackedFloat32Array()
var _queued_directions: Array[Vector2] = []
var _queue_positions: Array[Vector2] = []
var _queue_remaining: float = 0.0
var _queue_duration: float = 1.0
var _queue_completed: bool = false
var _queue_failed: bool = false
var _stabilized_circle: bool = false
var _circle_center := Vector2.ZERO
var _circle_radius: float = 0.0

func _ready() -> void:
	get_viewport().size_changed.connect(reset)

func _draw() -> void:
	if _stabilized_circle:
		_draw_stabilized_circle()
		_draw_queue_marker()
		return
	# Wide translucent layers provide a glow even in the compatibility renderer.
	for layer in range(4):
		var width_scale: float = [5.0, 3.0, 1.5, 0.65][layer]
		var opacity: float = [0.045, 0.10, 0.35, 1.0][layer]
		var colors := PackedColorArray()
		for index in range(_points.size()):
			var fade := _trail_opacity(_ages[index])
			var color := trail_color
			if layer == 3:
				color = color.lerp(Color.WHITE, 0.7)
			color.a = trail_color.a * opacity * fade * (glow_strength if layer < 3 else 1.0)
			colors.append(color)
		if _points.size() > 1:
			draw_polyline_colors(_points, colors, trail_width * width_scale, true)
	if not _points.is_empty():
		var tip := trail_color.lerp(Color.WHITE, 0.8)
		tip.a = trail_color.a * _trail_opacity(_ages[-1])
		draw_circle(_points[-1], trail_width * 0.65, tip, true, -1.0, true)
	_draw_queue_marker()

func _draw_stabilized_circle() -> void:
	if _circle_radius <= 0.0:
		return
	for layer in range(4):
		var width_scale: float = [5.0, 3.0, 1.5, 0.65][layer]
		var opacity: float = [0.045, 0.10, 0.35, 1.0][layer]
		var color := trail_color
		if layer == 3:
			color = color.lerp(Color.WHITE, 0.7)
		color.a = trail_color.a * opacity * (glow_strength if layer < 3 else 1.0)
		draw_arc(_circle_center, _circle_radius, 0.0, TAU, 96, color, trail_width * width_scale, true)

func _draw_queue_marker() -> void:
	if _queue_remaining <= 0.0 or _queued_directions.is_empty():
		return
	var progress := clampf(_queue_remaining / _queue_duration, 0.0, 1.0)
	var color := Color(1.0, 0.25, 0.22, 0.98) if _queue_failed else (Color(0.35, 1.0, 0.48, 0.98) if _queue_completed else Color(1.0, 0.82, 0.28, 0.95))
	for index in range(_queued_directions.size()):
		var direction := _queued_directions[index]
		var marker_position := _queue_positions[index]
		var start := marker_position - direction * 16.0
		var finish := marker_position + direction * 16.0
		draw_line(start, finish, color, 4.5, true)
		var side := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([
			finish + direction * 7.0,
			finish - direction * 5.0 + side * 6.0,
			finish - direction * 5.0 - side * 6.0,
		]), color)
		draw_arc(marker_position, 28.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 28, color, 3.0, true)

func _trail_opacity(age: float) -> float:
	var progress := clampf((age - trail_hold_time) / trail_lifetime, 0.0, 1.0)
	return 1.0 - smoothstep(0.0, 1.0, progress)

func _process(delta: float) -> void:
	if _queue_remaining > 0.0:
		_queue_remaining = maxf(0.0, _queue_remaining - delta)
	for index in range(_ages.size()):
		_ages[index] += delta
	while not _ages.is_empty() and _ages[0] >= trail_hold_time + trail_lifetime:
		_ages.remove_at(0)
		_points.remove_at(0)
	queue_redraw()

func show_queued_stroke(direction: Vector2, duration: float) -> void:
	_queued_directions = [direction.normalized()]
	_queue_positions = [_points[-1] if not _points.is_empty() else size * 0.5]
	_queue_completed = false
	_queue_failed = false
	_queue_duration = maxf(duration, 0.001)
	_queue_remaining = _queue_duration
	queue_redraw()

func add_queued_stroke(direction: Vector2, duration: float, marker_position: Vector2 = Vector2.INF) -> void:
	_queued_directions.append(direction.normalized())
	if marker_position.is_finite():
		_queue_positions.append(marker_position)
	else:
		_queue_positions.append(_points[-1] if not _points.is_empty() else size * 0.5)
	_queue_completed = false
	_queue_failed = false
	_queue_duration = maxf(duration, 0.001)
	_queue_remaining = _queue_duration
	queue_redraw()

func complete_queued_gesture(direction: Vector2, duration: float) -> void:
	add_queued_stroke(direction, duration)

func mark_queued_gesture_completed(duration: float) -> void:
	_queue_completed = false
	_queue_failed = false
	_queue_duration = maxf(duration, 0.001)
	_queue_remaining = _queue_duration
	queue_redraw()

func resolve_queued_gesture(success: bool) -> void:
	if _queued_directions.is_empty() or _queue_remaining <= 0.0:
		return
	_queue_completed = success
	_queue_failed = not success
	_queue_remaining = _queue_duration
	queue_redraw()

func clear_queued_stroke() -> void:
	_queued_directions.clear()
	_queue_positions.clear()
	_queue_completed = false
	_queue_failed = false
	_queue_remaining = 0.0
	queue_redraw()

func update_sustained_gesture(trigger: StringName, value: float) -> void:
	if trigger != &"circle":
		return
	if is_zero_approx(value):
		if _stabilized_circle:
			_stabilized_circle = false
			_points.clear()
			_ages.clear()
			queue_redraw()
		return
	var sample_count := mini(_points.size(), 144)
	if sample_count < 12:
		return
	var center_sum := Vector2.ZERO
	for index in range(_points.size() - sample_count, _points.size()):
		center_sum += _points[index]
	var measured_center := center_sum / float(sample_count)
	var measured_radius: float = 0.0
	for index in range(_points.size() - sample_count, _points.size()):
		measured_radius += _points[index].distance_to(measured_center)
	measured_radius /= float(sample_count)
	if not _stabilized_circle:
		_circle_center = measured_center
		_circle_radius = measured_radius
		_stabilized_circle = true
	else:
		_circle_center = _circle_center.lerp(measured_center, 0.12)
		_circle_radius = lerpf(_circle_radius, measured_radius, 0.12)
	queue_redraw()

func _local(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not event.canceled and touch_index == -1:
		var point := _local(event.position)
		if not Rect2(Vector2.ZERO, size).has_point(point):
			return
		touch_index = event.index
		_smoother.smoothing_distance = smoothing_distance
		_smoother.begin(point)
		_points = PackedVector2Array([point])
		_ages = PackedFloat32Array([0.0])
		stroke_started.emit(point)
		queue_redraw()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if touch_index == -1:
		return
	if event is InputEventScreenTouch and event.index == touch_index and (not event.pressed or event.canceled):
		_finish_stroke(event.canceled)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_index:
		var point := _local(event.position)
		if not Rect2(Vector2.ZERO, size).has_point(point):
			_finish_stroke(true)
		else:
			point = _smoother.sample(point)
			if _points.is_empty() or _points[-1].distance_to(point) >= 2.0:
				_points.append(point)
				_ages.append(0.0)
				if _points.size() > max_points:
					_points.remove_at(0)
					_ages.remove_at(0)
			stroke_sampled.emit(point)
			queue_redraw()
		get_viewport().set_input_as_handled()

func _finish_stroke(cancelled: bool) -> void:
	if touch_index == -1:
		return
	touch_index = -1
	stroke_ended.emit(cancelled)
	_points.clear()
	_ages.clear()
	queue_redraw()

func reset() -> void:
	_finish_stroke(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset()
