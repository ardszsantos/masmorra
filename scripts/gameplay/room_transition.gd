extends Node

signal room_entered(room: Node2D)

const GeneratedRoom = preload("res://scripts/gameplay/generated_room.gd")
const PieceAssembler = preload("res://scripts/gameplay/piece_assembler.gd")
const RoomRewards = preload("res://scripts/gameplay/room_rewards.gd")
const MAP_SETTINGS_PATH := "user://map_selection.cfg"

@export var room_scene: PackedScene
## Piece libraries exported by the builder and bundled with the game.
@export_dir var pieces_folder: String = "res://piece-libraries"
@export var rooms: Node2D
@export var player: CharacterBody2D
@export var stroke_pad: Control
@export var stroke_gesture: Node

var active_room: Node2D
var current_layout: Dictionary = {}
var _transitioning: bool = false
var stopped: bool = false
var _run_started: bool = false
var _assembler = PieceAssembler.new()
@onready var rewards: RoomRewards = $"../RoomRewards"


func _ready() -> void:
	player.get_node("Health").died.connect(stop)
	_load_pieces()


func start_run(saved_layout: Dictionary = {}) -> bool:
	if stopped or _run_started or _transitioning or _assembler.pieces.is_empty():
		return false
	_run_started = true
	_transitioning = true
	_enter_arena.call_deferred(null, saved_layout)
	return true


func _on_travel_requested(body: CharacterBody2D, source: Area2D) -> void:
	if body != player or not _run_started or stopped or _transitioning or not is_instance_valid(source) or source.locked or not source.enabled:
		return
	if not is_instance_valid(active_room) or not active_room.exit_doors.has(source):
		return
	if not rewards.can_claim(source):
		return
	_transitioning = true
	# Instantiate or remove colliders outside the door's physics signal.
	_enter_arena.call_deferred(source)


func _enter_arena(chosen_exit: Area2D = null, saved_layout: Dictionary = {}) -> void:
	if stopped:
		_transitioning = false
		_run_started = is_instance_valid(active_room)
		return
	if room_scene == null:
		_report_error("Configure Room Scene no Inspector de RoomTransition.")
		_transitioning = false
		_run_started = is_instance_valid(active_room)
		return
	var layout: Dictionary = saved_layout if not saved_layout.is_empty() else _assembler.assemble()
	if layout.is_empty():
		_report_error(_assembler.last_error)
		_transitioning = false
		_run_started = is_instance_valid(active_room)
		return
	var instance := room_scene.instantiate()
	var next_room := instance as GeneratedRoom
	if next_room == null:
		instance.free()
		_report_error("Room Scene precisa usar generated_room.gd.")
		_transitioning = false
		_run_started = is_instance_valid(active_room)
		return
	rooms.add_child(next_room)
	if not next_room.build_from_layout(layout):
		rooms.remove_child(next_room)
		next_room.queue_free()
		_report_error("Não foi possível montar a sala %s." % layout.name)
		_transitioning = false
		_run_started = is_instance_valid(active_room)
		return
	var spawner = $"../EnemySpawner"
	if next_room.enemy_spawn_positions(spawner.minimum_player_distance, spawner.minimum_door_distance).is_empty():
		rooms.remove_child(next_room)
		next_room.queue_free()
		_report_error("A sala %s não tem espaço para inimigos longe da entrada e das saídas." % layout.name)
		_transitioning = false
		_run_started = is_instance_valid(active_room)
		return
	# Consume the choice only after the next room has been built.
	if chosen_exit != null and not rewards.claim(chosen_exit, player):
		rooms.remove_child(next_room)
		next_room.queue_free()
		_transitioning = false
		return
	var previous_room: Node2D = active_room
	$"../EnemySpawner".reset_encounter()
	player.get_node("Upgrades").set_combat_context(null, false)
	player.get_node("Abilities").set_combat_context(null, false)
	stroke_pad.reset()
	stroke_gesture.reset()
	player.get_node("Abilities").interrupt()
	player.velocity = Vector2.ZERO
	player.global_position = next_room.spawn_point.global_position
	player.reset_physics_interpolation()
	active_room = next_room
	current_layout = layout
	for portal: Area2D in next_room.exit_doors:
		portal.travel_requested.connect(_on_travel_requested.bind(portal))
	print("Sala montada: %s [%s], tamanho=%s" % [next_room.layout_name, next_room.layout_id, next_room.generated_size])
	# Free the previous room and its colliders; preserve the player and their build.
	if is_instance_valid(previous_room):
		rooms.remove_child(previous_room)
		previous_room.queue_free()
	# Wait for physics to register the new walls and remove the old ones.
	await get_tree().physics_frame
	if not stopped:
		room_entered.emit(next_room)
	_transitioning = false


func stop() -> void:
	stopped = true
	if is_instance_valid(active_room):
		active_room.set_exits_locked(true)


func teleport_to_reward(portal: Area2D) -> void:
	if stopped or _transitioning or not is_instance_valid(active_room) or player.get_node("Health").dead:
		return
	if not active_room.exit_doors.has(portal) or not rewards.can_claim(portal):
		return
	var arrival: Vector2 = active_room.reward_approach_position(portal, player)
	if not arrival.is_finite():
		return
	stroke_pad.reset()
	stroke_gesture.reset()
	player.get_node("Abilities").interrupt()
	player.set_movement_direction(Vector2.ZERO)
	player.velocity = Vector2.ZERO
	player.global_position = arrival
	player.reset_physics_interpolation()


func can_select_libraries() -> bool:
	return not stopped and not _run_started and not _transitioning


func can_start_run() -> bool:
	return can_select_libraries() and not _assembler.pieces.is_empty()


func get_available_libraries() -> Array:
	return _assembler.available_libraries.keys()


func is_library_enabled(file_name: String) -> bool:
	return _assembler.enabled_libraries.has(file_name)


func set_library_enabled(file_name: String, enabled: bool) -> bool:
	if not can_select_libraries():
		return false
	if not _assembler.set_library_enabled(file_name, enabled):
		return false
	_save_map_selection()
	return true


func set_all_libraries_enabled(enabled: bool) -> void:
	if not can_select_libraries():
		return
	_assembler.set_all_libraries_enabled(enabled)
	_save_map_selection()


func _save_map_selection() -> void:
	var config := ConfigFile.new()
	for file_name: String in _assembler.available_libraries:
		config.set_value("maps", file_name, is_library_enabled(file_name))
	var error := config.save(MAP_SETTINGS_PATH)
	if error != OK:
		push_warning("Não foi possível salvar a seleção de mapas: " + error_string(error))


func _restore_map_selection() -> void:
	var config := ConfigFile.new()
	if config.load(MAP_SETTINGS_PATH) != OK:
		return
	for file_name: String in _assembler.available_libraries:
		var enabled: bool = bool(config.get_value("maps", file_name, true))
		_assembler.set_library_enabled(file_name, enabled)


func _load_pieces() -> void:
	if not _assembler.load_folder(pieces_folder):
		_report_error(_assembler.last_error)
		return
	if not _assembler.last_error.is_empty():
		_report_error(_assembler.last_error)
	_restore_map_selection()
	print("Peças disponíveis: %d (%s)" % [_assembler.pieces.size(), pieces_folder])


func _report_error(message: String) -> void:
	push_error("RoomTransition: %s" % message)
