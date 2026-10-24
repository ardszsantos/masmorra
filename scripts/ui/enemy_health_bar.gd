extends Node2D

@export var bar_size := Vector2(36.0, 4.0)
@export var fill_color := Color(0.85, 0.22, 0.2)
@export var background_color := Color(0.1, 0.07, 0.07, 0.85)
var _fraction: float = 1.0

func _ready() -> void:
	var health := get_parent().get_node("Health")
	health.changed.connect(_update_health)
	_update_health(health.current, health.maximum)

func _update_health(current: float, maximum: float) -> void:
	_fraction = clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	visible = current > 0.0
	queue_redraw()

func _draw() -> void:
	var area := Rect2(-bar_size * 0.5, bar_size)
	draw_rect(area.grow(1.0), Color(0.0, 0.0, 0.0, 0.8))
	draw_rect(area, background_color)
	draw_rect(Rect2(area.position, Vector2(bar_size.x * _fraction, bar_size.y)), fill_color)
