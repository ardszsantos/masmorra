extends "res://scripts/upgrades/passive_upgrade.gd"

func details() -> String:
	var rate := charge_per_second * (1.0 + 0.15 * (level - 1))
	return "Carrega sozinho, mesmo em movimento. Com carga cheia e um alvo visível dentro do alcance útil, antecipa seu movimento e lança os projéteis em asterisco. Paredes ou uma trajetória longa demais impedem o disparo e preservam a carga.\n\nAtual: %d projéteis, %.1f de dano por projétil e %.2f s para carregar.\nPor nível: +%d projéteis (máximo %d), +2 de dano por projétil e +15%% da velocidade base de carga." % [capacity(), damage + 2.0 * (level - 1), float(capacity()) / maxf(0.001, rate), extra_per_level, maximum_capacity]

const Targets = preload("res://scripts/upgrades/upgrade_targets.gd")
const Shot = preload("res://scripts/upgrades/shuriken_projectile.gd")
const TRIGGER_RANGE_FRACTION: float = 0.8
const AIM_EPSILON: float = 0.001

@export_range(4, 20, 1) var base_capacity: int = 8
@export_range(0, 4, 1) var extra_per_level: int = 2
@export_range(4, 40, 1) var maximum_capacity: int = 20
@export var charge_per_second: float = 2.0
@export var detection_radius: float = 400.0
@export_range(100.0, 1500.0, 10.0) var projectile_range: float = 640.0
@export var projectile_speed: float = 700.0
@export var damage: float = 14.0

var _charge: float = 0.0
var _angle: float = 0.0


func capacity() -> int:
	return mini(maximum_capacity, base_capacity + extra_per_level * (level - 1))


func set_combat_context(room: Node2D, active: bool) -> void:
	super.set_combat_context(room, active)
	visible = is_instance_valid(room)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(combat_room):
		return
	if actor.get_node("Health").dead:
		return
	_charge = minf(float(capacity()), _charge + charge_per_second * (1.0 + 0.15 * (level - 1)) * delta)
	_angle += delta * 0.7
	if combat_active and _charge >= float(capacity()):
		var useful_range := minf(detection_radius, projectile_range * TRIGGER_RANGE_FRACTION)
		for target in Targets.visible_enemies(actor, useful_range):
			var heading := _intercept_heading(target)
			if not heading.is_zero_approx():
				_release(actor.global_position + heading)
				break
	queue_redraw()


func _intercept_heading(target: Node2D) -> Vector2:
	var offset := target.global_position - actor.global_position
	if offset.is_zero_approx():
		return Vector2.RIGHT
	var target_velocity := Vector2.ZERO
	if target is CharacterBody2D:
		target_velocity = (target as CharacterBody2D).velocity
	var a := target_velocity.length_squared() - projectile_speed * projectile_speed
	var b := 2.0 * offset.dot(target_velocity)
	var c := offset.length_squared()
	var intercept_time: float = INF
	if absf(a) < AIM_EPSILON:
		if absf(b) > AIM_EPSILON:
			intercept_time = -c / b
	else:
		var discriminant := b * b - 4.0 * a * c
		if discriminant < 0.0:
			return Vector2.ZERO
		var root := sqrt(discriminant)
		var first := (-b - root) / (2.0 * a)
		var second := (-b + root) / (2.0 * a)
		if first > 0.0:
			intercept_time = first
		if second > 0.0:
			intercept_time = minf(intercept_time, second)
	if intercept_time <= 0.0 or intercept_time > projectile_range / maxf(1.0, projectile_speed):
		return Vector2.ZERO
	var intercept := target.global_position + target_velocity * intercept_time
	if not Targets.clear_path(actor, intercept):
		return Vector2.ZERO
	return (intercept - actor.global_position).normalized()


func _release(target_position: Vector2) -> void:
	var start_angle := (target_position - actor.global_position).angle()
	var count := capacity()
	for index in range(count):
		var shot := Shot.new()
		shot.upgrade_owner = self
		shot.speed = projectile_speed
		shot.maximum_distance = projectile_range
		shot.lifetime = projectile_range / maxf(1.0, projectile_speed) + 0.1
		shot.damage = damage + 2.0 * (level - 1)
		shot.color = Color(0.85, 0.95, 1.0)
		shot.z_index = 3
		combat_room.add_child(shot)
		var heading := Vector2.from_angle(start_angle + TAU * float(index) / float(count))
		shot.launch(actor.global_position, heading, actor)
	_charge = 0.0


func _draw() -> void:
	for index in range(int(_charge)):
		var center := Vector2.from_angle(_angle + TAU * float(index) / float(capacity())) * 42.0
		draw_set_transform(center, _angle * 3.0)
		draw_texture_rect(Shot.TEXTURE, Rect2(-8, -8, 16, 16), false)
	draw_set_transform(Vector2.ZERO)
