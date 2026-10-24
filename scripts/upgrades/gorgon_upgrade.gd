extends "res://scripts/upgrades/passive_upgrade.gd"

func details() -> String:
	return "Congela automaticamente o inimigo próximo e visível mais próximo, impedindo movimento e ataques.\n\nAtual: congelamento de %.2f s; intervalo %.2f s.\nPor nível: +%.2f s de congelamento (máximo %.2f s) e +8%% da frequência base. Intervalo mínimo: 1 s. Sem alvo, aguarda pronto para atacar." % [minf(maximum_duration, freeze_duration + duration_per_level * (level - 1)), maxf(1.0, cooldown / (1.0 + 0.08 * (level - 1))), duration_per_level, maximum_duration]

const Targets = preload("res://scripts/upgrades/upgrade_targets.gd")
const EYE = preload("res://assets/sprites/item-upgrades/gorgon-eye/eye-icon.png")

@export var cooldown: float = 6.0
@export var detection_radius: float = 380.0
@export var freeze_duration: float = 2.5
@export var duration_per_level: float = 0.3
@export var maximum_duration: float = 5.0

var _remaining: float = 0.0
var _beam_time: float = 0.0
var _beam_target := Vector2.ZERO


func set_combat_context(room: Node2D, active: bool) -> void:
	super.set_combat_context(room, active)
	visible = is_instance_valid(room)
	_beam_time = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not combat_active or not is_instance_valid(actor):
		return
	_remaining = maxf(0.0, _remaining - delta)
	_beam_time = maxf(0.0, _beam_time - delta)
	if _remaining <= 0.0:
		var target := Targets.nearest_visible(actor, detection_radius)
		if target != null and target.has_method("apply_freeze"):
			_beam_target = target.global_position
			global_rotation = (_beam_target - global_position).angle()
			target.apply_freeze(minf(maximum_duration, freeze_duration + duration_per_level * (level - 1)))
			_remaining = maxf(1.0, cooldown / (1.0 + 0.08 * (level - 1)))
			_beam_time = 0.25
	queue_redraw()


func _draw() -> void:
	var dimensions := EYE.get_size()
	dimensions *= 30.0 / maxf(dimensions.x, dimensions.y)
	draw_texture_rect(EYE, Rect2(-dimensions * 0.5, dimensions), false)
	if _beam_time > 0.0:
		draw_line(Vector2.ZERO, to_local(_beam_target), Color(0.5, 1.0, 0.8, _beam_time * 4.0), 3.0, true)
