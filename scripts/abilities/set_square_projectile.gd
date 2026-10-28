extends CharacterBody2D
## Steer through an arc, slide around walls, and retain a clear route home.
const Flight = preload("res://scripts/abilities/set_square_flight.gd")
const Health = preload("res://scripts/gameplay/health.gd")
const ENEMY_MASK: int = 10
const WALL_MASK: int = 1
@export var hit_radius: float = 25.0
@export var spin_speed: float = 15.0
@export_range(0.15, 0.8) var curve_width_ratio: float = 0.35
@export_range(100.0, 600.0) var tracking_radius: float = 280.0
@export_range(30.0, 85.0) var tracking_cone_half_angle: float = 75.0
@export_range(1.0, 15.0) var steering_speed: float = 8.0
@export_range(0.05, 0.5) var target_refresh_interval: float = 0.12
var actor: CharacterBody2D
var direction := Vector2.RIGHT
var damage: float = 28.0
var throw_distance: float = 360.0
var outward_speed: float = 650.0
var return_speed: float = 900.0
var _launch_origin := Vector2.ZERO
var _heading := Vector2.RIGHT
var _curve_side: float = 1.0
var _sweep_time: float = 0.0
var _sweep_duration: float = 1.0
var _returning: bool = false
var _target: Node2D
var _target_refresh: float = 0.0
var _hit: Array[int] = []
var _shape := CapsuleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()
var _target_shape := CircleShape2D.new()
var _target_query := PhysicsShapeQueryParameters2D.new()
var _breadcrumbs := PackedVector2Array()
var _owner_trail := PackedVector2Array()
var _wall_tangent := Vector2.ZERO
var _last_normal := Vector2.ZERO
var _record_return_path: bool = false
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _trail: Line2D = $Trail

func _ready() -> void:
	_launch_origin = global_position
	_heading = direction
	_sweep_duration = maxf(0.4, throw_distance * 2.4 / outward_speed)
	_breadcrumbs.append(global_position)
	_owner_trail.append(actor.global_position)
	_shape.radius = hit_radius
	_query.shape = _shape
	_query.collision_mask = ENEMY_MASK
	_query.exclude = [actor.get_rid()]
	_target_shape.radius = tracking_radius
	_target_query.shape = _target_shape
	_target_query.collision_mask = ENEMY_MASK
	# Prefer the side with more room without changing the launch heading.
	var side := direction.orthogonal()
	_curve_side = 1.0 if _free_distance(global_position, direction + side, throw_distance) >= _free_distance(global_position, direction - side, throw_distance) else -1.0
	_trail.top_level = true
	_trail.global_position = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		queue_free()
		return
	_sprite.rotation += delta * spin_speed
	_record_owner_path()
	if _returning:
		_return_step(delta)
	else:
		_outward_step(delta)
	_trail.add_point(global_position)
	while _trail.get_point_count() > 12:
		_trail.remove_point(0)

func _outward_step(delta: float) -> void:
	_sweep_time += delta
	var progress := clampf(_sweep_time / _sweep_duration, 0.0, 1.0)
	var desired := Flight.tangent(progress, direction, throw_distance, throw_distance * curve_width_ratio, _curve_side)
	_target_refresh -= delta
	if _target_refresh <= 0.0:
		_target_refresh = target_refresh_interval
		_target = _find_target()
	if _target_alive(_target) and not _hit.has(_target.get_instance_id()):
		var toward := (_target.global_position - global_position).normalized()
		if toward.dot(_heading) > -0.15 and _clear_segment(global_position, _target.global_position):
			# Aim assistance fades before the turnaround to preserve the curve.
			var attraction := 0.85 * (1.0 - smoothstep(0.55, 0.9, progress))
			desired = desired.lerp(toward, attraction).normalized()
	_heading = Vector2.from_angle(rotate_toward(_heading.angle(), desired.angle(), steering_speed * delta))
	_move_along_walls(_heading * outward_speed * delta)
	if progress >= 1.0:
		_returning = true
		_target = null
		_hit.clear()

func _return_step(delta: float) -> void:
	var destination := actor.global_position
	var direct := _route_clear(global_position, destination)
	if not direct:
		# Retrace actual collision-free movement instead of crossing the wall.
		while not _breadcrumbs.is_empty() and global_position.distance_to(_breadcrumbs[-1]) < 2.0:
			_breadcrumbs.resize(_breadcrumbs.size() - 1)
		if not _breadcrumbs.is_empty():
			destination = _breadcrumbs[-1]
		else:
			while _owner_trail.size() > 1 and global_position.distance_to(_owner_trail[0]) < 2.0:
				_owner_trail.remove_at(0)
			if not _owner_trail.is_empty():
				destination = _owner_trail[0]
	var offset := destination - global_position
	var desired := offset.normalized()
	if direct:
		_heading = Vector2.from_angle(rotate_toward(_heading.angle(), desired.angle(), steering_speed * delta))
	else:
		_heading = desired
	if offset.length() < hit_radius * 2.0:
		_heading = desired
	var distance := minf(return_speed * delta, offset.length())
	if direct:
		var predicted := global_position + _heading * distance
		if not _route_clear(global_position, predicted) or not _route_clear(predicted, destination):
			_heading = desired
	_record_return_path = direct
	_move_along_walls(_heading * distance)
	if global_position.distance_to(actor.global_position) <= hit_radius and _clear_segment(global_position, actor.global_position):
		queue_free()

func _move_along_walls(motion: Vector2) -> void:
	var remaining := motion
	for attempt in range(4):
		if remaining.length_squared() < 0.01:
			break
		var origin := global_position
		var collision := move_and_collide(remaining, false, 0.5)
		_damage_segment(origin, global_position)
		if (not _returning or _record_return_path) and (_breadcrumbs.is_empty() or global_position.distance_to(_breadcrumbs[-1]) > 1.0):
			_breadcrumbs.append(global_position)
		if collision == null:
			_last_normal = Vector2.ZERO
			break
		var normal := collision.get_normal()
		var tangent := normal.orthogonal()
		if _last_normal.dot(normal) > 0.9:
			tangent = _wall_tangent
		else:
			var positive := _free_distance(global_position, tangent, 64.0)
			var negative := _free_distance(global_position, -tangent, 64.0)
			if negative > positive + 8.0 or (absf(negative - positive) <= 8.0 and tangent.dot(_heading) < 0.0):
				tangent = -tangent
		_wall_tangent = tangent
		_last_normal = normal
		remaining = tangent * collision.get_remainder().length()
		_heading = tangent

func _record_owner_path() -> void:
	if _owner_trail.is_empty() or _owner_trail[-1].distance_to(actor.global_position) >= 8.0:
		_owner_trail.append(actor.global_position)

func _find_target() -> Node2D:
	_target_query.transform = Transform2D(0.0, global_position)
	var best: Node2D
	var best_score: float = INF
	var threshold := cos(deg_to_rad(tracking_cone_half_angle))
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(_target_query, 64):
		var candidate := result.collider as Node2D
		if not _target_alive(candidate) or _hit.has(candidate.get_instance_id()):
			continue
		var launch_offset := candidate.global_position - _launch_origin
		var alignment := launch_offset.normalized().dot(direction)
		if alignment < threshold or not _clear_segment(global_position, candidate.global_position):
			continue
		var score := global_position.distance_to(candidate.global_position) + (1.0 - alignment) * tracking_radius
		if score < best_score:
			best = candidate
			best_score = score
	return best

func _target_alive(target: Node2D) -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_inside_tree():
		return false
	var health := target.get_node_or_null("Health") as Health
	return health != null and not health.dead

func _clear_segment(origin: Vector2, destination: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(origin, destination, WALL_MASK)
	ray.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _route_clear(origin: Vector2, destination: Vector2) -> bool:
	var from := global_transform
	from.origin = origin
	return not test_move(from, destination - origin, null, 0.5)

func _free_distance(origin: Vector2, heading: Vector2, distance: float) -> float:
	var ray := PhysicsRayQueryParameters2D.create(origin, origin + heading.normalized() * distance, WALL_MASK)
	ray.hit_from_inside = true
	var wall := get_world_2d().direct_space_state.intersect_ray(ray)
	if wall.is_empty():
		return distance
	var contact: Vector2 = wall.position
	return origin.distance_to(contact)

func _damage_segment(origin: Vector2, destination: Vector2) -> void:
	var segment := destination - origin
	_shape.height = segment.length() + hit_radius * 2.0
	_query.transform = Transform2D(segment.angle() - PI * 0.5, (origin + destination) * 0.5)
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(_query, 128):
		var target := result.collider as Node2D
		if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.has_method("take_damage"):
			continue
		if _hit.has(target.get_instance_id()):
			continue
		var ray := PhysicsRayQueryParameters2D.create(origin, target.global_position, WALL_MASK)
		ray.hit_from_inside = true
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		_hit.append(target.get_instance_id())
		target.take_damage(damage, origin)
