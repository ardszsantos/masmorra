extends RefCounted

const Health = preload("res://scripts/gameplay/health.gd")
const WALL_MASK: int = 1
const ENEMY_MASK: int = 10
const BODY_OUTLINE_SAMPLES: int = 32


static func alive(enemy: Node2D) -> bool:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.is_inside_tree():
		return false
	var health := enemy.get_node_or_null("Health") as Health
	return health != null and not health.dead


static func clear_path(source: Node2D, destination: Vector2) -> bool:
	return clear_path_from(source, source.global_position, destination)


static func clear_path_from(source: Node2D, origin: Vector2, destination: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(origin, destination, WALL_MASK)
	query.hit_from_inside = true
	return source.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


static func nearest_visible(source: Node2D, radius: float, require_clear_path: bool = true, observer: Node2D = null) -> Node2D:
	var candidates := visible_enemies(source, radius, require_clear_path, observer)
	return candidates[0] if not candidates.is_empty() else null


static func visible_enemies(source: Node2D, radius: float, require_clear_path: bool = true, observer: Node2D = null) -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	var screen := source.get_viewport_rect()
	for node in source.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if not alive(enemy) or not enemy.is_visible_in_tree():
			continue
		if not screen.has_point(enemy.get_global_transform_with_canvas().origin):
			continue
		if source.global_position.distance_squared_to(enemy.global_position) > radius * radius:
			continue
		if require_clear_path and not clear_path(source, enemy.global_position):
			continue
		if is_instance_valid(observer) and not clear_path(observer, enemy.global_position):
			continue
		candidates.append(enemy)
	var origin := source.global_position
	candidates.sort_custom(func(left: Node2D, right: Node2D) -> bool:
		return origin.distance_squared_to(left.global_position) < origin.distance_squared_to(right.global_position))
	return candidates


static func body_radius(enemy: Node2D) -> float:
	var collision := enemy.get_node_or_null("Collision") as CollisionShape2D
	if collision == null or collision.shape == null or collision.disabled:
		return 0.0
	var half_size := collision.shape.get_rect().size * 0.5
	return maxf(half_size.x * collision.global_transform.x.length(), half_size.y * collision.global_transform.y.length())


static func touching_ring(source: Node2D, inner_radius: float, outer_radius: float) -> Array[Node2D]:
	var shape := CircleShape2D.new()
	shape.radius = outer_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, source.global_position)
	query.collision_mask = ENEMY_MASK
	var enemies: Array[Node2D] = []
	for hit in source.get_world_2d().direct_space_state.intersect_shape(query, 128):
		var enemy := hit.collider as Node2D
		if not alive(enemy) or enemies.has(enemy):
			continue
		# The outer edge uses the actual body overlap, including scaled shapes.
		if not _reaches_ring(enemy, source.global_position, inner_radius):
			continue
		if clear_path(source, enemy.global_position):
			enemies.append(enemy)
	return enemies


static func _reaches_ring(enemy: Node2D, origin: Vector2, inner_radius: float) -> bool:
	if inner_radius <= 0.0:
		return true
	var collision := enemy.get_node_or_null("Collision") as CollisionShape2D
	if collision == null or collision.shape == null:
		return false
	var inner_squared := inner_radius * inner_radius
	if collision.global_position.distance_squared_to(origin) >= inner_squared:
		return true
	if collision.shape is CircleShape2D:
		var circle := collision.shape as CircleShape2D
		# Sample the scaled outline; a wide body is not equally tall.
		for index in range(BODY_OUTLINE_SAMPLES):
			var local_point := Vector2.from_angle(TAU * float(index) / float(BODY_OUTLINE_SAMPLES)) * circle.radius
			if (collision.global_transform * local_point).distance_squared_to(origin) >= inner_squared:
				return true
		return false
	var bounds := collision.shape.get_rect()
	for local_point: Vector2 in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		if (collision.global_transform * local_point).distance_squared_to(origin) >= inner_squared:
			return true
	return false
