extends Node
## Base contract for an equipped action. The motor applies its velocity override.

@export var ability_id: StringName
@export var trigger_id: StringName
@export var sustained: bool = false
@export var overrides_movement: bool = true
@export var blocks_other_actions: bool = true
@export var stamina_cost: float = 0.0
@export var stamina_per_second: float = 0.0
var active: bool = false

func update_input(_value: float) -> void:
	pass


func try_activate(_direction: Vector2) -> bool:
	return false


func get_activation_failure(_direction: Vector2) -> StringName:
	return &"unavailable"


func step(_delta: float) -> void:
	pass


func movement_velocity(_delta: float) -> Vector2:
	return Vector2.ZERO


func cancel() -> void:
	active = false
