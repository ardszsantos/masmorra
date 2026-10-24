extends RefCounted

static func hit(body: CharacterBody2D, radius: float, damage: float, already_hit: Array, direction := Vector2.ZERO, arc: float = 360.0, damage_mask: int = 10) -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, body.global_position)
	query.collision_mask = damage_mask
	query.exclude = [body.get_rid()]
	for result in body.get_world_2d().direct_space_state.intersect_shape(query, 64):
		var target = result.collider
		if not target.has_method("take_damage") or already_hit.has(target.get_instance_id()):
			continue
		var offset: Vector2 = target.global_position - body.global_position
		if not direction.is_zero_approx() and absf(direction.angle_to(offset)) > deg_to_rad(arc * 0.5):
			continue
		var ray := PhysicsRayQueryParameters2D.create(body.global_position, target.global_position, 1)
		if not body.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		already_hit.append(target.get_instance_id())
		target.take_damage(damage, body.global_position)
