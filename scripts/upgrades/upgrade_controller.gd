extends Node2D
## The player's build persists between rooms and resets when a new run starts.

signal changed

const Passive = preload("res://scripts/upgrades/passive_upgrade.gd")
const Reward = preload("res://scripts/gameplay/room_reward.gd")
const SLOT_COUNT: int = 8

var _equipped: Dictionary = {}
var _definitions: Dictionary = {}
var _room: Node2D
var _combat_active: bool = false
var _stopped: bool = false
@onready var actor: CharacterBody2D = get_parent() as CharacterBody2D


func _ready() -> void:
	actor.get_node("Health").died.connect(shutdown)


func level_of(id: StringName) -> int:
	var effect := _equipped.get(id) as Passive
	return effect.level if is_instance_valid(effect) else 0


func details_of(id: StringName) -> String:
	var effect := _equipped.get(id) as Passive
	return effect.details() if is_instance_valid(effect) else "Este item não está equipado."


func grant_upgrade(reward: Reward) -> bool:
	if _stopped or reward == null or reward.upgrade_scene == null:
		return false
	if not can_equip(reward.reward_id):
		return false
	var effect := _equipped.get(reward.reward_id) as Passive
	if is_instance_valid(effect):
		effect.set_level(effect.level + 1)
	else:
		var instance := reward.upgrade_scene.instantiate()
		effect = instance as Passive
		if effect == null:
			instance.free()
			push_error("Upgrade: a cena precisa herdar passive_upgrade.gd.")
			return false
		add_child(effect)
		effect.equip(actor, 1)
		effect.set_combat_context(_room, _combat_active)
		_equipped[reward.reward_id] = effect
		_definitions[reward.reward_id] = reward
	changed.emit()
	return true


func can_equip(id: StringName) -> bool:
	return _equipped.has(id) or _equipped.size() < SLOT_COUNT


func remove_upgrade(id: StringName) -> void:
	var effect := _equipped.get(id) as Passive
	if not is_instance_valid(effect):
		return
	effect.unequip()
	remove_child(effect)
	effect.queue_free()
	_equipped.erase(id)
	_definitions.erase(id)
	_clear_effects(effect)
	changed.emit()


func set_combat_context(room: Node2D, active: bool) -> void:
	_clear_effects()
	_room = room
	_combat_active = active and not _stopped
	for effect: Passive in _equipped.values():
		effect.set_combat_context(room, _combat_active)


func description() -> String:
	var lines := PackedStringArray()
	for id: StringName in _equipped:
		var definition := _definitions[id] as Reward
		lines.append("%s · Nv. %d" % [definition.display_name, level_of(id)])
	return "\n".join(lines)


func equipped_rewards() -> Array[Resource]:
	var result: Array[Resource] = []
	for id: StringName in _equipped:
		result.append(_definitions[id])
	return result


func shutdown() -> void:
	_stopped = true
	set_combat_context(null, false)


func _clear_effects(effect_owner: Node = null) -> void:
	if not is_instance_valid(_room):
		return
	for node in _room.get_children():
		if node.is_in_group("upgrade_effects") and (effect_owner == null or node.get("upgrade_owner") == effect_owner):
			node.queue_free()
