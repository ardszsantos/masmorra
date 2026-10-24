extends SceneTree

const ROOM = preload("res://scenes/generated_room.tscn")
const MAIN = preload("res://scenes/main.tscn")
const Assembler = preload("res://scripts/gameplay/piece_assembler.gd")
const Rules = preload("res://scripts/gameplay/piece_rules.gd")
const LIBRARY_PATH := "res://piece-libraries/survival.piece_library.json"
var failures: int = 0


func _init() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func run() -> void:
	var assembler = Assembler.new()
	check(assembler.load_file(LIBRARY_PATH), "The new bundled library must load")
	if assembler.pieces.is_empty():
		quit(1)
		return
	test_catalog(assembler)
	var room = ROOM.instantiate()
	root.add_child(room)
	for attempt in range(12):
		var layout: Dictionary = assembler.assemble()
		check(not layout.is_empty(), "Accepted library must assemble on every request")
		check(room.build_from_layout(layout), "Every authored layout must build")
		check(room.layout_id == layout.id, "Room identity must come from the deck")
		check(room.generated_size == Vector2i(layout.width, layout.height), "Dimensions must not be randomized")
		check(room.exit_doors.size() == layout.exits.size(), "Every authored exit must be instantiated")
		for y in range(layout.height):
			for x in range(layout.width):
				var cell := Vector2i(x, y)
				var tile: String = layout.rows[y].substr(x, 1)
				check((room.floor_layer.get_cell_source_id(cell) != -1) == (tile == "1"), "Floor must match authored data exactly")
				check((room.wall_layer.get_cell_source_id(cell) != -1) == (tile == "2"), "Wall art must match authored data exactly")
		for index in range(layout.exits.size()):
			var point: Array = layout.exits[index]
			var expected: Vector2 = room.floor_layer.to_global(room.floor_layer.map_to_local(Vector2i(point[0], point[1])))
			check(room.exit_doors[index].global_position.is_equal_approx(expected), "Exit position must match the marker")
		room.set_exits_locked(false)
		for portal: Area2D in room.exit_doors:
			check(not portal.locked, "All exits must unlock together")
		room.set_exits_locked(true)
		for portal: Area2D in room.exit_doors:
			check(portal.locked, "All exits must lock together")
		var spawn_locations: PackedVector2Array = room.enemy_spawn_positions(140, 96)
		check(not spawn_locations.is_empty(), "Bundled rooms must have enemy spawn space")
		for location in spawn_locations:
			for portal: Area2D in room.exit_doors:
				check(location.distance_to(portal.global_position) >= 96.0, "Spawns must avoid every exit")
		await physics_frame
		await physics_frame
		check_wall_physics(room)
	room.free()
	await test_transition()
	print("Piece generation integration tests: ", failures, " failures")
	quit(1 if failures else 0)


func test_catalog(assembler: RefCounted) -> void:
	var previous_count: int = assembler.pieces.size()
	check(not assembler.load_text("{}"), "Unrelated JSON is rejected")
	check(not assembler.load_text("{"), "Malformed JSON is rejected")
	check(assembler.pieces.size() == previous_count, "Rejected imports preserve the working catalog")
	check(not assembler.assemble().is_empty(), "The previous library still assembles after a failed import")
	var pooled = Assembler.new()
	check(pooled.load_folder("res://piece-libraries"), "Folder loading finds playable libraries")
	var exported := "C:/Users/Admin/Documents/RoomBuilder/test-output/builder-export.piece_library.json"
	if FileAccess.file_exists(exported):
		var from_builder = Assembler.new()
		check(from_builder.load_file(exported), "The actual builder export is accepted by the game")
		check(not from_builder.assemble().is_empty(), "The actual builder export can generate a room")
	else:
		check(false, "Run the builder workflow test to supply an actual export")


func check_wall_physics(room: Node2D) -> void:
	var space := room.get_world_2d().direct_space_state
	var origin: Vector2 = room.spawn_point.global_position
	for index in range(32):
		var ray := PhysicsRayQueryParameters2D.create(origin, origin + Vector2.from_angle(TAU * index / 32.0) * 10000.0, 1)
		check(not space.intersect_ray(ray).is_empty(), "Authored rooms must retain physical boundaries")
	var shape := CircleShape2D.new()
	shape.radius = 24.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, origin)
	query.collision_mask = 1
	check(space.intersect_shape(query).is_empty(), "Arrival must have clearance for the player")


func test_transition() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	var transition = main.get_node("RoomTransition")
	var player = main.get_node("Player")
	player.set_physics_process(false)
	player.get_node("Stamina").set_physics_process(false)
	var door = main.get_node("Rooms/Room/Door")
	var rooms = main.get_node("Rooms")
	var old_lobby = main.get_node("Rooms/Room")
	var health = player.get_node("Health")
	health.current = 75.0
	var ability_count: int = player.get_node("Abilities").get_child_count()
	var other_body := CharacterBody2D.new()
	door.body_entered.emit(other_body)
	check(transition.active_room == null, "Only the player may trigger room changes")
	other_body.free()
	door.body_entered.emit(player)
	door.body_entered.emit(player)
	for attempt in range(10):
		await physics_frame
		if main.get_node("GameSession").room_number == 1:
			break
	var arena = transition.active_room
	check(is_instance_valid(arena), "Door must load an assembled room")
	if is_instance_valid(arena):
		check(player.global_position.is_equal_approx(arena.spawn_point.global_position), "Arrival must use the generated entrance")
		check_wall_physics(arena)
	check(not is_instance_valid(old_lobby), "Previous room must be released")
	check(rooms.get_child_count() == 1, "Duplicate door events must not create duplicate rooms")
	check(health.current == 75.0, "Room changes must preserve health")
	check(player.get_node("Abilities").get_child_count() == ability_count, "Room changes must preserve equipped abilities")
	check(main.get_node("EnemySpawner").total_count == 3, "The existing encounter progression must be preserved")
	if is_instance_valid(arena):
		for portal: Area2D in arena.exit_doors:
			check(portal.locked, "Every new exit must be locked during combat")
	main.free()
