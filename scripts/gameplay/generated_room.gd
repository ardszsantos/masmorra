extends Node2D
## Instantiate geometry assembled by the rules shared with the builder.
const Rules = preload("res://scripts/gameplay/piece_rules.gd")
const TileArt = preload("res://scripts/gameplay/tile_art.gd")

@export_group("Tiles")
@export var floor_source_id: int = 0
@export var floor_atlas_coords := Vector2i.ZERO
@export var wall_source_id: int = 1
@export var wall_atlas_coords := Vector2i.ZERO

@export_group("Floor Appearance")
@export var floor_art_seed: int = 0
@export_range(0.0, 1.0, 0.01) var floor_wear_coverage: float = 0.2
@export_range(1, 5, 1) var floor_patch_radius: int = 2

var layout_id: String = ""
var layout_name: String = ""
var generated_size := Vector2i.ZERO
var generated: bool = false
var exit_doors: Array[Area2D] = []
var _walkable_cells: Dictionary = {}
var _manual_enemy_positions := PackedVector2Array()
var _void_boundary: StaticBody2D
var _path_target := Vector2i(2147483647, 2147483647)
var _path_steps: Dictionary = {}
@onready var floor_layer: TileMapLayer = $Floor
@onready var wall_layer: TileMapLayer = $Walls
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var exit_door: Area2D = $Door
@onready var destination_marker: Marker2D = $Destination


func build_from_layout(layout: Dictionary) -> bool:
	generated = false
	_path_steps.clear()
	_path_target = Vector2i(2147483647, 2147483647)
	if not _tiles_are_valid() or not layout.has("_walkable_cells"):
		return false
	for index in range(1, exit_doors.size()):
		exit_doors[index].free()
	exit_doors.clear()
	if is_instance_valid(_void_boundary):
		_void_boundary.free()
	floor_layer.clear()
	wall_layer.clear()
	layout_id = layout.id
	layout_name = layout.name
	generated_size = Vector2i(layout.width, layout.height)
	for y in range(layout.height):
		var row: String = layout.rows[y]
		for x in range(layout.width):
			var cell := Vector2i(x, y)
			match row.substr(x, 1):
				"1": floor_layer.set_cell(cell, floor_source_id, floor_atlas_coords)
				"2": wall_layer.set_cell(cell, wall_source_id, wall_atlas_coords)
	TileArt.apply(floor_layer, wall_layer, hash(layout_id) + floor_art_seed,
		floor_wear_coverage, floor_patch_radius)
	_walkable_cells = layout._walkable_cells
	_manual_enemy_positions.clear()
	for point: Array in layout.get("enemy_spawns", []):
		_manual_enemy_positions.append(_world_position(Vector2i(int(point[0]), int(point[1]))))
	spawn_point.global_position = _world_position(layout._spawn_cell)
	destination_marker.global_position = spawn_point.global_position
	exit_door.set_locked(false)
	for index in range(layout.exits.size()):
		var portal: Area2D = exit_door
		if index > 0:
			portal = exit_door.duplicate() as Area2D
			portal.name = "Door%d" % (index + 1)
			add_child(portal)
		var point: Array = layout.exits[index]
		portal.global_position = _world_position(Vector2i(int(point[0]), int(point[1])))
		exit_doors.append(portal)
	set_exits_locked(true)
	_close_void_edges(layout._floor_cells)
	floor_layer.update_internals()
	wall_layer.update_internals()
	generated = true
	return true


func set_exits_locked(value: bool) -> void:
	for portal in exit_doors:
		portal.set_locked(value)


func enemy_spawn_positions(start_distance: float, door_distance: float) -> PackedVector2Array:
	if not _manual_enemy_positions.is_empty():
		return _manual_enemy_positions.duplicate()
	var positions := PackedVector2Array()
	for cell: Vector2i in _walkable_cells:
		var location := _world_position(cell)
		if location.distance_to(spawn_point.global_position) < start_distance:
			continue
		var near_exit := false
		for portal in exit_doors:
			if location.distance_to(portal.global_position) < door_distance:
				near_exit = true
				break
		if not near_exit:
			positions.append(location)
	return positions


func reward_approach_position(portal: Area2D, player: CharacterBody2D) -> Vector2:
	# The door's visual front is below it. If a wall blocks that spot,
	# find the nearest free floor position outside every door trigger.
	var preferred := portal.global_position + Vector2.DOWN * 80.0
	var candidates: Array[Vector2] = [preferred]
	for cell: Vector2i in _walkable_cells:
		var point := _world_position(cell)
		if point.distance_to(portal.global_position) <= 180.0:
			candidates.append(point)
	var collision := player.get_node("Collision") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.collision_mask = 1
	query.collide_with_areas = true
	query.margin = 8.0
	query.exclude = [player.get_rid()]
	var best := Vector2(INF, INF)
	var score: float = INF
	var space := get_world_2d().direct_space_state
	for point in candidates:
		var distance := point.distance_squared_to(preferred)
		if distance >= score:
			continue
		var cell := floor_layer.local_to_map(floor_layer.to_local(point))
		if not _walkable_cells.has(cell):
			continue
		query.transform = collision.global_transform
		query.transform.origin += point - player.global_position
		if not space.intersect_shape(query).is_empty():
			continue
		var ray := PhysicsRayQueryParameters2D.create(point, portal.global_position, 1)
		if not space.intersect_ray(ray).is_empty():
			continue
		best = point
		score = distance
	return best


func _world_position(cell: Vector2i) -> Vector2:
	return floor_layer.to_global(floor_layer.map_to_local(cell))


## One search shared by all enemies, rebuilt when the target changes tiles.
func pursuit_point(origin: Vector2, target: Vector2) -> Vector2:
	var target_cell := floor_layer.local_to_map(floor_layer.to_local(target))
	if target_cell != _path_target:
		_path_target = target_cell
		var goal := _nearest_walkable(target_cell)
		_path_steps = {goal: goal}
		var queue: Array[Vector2i] = [goal]
		var cursor := 0
		while cursor < queue.size():
			var cell := queue[cursor]
			cursor += 1
			for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				var neighbor := cell + direction
				if _walkable_cells.has(neighbor) and not _path_steps.has(neighbor):
					_path_steps[neighbor] = cell
					queue.append(neighbor)
	var from := floor_layer.local_to_map(floor_layer.to_local(origin))
	if not _walkable_cells.has(from):
		return _world_position(_nearest_walkable(from))
	var next: Vector2i = _path_steps.get(from, from)
	return target if next == from else _world_position(next)


func _nearest_walkable(cell: Vector2i) -> Vector2i:
	if _walkable_cells.has(cell):
		return cell
	var nearest := cell
	var distance := INF
	for candidate: Vector2i in _walkable_cells:
		var candidate_distance := Vector2(candidate - cell).length_squared()
		if candidate_distance < distance:
			distance = candidate_distance
			nearest = candidate
	return nearest


func navigation_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for cell: Vector2i in _walkable_cells:
		points.append(_world_position(cell))
	return points


func navigation_path(origin: Vector2, destination: Vector2) -> PackedVector2Array:
	# Reuse the same walkable cells and reverse search as ordinary pursuit.
	pursuit_point(origin, destination)
	var from := _nearest_walkable(floor_layer.local_to_map(floor_layer.to_local(origin)))
	var goal := _nearest_walkable(floor_layer.local_to_map(floor_layer.to_local(destination)))
	var points := PackedVector2Array()
	if not _path_steps.has(from):
		return points
	points.append(_world_position(from))
	while from != goal:
		var next: Vector2i = _path_steps.get(from, from)
		if next == from:
			return PackedVector2Array()
		from = next
		points.append(_world_position(from))
	points.append(destination)
	return points


func _close_void_edges(floor_cells: Dictionary) -> void:
	# Empty space has no artwork, but must not become a walkable exit from the map.
	_void_boundary = StaticBody2D.new()
	_void_boundary.name = "VoidBoundary"
	_void_boundary.collision_layer = wall_layer.tile_set.get_physics_layer_collision_layer(0)
	_void_boundary.collision_mask = wall_layer.tile_set.get_physics_layer_collision_mask(0)
	floor_layer.add_child(_void_boundary)
	var border := {}
	for cell: Vector2i in floor_cells:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var neighbor := cell + Vector2i(dx, dy)
				if not floor_cells.has(neighbor) and wall_layer.get_cell_source_id(neighbor) == -1:
					border[neighbor] = true
	var shape := RectangleShape2D.new()
	shape.size = Vector2(floor_layer.tile_set.tile_size)
	for cell: Vector2i in border:
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = floor_layer.map_to_local(cell)
		_void_boundary.add_child(collision)


func _tiles_are_valid() -> bool:
	if not _has_tile(floor_layer.tile_set, floor_source_id, floor_atlas_coords):
		push_error("GeneratedRoom: configure o tile de Floor no Inspector.")
		return false
	if not _has_tile(wall_layer.tile_set, wall_source_id, wall_atlas_coords):
		push_error("GeneratedRoom: configure o tile de Walls no Inspector.")
		return false
	if floor_layer.tile_set.tile_size != Vector2i.ONE * Rules.TILE_SIZE:
		push_error("GeneratedRoom: o contrato de peças usa tiles de 32 × 32 px.")
		return false
	if floor_layer.tile_set.tile_size != wall_layer.tile_set.tile_size or not floor_layer.transform.is_equal_approx(wall_layer.transform):
		push_error("GeneratedRoom: Floor e Walls precisam do mesmo tamanho de célula e Transform.")
		return false
	if wall_layer.tile_set.get_physics_layers_count() == 0:
		push_error("GeneratedRoom: Walls precisa de uma camada de colisão.")
		return false
	return true


func _has_tile(tiles: TileSet, source_id: int, atlas_coords: Vector2i) -> bool:
	if tiles == null or not tiles.has_source(source_id):
		return false
	var source := tiles.get_source(source_id) as TileSetAtlasSource
	return source != null and source.has_tile(atlas_coords)
