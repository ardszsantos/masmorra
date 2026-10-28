extends "res://scripts/abilities/player_ability.gd"
## Damage receivers implement take_damage(amount). Collision mask selects targets.
@export var ramp_speed: float = 3.0
@export var input_timeout: float = 0.35
@export var radius: float = 120.0
@export var turns_per_second: float = 2.5
@export var damage_per_tick: float = 40.0
@export var tick_interval: float = 0.2
@export_flags_2d_physics var damage_mask: int = 10
var _input_remaining: float = 0.0
var _strength: float = 0.0
var _target_strength: float = 0.0
var _angle: float = 0.0
var _tick_remaining: float = 0.0
var _sign: float = 1.0
var _original_rotation: float = 0.0
var _arc: Line2D
var _body: CharacterBody2D
var _sprite: Node2D

func _ready() -> void:
	_body = get_parent().get_parent()
	_sprite = _body.get_node("Visual")
	_arc = Line2D.new()
	_arc.width = 10.0
	_arc.default_color = Color(0.4, 0.9, 1.0, 0.8)
	add_child(_arc)
	_arc.hide()

func try_activate(direction: Vector2) -> bool:
	if active:
		return false
	active = true
	_input_remaining = input_timeout
	_strength = 0.0
	_angle = 0.0
	_tick_remaining = 0.0
	_sign = -1.0 if direction.x < 0.0 else 1.0
	_original_rotation = _sprite.rotation
	_arc.show()
	_update_visual()
	return true

func update_input(value: float) -> void:
	if is_zero_approx(value):
		cancel()
		return
	if not active:
		try_activate(Vector2(value, 0.0))
	_sign = signf(value)
	_target_strength = absf(value)
	_input_remaining = input_timeout

func step(delta: float) -> void:
	if not active:
		return
	_input_remaining -= delta
	if _input_remaining <= 0.0:
		cancel()
		return
	_strength = move_toward(_strength, _target_strength, ramp_speed * delta)
	_angle += delta * TAU * turns_per_second * _sign * _strength
	_tick_remaining -= delta
	while _tick_remaining <= 0.0:
		_damage_targets()
		_tick_remaining += maxf(0.01, tick_interval)
	_update_visual()
func _update_visual() -> void:
	var angle := _angle
	_arc.modulate.a = _strength
	_sprite.rotation = _original_rotation + angle
	_arc.global_position = _body.global_position
	var points := PackedVector2Array()
	for index in range(49):
		points.append(Vector2.from_angle(angle + float(index) / 48.0 * TAU * 0.85) * radius)
	_arc.points = points

func _damage_targets() -> void:
	var hit: Array = []
	preload("res://scripts/gameplay/damage_query.gd").hit(_body, radius, damage_per_tick, hit, Vector2.ZERO, 360.0, damage_mask)

func cancel() -> void:
	super.cancel()
	if is_instance_valid(_sprite):
		_sprite.rotation = _original_rotation
	if is_instance_valid(_arc):
		_arc.hide()

func _exit_tree() -> void:
	if active:
		cancel()


