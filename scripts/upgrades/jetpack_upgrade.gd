extends "res://scripts/upgrades/passive_upgrade.gd"

func details() -> String:
	return "Seu dash deixa um rastro de fogo que causa dano por contato e aplica queimadura.\n\nAtual: %.1f de dano por pulso; fogo dura %.1f s. Queimadura: %.1f de dano/s por %.1f s após o contato.\nPor nível: +%.1f de dano por pulso, +%.1f de dano/s na queimadura e +0,2 s de duração do fogo.\nNovo contato renova a queimadura sem empilhar seu dano." % [damage_per_tick + damage_per_level * (level - 1), fire_duration + 0.2 * (level - 1), burn_damage_per_second + damage_per_level * (level - 1), burn_duration, damage_per_level, damage_per_level]

const Dash = preload("res://scripts/abilities/dash_ability.gd")
const Fire = preload("res://scripts/upgrades/fire_area.gd")

@export_range(8.0, 80.0, 1.0) var trail_spacing: float = 30.0
@export var fire_radius: float = 24.0
@export var fire_duration: float = 1.8
@export var damage_per_tick: float = 6.0
@export var damage_per_level: float = 2.0
@export var burn_duration: float = 3.0
@export var burn_damage_per_second: float = 4.0

var _abilities: Node
var _dash: Dash
var _trail_position := Vector2.ZERO


func equip(body: CharacterBody2D, rank: int) -> void:
	super.equip(body, rank)
	_abilities = body.get_node("Abilities")
	_abilities.ability_started.connect(_on_ability_started)


func _on_ability_started(ability: Node) -> void:
	if not combat_active or not is_instance_valid(combat_room) or not ability is Dash:
		return
	_dash = ability as Dash
	_trail_position = actor.global_position
	_spawn_fire(_trail_position)


func _physics_process(_delta: float) -> void:
	if not combat_active or not is_instance_valid(_dash) or not is_instance_valid(actor):
		return
	var finish := actor.global_position
	# Sample the final movement step even if the dash ends this frame.
	var distance := _trail_position.distance_to(finish)
	if distance < 1000.0:
		while _trail_position.distance_to(finish) >= trail_spacing:
			_trail_position = _trail_position.move_toward(finish, trail_spacing)
			_spawn_fire(_trail_position)
	if not _dash.active:
		_dash = null


func _spawn_fire(point: Vector2) -> void:
	var flame := Fire.new()
	flame.actor = actor
	flame.upgrade_owner = self
	flame.radius = fire_radius
	flame.duration = fire_duration + 0.2 * (level - 1)
	flame.damage = damage_per_tick + damage_per_level * (level - 1)
	flame.burn_duration = burn_duration
	flame.burn_damage_per_second = burn_damage_per_second + damage_per_level * (level - 1)
	combat_room.add_child(flame)
	flame.global_position = point


func set_combat_context(room: Node2D, active: bool) -> void:
	super.set_combat_context(room, active)
	_dash = null
	visible = is_instance_valid(room)


func unequip() -> void:
	if is_instance_valid(_abilities) and _abilities.ability_started.is_connected(_on_ability_started):
		_abilities.ability_started.disconnect(_on_ability_started)
	super.unequip()


func _draw() -> void:
	for x in [-7.0, 7.0]:
		draw_rect(Rect2(x - 5.0, -10.0, 10.0, 22.0), Color(0.5, 0.55, 0.65))
		draw_rect(Rect2(x - 3.0, 7.0, 6.0, 8.0), Color(1.0, 0.4, 0.1))
