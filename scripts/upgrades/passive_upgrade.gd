extends Node2D

func details() -> String:
	return "Upgrade passivo equipado."
## Contract for an upgrade equipped during a run, independent of gestures.

var actor: CharacterBody2D
var level: int = 1
var combat_room: Node2D
var combat_active: bool = false


func equip(body: CharacterBody2D, rank: int) -> void:
	actor = body
	set_level(rank)


func set_level(rank: int) -> void:
	level = maxi(1, rank)


func set_combat_context(room: Node2D, active: bool) -> void:
	combat_room = room
	combat_active = active


func unequip() -> void:
	set_combat_context(null, false)
	actor = null
