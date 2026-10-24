extends Node
@export var stun_duration: float = 0.25
@export var knockback_speed: float = 260.0
@export var deceleration: float = 1100.0
@export var flash_color := Color(1.0, 0.3, 0.3, 1.0)
@export var flash_duration: float = 0.22
var remaining: float = 0.0
var impulse := Vector2.ZERO
var _flash: Tween
@onready var _visual: CanvasItem = get_parent().get_node("Visual")
@onready var _original_color: Color = _visual.self_modulate

func apply(source: Vector2) -> void:
	var direction: Vector2 = get_parent().global_position - source
	if direction.is_zero_approx():
		direction = Vector2.DOWN
	impulse = direction.normalized() * knockback_speed
	remaining = stun_duration
	flash()
	var abilities = get_parent().get_node_or_null("Abilities")
	if abilities != null:
		abilities.interrupt()

func flash() -> void:
	if _flash != null and _flash.is_valid():
		_flash.kill()
	_visual.self_modulate = _original_color * flash_color
	_flash = create_tween()
	_flash.tween_property(_visual, "self_modulate", _original_color, flash_duration)

func is_stunned() -> bool:
	return remaining > 0.0

func resolve_velocity(base: Vector2, delta: float) -> Vector2:
	if not is_stunned():
		return base
	var result := impulse
	impulse = impulse.move_toward(Vector2.ZERO, deceleration * delta)
	remaining = maxf(0.0, remaining - delta)
	return result
