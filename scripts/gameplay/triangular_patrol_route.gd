extends RefCounted
## Find a full-sized triangle first; route its checkpoints around walls if needed.

const Room = preload("res://scripts/gameplay/generated_room.gd")
const ROTATION_COUNT: int = 12
const MAX_SEARCH_ORIGINS: int = 32
const MINIMUM_SPAN_FRACTION: float = 0.75
const POINT_EPSILON: float = 0.5

var vertices := PackedVector2Array()
var circuit := PackedVector2Array()
var approach := PackedVector2Array()


func build(body: CharacterBody2D, room: Room, side: float, angle: float, clockwise: bool) -> bool:
	vertices.clear()
	circuit.clear()
	approach.clear()
	var origins := _search_origins(body.global_position, room, side)
	var turn_sign := 1.0 if clockwise else -1.0
	for origin in origins:
		for index in range(ROTATION_COUNT):
			var rotation := angle + TAU * float(index) / float(ROTATION_COUNT)
			var first := Vector2(side, 0.0).rotated(rotation)
			var second := Vector2(side * 0.5, side * sqrt(3.0) * 0.5 * turn_sign).rotated(rotation)
			var triangle := PackedVector2Array([origin, origin + first, origin + second])
			if not _triangle_clear(body, triangle):
				continue
			var entry := _path(body, room, body.global_position, origin)
			if entry.is_empty() and body.global_position.distance_to(origin) > POINT_EPSILON:
				continue
			vertices = triangle
			approach = entry
			circuit = PackedVector2Array([triangle[1], triangle[2], triangle[0]])
			return true
	return _build_navigated_circuit(body, room, side, angle, turn_sign)


func _search_origins(origin: Vector2, room: Room, side: float) -> Array[Vector2]:
	var result: Array[Vector2] = [origin]
	if not is_instance_valid(room):
		for index in range(ROTATION_COUNT):
			result.append(origin + Vector2.from_angle(TAU * float(index) / float(ROTATION_COUNT)) * side * 0.5)
		return result
	var points: Array[Vector2] = []
	var buckets: Dictionary = {}
	var spacing := side * 0.4
	for point in room.navigation_points():
		var bucket := Vector2i(floori(point.x / spacing), floori(point.y / spacing))
		if not buckets.has(bucket):
			buckets[bucket] = true
			points.append(point)
	points.sort_custom(func(left: Vector2, right: Vector2) -> bool:
		return origin.distance_squared_to(left) < origin.distance_squared_to(right))
	var near_count := mini(MAX_SEARCH_ORIGINS / 2, points.size())
	for index in range(near_count):
		result.append(points[index])
	var remaining := points.size() - near_count
	var far_count := mini(MAX_SEARCH_ORIGINS - near_count, remaining)
	for index in range(far_count):
		var sample := near_count + index * remaining / far_count
		result.append(points[sample])
	return result


func _triangle_clear(body: CharacterBody2D, triangle: PackedVector2Array) -> bool:
	for index in range(3):
		if not _position_clear(body, triangle[index]):
			return false
		if not _segment_clear(body, triangle[index], triangle[(index + 1) % 3]):
			return false
	return true


func _position_clear(body: CharacterBody2D, point: Vector2) -> bool:
	var collision := body.get_node("Collision") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.transform.origin += point - body.global_position
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	query.margin = body.safe_margin
	return body.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _segment_clear(body: CharacterBody2D, origin: Vector2, destination: Vector2) -> bool:
	var transform := body.global_transform
	transform.origin = origin
	return not body.test_move(transform, destination - origin, null, body.safe_margin, true)


func _path(body: CharacterBody2D, room: Room, origin: Vector2, destination: Vector2) -> PackedVector2Array:
	if origin.distance_to(destination) <= POINT_EPSILON:
		return PackedVector2Array()
	if _segment_clear(body, origin, destination):
		return PackedVector2Array([destination])
	if not is_instance_valid(room):
		return PackedVector2Array()
	var raw := room.navigation_path(origin, destination)
	var result := PackedVector2Array()
	var cursor := origin
	var next_index: int = 0
	# Skip grid points whenever the entire body can take a straight shortcut.
	while next_index < raw.size():
		var reachable: int = -1
		for index in range(raw.size() - 1, next_index - 1, -1):
			if _segment_clear(body, cursor, raw[index]):
				reachable = index
				break
		if reachable < 0:
			return PackedVector2Array()
		if cursor.distance_to(raw[reachable]) > POINT_EPSILON:
			result.append(raw[reachable])
		cursor = raw[reachable]
		next_index = reachable + 1
	return result


func _build_navigated_circuit(body: CharacterBody2D, room: Room, side: float, angle: float, turn_sign: float) -> bool:
	if not is_instance_valid(room):
		return false
	var candidates: Array[Vector2] = []
	for point in room.navigation_points():
		candidates.append(point)
	var origin := body.global_position
	var desired_second := origin + Vector2(side, 0.0).rotated(angle)
	candidates.sort_custom(func(left: Vector2, right: Vector2) -> bool:
		return desired_second.distance_squared_to(left) < desired_second.distance_squared_to(right))
	var second := Vector2.INF
	var outward := PackedVector2Array()
	for point in candidates:
		if point.distance_to(origin) < side * MINIMUM_SPAN_FRACTION:
			continue
		var path := _path(body, room, origin, point)
		if not path.is_empty():
			second = point
			outward = path
			break
	if not second.is_finite():
		# A spawn in the middle of a corridor may be close to both ends.
		# Join one end before choosing the other, preserving a useful patrol span.
		candidates.sort_custom(func(left: Vector2, right: Vector2) -> bool:
			return origin.distance_squared_to(left) > origin.distance_squared_to(right))
		for point in candidates:
			var entry := _path(body, room, origin, point)
			if entry.is_empty():
				continue
			origin = point
			approach = entry
			break
		for point in candidates:
			if point.distance_to(origin) < side * MINIMUM_SPAN_FRACTION:
				continue
			var path := _path(body, room, origin, point)
			if not path.is_empty():
				second = point
				outward = path
				break
		if not second.is_finite():
			approach.clear()
			return false
	var heading := (second - origin).normalized()
	var perpendicular := Vector2(-heading.y, heading.x)
	var desired_third := (origin + second) * 0.5 + perpendicular * side * sqrt(3.0) * 0.5 * turn_sign
	candidates.sort_custom(func(left: Vector2, right: Vector2) -> bool:
		return desired_third.distance_squared_to(left) < desired_third.distance_squared_to(right))
	for point in candidates:
		if point.distance_to(origin) < side * MINIMUM_SPAN_FRACTION or point.distance_to(second) < side * MINIMUM_SPAN_FRACTION:
			continue
		var next := _path(body, room, second, point)
		if next.is_empty():
			continue
		var home := _path(body, room, point, origin)
		if home.is_empty():
			continue
		vertices = PackedVector2Array([origin, second, point])
		circuit.append_array(outward)
		circuit.append_array(next)
		circuit.append_array(home)
		return true
	# A corridor cannot contain a broad triangle: cover its full useful span.
	# Three checkpoints still repeat, with wall-safe detours between them.
	var home := _path(body, room, second, origin)
	if home.is_empty():
		return false
	var checkpoint := _insert_midpoint(origin, outward)
	vertices = PackedVector2Array([origin, checkpoint, second])
	circuit.append_array(outward)
	circuit.append_array(home)
	return true


func _insert_midpoint(origin: Vector2, path: PackedVector2Array) -> Vector2:
	var length: float = 0.0
	var previous := origin
	for point in path:
		length += previous.distance_to(point)
		previous = point
	var remaining := length * 0.5
	previous = origin
	for index in range(path.size()):
		var distance := previous.distance_to(path[index])
		if remaining <= distance:
			var midpoint := previous.move_toward(path[index], remaining)
			path.insert(index, midpoint)
			return midpoint
		remaining -= distance
		previous = path[index]
	return origin
