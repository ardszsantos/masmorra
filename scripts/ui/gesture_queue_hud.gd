extends Control
## Visual queue of completed stroke tokens. Each direction occupies one square.

@export_range(40.0, 120.0) var token_size: float = 72.0
@export_range(4.0, 32.0) var token_gap: float = 12.0
@export var token_color := Color(1.0, 0.82, 0.28, 0.98)
@export var completed_color := Color(0.35, 1.0, 0.48, 0.98)
@export var failed_color := Color(1.0, 0.25, 0.22, 0.98)
@export var token_background := Color(0.035, 0.045, 0.07, 0.88)

var queued_directions: Array[Vector2] = []
var _remaining: float = 0.0
var _duration: float = 1.0
var _completed: bool = false
var _failed: bool = false

func _ready() -> void:
	visible = false
	set_process(false)

func _draw() -> void:
	if queued_directions.is_empty():
		return
	var total_width := queued_directions.size() * token_size + (queued_directions.size() - 1) * token_gap
	var origin := Vector2((size.x - total_width) * 0.5, (size.y - token_size) * 0.5)
	for index in range(queued_directions.size()):
		_draw_token(origin + Vector2(index * (token_size + token_gap), 0.0), queued_directions[index])

func _draw_token(point: Vector2, direction: Vector2) -> void:
	var rect := Rect2(point, Vector2.ONE * token_size)
	var color := failed_color if _failed else (completed_color if _completed else token_color)
	draw_style_box(_token_style(color), rect)
	var center := rect.get_center()
	var heading := direction.normalized()
	var side := heading.orthogonal()
	var start := center - heading * token_size * 0.22
	var finish := center + heading * token_size * 0.18
	draw_line(start, finish, color, 6.0, true)
	draw_colored_polygon(PackedVector2Array([
		finish + heading * token_size * 0.14,
		finish - heading * token_size * 0.08 + side * token_size * 0.11,
		finish - heading * token_size * 0.08 - side * token_size * 0.11,
	]), color)
	var progress := clampf(_remaining / _duration, 0.0, 1.0)
	draw_arc(center, token_size * 0.39, -PI / 2.0, -PI / 2.0 + TAU * progress, 36, color, 3.0, true)

func _token_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = token_background
	style.border_color = Color(color, 0.65)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style

func show_queued_stroke(direction: Vector2, duration: float) -> void:
	queued_directions = [direction.normalized()]
	_completed = false
	_failed = false
	_duration = maxf(duration, 0.001)
	_remaining = _duration
	visible = true
	set_process(true)
	queue_redraw()

func add_queued_stroke(direction: Vector2, duration: float, _marker_position: Vector2 = Vector2.ZERO) -> void:
	queued_directions.append(direction.normalized())
	_completed = false
	_failed = false
	_duration = maxf(duration, 0.001)
	_remaining = _duration
	visible = true
	set_process(true)
	queue_redraw()

func complete_queued_gesture(direction: Vector2, duration: float) -> void:
	add_queued_stroke(direction, duration)

func resolve_queued_gesture(success: bool) -> void:
	if queued_directions.is_empty() or _remaining <= 0.0:
		return
	_completed = success
	_failed = not success
	_remaining = _duration
	visible = true
	set_process(true)
	queue_redraw()

func clear_queued_stroke() -> void:
	queued_directions.clear()
	_completed = false
	_failed = false
	_remaining = 0.0
	visible = false
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining <= 0.0:
		clear_queued_stroke()
	else:
		queue_redraw()
