extends Node

const Rules = preload("res://scripts/gameplay/piece_rules.gd")

signal enemy_spawned(enemy: Node)
signal progress_changed(defeated: int, total: int)
signal encounter_cleared

@export var enemy_scene: PackedScene
@export var enemy_variants: Array[PackedScene] = []
@export_range(1, 100, 1) var maximum_alive: int = 30
var minimum_player_distance: float = Rules.PLAYER_DISTANCE
var minimum_door_distance: float = Rules.DOOR_DISTANCE
@export var clearance_radius: float = 24.0
@export_range(0.05, 5.0, 0.05) var spawn_interval: float = 0.35

var enabled: bool = false
var active: bool = false
var total_count: int = 0
var pending_count: int = 0
var defeated_count: int = 0
var _positions := PackedVector2Array()
var _living: Dictionary = {}
@onready var container: Node2D = $"../Enemies"
@onready var player: CharacterBody2D = $"../Player"

func _ready() -> void:
	$SpawnTimer.timeout.connect(spawn_enemy)

func begin_encounter(positions: PackedVector2Array, count: int) -> bool:
	reset_encounter()
	if positions.is_empty() or enemy_scene == null or count < 1:
		push_error("EnemySpawner: encounter requires positions, an enemy scene and a positive count.")
		return false
	_positions = positions
	total_count = count
	pending_count = count
	active = true
	enabled = true
	$SpawnTimer.wait_time = spawn_interval
	$SpawnTimer.start()
	progress_changed.emit(0, total_count)
	for index in range(mini(count, maximum_alive)):
		if not spawn_enemy():
			break
	return true

func stop() -> void:
	active = false
	enabled = false
	$SpawnTimer.stop()

func reset_encounter() -> void:
	stop()
	_living.clear()
	_positions.clear()
	total_count = 0
	pending_count = 0
	defeated_count = 0
	for enemy in container.get_children():
		container.remove_child(enemy)
		enemy.queue_free()

func spawn_enemy() -> bool:
	if not active or not enabled or pending_count <= 0 or _living.size() >= maximum_alive:
		return false
	var indices := range(_positions.size())
	indices.shuffle()
	var shape := CircleShape2D.new()
	shape.radius = clearance_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 7
	for index in indices:
		var location := _positions[index]
		if location.distance_to(player.global_position) < minimum_player_distance:
			continue
		# New bodies may not be visible to physics queries until the next frame.
		var occupied := false
		for enemy in _living.values():
			if location.distance_to(enemy.global_position) < clearance_radius * 2.0:
				occupied = true
				break
		if occupied:
			continue
		query.transform = Transform2D(0.0, location)
		if not player.get_world_2d().direct_space_state.intersect_shape(query).is_empty():
			continue
		var chosen_scene: PackedScene = enemy_scene
		if not enemy_variants.is_empty():
			var variant: PackedScene = enemy_variants.pick_random()
			if variant != null:
				chosen_scene = variant
		var enemy = chosen_scene.instantiate()
		enemy.position = container.to_local(location)
		enemy.target = player
		enemy.navigation_room = $"../RoomTransition".active_room
		container.add_child(enemy)
		_living[enemy.get_instance_id()] = enemy
		pending_count -= 1
		enemy.defeated.connect(_enemy_defeated, CONNECT_ONE_SHOT)
		enemy_spawned.emit(enemy)
		if pending_count == 0:
			enabled = false
			$SpawnTimer.stop()
		return true
	return false

func _enemy_defeated(enemy: Node) -> void:
	if not active or not _living.erase(enemy.get_instance_id()):
		return
	defeated_count += 1
	progress_changed.emit(defeated_count, total_count)
	if pending_count == 0 and _living.is_empty():
		stop()
		encounter_cleared.emit()
