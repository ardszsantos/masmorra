extends Node2D
## The timer keeps running while movement and attacks are frozen.

@export var tint := Color(0.45, 0.9, 1.0, 0.65)
var remaining: float = 0.0


func _ready() -> void:
	get_parent().get_node("Health").died.connect(clear)
	visible = false


func apply(duration: float) -> void:
	if get_parent().get_node("Health").dead:
		return
	remaining = maxf(remaining, duration)
	visible = remaining > 0.0
	queue_redraw()


func active() -> bool:
	return remaining > 0.0


func clear() -> void:
	remaining = 0.0
	hide()


func _physics_process(delta: float) -> void:
	if remaining > 0.0:
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.0:
			hide()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 30.0, Color(tint, 0.2))
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 6, tint, 3.0, true)
	for index in range(3):
		var arm := Vector2.from_angle(float(index) * PI / 3.0) * 20.0
		draw_line(-arm, arm, tint, 2.0, true)
