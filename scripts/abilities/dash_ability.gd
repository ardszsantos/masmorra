extends "res://scripts/abilities/player_ability.gd"

@export_range(1.0, 2000.0) var distance: float = 200.0
@export_range(0.01, 1.0) var duration: float = 0.16
@export_range(0.0, 5.0) var cooldown: float = 0.45
@export var dash_tint := Color(1.0, 0.9, 0.45, 1.0)
var _protected: bool = false
var _original_modulate := Color.WHITE
@onready var _health = get_parent().get_parent().get_node("Health")
@onready var _visual: CanvasItem = get_parent().get_parent().get_node("Visual")
var _direction := Vector2.ZERO
var _remaining: float = 0.0
var _cooldown_remaining: float = 0.0
@export var damage: float = 40.0
@export var hit_radius: float = 48.0
var _hit: Array = []


func try_activate(direction: Vector2) -> bool:
	if active or _cooldown_remaining > 0.0 or direction.is_zero_approx():
		return false
	_direction = direction.normalized()
	_remaining = duration
	_cooldown_remaining = cooldown
	active = true
	_health.set_damage_blocked(self, true)
	_original_modulate = _visual.modulate
	_visual.modulate = _original_modulate * dash_tint
	_protected = true
	_hit.clear()
	return true


func movement_velocity(delta: float) -> Vector2:
	# Scale the last physics step so distance is independent of the tick rate.
	return _direction * (distance / duration) * minf(1.0, _remaining / delta)


func step(delta: float) -> void:
	if active:
		preload("res://scripts/gameplay/damage_query.gd").hit(get_parent().get_parent(), hit_radius, damage, _hit)
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	_remaining = maxf(0.0, _remaining - delta)
	if active and _remaining <= 0.0:
		cancel()


func cancel() -> void:
	super.cancel()
	_remaining = 0.0
	_clear_protection()


func _clear_protection() -> void:
	if not _protected:
		return
	_protected = false
	if is_instance_valid(_health):
		_health.set_damage_blocked(self, false)
	if is_instance_valid(_visual):
		_visual.modulate = _original_modulate


func _exit_tree() -> void:
	_clear_protection()
