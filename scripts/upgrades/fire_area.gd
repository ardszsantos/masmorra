extends Node2D
## Stationary patch or player-following ring; damage is limited to the fire area.

const Targets = preload("res://scripts/upgrades/upgrade_targets.gd")
const FLAME = preload("res://assets/sprites/item-upgrades/fire-ring/fire-ring-barrier-sprites.png")
@export var flame_size: float = 42.0
@export var orbit_speed: float = 0.3

@export var radius: float = 24.0
@export var inner_radius: float = 0.0
@export var damage: float = 6.0
@export var tick_interval: float = 0.3
@export var duration: float = 2.0
@export var follows_actor: bool = false
@export_range(0.0, 2.0, 0.05) var formation_duration: float = 0.0
@export var burn_duration: float = 3.0
@export var burn_damage_per_second: float = 4.0

var actor: CharacterBody2D
var upgrade_owner: Node
var _tick: float = 0.0
var _age: float = 0.0


func _ready() -> void:
	top_level = true
	z_index = 1
	add_to_group("upgrade_effects")


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if not is_instance_valid(actor) or actor.get_node("Health").dead:
		queue_free()
		return
	if follows_actor:
		global_position = actor.global_position
	_age += delta
	if _age >= duration:
		queue_free()
		return
	_tick -= delta
	var damage_tick := _tick <= 0.0
	if damage_tick:
		_tick = maxf(0.05, tick_interval)
	for enemy in Targets.touching_ring(self, inner_radius, radius):
		if inner_radius > 0.0 and _formation_progress() < 1.0:
			var angle := fposmod((enemy.global_position - global_position).angle() + PI * 0.5 - _age * orbit_speed, TAU)
			if angle > TAU * _formation_progress():
				continue
		if enemy.has_method("apply_burn"):
			enemy.apply_burn(burn_duration, burn_damage_per_second, actor)
		if damage_tick:
			enemy.take_damage(damage, global_position)
			# Killing the last enemy may end the encounter and clear all effects.
			if is_queued_for_deletion():
				return
	queue_redraw()


func _formation_progress() -> float:
	return clampf(_age / formation_duration, 0.0, 1.0) if formation_duration > 0.0 else 1.0


func _draw() -> void:
	var fade := clampf((duration - _age) / 0.4, 0.0, 1.0)
	var orange := Color(1.0, 0.3, 0.05, 0.25 * fade)
	if inner_radius > 0.0:
		var width := maxf(1.0, radius - inner_radius)
		var middle := (radius + inner_radius) * 0.5
		var sweep := TAU * _formation_progress()
		if sweep > 0.0:
			draw_arc(Vector2.ZERO, middle, -PI * 0.5 + _age * orbit_speed, -PI * 0.5 + _age * orbit_speed + sweep, 64, orange, width, true)
		var count := maxi(8, ceili(TAU * middle / maxf(12.0, flame_size * 0.65)))
		for index in range(count):
			var fraction := float(index) / float(count)
			var flame_age := _age - formation_duration * fraction
			if flame_age <= 0.0 and formation_duration > 0.0:
				continue
			var reveal := smoothstep(0.0, 0.08, flame_age) if formation_duration > 0.0 else 1.0
			var angle := -PI * 0.5 + TAU * fraction + _age * orbit_speed
			_draw_flame(Vector2.from_angle(angle) * middle, float(index), fade * reveal)
	else:
		draw_circle(Vector2.ZERO, radius, orange)
		_draw_flame(Vector2.ZERO, 0.0, fade)


func _draw_flame(center: Vector2, phase: float, fade: float) -> void:
	var pulse := 1.0 + 0.08 * sin(_age * 11.0 + phase * 1.7)
	var dimensions := FLAME.get_size()
	dimensions *= flame_size * pulse / maxf(dimensions.x, dimensions.y)
	draw_set_transform(center, 0.08 * sin(_age * 7.0 + phase))
	draw_texture_rect(FLAME, Rect2(-dimensions * 0.5, dimensions), false, Color(1, 1, 1, fade))
	draw_set_transform(Vector2.ZERO)
