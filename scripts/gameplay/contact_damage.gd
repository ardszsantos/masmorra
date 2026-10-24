extends Node2D
## Nonblocking body contact, including the swept path of each rush step.
@export var damage: float = 10.0
@export_range(0.05, 5.0, 0.05) var interval: float = 0.6
var _remaining: float = 0.0
@onready var _body: CharacterBody2D = get_parent()
@onready var _collision: CollisionShape2D = $"../Collision"


func _physics_process(delta: float) -> void:
	if _body.has_method("is_frozen") and _body.is_frozen():
		return
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining > 0.0 or _body.get_node("Health").dead:
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _collision.shape
	query.transform = _collision.global_transform
	query.collision_mask = 4
	# Only a subpixel tolerance for bodies separated by the physics safe margin.
	query.margin = 0.1
	for result in _body.get_world_2d().direct_space_state.intersect_shape(query):
		try_hit(result.collider)

func sweep(start: Transform2D, motion: Vector2) -> void:
	if _body.has_method("is_frozen") and _body.is_frozen():
		return
	if not is_physics_processing() or _remaining > 0.0 or _body.get_node("Health").dead:
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _collision.shape
	query.transform = start
	query.collision_mask = 4
	query.margin = 0.1
	var space := _body.get_world_2d().direct_space_state
	# cast_motion ignores bodies already overlapping at the start.
	for result in space.intersect_shape(query):
		try_hit(result.collider)
	query.motion = motion
	var fractions := space.cast_motion(query)
	if fractions[0] < 1.0:
		query.transform.origin += motion * fractions[1]
	else:
		query.transform.origin += motion
	query.motion = Vector2.ZERO
	for result in space.intersect_shape(query):
		try_hit(result.collider)


func try_hit(body: Node) -> void:
	if _body.has_method("is_frozen") and _body.is_frozen():
		return
	if not is_physics_processing() or _remaining > 0.0 or _body.get_node("Health").dead:
		return
	if not body.is_in_group("player") or not body.has_method("take_damage"):
		return
	var ray := PhysicsRayQueryParameters2D.create(_body.global_position, body.global_position, 1)
	if not _body.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		return
	_remaining = interval
	body.take_damage(damage, _body.global_position, true)
