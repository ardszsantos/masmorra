extends Node

signal reward_claimed(message: String)
signal choices_unlocked
signal offers_cleared

const Reward = preload("res://scripts/gameplay/room_reward.gd")
const GeneratedRoom = preload("res://scripts/gameplay/generated_room.gd")
const Upgrades = preload("res://scripts/upgrades/upgrade_controller.gd")
const MarkerScene = preload("res://scenes/reward_marker.tscn")
const MarkerScript = preload("res://scripts/ui/reward_marker.gd")

## Each exit gets a random offer, without repeating upgrades within a room.
@export var reward_pool: Array[Resource] = []
@export_enum("space", "normal", "medieval", "polygons") var active_world: String = "space"
@export var offer_all_worlds: bool = true

var _offers: Dictionary = {}
var _offer_levels: Dictionary = {}
var _available: bool = false
var _claimed: bool = false


func prepare_room(room: GeneratedRoom, player: CharacterBody2D) -> bool:
	offers_cleared.emit()
	_offers.clear()
	_offer_levels.clear()
	_available = false
	_claimed = false
	var options: Array[Reward] = []
	var ids: Dictionary = {}
	for resource in reward_pool:
		var reward := resource as Reward
		if reward == null or reward.reward_id.is_empty() or ids.has(reward.reward_id):
			continue
		if not offer_all_worlds and reward.world != "common" and reward.world != active_world:
			continue
		if reward.kind == Reward.Kind.UPGRADE and reward.upgrade_scene == null:
			continue
		options.append(reward)
		ids[reward.reward_id] = true
	if options.is_empty() or room.exit_doors.is_empty():
		push_error("RoomRewards: configure recompensas e pelo menos uma saída.")
		return false
	options.shuffle()
	# One playable exit per distinct offer; never display duplicate choices.
	while room.exit_doors.size() > options.size():
		var surplus: Area2D = room.exit_doors.pop_back()
		surplus.enabled = false
		surplus.hide()
		surplus.queue_free()
	var upgrades := player.get_node("Upgrades") as Upgrades
	for index in range(room.exit_doors.size()):
		var portal: Area2D = room.exit_doors[index]
		var reward: Reward = options[index]
		_offers[portal] = reward
		_offer_levels[portal] = upgrades.level_of(reward.reward_id) + 1
		var marker := MarkerScene.instantiate() as MarkerScript
		portal.add_child(marker)
		marker.show_reward(reward, upgrades.level_of(reward.reward_id) + 1)
	return true


func unlock_choices() -> void:
	if not _claimed:
		_available = true
		choices_unlocked.emit()


func guide_offers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _available or _claimed:
		return result
	for portal: Area2D in _offers:
		if is_instance_valid(portal):
			result.append({"door": portal, "reward": _offers[portal], "level": _offer_levels[portal]})
	return result


func hide_choices() -> void:
	_available = false
	offers_cleared.emit()


func can_claim(portal: Area2D) -> bool:
	return _available and not _claimed and is_instance_valid(portal) and _offers.has(portal) and portal.enabled and not portal.locked


func claim(portal: Area2D, player: CharacterBody2D) -> bool:
	if not can_claim(portal) or player.get_node("Health").dead:
		return false
	var reward := _offers[portal] as Reward
	var upgrades := player.get_node("Upgrades") as Upgrades
	_claimed = true
	var message := ""
	match reward.kind:
		Reward.Kind.UPGRADE:
			if not upgrades.grant_upgrade(reward):
				_claimed = false
				return false
			message = "%s · Nv. %d" % [reward.display_name, upgrades.level_of(reward.reward_id)]
		Reward.Kind.HEALTH:
			player.get_node("Health").increase_maximum(reward.amount)
			player.get_node("Health").heal(reward.amount)
			message = "+%d vida máxima e vida" % int(reward.amount)
		Reward.Kind.STAMINA:
			player.get_node("Stamina").increase_maximum(reward.amount)
			message = "+%d stamina máxima" % int(reward.amount)
	_available = false
	for door: Area2D in _offers:
		if is_instance_valid(door):
			door.set_locked(true)
	reward_claimed.emit(message)
	offers_cleared.emit()
	return true
