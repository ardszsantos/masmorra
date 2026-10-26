extends SceneTree

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const MAIN_SCENE = preload("res://scenes/main.tscn")
const ROOM_SCENE = preload("res://scenes/generated_room.tscn")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/gameplay/enemy.gd")
const Controller = preload("res://scripts/upgrades/upgrade_controller.gd")
const Passive = preload("res://scripts/upgrades/passive_upgrade.gd")
const Reward = preload("res://scripts/gameplay/room_reward.gd")
const Targets = preload("res://scripts/upgrades/upgrade_targets.gd")
const Plasma = preload("res://scripts/upgrades/plasma_projectile.gd")
const Shuriken = preload("res://scripts/upgrades/shuriken_projectile.gd")
const Fire = preload("res://scripts/upgrades/fire_area.gd")
const Wave = preload("res://scripts/upgrades/gorgon_wave.gd")

var failures: int = 0
var checks: int = 0
var world: Node2D
var actor: Player
var upgrades: Controller


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


func setup_arena() -> void:
	if is_instance_valid(world):
		world.free()
	world = Node2D.new()
	root.add_child(world)
	actor = PLAYER_SCENE.instantiate() as Player
	actor.position = Vector2(200, 400)
	world.add_child(actor)
	actor.get_node("Camera2D").enabled = false
	actor.set_physics_process(false)
	actor.get_node("Visual").set_physics_process(false)
	upgrades = actor.get_node("Upgrades") as Controller
	upgrades.set_combat_context(world, true)
	await settle()


func make_enemy(offset: Vector2) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = actor.position + offset
	enemy.get_node("Health").maximum = 1000.0
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.get_node("MeleeAttack").set_physics_process(false)
	enemy.get_node("FreezeStatus").set_physics_process(false)
	return enemy


func make_wall(position: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = position
	wall.collision_layer = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	return wall


func grant(id: StringName) -> Passive:
	var reward := load("res://resources/rewards/%s.tres" % id) as Reward
	check(upgrades.grant_upgrade(reward), "Upgrade must equip: %s" % id)
	var effect := upgrades._equipped[id] as Passive
	effect.set_physics_process(false)
	return effect


func effects(effect_script: Script) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for node in world.get_children():
		if node.get_script() == effect_script and not node.is_queued_for_deletion():
			result.append(node as Node2D)
	return result


func run() -> void:
	await test_laser_and_walls()
	await test_generated_room_separation()
	await test_gorgon_levels_and_cone()
	await test_fire_barrier()
	await test_shuriken_interception()
	await test_directional_attachments()
	await test_effect_lifecycle()
	world.free()
	await test_real_encounter()
	print("Upgrade combat: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func test_laser_and_walls() -> void:
	await setup_arena()
	var hidden := make_enemy(Vector2(200, 0))
	make_wall(actor.position + Vector2(100, 0), Vector2(24, 200))
	var laser := grant(&"laser")
	await settle()
	laser._physics_process(0.02)
	check(effects(Plasma).is_empty(), "Laser must not fire through a separating wall")
	check(laser._remaining == 0.0, "Blocked laser must preserve its ready cooldown")
	check(not Targets.clear_path(actor, hidden.global_position), "Wall must block shared target visibility")
	var exposed := make_enemy(Vector2(0, 180))
	await settle()
	laser._physics_process(0.02)
	var shots := effects(Plasma)
	check(shots.size() == 1, "Laser must choose an exposed enemy instead of a blocked one")
	if not shots.is_empty():
		var shot := shots[0] as Plasma
		shot.set_physics_process(false)
		shot._physics_process(0.5)
	check(exposed.health.current < exposed.health.maximum, "Laser must actually damage its reachable target")
	check(hidden.health.current == hidden.health.maximum, "Enemy behind the wall must remain unharmed")
	var ally := grant(&"triangelo")
	ally.global_position = hidden.global_position - Vector2(30, 0)
	ally._physics_process(0.0)
	check(ally._phase == ally.Phase.FOLLOW, "Detached ally must not acquire a target hidden from the player")


func test_gorgon_levels_and_cone() -> void:
	await setup_arena()
	var group: Array[Enemy] = [
		make_enemy(Vector2(120, 0)),
		make_enemy(Vector2(160, 20)),
		make_enemy(Vector2(200, -20)),
		make_enemy(Vector2(240, 0)),
	]
	var outside := make_enemy(Vector2(0, 160))
	var hidden := make_enemy(Vector2(250, 100))
	make_wall(actor.position + Vector2(210, 84), Vector2(16, 55))
	var gorgon := grant(&"gorgon")
	await settle()
	for rank in range(1, 4):
		gorgon.set_level(rank)
		gorgon._remaining = 0.0
		for enemy in group:
			enemy.get_node("FreezeStatus").clear()
		gorgon._physics_process(0.01)
		var waves := effects(Wave)
		check(waves.size() == 1, "Ready gorgon must emit one directional wave")
		if waves.is_empty():
			continue
		var wave := waves[0] as Wave
		wave.set_physics_process(false)
		wave._physics_process(wave.duration)
		var frozen: int = 0
		for enemy in group:
			if enemy.is_frozen():
				frozen += 1
		check(frozen == rank + 1, "Gorgon level %d must freeze exactly %d enemies" % [rank, rank + 1])
		check(not outside.is_frozen(), "Enemy outside the cone must not freeze")
		check(not hidden.is_frozen(), "Enemy behind a wall must not freeze")
		await settle()
	await setup_arena()
	make_enemy(Vector2(200, 0))
	make_wall(actor.position + Vector2(100, 0), Vector2(24, 180))
	gorgon = grant(&"gorgon")
	await settle()
	gorgon._physics_process(0.01)
	check(effects(Wave).is_empty() and gorgon._remaining == 0.0, "Blocked gorgon must preserve its charge")


func test_generated_room_separation() -> void:
	for with_walls in [true, false]:
		await setup_arena()
		var room := ROOM_SCENE.instantiate()
		world.add_child(room)
		room.floor_layer.clear()
		room.wall_layer.clear()
		var floor_cells: Dictionary = {}
		for y in range(9, 16):
			for x in range(1, 14):
				if x <= 5 or x >= 9:
					var cell := Vector2i(x, y)
					floor_cells[cell] = true
					room.floor_layer.set_cell(cell, 0, Vector2i.ZERO)
			if with_walls:
				room.wall_layer.set_cell(Vector2i(6, y), 1, Vector2i.ZERO)
				room.wall_layer.set_cell(Vector2i(8, y), 1, Vector2i.ZERO)
		room._close_void_edges(floor_cells)
		room.floor_layer.update_internals()
		room.wall_layer.update_internals()
		room.global_position += actor.global_position - room.floor_layer.to_global(room.floor_layer.map_to_local(Vector2i(5, 12)))
		var enemy := make_enemy(Vector2.ZERO)
		enemy.global_position = room.floor_layer.to_global(room.floor_layer.map_to_local(Vector2i(9, 12)))
		var laser := grant(&"laser")
		var gorgon := grant(&"gorgon")
		var shuriken := grant(&"shuriken")
		shuriken._charge = float(shuriken.capacity())
		await settle()
		laser._physics_process(0.01)
		gorgon._physics_process(0.01)
		shuriken._physics_process(0.0)
		check(not Targets.clear_path(actor, enemy.global_position), "Generated walls or void boundaries must separate sections")
		check(effects(Plasma).is_empty() and effects(Wave).is_empty() and effects(Shuriken).is_empty(), "No upgrade may trigger across wall-gap-wall or bare void")
		check(shuriken._charge == shuriken.capacity(), "Generated section separation must preserve shuriken charge")


func test_fire_barrier() -> void:
	await setup_arena()
	var ring := grant(&"fire_ring")
	ring._physics_process(0.01)
	check(effects(Fire).is_empty() and ring._remaining == 0.0, "Fire barrier must wait without an enemy")
	var enemy := make_enemy(Vector2(150, 0))
	await settle()
	ring._physics_process(0.01)
	check(effects(Fire).is_empty(), "Enemy outside the fire's actual reach must not trigger it")
	enemy.position = actor.position + Vector2(110, 0)
	var wall := make_wall(actor.position + Vector2(55, 0), Vector2(12, 160))
	await settle()
	ring._physics_process(0.01)
	check(effects(Fire).is_empty(), "Enemy across a wall must not trigger the barrier")
	wall.free()
	await settle()
	ring._physics_process(0.01)
	var fires := effects(Fire)
	check(fires.size() == 1 and ring._remaining > 0.0, "Actual edge contact must activate the barrier")
	if not fires.is_empty():
		var fire := fires[0] as Fire
		fire.set_physics_process(false)
		fire._physics_process(0.01)
		check(enemy.health.current < enemy.health.maximum, "Activating the barrier must reach and damage its trigger")
		actor.position += Vector2(0, 15)
		fire._physics_process(0.01)
		check(fire.global_position.is_equal_approx(actor.global_position), "Active barrier must follow the player")
	await setup_arena()
	ring = grant(&"fire_ring")
	enemy = make_enemy(Vector2(0, 40))
	enemy.get_node("Collision").scale = Vector2(2.4, 1.4)
	await settle()
	ring._physics_process(0.01)
	check(effects(Fire).is_empty(), "A wide enemy wholly inside the ring's hole must not trigger it")


func test_shuriken_interception() -> void:
	await setup_arena()
	var enemy := make_enemy(Vector2(200, 0))
	var wall := make_wall(actor.position + Vector2(100, 0), Vector2(24, 200))
	var shuriken := grant(&"shuriken")
	shuriken._charge = float(shuriken.capacity())
	await settle()
	shuriken._physics_process(0.0)
	check(effects(Shuriken).is_empty() and shuriken._charge == shuriken.capacity(), "Blocked shurikens must preserve the full charge")
	wall.free()
	enemy.position = actor.position + Vector2(500, 0)
	await settle()
	shuriken._physics_process(0.0)
	check(effects(Shuriken).is_empty(), "Enemy beyond useful firing range must not consume shurikens")
	enemy.position = actor.position + Vector2(200, 0)
	enemy.velocity = Vector2(1000, 0)
	await settle()
	shuriken._physics_process(0.0)
	check(effects(Shuriken).is_empty(), "An impossible interception must preserve shurikens")
	enemy.velocity = Vector2(0, 120)
	shuriken._physics_process(0.0)
	var shots := effects(Shuriken)
	check(shots.size() == shuriken.capacity(), "Reachable moving target must trigger the charged volley")
	for shot in shots:
		shot.set_physics_process(false)
	if not shots.is_empty():
		check((shots[0] as Shuriken)._direction.y > 0.0, "First shuriken must lead the target's movement")
	for step in range(50):
		enemy.position += enemy.velocity * 0.01
		await settle()
		for shot in shots:
			if is_instance_valid(shot) and not shot.is_queued_for_deletion():
				shot._physics_process(0.01)
	check(enemy.health.current < enemy.health.maximum, "A moving target must actually be hit by the volley")
	var ranged := Shuriken.new()
	ranged.maximum_distance = 640.0
	ranged.speed = 700.0
	ranged.lifetime = 2.0
	world.add_child(ranged)
	ranged.set_physics_process(false)
	ranged.launch(Vector2(0, 900), Vector2.RIGHT, actor)
	ranged._physics_process(1.0)
	check(ranged.global_position.is_equal_approx(Vector2(640, 900)), "Shuriken must stop at its configured travel range")
	check(ranged.is_queued_for_deletion(), "Shuriken must despawn at maximum range")


func test_directional_attachments() -> void:
	await setup_arena()
	var jetpack := grant(&"jetpack")
	var laser := grant(&"laser")
	var gorgon := grant(&"gorgon")
	var visual := actor.get_node("Visual")
	var back := visual.get_node("BackSocket") as Node2D
	var hand := visual.get_node("HandSocket") as Node2D
	var eye := visual.get_node("EyeSocket") as Node2D
	upgrades.set_combat_context(world, false)
	for index in range(8):
		var direction := Vector2.from_angle(float(index) * TAU / 8.0)
		visual._face_direction(direction)
		check(jetpack.global_position.is_equal_approx(back.global_position), "Jetpack must follow back socket in direction %d" % index)
		check(laser.global_position.is_equal_approx(hand.global_position), "Laser must follow hand socket in direction %d" % index)
		check(gorgon.global_position.is_equal_approx(eye.global_position), "Eye must follow head socket in direction %d" % index)
		check(is_equal_approx(cos(laser.global_rotation - direction.angle()), 1.0), "Idle laser must follow facing in direction %d" % index)
	visual._face_direction(Vector2.DOWN)
	check(jetpack.z_index < visual.z_index, "Front-facing body must occlude the jetpack")
	visual._face_direction(Vector2.UP)
	check(jetpack.z_index > visual.z_index, "Back-facing body must show the jetpack")
	visual.animation = &"walk_n"
	visual.stop()
	visual.frame = 0
	var idle_position := jetpack.global_position
	visual.frame = 1
	check(not jetpack.global_position.is_equal_approx(idle_position), "Equipment must follow the walk animation's bob")
	check(jetpack.global_position.is_equal_approx(back.global_position), "Walk bob must preserve back alignment")
	visual.rotation = PI * 0.5
	await process_frame
	check(jetpack.global_position.is_equal_approx(back.global_position), "Equipment must follow the spin transform")
	check(is_equal_approx(jetpack.global_rotation, back.global_rotation), "Jetpack must rotate with the player's visual")


func test_effect_lifecycle() -> void:
	await setup_arena()
	make_enemy(Vector2(120, 0))
	var gorgon := grant(&"gorgon")
	await settle()
	gorgon._physics_process(0.01)
	check(effects(Wave).size() == 1, "Lifecycle fixture must create an active wave")
	upgrades.remove_upgrade(&"gorgon")
	await settle()
	check(effects(Wave).is_empty(), "Removing gorgon must clean up its active wave")
	var jetpack := grant(&"jetpack")
	var dash := actor.get_node("Abilities/Dash")
	dash.try_activate(Vector2.RIGHT)
	jetpack._on_ability_started(dash)
	check(not effects(Fire).is_empty(), "Jetpack dash must create its owned fire")
	upgrades.set_combat_context(world, false)
	await settle()
	check(effects(Fire).is_empty(), "Leaving combat must clear owned fire effects")
	check(jetpack._dash == null, "Leaving combat must stop jetpack trail sampling")
	dash.cancel()


func test_real_encounter() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	var transition := main.get_node("RoomTransition")
	check(transition.start_run(), "Current start-run flow must create an encounter")
	for frame in range(60):
		await physics_frame
		if main.get_node("GameSession").room_number == 1:
			break
	check(main.get_node("GameSession").room_number == 1, "Actual generated encounter must start")
	var build := main.get_node("Player/Upgrades") as Controller
	for id in [&"laser", &"gorgon", &"fire_ring", &"shuriken", &"jetpack", &"triangelo"]:
		var reward := load("res://resources/rewards/%s.tres" % id) as Reward
		check(build.grant_upgrade(reward), "Actual encounter must accept upgrade %s" % id)
	for frame in range(120):
		await physics_frame
	check(build.level_of(&"gorgon") == 1 and build.level_of(&"laser") == 1, "Build must remain equipped during live combat")
	main.get_node("Player/Health").take_damage(10000.0)
	await settle()
	check(main.get_node("GameSession").ended, "Death must stop the live encounter")
	for effect in transition.active_room.get_children():
		check(not effect.is_in_group("upgrade_effects"), "Game over must remove upgrade effects")
	main.free()
