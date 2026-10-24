extends Node2D
## Visual-only contraction shake, world-space telegraph and current-side trail.
@export var marker_color := Color(1.0, 0.65, 0.2, 0.95)
@export var trail_color := Color(1.0, 0.65, 0.2, 0.4)
@export_range(2.0, 40.0, 1.0) var marker_radius: float = 12.0
@export_range(1.0, 12.0, 0.5) var trail_width: float = 3.0
@export_group("Contraction shake")
@export_range(0.0, 4.0, 0.1) var shake_amount: float = 0.8
@export_range(1.0, 40.0, 1.0) var shake_frequency: float = 18.0
var _shake_time: float = 0.0
var _visual_rest_position := Vector2.ZERO
@onready var _visual: AnimatedSprite2D = $"../Visual"
var _destination := Vector2.ZERO
var _start := Vector2.ZERO
var _end := Vector2.ZERO
var _announced: bool = false
var _rushing: bool = false


func _ready() -> void:
	top_level = true
	global_transform = Transform2D.IDENTITY
	_visual_rest_position = _visual.position
	set_process(false)


func _process(delta: float) -> void:
	_shake_time += delta
	var wave := _shake_time * TAU * shake_frequency
	_visual.position = _visual_rest_position + Vector2(sin(wave), sin(wave * 1.3)) * shake_amount


func set_contracting(active: bool) -> void:
	_shake_time = 0.0
	_visual.position = _visual_rest_position
	set_process(active)


func announce(destination: Vector2) -> void:
	set_contracting(true)
	_destination = destination
	_announced = true
	_rushing = false
	queue_redraw()


func rush(start: Vector2, current: Vector2) -> void:
	_start = start
	_end = current
	_rushing = true
	queue_redraw()


func clear() -> void:
	set_contracting(false)
	_announced = false
	_rushing = false
	queue_redraw()


func _draw() -> void:
	if _rushing and not _start.is_equal_approx(_end):
		draw_line(_start, _end, trail_color, trail_width, true)
	if _announced:
		draw_arc(_destination, marker_radius, 0.0, TAU, 24, marker_color, 2.0, true)
		draw_circle(_destination, 2.0, marker_color)
