extends SceneTree

var failures: int = 0
const MAIN = preload("res://scenes/main.tscn")

func _init() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func freeze_enemy(enemy: Node) -> void:
	enemy.set_physics_process(false)
	enemy.get_node("MeleeAttack").set_physics_process(false)

func wait_for_room(session: Node, number: int) -> void:
	for attempt in range(20):
		await physics_frame
		if session.room_number == number:
			return
	check(false, "Room transition did not complete")

func run() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	var player = main.get_node("Player")
	var session = main.get_node("GameSession")
	var transition = main.get_node("RoomTransition")
	var spawner = main.get_node("EnemySpawner")
	var enemies = main.get_node("Enemies")
	var health = player.get_node("Health")
	var stamina = player.get_node("Stamina")
	var stats = main.get_node("HUD/StatusHud/Stats")
	player.set_physics_process(false)
	stamina.set_physics_process(false)
	spawner.maximum_alive = 2
	spawner.enemy_spawned.connect(freeze_enemy)
	check(enemies.get_child_count() == 0 and not spawner.active, "Lobby must have no encounter")
	transition.door.body_entered.emit(player)
	await wait_for_room(session, 1)
	for number in range(1, 11):
		var room = transition.active_room
		var target_count: int = 3 + (number - 1) * 2
		check(session.room_number == number and spawner.total_count == target_count, "Enemy quota must increase by two each room")
		check(room.exit_door.locked, "Room must begin with a locked door")
		check(enemies.get_child_count() <= 2 and spawner.pending_count > 0, "Alive cap must leave enemies pending without dropping the quota")
		room.exit_door.body_entered.emit(player)
		await physics_frame
		check(transition.active_room == room, "Locked door must not advance rooms")
		var locations := PackedVector2Array()
		for enemy in enemies.get_children():
			check(enemy.global_position.distance_to(player.global_position) >= spawner.minimum_player_distance, "Enemies must spawn outside player safety distance")
			check(enemy.global_position.distance_to(room.exit_door.global_position) >= spawner.minimum_door_distance, "Enemies must leave door clearance")
			for previous in locations:
				check(previous.distance_to(enemy.global_position) >= spawner.clearance_radius * 2.0, "Initial enemies must not overlap")
			locations.append(enemy.global_position)
		health.current = 50.0
		var before_completed: int = session.completed_rooms
		# Kill the first wave while withholding all future spawns.
		spawner.get_node("SpawnTimer").stop()
		for enemy in enemies.get_children():
			enemy.take_damage(1000.0)
		check(room.exit_door.locked and not session.room_cleared, "Zero living enemies must not clear a room while spawns are pending")
		check(health.current == 50.0, "An unfinished quota must not heal the player")
		for attempt in range(300):
			if not spawner.active:
				break
			await physics_frame
			spawner.spawn_enemy()
			for enemy in enemies.get_children():
				if not enemy.get_node("Health").dead:
					enemy.take_damage(1000.0)
		check(session.completed_rooms == before_completed + 1 and session.room_cleared, "Exactly one clear must be counted after the full quota")
		check(not room.exit_door.locked and not spawner.active and spawner.pending_count == 0, "Cleared room must unlock and stop spawning")
		var expected_max := 100.0 + floori(number / 5.0) * 20.0
		check(health.maximum == expected_max and stamina.maximum == expected_max, "Stats must increase only on clears five and ten")
		check(is_equal_approx(health.current, 50.0 + expected_max * 0.2), "Clear must heal 20 percent of maximum health")
		check(stats.get_node("HealthBar").max_value == expected_max and stats.get_node("StaminaBar").max_value == expected_max, "HUD must follow stat upgrades")
		check(not stats.get_node("RewardLabel").text.is_empty(), "Room clear must display healing feedback")
		check(stats.get_node("RewardLabel").text.contains("Bônus") == (number % 5 == 0), "Milestone upgrades must be shown on the HUD")
		var healed: float = health.current
		spawner.encounter_cleared.emit()
		check(health.current == healed and session.completed_rooms == number, "Duplicate clear signals must not duplicate heals or rewards")
		check(not spawner.spawn_enemy(), "Cleared rooms must never replenish enemies")
		if number < 10:
			room.exit_door.body_entered.emit(player)
			room.exit_door.body_entered.emit(player)
			await wait_for_room(session, number + 1)
			await process_frame
			check(not is_instance_valid(room), "Previous room must be freed during transition")
			check(main.get_node("Rooms").get_child_count() == 1, "Only one room may remain after transition")
			check(health.maximum == expected_max and health.current == healed, "Stats and health must persist through the door")
	# Death with both surviving and pending enemies must stop the complete loop.
	transition.door.body_entered.emit(player)
	await wait_for_room(session, 11)
	health._invulnerability = 0.0
	player.take_damage(10000.0)
	for enemy in enemies.get_children():
		enemy.take_damage(10000.0)
	spawner.encounter_cleared.emit()
	transition.door.body_entered.emit(player)
	await physics_frame
	check(session.ended and transition.stopped and not spawner.active, "Death must stop encounters and transitions")
	check(session.room_number == 11 and session.completed_rooms == 10 and health.current == 0.0, "Death must not award completion, heal or advance")
	main.free()
	print("Survival loop tests: ", failures, " failures (10 clears, rewards, finite waves, death)")
	quit(1 if failures else 0)
