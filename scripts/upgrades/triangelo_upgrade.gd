extends "res://scripts/upgrades/passive_upgrade.gd"

func details() -> String:
	return "Um aliado acompanha você, se arremessa contra um inimigo próximo e retorna. A investida mantém a direção escolhida no início.\n\nAtual: %.1f de dano; recarga %.2f s. Ele também precisa retornar antes de atacar novamente.\nPor nível: +%.1f de dano e +12%% da frequência base, até a recarga mínima de 0,65 s." % [damage + damage_per_level * (level - 1), maxf(0.65, cooldown / (1.0 + 0.12 * (level - 1))), damage_per_level]

const Targets = preload("res://scripts/upgrades/upgrade_targets.gd")
enum Phase { FOLLOW, RUSH, RETURN }

@export var follow_offset := Vector2(-46.0, 32.0)
@export var follow_speed: float = 420.0
@export var attack_range: float = 320.0
@export var rush_speed: float = 650.0
@export var rush_duration: float = 0.6
@export var cooldown: float = 2.4
@export var damage: float = 24.0
@export var damage_per_level: float = 5.0

var _phase: Phase = Phase.FOLLOW
var _cooldown: float = 0.0
var _rush_time: float = 0.0
var _heading := Vector2.RIGHT


func _ready() -> void:
	top_level = true
	z_index = 3


func set_combat_context(room: Node2D, active: bool) -> void:
	super.set_combat_context(room, active)
	_phase = Phase.FOLLOW
	visible = is_instance_valid(room)
	if is_instance_valid(actor):
		global_position = actor.global_position + follow_offset


func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(combat_room):
		return
	var home := actor.global_position + follow_offset
	if not combat_active:
		global_position = global_position.move_toward(home, follow_speed * delta)
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if _phase == Phase.RUSH:
		_rush(delta)
		return
	global_position = global_position.move_toward(home, follow_speed * delta)
	global_rotation = rotate_toward(global_rotation, 0.0, delta * 8.0)
	if _phase == Phase.RETURN:
		if global_position.distance_to(home) < 8.0:
			_phase = Phase.FOLLOW
		return
	if _cooldown > 0.0:
		return
	var target := Targets.nearest_visible(self, attack_range)
	if target == null:
		return
	_heading = (target.global_position - global_position).normalized()
	global_rotation = _heading.angle()
	_rush_time = rush_duration
	_phase = Phase.RUSH
	_cooldown = maxf(0.65, cooldown / (1.0 + 0.12 * (level - 1)))


func _rush(delta: float) -> void:
	var finish := global_position + _heading * rush_speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, finish, 11)
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		_phase = Phase.RETURN
		var enemy := hit.collider as Node2D
		if enemy != null and enemy.is_in_group("enemies") and Targets.alive(enemy):
			enemy.take_damage(damage + damage_per_level * (level - 1), global_position)
		return
	global_position = finish
	_rush_time -= delta
	if _rush_time <= 0.0:
		_phase = Phase.RETURN


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(19, 0), Vector2(-12, -14), Vector2(-12, 14)]), Color(0.65, 1.0, 0.35))
	draw_circle(Vector2(1, -4), 2.0, Color(0.1, 0.15, 0.05))
	draw_circle(Vector2(1, 4), 2.0, Color(0.1, 0.15, 0.05))
