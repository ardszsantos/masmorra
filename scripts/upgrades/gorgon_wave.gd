extends Node2D
## A committed cone wave; walls block both its outline and its freeze effect.

const Targets = preload("res://scripts/upgrades/upgrade_targets.gd")
const OUTLINE_SEGMENTS: int = 24

var actor: CharacterBody2D
var upgrade_owner: Node
var heading := Vector2.RIGHT
var radius: float = 380.0
var arc_degrees: float = 80.0
var duration: float = 0.45
var wave_width: float = 40.0
var freeze_duration: float = 2.5
var target_limit: int = 2
var _age: float = 0.0
var _previous_radius: float = 0.0
var _hit_ids: Dictionary = {}
var _outer_points := PackedVector2Array()
var _inner_points := PackedVector2Array()


func _ready() -> void:
	top_level = true
	z_index = 2
	add_to_group("upgrade_effects")


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if not is_instance_valid(actor) or actor.get_node("Health").dead:
		queue_free()
		return
	_age += delta
	var front := radius * clampf(_age / maxf(0.01, duration), 0.0, 1.0)
	var swept_inner := maxf(0.0, _previous_radius - wave_width)
	for enemy in Targets.visible_enemies(self, radius):
		if _hit_ids.size() >= target_limit:
			break
		if _hit_ids.has(enemy.get_instance_id()) or not enemy.has_method("apply_freeze"):
			continue
		var offset := enemy.global_position - global_position
		var distance := offset.length()
		var body_radius := Targets.body_radius(enemy)
		if distance - body_radius > front or distance + body_radius < swept_inner:
			continue
		var angular_margin := asin(clampf(body_radius / maxf(1.0, distance), 0.0, 1.0))
		if not offset.is_zero_approx() and absf(heading.angle_to(offset)) > deg_to_rad(arc_degrees * 0.5) + angular_margin:
			continue
		_hit_ids[enemy.get_instance_id()] = true
		enemy.apply_freeze(freeze_duration)
	_previous_radius = front
	_update_outline(front, maxf(0.0, front - wave_width))
	queue_redraw()
	if _age >= duration:
		queue_free()


func _update_outline(front: float, inner: float) -> void:
	_outer_points.clear()
	_inner_points.clear()
	var half_arc := deg_to_rad(arc_degrees * 0.5)
	for index in range(OUTLINE_SEGMENTS + 1):
		var angle := heading.angle() - half_arc + 2.0 * half_arc * float(index) / float(OUTLINE_SEGMENTS)
		var direction := Vector2.from_angle(angle)
		var query := PhysicsRayQueryParameters2D.create(global_position, global_position + direction * front, Targets.WALL_MASK)
		query.hit_from_inside = true
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		var distance: float = global_position.distance_to(hit.position) if not hit.is_empty() else front
		_outer_points.append(direction * distance)
		_inner_points.append(direction * minf(inner, distance))


func _draw() -> void:
	if _outer_points.size() < 2:
		return
	var fade := 1.0 - 0.5 * clampf(_age / maxf(0.01, duration), 0.0, 1.0)
	var fill := Color(0.4, 1.0, 0.75, 0.3 * fade)
	for index in range(_outer_points.size() - 1):
		_draw_wave_triangle(_inner_points[index], _outer_points[index], _outer_points[index + 1], fill)
		_draw_wave_triangle(_inner_points[index], _outer_points[index + 1], _inner_points[index + 1], fill)
	draw_polyline(_outer_points, Color(0.65, 1.0, 0.85, 0.9 * fade), 3.0, true)


func _draw_wave_triangle(first: Vector2, second: Vector2, third: Vector2, color: Color) -> void:
	if absf((second - first).cross(third - first)) > 0.01:
		draw_colored_polygon(PackedVector2Array([first, second, third]), color)
