extends Node
@export_range(1, 100, 1) var initial_enemies: int = 3
@export_range(1, 20, 1) var enemies_per_room: int = 2
var score: int = 0
var ended: bool = false
var room_number: int = 0
var completed_rooms: int = 0
var room_cleared: bool = false
var resume_remaining: int = -1
var resume_cleared: bool = false
var resume_offer_ids: Array = []
@onready var player = $"../Player"
@onready var spawner = $"../EnemySpawner"
@onready var stats = $"../HUD/StatusHud/Stats"
@onready var transition = $"../RoomTransition"
@onready var rewards = $"../RoomRewards"
@onready var upgrades = $"../Player/Upgrades"

func _ready() -> void:
	player.get_node("Health").changed.connect(_health_changed)
	player.get_node("Stamina").changed.connect(_stamina_changed)
	player.get_node("Health").died.connect(_game_over)
	spawner.enemy_spawned.connect(_enemy_spawned)
	spawner.progress_changed.connect(_encounter_progress)
	spawner.encounter_cleared.connect(_room_completed)
	transition.room_entered.connect(_room_entered)
	_health_changed(player.get_node("Health").current, player.get_node("Health").maximum)
	_stamina_changed(player.get_node("Stamina").current, player.get_node("Stamina").maximum)
	stats.get_node("ScoreLabel").text = "Pontos: 0"
	stats.get_node("RoomLabel").text = "Masmorra"
	stats.get_node("EncounterLabel").text = "Prepare-se para a descida"

func _room_entered(room: Node2D) -> void:
	if ended:
		return
	room_number += 1
	room_cleared = false
	stats.get_node("RoomLabel").text = "Sala %d" % room_number
	if not rewards.prepare_room(room, player):
		_game_over()
		return
	if not resume_offer_ids.is_empty():
		rewards.restore_offers(room, player, resume_offer_ids)
		resume_offer_ids.clear()
	room.set_exits_locked(true)
	upgrades.set_combat_context(room, true)
	player.get_node("Abilities").set_combat_context(room, true)
	var positions: PackedVector2Array = room.enemy_spawn_positions(spawner.minimum_player_distance, spawner.minimum_door_distance)
	var count := initial_enemies + (room_number - 1) * enemies_per_room
	if resume_cleared:
		room_cleared = true
		upgrades.set_combat_context(room, false)
		player.get_node("Abilities").set_combat_context(room, false)
		rewards.unlock_choices()
		stats.get_node("EncounterLabel").text = "Escolha uma saída: 1 recompensa"
		room.set_exits_locked(false)
	elif resume_remaining >= 0:
		spawner.begin_encounter(positions, maxi(1, resume_remaining))
	else:
		spawner.begin_encounter(positions, count)
	resume_remaining = -1
	resume_cleared = false

func _encounter_progress(defeated: int, total: int) -> void:
	if not ended:
		stats.get_node("EncounterLabel").text = "Inimigos: %d / %d" % [defeated, total]

func _room_completed() -> void:
	if ended or room_cleared or room_number == 0:
		return
	room_cleared = true
	completed_rooms += 1
	upgrades.set_combat_context(transition.active_room, false)
	player.get_node("Abilities").set_combat_context(transition.active_room, false)
	rewards.unlock_choices()
	stats.get_node("EncounterLabel").text = "Escolha uma saída: 1 recompensa"
	transition.active_room.set_exits_locked(false)

func _health_changed(value: float, maximum: float) -> void:
	stats.get_node("HealthBar").max_value = maximum
	stats.get_node("HealthBar").value = value

func _stamina_changed(value: float, maximum: float) -> void:
	stats.get_node("StaminaBar").max_value = maximum
	stats.get_node("StaminaBar").value = value

func _enemy_spawned(enemy: Node) -> void:
	enemy.defeated.connect(_enemy_defeated, CONNECT_ONE_SHOT)

func _enemy_defeated(_enemy: Node) -> void:
	if not ended:
		score += 1
		stats.get_node("ScoreLabel").text = "Pontos: %d" % score

func _game_over() -> void:
	ended = true
	$"../RunCheckpoint".clear_checkpoint()
	rewards.hide_choices()
	spawner.stop()
	transition.stop()
	upgrades.shutdown()
	var pad = $"../HUD/StrokePad"
	pad.reset()
	pad.set_process_input(false)
	pad.set_process_unhandled_input(false)
	player.set_physics_process(false)
	player.get_node("Abilities").shutdown()
	player.get_node("Stamina").set_physics_process(false)
	for enemy in $"../Enemies".get_children():
		enemy.stop_combat()
	stats.get_node("ScoreLabel").text = "Fim de jogo — Pontos: %d" % score
	var restart := Button.new()
	restart.text = "Jogar novamente"
	restart.custom_minimum_size.y = 56
	stats.add_child(restart)
	restart.pressed.connect(func(): get_tree().reload_current_scene())
