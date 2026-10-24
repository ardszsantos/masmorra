extends "res://scripts/upgrades/passive_upgrade.gd"

func details() -> String:
	var rate := charge_per_second * (1.0 + 0.15 * (level - 1))
	return "Carrega sozinho, mesmo em movimento. Com carga cheia e um alvo próximo e visível, lança todos os projéteis em asterisco. Sem alvo, guarda a carga.\n\nAtual: %d projéteis, %.1f de dano por projétil e %.2f s para carregar.\nPor nível: +%d projéteis (máximo %d), +2 de dano por projétil e +15%% da velocidade base de carga." % [capacity(), damage + 2.0 * (level - 1), float(capacity()) / maxf(0.001, rate), extra_per_level, maximum_capacity]

const Targets = preload("res://scripts/upgrades/upgrade_targets.gd")
const Shot = preload("res://scripts/upgrades/shuriken_projectile.gd")

@export_range(4, 20, 1) var base_capacity: int = 8
@export_range(0, 4, 1) var extra_per_level: int = 2
@export_range(4, 40, 1) var maximum_capacity: int = 20
@export var charge_per_second: float = 2.0
@export var detection_radius: float = 450.0
@export var projectile_speed: float = 440.0
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
		var target := Targets.nearest_visible(actor, detection_radius)
		if target != null:
			_release(target.global_position)
	queue_redraw()


func _release(target_position: Vector2) -> void:
	var start_angle := (target_position - actor.global_position).angle()
	var count := capacity()
	for index in range(count):
		var shot := Shot.new()
		shot.upgrade_owner = self
		shot.speed = projectile_speed
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
