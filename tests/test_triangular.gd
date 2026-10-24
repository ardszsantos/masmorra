extends SceneTree

const TRIANGULAR = preload("res://scenes/triangular.tscn")
const PLAYER = preload("res://scenes/player.tscn")
const MAIN = preload("res://scenes/main.tscn")
var failures: int = 0
var checks: int = 0
var world: Node2D
var player: CharacterBody2D


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


func make_enemy(location := Vector2.ZERO):
	var enemy = TRIANGULAR.instantiate()
	enemy.position = location
	enemy.target = player
	world.add_child(enemy)
	return enemy


func make_wall(location: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = location
	wall.collision_layer = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	return wall


func run() -> void:
	seed(20261016)
	world = Node2D.new()
	root.add_child(world)
	player = PLAYER.instantiate()
	player.position = Vector2(5000, 5000)
	world.add_child(player)
	player.set_physics_process(false)
	player.get_node("Stamina").set_physics_process(false)
	await settle()
	await test_burst()
	await test_player_abilities()
	await test_contact()
	await test_obstacles()
	world.free()
	await test_encounter()
	print("Triangular tests: %d failures / %d checks" % [failures, checks])
	quit(1 if failures else 0)


func test_burst() -> void:
	player.global_position = Vector2(1000, 0)
	var enemy = make_enemy()
	await settle()
	check(enemy.phase == enemy.Phase.HUNT and enemy.position.x > 0.0, "Distant player must trigger pursuit")
	enemy.set_physics_process(false)
	enemy.global_position = Vector2.ZERO
	player.global_position = Vector2(180, 0)
	await settle()
	enemy._physics_process(0.01)
	check(enemy.phase == enemy.Phase.WINDUP, "Nearby player must trigger a telegraphed dash")
	var committed: Vector2 = enemy._dash_direction
	var marker: Vector2 = enemy.get_node("RouteFeedback")._destination
	player.global_position = Vector2(180, 100)
	enemy._physics_process(0.05)
	check(enemy._dash_direction == committed and enemy.get_node("RouteFeedback")._destination == marker, "Wind-up must not track a dodge")
	enemy._physics_process(enemy.first_windup)
	check(enemy.phase == enemy.Phase.RUSH, "Wind-up must start the rush")
	var before: float = enemy.health.current
	enemy.take_damage(1.0)
	check(enemy.health.current == before - 1.0, "Rush must remain vulnerable")
	check(not enemy.get_node("HitReaction").is_stunned() and enemy.get_node("HitReaction").impulse == Vector2.ZERO, "Hits must not stun or knock back the triangle")
	enemy._physics_process(0.05)
	check(enemy._dash_direction == committed and is_zero_approx(enemy.position.y), "Rush must not steer toward the moving player")
	for dash in range(enemy.dashes_per_burst):
		if dash > 0:
			check(enemy.phase == enemy.Phase.WINDUP, "Each follow-up needs a wind-up")
			var toward: Vector2 = (player.global_position - enemy.global_position).normalized()
			check(enemy._dash_direction.is_equal_approx(toward), "Follow-up must aim at the player's new position")
			enemy._physics_process(enemy.followup_windup)
		for step in range(120):
			enemy._physics_process(1.0 / 60.0)
			if enemy.phase != enemy.Phase.RUSH:
				break
	check(enemy._dash_count == 3 and enemy.phase == enemy.Phase.RECOVER, "Three dashes must lead to recovery")
	var recovery_position: Vector2 = enemy.position
	enemy._physics_process(enemy.recovery_duration * 0.5)
	check(enemy.phase == enemy.Phase.RECOVER and enemy.position == recovery_position, "Recovery must leave a punish window")
	enemy._physics_process(enemy.recovery_duration)
	check(enemy.phase == enemy.Phase.HUNT and enemy._dash_count == 0, "Recovery must reset the burst")
	enemy.stop_combat()
	check(not enemy.is_physics_processing() and not enemy.get_node("MeleeAttack").is_physics_processing(), "Stopping combat must stop movement and contact")
	check(not enemy.get_node("RouteFeedback")._announced, "Stopping combat must clear feedback")
	enemy.free()
	player.global_position = Vector2(5000, 5000)


func test_player_abilities() -> void:
	var abilities = player.get_node("Abilities")
	var enemy = make_enemy(player.global_position + Vector2(60, 0))
	enemy.stop_combat()
	await settle()
	abilities.request_action(&"stroke_turn", Vector2.RIGHT)
	abilities.step(0.3)
	check(enemy.health.current == 20.0, "Actual slash must damage Triangular")
	check(not enemy.get_node("HitReaction").is_stunned(), "Slash must not stun Triangular")
	abilities.request_action(&"double_flick", Vector2.RIGHT)
	abilities.step(0.1)
	check(enemy.health.dead, "Actual dash must kill Triangular")
	abilities.step(0.2)
	enemy.free()
	enemy = make_enemy(player.global_position + Vector2(60, 0))
	enemy.stop_combat()
	await settle()
	abilities.update_sustained_action(&"circle", 1.0)
	abilities.step(0.1)
	check(enemy.health.current == enemy.health.maximum - 40.0, "Actual spin must damage Triangular")
	abilities.interrupt()
	enemy.free()
	enemy = make_enemy(player.global_position + Vector2(500, 0))
	enemy.stop_combat()
	await settle()
	abilities.request_action(&"cross_nuke", Vector2.ZERO)
	check(enemy.health.dead, "Actual nuke must find Triangular in the enemies group")
	enemy.free()


func test_contact() -> void:
	var enemy = make_enemy()
	enemy.set_physics_process(false)
	var attack = enemy.get_node("MeleeAttack")
	var health = player.get_node("Health")
	health.current = health.maximum
	health._invulnerability = 0.0
	var player_offset: Vector2 = player.get_node("Collision").position
	player.global_position = Vector2(80, 0) - player_offset
	await settle()
	check(health.current == health.maximum, "Proximity alone must not cause damage")
	player.global_position = Vector2(34.5, 0) - player_offset
	await settle()
	check(health.current == health.maximum - attack.damage, "Body overlap must deal damage")
	check(not player.get_node("HitReaction").is_stunned(), "Contact must not stun the player")
	check(player.get_node("HitReaction").impulse == Vector2.ZERO, "Contact must not knock the player back")
	var after_contact: float = health.current
	await settle()
	check(health.current == after_contact, "Continuous contact must respect the hit interval")
	attack._remaining = 0.0
	attack.try_hit(player)
	check(health.current == after_contact, "Player invulnerability must reject repeated damage")
	player.global_position = Vector2(120, 0) - player_offset
	attack._remaining = 0.0
	health._invulnerability = 0.0
	enemy._dash_direction = Vector2.RIGHT
	enemy._dash_distance = 240.0
	enemy.phase = enemy.Phase.RUSH
	enemy._dash_start = Vector2.ZERO
	enemy._rush_speed = 1500.0
	enemy.speed = 1500.0
	await settle()
	enemy._physics_process(0.1)
	check(health.current == after_contact - attack.damage, "Swept rush must hit across a large physics step")
	check(enemy.global_position.x > 120.0 and enemy.phase == enemy.Phase.RUSH, "Contact must not block or interrupt the rush")
	player.global_position = Vector2(400, 0) - player_offset
	enemy.global_position = Vector2(500, 0)
	enemy.get_node("RouteFeedback").announce(Vector2(400, 0))
	enemy.get_node("RouteFeedback").rush(Vector2(300, 0), Vector2(500, 0))
	attack._remaining = 0.0
	health._invulnerability = 0.0
	var before_trail: float = health.current
	await settle()
	check(health.current == before_trail, "Trail and marker must never deal damage")
	enemy.take_damage(1000.0)
	check(enemy.health.dead and not attack.is_physics_processing(), "Death must disable contact immediately")
	check(not enemy.get_node("RouteFeedback")._announced and not enemy.get_node("RouteFeedback")._rushing, "Death must clear feedback")
	for frame in range(60):
		await physics_frame
		if not is_instance_valid(enemy):
			break
	check(not is_instance_valid(enemy), "Triangular must finish death and despawn")
	player.global_position = Vector2(5000, 5000)


func test_obstacles() -> void:
	player.global_position = Vector2(180, 0)
	var enemy = make_enemy()
	enemy.set_physics_process(false)
	var wall := make_wall(Vector2(120, 0), Vector2(20, 100))
	await settle()
	check(not enemy._can_attack(), "Wall must prevent winding up into a blocked player")
	enemy.phase = enemy.Phase.RUSH
	enemy._dash_direction = Vector2.RIGHT
	enemy._dash_distance = 300.0
	enemy._dash_start = Vector2.ZERO
	enemy._rush_speed = enemy.speed
	enemy._physics_process(0.2)
	check(enemy.phase == enemy.Phase.HUNT and enemy.position.x < 120.0, "Wall collision must end this dash and resume pursuit")
	check(enemy._dash_count == 1 and not enemy.get_node("RouteFeedback")._announced, "Wall impact must consume a dash and clear feedback")
	wall.free()
	enemy.free()
	# Fits the existing body, but not the old triangular route.
	var top := make_wall(Vector2(150, -40), Vector2(700, 10))
	var bottom := make_wall(Vector2(150, 40), Vector2(700, 10))
	enemy = make_enemy()
	await settle()
	for frame in range(90):
		await physics_frame
		if enemy.position.x > 100.0:
			break
	check(enemy.position.x > 100.0, "Narrow corridor must allow attacking without a triangular route")
	enemy.free()
	top.free()
	bottom.free()
	enemy = make_enemy()
	enemy.set_physics_process(false)
	var other = make_enemy(Vector2(80, 0))
	other.stop_combat()
	await settle()
	check(not enemy.test_move(enemy.global_transform, Vector2(200, 0)), "Triangles must pass through players and other triangles")
	check(not player.test_move(player.global_transform, Vector2(-200, 0)), "Player must also pass through triangles")
	enemy.free()
	other.free()
	player.global_position = Vector2(5000, 5000)


func test_encounter() -> void:
	var main = MAIN.instantiate()
	root.add_child(main)
	var session = main.get_node("GameSession")
	var spawner = main.get_node("EnemySpawner")
	var transition = main.get_node("RoomTransition")
	var hero = main.get_node("Player")
	hero.set_physics_process(false)
	transition.door.body_entered.emit(hero)
	for frame in range(30):
		await physics_frame
		if session.room_number == 1:
			break
	check(session.room_number == 1 and transition.active_room.exit_door.locked, "Generated encounter must start locked")
	check(spawner.enemy_scene == TRIANGULAR, "Main scene must spawn Triangular")
	await settle()
	for enemy in main.get_node("Enemies").get_children():
		check(enemy.has_method("_prepare_dash"), "Encounter must contain the burst attacker")
		check(enemy.collision_mask == 1 and enemy.collision_layer == 8, "Triangle must collide only with walls while remaining attackable")
		check(enemy.navigation_room == transition.active_room, "Spawner room contract must be preserved")
		var before: float = enemy.health.current
		enemy.take_damage(20.0, hero.global_position)
		check(enemy.health.current == before - 20.0 and not enemy.get_node("HitReaction").is_stunned(), "Player damage must work without stunning")
		enemy.take_damage(1000.0)
	check(session.score == 3 and session.room_cleared, "Three defeats must count once and clear the encounter")
	check(not transition.active_room.exit_door.locked, "Deaths must unlock the exit")
	transition.door.body_entered.emit(hero)
	for frame in range(30):
		await physics_frame
		if session.room_number == 2:
			break
	await settle()
	hero.get_node("Health")._invulnerability = 0.0
	hero.take_damage(10000.0)
	check(session.ended, "Player death must end the session")
	for enemy in main.get_node("Enemies").get_children():
		check(not enemy.is_physics_processing() and not enemy.get_node("MeleeAttack").is_physics_processing(), "Game over must stop every Triangular")
		check(not enemy.get_node("RouteFeedback")._announced, "Game over must remove every marker")
	main.free()
