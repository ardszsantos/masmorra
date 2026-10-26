extends Node2D

const PlayerVisual = preload("res://scripts/gameplay/player_visual.gd")

func details() -> String:
	return "Upgrade passivo equipado."
## Contract for an upgrade equipped during a run, independent of gestures.

var actor: CharacterBody2D
var level: int = 1
var combat_room: Node2D
var combat_active: bool = false
@export var attachment_socket: StringName = &""
@export var follow_socket_rotation: bool = false
var _attachment: Node2D
var _actor_visual: PlayerVisual
var _equipment_scale := Vector2.ONE


func equip(body: CharacterBody2D, rank: int) -> void:
	actor = body
	set_level(rank)
	if not attachment_socket.is_empty():
		_actor_visual = actor.get_node("Visual") as PlayerVisual
		if _actor_visual == null:
			push_error("Attached upgrades require the player's visual component.")
			return
		_attachment = _actor_visual.get_node_or_null(NodePath(String(attachment_socket))) as Node2D
		_equipment_scale = scale
		if _attachment == null:
			push_error("Missing player equipment socket: %s" % attachment_socket)
			return
		_actor_visual.connect("attachment_pose_changed", _sync_attachment)
		_sync_attachment()


func _sync_attachment() -> void:
	if not is_instance_valid(_attachment):
		return
	global_position = _attachment.global_position
	if follow_socket_rotation:
		global_rotation = _attachment.global_rotation
	global_scale = _attachment.global_scale * _equipment_scale
	z_index = _attachment.z_index


func _disconnect_attachment() -> void:
	if is_instance_valid(_actor_visual) and _actor_visual.is_connected("attachment_pose_changed", _sync_attachment):
		_actor_visual.disconnect("attachment_pose_changed", _sync_attachment)
	_attachment = null
	_actor_visual = null


func set_level(rank: int) -> void:
	level = maxi(1, rank)


func set_combat_context(room: Node2D, active: bool) -> void:
	combat_room = room
	combat_active = active


func unequip() -> void:
	_disconnect_attachment()
	set_combat_context(null, false)
	actor = null


func _exit_tree() -> void:
	_disconnect_attachment()
