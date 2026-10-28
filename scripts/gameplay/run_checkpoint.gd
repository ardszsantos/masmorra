extends Node

const SAVE_PATH := "user://run_checkpoint.cfg"
const SAVE_VERSION := 1
const Reward = preload("res://scripts/gameplay/room_reward.gd")

@onready var transition: Node = $"../RoomTransition"
@onready var session: Node = $"../GameSession"
@onready var player: CharacterBody2D = $"../Player"
@onready var spawner: Node = $"../EnemySpawner"
@onready var rewards: Node = $"../RoomRewards"
@onready var upgrades: Node = $"../Player/Upgrades"
@onready var knowledge: Node = $"../Player/Knowledge"

var _restoring: bool = false
var _saved_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	transition.room_entered.connect(_room_entered)
	player.get_node("Health").died.connect(clear_checkpoint)
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(save_checkpoint)
	add_child(timer)

func has_checkpoint() -> bool:
	var config := ConfigFile.new()
	return config.load(SAVE_PATH) == OK and _valid_checkpoint(config)

func start_new_run() -> bool:
	if not transition.can_start_run():
		return false
	clear_checkpoint()
	return transition.start_run()

func continue_run() -> bool:
	if not transition.can_start_run():
		return false
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK or not _valid_checkpoint(config):
		return false
	var state: Dictionary = config.get_value("run", "state")
	var layout: Dictionary = state["layout"]
	session.room_number = int(state["room_number"]) - 1
	session.completed_rooms = int(state.get("completed_rooms", 0))
	session.score = int(state.get("score", 0))
	session.stats.get_node("ScoreLabel").text = "Pontos: %d" % session.score
	session.resume_cleared = bool(state.get("room_cleared", false))
	session.resume_remaining = int(state.get("remaining_enemies", 1))
	session.resume_offer_ids = state.get("offer_ids", [])
	_restore_upgrades(state.get("upgrades", []))
	var health: Node = player.get_node("Health")
	health.maximum = float(state.get("health_maximum", health.maximum))
	health.current = clampf(float(state.get("health_current", health.current)), 1.0, health.maximum)
	health.changed.emit(health.current, health.maximum)
	var stamina: Node = player.get_node("Stamina")
	stamina.maximum = float(state.get("stamina_maximum", stamina.maximum))
	stamina.current = clampf(float(state.get("stamina_current", stamina.current)), 0.0, stamina.maximum)
	stamina.changed.emit(stamina.current, stamina.maximum)
	knowledge.restore(int(state.get("knowledge_stacks", 0)), float(state.get("knowledge_progress", 0.0)))
	_saved_position = state.get("position", Vector2.ZERO)
	_restoring = true
	if not transition.start_run(layout):
		_restoring = false
		return false
	return true

func save_checkpoint() -> void:
	if session.ended or not transition._run_started or transition._transitioning or not is_instance_valid(transition.active_room):
		return
	if transition.current_layout.is_empty():
		return
	var upgrade_levels: Array[Dictionary] = []
	for resource: Resource in upgrades.equipped_rewards():
		var reward := resource as Reward
		if reward != null:
			upgrade_levels.append({"id": String(reward.reward_id), "level": upgrades.level_of(reward.reward_id)})
	var health: Node = player.get_node("Health")
	var stamina: Node = player.get_node("Stamina")
	var remaining: int = spawner.total_count - spawner.defeated_count
	var state := {
		"layout": transition.current_layout,
		"room_number": session.room_number,
		"completed_rooms": session.completed_rooms,
		"score": session.score,
		"room_cleared": session.room_cleared,
		"remaining_enemies": maxi(1, remaining),
		"position": player.global_position,
		"health_maximum": health.maximum,
		"health_current": health.current,
		"stamina_maximum": stamina.maximum,
		"stamina_current": stamina.current,
		"knowledge_stacks": knowledge.stacks,
		"knowledge_progress": knowledge.progress,
		"upgrades": upgrade_levels,
		"offer_ids": rewards.offered_ids(transition.active_room),
	}
	var config := ConfigFile.new()
	config.set_value("run", "version", SAVE_VERSION)
	config.set_value("run", "state", state)
	var error: Error = config.save(SAVE_PATH)
	if error != OK:
		push_warning("RunCheckpoint: could not save run: %s" % error_string(error))

func clear_checkpoint() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if error != OK:
			push_warning("RunCheckpoint: could not remove save: %s" % error_string(error))

func _room_entered(_room: Node2D) -> void:
	if _restoring:
		player.global_position = _saved_position
		player.reset_physics_interpolation()
		_restoring = false
	save_checkpoint.call_deferred()

func _restore_upgrades(saved_upgrades: Array) -> void:
	for entry: Dictionary in saved_upgrades:
		var id := StringName(entry.get("id", ""))
		var level := clampi(int(entry.get("level", 0)), 0, 99)
		for resource: Resource in rewards.reward_pool:
			var reward := resource as Reward
			if reward != null and reward.reward_id == id:
				for _index in range(level):
					if not upgrades.grant_upgrade(reward):
						break
				break

func _valid_checkpoint(config: ConfigFile) -> bool:
	if int(config.get_value("run", "version", -1)) != SAVE_VERSION:
		return false
	var state: Variant = config.get_value("run", "state", {})
	if not state is Dictionary:
		return false
	var layout: Variant = state.get("layout", {})
	return layout is Dictionary and layout.has("_walkable_cells") and layout.has("rows") and int(state.get("room_number", 0)) > 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_node_ready():
			save_checkpoint()
