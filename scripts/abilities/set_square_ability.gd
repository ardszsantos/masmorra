extends "res://scripts/abilities/player_ability.gd"

const Projectile = preload("res://scripts/abilities/set_square_projectile.gd")
const ProjectileScene = preload("res://scenes/abilities/set_square_projectile.tscn")
@export var damage: float = 28.0
@export_range(100.0, 800.0) var throw_distance: float = 360.0
@export_range(100.0, 1600.0) var outward_speed: float = 650.0
@export_range(400.0, 2000.0) var return_speed: float = 900.0
var _projectile: Projectile
@onready var _actor: CharacterBody2D = get_parent().get_parent() as CharacterBody2D

func try_activate(direction: Vector2) -> bool:
	if active or is_instance_valid(_projectile) or direction.is_zero_approx():
		return false
	_projectile = ProjectileScene.instantiate() as Projectile
	_projectile.actor = _actor
	_projectile.direction = direction.normalized()
	_projectile.damage = damage
	_projectile.throw_distance = throw_distance
	_projectile.outward_speed = outward_speed
	_projectile.return_speed = return_speed
	_projectile.tree_exiting.connect(_on_returned, CONNECT_ONE_SHOT)
	_projectile.position = _actor.position
	_actor.get_parent().add_child(_projectile)
	active = true
	return true

func _on_returned() -> void:
	_projectile = null
	active = false

func get_activation_failure(_direction: Vector2) -> StringName:
	return &"returning" if active else &"unavailable"

func cancel() -> void:
	super.cancel()
	if is_instance_valid(_projectile):
		_projectile.tree_exiting.disconnect(_on_returned)
		_projectile.queue_free()
	_projectile = null

func _exit_tree() -> void:
	cancel()
