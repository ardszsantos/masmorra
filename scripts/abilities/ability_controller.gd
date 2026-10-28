extends Node

signal action_activated
signal action_resolved(success: bool)
signal action_failed(reason: StringName)
signal ability_started(ability: Node)
signal combat_context_changed(room: Node2D, active: bool)

const Ability = preload("res://scripts/abilities/player_ability.gd")
@export var starting_abilities: Array[PackedScene] = []
var disabled: bool = false
var _exhausted: bool = false
@onready var stamina = get_parent().get_node_or_null("Stamina")


func _ready() -> void:
	for scene in starting_abilities:
		grant_ability(scene)


func grant_ability(scene: PackedScene) -> void:
	var instance := scene.instantiate()
	if not instance is Ability:
		instance.free()
		push_error("Ability scenes must inherit player_ability.gd")
		return
	for ability in get_children():
		if ability is Ability and ability.ability_id == instance.ability_id:
			instance.free()
			return
	add_child(instance)


func remove_ability(id: StringName) -> void:
	for ability in get_children():
		if ability is Ability and ability.ability_id == id:
			ability.cancel()
			remove_child(ability)
			ability.queue_free()


func request_action(trigger: StringName, direction: Vector2) -> void:
	if disabled:
		_reject_action(&"disabled")
		return
	if _is_stunned():
		_reject_action(&"stunned")
		return
	for ability in get_children():
		if ability is Ability and ability.active and ability.blocks_other_actions:
			_reject_action(&"busy")
			return
	var failure: StringName = &"not_equipped"
	for ability in get_children():
		if ability is Ability and not ability.sustained and ability.trigger_id == trigger:
			if stamina != null and not stamina.can_spend(ability.stamina_cost):
				_reject_action(&"stamina")
				return
			if ability.try_activate(direction):
				if stamina != null:
					stamina.spend(ability.stamina_cost)
				action_activated.emit()
				ability_started.emit(ability)
				action_resolved.emit(true)
				return
			failure = ability.get_activation_failure(direction)
	_reject_action(failure)


func _reject_action(reason: StringName) -> void:
	action_resolved.emit(false)
	action_failed.emit(reason)


func resolve_velocity(base_velocity: Vector2, delta: float) -> Vector2:
	for ability in get_children():
		if ability is Ability and ability.active and ability.overrides_movement:
			return ability.movement_velocity(delta)
	return base_velocity

func update_sustained_action(trigger: StringName, value: float) -> void:
	if is_zero_approx(value):
		_exhausted = false
	if disabled or _is_stunned() or (_exhausted and not is_zero_approx(value)):
		return
	for ability in get_children():
		if ability is Ability and ability.active and not ability.sustained:
			return
	for ability in get_children():
		if ability is Ability and ability.sustained and ability.trigger_id == trigger:
			if not is_zero_approx(value) and not ability.active and stamina != null and not stamina.can_spend(ability.stamina_per_second / 60.0):
				_exhausted = true
				action_failed.emit(&"stamina")
				return
			ability.update_input(value)


func step(delta: float) -> void:
	for ability in get_children():
		if ability is Ability:
			if ability.active and ability.stamina_per_second > 0.0 and stamina != null:
				if not stamina.spend(ability.stamina_per_second * delta):
					stamina.spend(stamina.current)
					ability.cancel()
					_exhausted = true
					action_failed.emit(&"stamina")
					continue
			ability.step(delta)

func shutdown() -> void:
	disabled = true
	combat_context_changed.emit(null, false)
	interrupt()

func set_combat_context(room: Node2D, active: bool) -> void:
	combat_context_changed.emit(room, active and not disabled)

func _is_stunned() -> bool:
	var reaction = get_parent().get_node_or_null("HitReaction")
	return reaction != null and reaction.is_stunned()

func interrupt(include_independent_effects: bool = true) -> void:
	for ability in get_children():
		if ability is Ability and (include_independent_effects or ability.blocks_other_actions):
			ability.cancel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		for ability in get_children():
			if ability is Ability:
				ability.cancel()
