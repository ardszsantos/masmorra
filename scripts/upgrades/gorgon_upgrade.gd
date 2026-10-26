extends "res://scripts/upgrades/passive_upgrade.gd"

const Targets = preload("res://scripts/upgrades/upgrade_targets.gd")
const Wave = preload("res://scripts/upgrades/gorgon_wave.gd")
const EYE = preload("res://assets/sprites/item-upgrades/gorgon-eye/eye-icon.png")

@export var cooldown: float = 6.0
@export var detection_radius: float = 380.0
@export var freeze_duration: float = 2.5
@export var duration_per_level: float = 0.3
@export var maximum_duration: float = 5.0
@export_range(1, 10, 1) var base_targets: int = 2
@export_range(1, 5, 1) var targets_per_level: int = 1
@export_range(20.0, 160.0, 5.0) var wave_arc_degrees: float = 80.0
@export_range(0.1, 1.0, 0.05) var wave_duration: float = 0.45

var _remaining: float = 0.0


func details() -> String:
	return "Emite uma onda paralisante em cone na direção do alvo visível mais próximo. Paredes bloqueiam a onda.\n\nAtual: até %d inimigos por onda; alcance %.0f; cone de %.0f°; paralisia de %.2f s; intervalo %.2f s.\nPor nível: +%d inimigo por onda, +%.2f s de paralisia (máximo %.2f s) e +8%% da frequência base. Intervalo mínimo: 1 s. Sem alvo alcançável, guarda a recarga." % [target_capacity(), detection_radius, wave_arc_degrees, current_freeze_duration(), fire_interval(), targets_per_level, duration_per_level, maximum_duration]


func target_capacity() -> int:
	return base_targets + targets_per_level * (level - 1)


func current_freeze_duration() -> float:
	return minf(maximum_duration, freeze_duration + duration_per_level * (level - 1))


func fire_interval() -> float:
	return maxf(1.0, cooldown / (1.0 + 0.08 * (level - 1)))


func set_level(rank: int) -> void:
	super.set_level(rank)
	_remaining = minf(_remaining, fire_interval())


func set_combat_context(room: Node2D, active: bool) -> void:
	super.set_combat_context(room, active)
	visible = is_instance_valid(room)
	_remaining = 0.0


func _physics_process(delta: float) -> void:
	if not combat_active or not is_instance_valid(actor) or not is_instance_valid(combat_room):
		return
	if actor.get_node("Health").dead:
		return
	_sync_attachment()
	_remaining = maxf(0.0, _remaining - delta)
	var target: Node2D
	for candidate in Targets.visible_enemies(actor, detection_radius):
		if candidate.has_method("apply_freeze") and Targets.clear_path(self, candidate.global_position):
			target = candidate
			break
	if target == null:
		return
	var heading := (target.global_position - actor.global_position).normalized()
	if heading.is_zero_approx():
		heading = Vector2.RIGHT
	global_rotation = heading.angle()
	if _remaining > 0.0:
		return
	var wave := Wave.new()
	wave.actor = actor
	wave.upgrade_owner = self
	wave.heading = heading
	wave.radius = detection_radius
	wave.arc_degrees = wave_arc_degrees
	wave.duration = wave_duration
	wave.freeze_duration = current_freeze_duration()
	wave.target_limit = target_capacity()
	combat_room.add_child(wave)
	wave.global_position = actor.global_position
	_remaining = fire_interval()


func _draw() -> void:
	var dimensions := EYE.get_size()
	dimensions *= 30.0 / maxf(dimensions.x, dimensions.y)
	draw_texture_rect(EYE, Rect2(-dimensions * 0.5, dimensions), false)
