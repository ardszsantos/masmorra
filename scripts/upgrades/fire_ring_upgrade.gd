extends "res://scripts/upgrades/passive_upgrade.gd"

func details() -> String:
	return "Forma uma barreira de fogo ao seu redor, que acompanha você, causa dano e queima inimigos.\n\nAtual: %.1f de dano por pulso; duração %.1f s; intervalo %.2f s. Queimadura: %.1f de dano/s por %.1f s.\nPor nível: +%.1f de dano por pulso, +%.1f de dano/s na queimadura e +10%% da frequência base. O intervalo nunca fica abaixo da duração do anel + 0,5 s.\nNovo contato renova a queimadura sem empilhar seu dano." % [damage_per_tick + damage_per_level * (level - 1), duration, maxf(duration + 0.5, cooldown / (1.0 + 0.1 * (level - 1))), burn_damage_per_second + damage_per_level * (level - 1), burn_duration, damage_per_level, damage_per_level]

const Fire = preload("res://scripts/upgrades/fire_area.gd")

@export var cooldown: float = 6.0
@export var duration: float = 2.2
@export_range(0.0, 2.0, 0.05) var formation_duration: float = 0.55
@export var radius: float = 105.0
@export var thickness: float = 32.0
@export var damage_per_tick: float = 10.0
@export var damage_per_level: float = 3.0
@export var burn_duration: float = 3.0
@export var burn_damage_per_second: float = 4.0

var _remaining: float = 0.0


func _physics_process(delta: float) -> void:
	if not combat_active or not is_instance_valid(actor) or not is_instance_valid(combat_room):
		return
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining > 0.0:
		return
	var ring := Fire.new()
	ring.actor = actor
	ring.upgrade_owner = self
	ring.follows_actor = true
	ring.radius = radius
	ring.inner_radius = maxf(0.0, radius - thickness)
	ring.duration = duration
	ring.formation_duration = minf(formation_duration, duration)
	ring.damage = damage_per_tick + damage_per_level * (level - 1)
	ring.burn_duration = burn_duration
	ring.burn_damage_per_second = burn_damage_per_second + damage_per_level * (level - 1)
	combat_room.add_child(ring)
	ring.global_position = actor.global_position
	_remaining = maxf(duration + 0.5, cooldown / (1.0 + 0.1 * (level - 1)))
