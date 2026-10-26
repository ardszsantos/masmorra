extends SceneTree

const TRIANGULAR = preload("res://scenes/triangular.tscn")
const ROOM = preload("res://scenes/generated_room.tscn")
const Rules = preload("res://scripts/gameplay/piece_rules.gd")
const Triangle = preload("res://scripts/gameplay/triangular.gd")
const GeneratedRoom = preload("res://scripts/gameplay/generated_room.gd")

var failures: int = 0
var checks: int = 0
var world: Node2D


func _init() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func settle() -> void:
	await physics_frame
	await physics_frame


func make_world() -> void:
	if is_instance_valid(world):
		world.free()
	world = Node2D.new()
	root.add_child(world)


func make_enemy(location: Vector2, room: GeneratedRoom = null) -> Triangle:
	var enemy := TRIANGULAR.instantiate() as Triangle
	enemy.position = location
	enemy.navigation_room = room
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.get_node("MeleeAttack").set_physics_process(false)
	return enemy


func make_wall(location: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = location
	wall.collision_layer = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)


func path_length(origin: Vector2, path: PackedVector2Array) -> float:
	var length: float = 0.0
	var previous := origin
	for point in path:
		length += previous.distance_to(point)
		previous = point
	return length


func exercise_lap(enemy: Triangle, label: String) -> void:
	var route := enemy._route
	check(not route.circuit.is_empty(), label + ": must have a patrol")
	if route.circuit.is_empty():
		return
	var origin: Vector2 = route.vertices[0]
	var length := path_length(origin, route.circuit)
	var approach_length := path_length(enemy.global_position, route.approach)
	check(length >= enemy.circuit_side * 1.5, label + ": must not shrink to a miniature circuit")
	var steps := ceili((length + approach_length) / enemy.speed * 30.0) + 60
	var start_laps: int = enemy._completed_laps
	var original_circuit := route.circuit.duplicate()
	var largest_step: float = 0.0
	for step in range(steps):
		var previous := enemy.global_position
		enemy._physics_process(1.0 / 30.0)
		largest_step = maxf(largest_step, previous.distance_to(enemy.global_position))
		if route.circuit.is_empty():
			break
		if enemy._completed_laps > start_laps:
			break
	check(enemy._completed_laps > start_laps, label + ": must finish its loop without hitting walls")
	check(route.circuit == original_circuit, label + ": must retain the same loop")
	check(largest_step <= enemy.speed / 30.0 + 0.02, label + ": must never burst or accelerate")


func run() -> void:
	await test_autonomous_triangle()
	await test_near_wall()
	await test_narrow_corridor()
	await test_freeze_and_shutdown()
	world.free()
	print("Triangular patrol: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func test_autonomous_triangle() -> void:
	make_world()
	var enemy := make_enemy(Vector2.ZERO)
	var other := make_enemy(Vector2.ZERO)
	var player := CharacterBody2D.new()
	player.collision_layer = 4
	world.add_child(player)
	enemy.target = player
	await settle()
	enemy._physics_process(0.0)
	other._physics_process(0.0)
	check(enemy._route.vertices.size() == 3, "Open ground must produce three triangle vertices")
	check(enemy._route.circuit.size() == 3, "Open ground must use three straight sides")
	for index in range(3):
		var side: float = enemy._route.vertices[index].distance_to(enemy._route.vertices[(index + 1) % 3])
		check(is_equal_approx(side, enemy.circuit_side), "Every open-ground side must retain the full configured length")
	var largest_difference: float = 0.0
	for step in range(450):
		player.position = Vector2.from_angle(float(step) * 0.2) * 300.0
		enemy._physics_process(1.0 / 30.0)
		other._physics_process(1.0 / 30.0)
		largest_difference = maxf(largest_difference, enemy.global_position.distance_to(other.global_position))
	check(largest_difference < 0.01, "Player movement or absence must not change the patrol")
	check(enemy._completed_laps >= 2, "Triangle must repeat without recovery or wind-up")
	check(enemy.speed == 120.0, "Triangle must use a moderate obstacle speed")
	check(enemy.get_node("Visual").frame == 0, "Patrol must not use attack poses")
	check(not enemy.get_node("RouteFeedback")._announced, "Patrol must not announce attacks at the player")


func test_near_wall() -> void:
	make_world()
	make_wall(Vector2(100, -100), Vector2(20, 400))
	var enemy := make_enemy(Vector2.ZERO)
	await settle()
	enemy._physics_process(0.0)
	check(enemy._route.vertices.size() == 3, "Nearby wall must allow a rotated full-sized triangle")
	for index in range(enemy._route.vertices.size()):
		var side: float = enemy._route.vertices[index].distance_to(enemy._route.vertices[(index + 1) % 3])
		check(is_equal_approx(side, enemy.circuit_side), "Wall fitting must rotate or relocate instead of shrinking")
	exercise_lap(enemy, "Nearby wall")
	exercise_lap(enemy, "Repeated wall-safe loop")


func test_narrow_corridor() -> void:
	make_world()
	var room := ROOM.instantiate() as GeneratedRoom
	world.add_child(room)
	room.floor_layer.clear()
	room.wall_layer.clear()
	var floor_cells: Dictionary = {}
	for y in range(26):
		for x in range(26):
			if y < 5 or x >= 21:
				var cell := Vector2i(x, y)
				floor_cells[cell] = true
				room.floor_layer.set_cell(cell, 0, Vector2i.ZERO)
	room._walkable_cells = Rules.spacious_cells(floor_cells)
	room._close_void_edges(floor_cells)
	room.floor_layer.update_internals()
	room.wall_layer.update_internals()
	var location := room.floor_layer.to_global(room.floor_layer.map_to_local(Vector2i(2, 2)))
	var enemy := make_enemy(location, room)
	await settle()
	enemy._physics_process(0.0)
	check(not enemy._route.circuit.is_empty(), "Narrow rooms must still provide a substantial patrol")
	exercise_lap(enemy, "L-shaped corridor")
	exercise_lap(enemy, "Repeated corridor patrol")


func test_freeze_and_shutdown() -> void:
	make_world()
	var enemy := make_enemy(Vector2.ZERO)
	await settle()
	enemy._physics_process(0.1)
	var location := enemy.global_position
	enemy.apply_freeze(1.0)
	enemy._physics_process(0.5)
	check(enemy.global_position == location, "Freeze must pause the patrol")
	enemy.get_node("FreezeStatus").clear()
	enemy._physics_process(0.1)
	check(enemy.global_position.distance_to(location) > 1.0, "Patrol must resume after freeze without rebuilding a small circuit")
	enemy.take_damage(1.0)
	check(not enemy.get_node("HitReaction").is_stunned(), "Normal damage must not turn an obstacle into a reactive enemy")
	enemy.stop_combat()
	location = enemy.global_position
	enemy._physics_process(1.0)
	check(enemy.global_position == location, "Game over must stop the patrol")
	check(not enemy.get_node("MeleeAttack").is_physics_processing(), "Stopping combat must disable contact damage")
	enemy.take_damage(1000.0)
	check(enemy.health.dead, "Obstacle must remain killable")
	for frame in range(60):
		await physics_frame
		if not is_instance_valid(enemy):
			break
	check(not is_instance_valid(enemy), "Dead obstacle must finish cleanup")


