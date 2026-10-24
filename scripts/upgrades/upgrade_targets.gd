extends RefCounted

const Health = preload("res://scripts/gameplay/health.gd")


static func alive(enemy: Node2D) -> bool:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.is_inside_tree():
		return false
	var health := enemy.get_node_or_null("Health") as Health
	return health != null and not health.dead


static func clear_path(source: Node2D, destination: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(source.global_position, destination, 1)
	return source.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


static func nearest_visible(source: Node2D, radius: float, require_clear_path: bool = true) -> Node2D:
	var nearest: Node2D
	var best: float = radius * radius
	var screen := source.get_viewport_rect()
	for node in source.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if not alive(enemy) or not enemy.is_visible_in_tree():
			continue
		if not screen.has_point(enemy.get_global_transform_with_canvas().origin):
			continue
		var distance := source.global_position.distance_squared_to(enemy.global_position)
		if distance > best:
			continue
		if require_clear_path and not clear_path(source, enemy.global_position):
			continue
		best = distance
		nearest = enemy
	return nearest
