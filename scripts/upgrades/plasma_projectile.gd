extends Node2D
## Fixed trajectory. The query sweeps the entire displacement each frame.

@export_range(1.0, 2000.0, 1.0) var speed: float = 520.0
@export_range(1.0, 500.0, 1.0) var damage: float = 18.0
@export_range(0.1, 10.0, 0.1) var lifetime: float = 2.5
@export var color := Color(0.25, 0.9, 1.0, 1.0)
@export_flags_2d_physics var collision_mask: int = 11

var _direction := Vector2.RIGHT
var _source: CharacterBody2D
var upgrade_owner: Node
const STAGES = [
	preload("res://assets/sprites/item-upgrades/lazer-gun/lazer-dot-stage.png"),
	preload("res://assets/sprites/item-upgrades/lazer-gun/lazer-short-stage.png"),
	preload("res://assets/sprites/item-upgrades/lazer-gun/lazer-medium-stage.png"),
	preload("res://assets/sprites/item-upgrades/lazer-gun/lazer-long-stage.png"),
]
@export var formation_time: float = 0.09
@export var projectile_width: float = 10.0
@export_range(0.0, 2000.0, 10.0) var maximum_distance: float = 0.0
var visual_scale: float = 1.0
var _visual_age: float = 0.0
var _distance_traveled: float = 0.0

func _process(delta: float) -> void:
	_visual_age += delta
	queue_redraw()


func _ready() -> void:
	top_level = true
	add_to_group("upgrade_effects")


func launch(origin: Vector2, direction: Vector2, source: CharacterBody2D) -> void:
	global_position = origin
	_direction = direction.normalized()
	global_rotation = _direction.angle()
	_source = source
	_distance_traveled = 0.0


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if not is_instance_valid(_source) or _source.get_node("Health").dead:
		queue_free()
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var travel := speed * delta
	if maximum_distance > 0.0:
		travel = minf(travel, maxf(0.0, maximum_distance - _distance_traveled))
	var finish := global_position + _direction * travel
	var query := PhysicsRayQueryParameters2D.create(global_position, finish, collision_mask)
	query.exclude = [_source.get_rid()]
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target := hit.collider as Node2D
		global_position = hit.position
		if target != null and target.is_in_group("enemies") and target.has_method("take_damage"):
			target.take_damage(damage, _source.global_position)
		queue_free()
		return
	global_position = finish
	_distance_traveled += travel
	if maximum_distance > 0.0 and _distance_traveled >= maximum_distance:
		queue_free()


func _draw() -> void:
	var stage := mini(3, int(_visual_age / maxf(0.001, formation_time) * 4.0))
	var texture: Texture2D = STAGES[stage]
	var dimensions := texture.get_size() * projectile_width * visual_scale / texture.get_width()
	# The artwork points upward; the local trajectory points right.
	draw_set_transform(Vector2.ZERO, PI * 0.5)
	draw_texture_rect(texture, Rect2(-dimensions * 0.5, dimensions), false)
	draw_set_transform(Vector2.ZERO)
