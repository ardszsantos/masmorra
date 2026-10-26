extends "res://scripts/upgrades/passive_upgrade.gd"

func details() -> String:
	return "Dispara automaticamente no inimigo visível mais próximo com linha de tiro livre. Paredes bloqueiam a seleção do alvo, além de bloquear o projétil. O tiro segue em linha reta, sem perseguir o alvo.\n\nIntervalo atual: %.2f s.\nPor nível: +%.0f%% da cadência base (bônus aditivo), até o intervalo mínimo de %.2f s.\nO projétil cresce visualmente 5%% por nível, até 35%%; esse crescimento não aumenta o dano." % [fire_interval(), fire_rate_per_level * 100.0, minimum_fire_interval]

const Projectile = preload("res://scripts/upgrades/plasma_projectile.gd")
const Targets = preload("res://scripts/upgrades/upgrade_targets.gd")

@export var projectile_scene: PackedScene
@export_range(0.1, 5.0, 0.05) var base_fire_interval: float = 1.1
@export_range(0.0, 1.0, 0.01) var fire_rate_per_level: float = 0.18
@export_range(0.05, 1.0, 0.01) var minimum_fire_interval: float = 0.18
@export var muzzle_offset := Vector2(19.0, 0.0)
@export var plasma_color := Color(0.25, 0.9, 1.0, 1.0)

var _remaining: float = 0.0


func _sync_attachment() -> void:
	super._sync_attachment()
	if not combat_active and is_instance_valid(_actor_visual):
		global_rotation = _actor_visual.facing_direction().angle()
	queue_redraw()


func set_level(rank: int) -> void:
	super.set_level(rank)
	_remaining = minf(_remaining, fire_interval())


func fire_interval() -> float:
	return maxf(minimum_fire_interval, base_fire_interval / (1.0 + fire_rate_per_level * (level - 1)))


func set_combat_context(room: Node2D, active: bool) -> void:
	super.set_combat_context(room, active)
	visible = is_instance_valid(room)
	_remaining = 0.0


func _physics_process(delta: float) -> void:
	if not combat_active or not is_instance_valid(combat_room) or not is_instance_valid(actor):
		return
	if actor.get_node("Health").dead:
		return
	_remaining = maxf(0.0, _remaining - delta)
	_sync_attachment()
	queue_redraw()
	var target := _nearest_visible_enemy()
	if target == null:
		if is_instance_valid(_actor_visual):
			var facing: Vector2 = _actor_visual.facing_direction()
			global_rotation = facing.angle()
		return
	global_rotation = (target.global_position - global_position).angle()
	if _remaining > 0.0 or projectile_scene == null:
		return
	# Snapshot the direction to the current position; the projectile has no target reference.
	var origin := to_global(muzzle_offset)
	if not Targets.clear_path_from(self, actor.global_position, origin):
		origin = actor.global_position
	if not Targets.clear_path_from(self, origin, target.global_position):
		return
	var direction := (target.global_position - origin).normalized()
	if direction.is_zero_approx():
		return
	var instance := projectile_scene.instantiate()
	var shot := instance as Projectile
	if shot == null:
		instance.free()
		return
	combat_room.add_child(shot)
	shot.upgrade_owner = self
	shot.visual_scale = minf(1.35, 1.0 + 0.05 * (level - 1))
	shot.launch(origin, direction, actor)
	_remaining = fire_interval()


func _nearest_visible_enemy() -> Node2D:
	return Targets.nearest_visible(self, INF, true, actor)


func _draw() -> void:
	var vertical_flip := -1.0 if cos(global_rotation) < 0.0 else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, vertical_flip))
	draw_rect(Rect2(-7.0, -6.0, 23.0, 12.0), Color(0.3, 0.35, 0.42))
	draw_rect(Rect2(-6.0, 4.0, 8.0, 11.0), Color(0.18, 0.2, 0.25))
	draw_rect(Rect2(10.0, -4.0, 10.0, 8.0), plasma_color)
	draw_line(Vector2(-3.0, -2.0), Vector2(8.0, -2.0), Color.WHITE, 2.0)
	draw_set_transform(Vector2.ZERO)
