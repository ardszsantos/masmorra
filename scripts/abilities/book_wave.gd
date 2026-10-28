extends Node2D
## Spawned only at book contact: a local smash followed by a traveling wavefront.
const ENEMY_MASK: int = 10
const WALL_MASK: int = 1
@export_range(0.1, 1.0) var duration: float = 0.35
var actor: CharacterBody2D
var direction := Vector2.RIGHT
var reach: float = 150.0
var arc_degrees: float = 55.0
var damage: float = 22.0
var impact_damage: float = 55.0
var impact_radius: float = 48.0
var _elapsed: float = 0.0
var _previous_radius: float = 0.0
var _impact_pending: bool = true
var _hit: Array[int] = []
var _shape := CircleShape2D.new()
var _query := PhysicsShapeQueryParameters2D.new()

func _ready() -> void:
	_query.shape = _shape
	_query.collision_mask = ENEMY_MASK
	_query.exclude = [actor.get_rid()]

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		queue_free()
		return
	if _impact_pending:
		_impact_pending = false
		_damage_area(impact_radius, true)
	_elapsed = minf(duration, _elapsed + delta)
	var radius := reach * _elapsed / duration
	_damage_area(radius, false)
	_previous_radius = radius
	queue_redraw()
	if _elapsed >= duration:
		queue_free()

func _damage_area(radius: float, impact: bool) -> void:
	_shape.radius = radius
	_query.transform = Transform2D(0.0, global_position)
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(_query, 128):
		var target := result.collider as Node2D
		if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.has_method("take_damage"):
			continue
		if _hit.has(target.get_instance_id()):
			continue
		var offset := target.global_position - global_position
		if not impact and absf(direction.angle_to(offset)) > deg_to_rad(arc_degrees * 0.5):
			continue
		if not impact and offset.length() < _previous_radius - 24.0:
			continue
		var ray := PhysicsRayQueryParameters2D.create(global_position, target.global_position, WALL_MASK)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		_hit.append(target.get_instance_id())
		target.take_damage(impact_damage if impact else damage, global_position)

func _draw() -> void:
	var progress := _elapsed / duration
	var radius := maxf(1.0, reach * progress)
	var start := direction.angle() - deg_to_rad(arc_degrees * 0.5)
	var end := direction.angle() + deg_to_rad(arc_degrees * 0.5)
	var inner_radius := maxf(0.5, radius - 24.0)
	var points := PackedVector2Array()
	for index in range(25):
		points.append(Vector2.from_angle(lerpf(start, end, float(index) / 24.0)) * radius)
	for index in range(24, -1, -1):
		points.append(Vector2.from_angle(lerpf(start, end, float(index) / 24.0)) * inner_radius)
	draw_colored_polygon(points, Color(1.0, 0.85, 0.45, (1.0 - progress) * 0.23))
	draw_arc(Vector2.ZERO, radius, start, end, 32, Color(1.0, 0.9, 0.6, 1.0 - progress), 5.0, true)
	draw_arc(Vector2.ZERO, impact_radius * (0.5 + progress), 0.0, TAU, 32, Color(1, 0.86, 0.6, (1.0 - progress) * 0.8), 3.0, true)
	for index in range(8):
		var radial := Vector2.from_angle(TAU * float(index) / 8.0)
		draw_line(radial * impact_radius * 0.35, radial * impact_radius * (0.65 + progress * 0.3), Color(1, 0.86, 0.6, 1.0 - progress), 3.0)
