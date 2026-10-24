extends SceneTree
var failures: int = 0
func _init() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func wait_for_despawn(enemy: Node) -> void:
	for attempt in range(120):
		await physics_frame
		if not is_instance_valid(enemy):
			return
	check(false, "Defeated enemies must finish their death animation and leave the tree")

func run() -> void:
	var main = preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var player = main.get_node("Player")
	var stamina = player.get_node("Stamina")
	var health = player.get_node("Health")
	var abilities = player.get_node("Abilities")
	var spawner = main.get_node("EnemySpawner")
	# This suite covers the original pursuer's melee range, stun and knockback.
	spawner.enemy_scene = preload("res://scenes/enemy.tscn")
	var session = main.get_node("GameSession")
	check(not spawner.enabled, "Lobby without spawn points must not start spawning")
	check(spawner.get_node("SpawnTimer").is_stopped(), "Lobby must not run the spawn timer")
	spawner.spawn_enemy()
	check(main.get_node("Enemies").get_child_count() == 0, "Lobby must stay empty without spawn points")
	# Isolated finite encounter for testing combat without depending on the lobby layout.
	spawner.maximum_alive = 1
	player.set_physics_process(false)
	stamina.set_physics_process(false)
	await physics_frame
	await physics_frame
	spawner.begin_encounter(PackedVector2Array([Vector2(10000, 10000)]), 3)
	# This test advances each wave explicitly; the timer is covered by the survival suite.
	spawner.get_node("SpawnTimer").stop()
	spawner.spawn_enemy()
	check(main.get_node("Enemies").get_child_count() == 1, "Configured arena must allow spawning")
	var enemy = main.get_node("Enemies").get_child(0)
	enemy.set_physics_process(false)
	enemy.get_node("MeleeAttack").set_physics_process(false)
	enemy.global_position = player.global_position + Vector2(60, 0)
	await physics_frame
	await physics_frame
	abilities.request_action(&"stroke_turn", Vector2.RIGHT)
	check(stamina.current == 80.0, "Slash must cost 20")
	abilities.step(0.1)
	check(enemy.get_node("Health").current == 20.0, "Slash must deal 20 damage")
	check(enemy.get_node("HitReaction").is_stunned(), "Enemy must enter hitstun")
	check(enemy.get_node("HitReaction").impulse.x > 0.0, "Enemy must recoil away from attacker")
	check(enemy.get_node("Visual").self_modulate.g < 0.5, "Enemy must flash red")
	abilities.step(0.2)
	check(enemy.get_node("Health").current == 20.0, "Slash must hit each enemy only once")
	abilities.request_action(&"stroke_turn", Vector2.RIGHT)
	abilities.step(0.3)
	check(session.score == 1, "Death must award exactly one point")
	enemy.take_damage(100.0)
	check(session.score == 1, "Repeated lethal damage must not double score")
	await wait_for_despawn(enemy)
	spawner.spawn_enemy()
	check(main.get_node("Enemies").get_child_count() == 1, "Spawn must continue after death")
	enemy = main.get_node("Enemies").get_child(0)
	enemy.set_physics_process(false)
	enemy.get_node("MeleeAttack").set_physics_process(false)
	enemy.global_position = player.global_position + Vector2(35, 0)
	await physics_frame
	await physics_frame
	enemy.get_node("MeleeAttack")._physics_process(0.01)
	check(health.current == 90.0, "Enemy attack must damage player")
	check(player.get_node("Visual").self_modulate.g < 0.5, "Player must flash red")
	check(player.get_node("HitReaction").impulse.x < 0.0, "Player must recoil away from enemy")
	abilities.request_action(&"stroke_turn", Vector2.RIGHT)
	check(not abilities.get_node("Slash").active, "Hitstun must block attacks")
	enemy.get_node("MeleeAttack")._physics_process(0.01)
	check(health.current == 90.0, "Attack cooldown must prevent frame damage")
	player.get_node("HitReaction").resolve_velocity(Vector2.ZERO, 0.3)
	abilities.request_action(&"double_flick", Vector2.RIGHT)
	abilities.step(0.1)
	check(enemy.get_node("Health").dead, "Dash must kill with one hit")
	await wait_for_despawn(enemy)
	var flash: Tween = player.get_node("HitReaction")._flash
	if flash != null and flash.is_running():
		await flash.finished
	check(player.get_node("Visual").self_modulate.is_equal_approx(Color.WHITE), "Flash must restore player color")
	abilities.step(0.2)
	stamina.current = 5.0
	abilities.request_action(&"stroke_turn", Vector2.RIGHT)
	check(not abilities.get_node("Slash").active and stamina.current == 5.0, "Insufficient stamina must reject attack")
	abilities.update_sustained_action(&"circle", 1.0)
	abilities.step(0.1)
	check(is_equal_approx(stamina.current, 2.5), "Spin must drain 25 per second")
	abilities.step(0.2)
	check(not abilities.get_node("Spin").active and stamina.current == 0.0, "Exhaustion must end spin")
	check(abilities.resolve_velocity(Vector2(100, 0), 0.01) == Vector2(100, 0), "Exhaustion must preserve walking")
	stamina._physics_process(0.5)
	check(stamina.current == 0.0, "Recovery must respect delay")
	stamina._physics_process(1.0)
	check(is_equal_approx(stamina.current, 10.0), "Recovery must restore 20 per second after delay")
	check(main.get_node("HUD/StatusHud/Stats/StaminaBar").value == stamina.current, "Stamina HUD must track resource")
	spawner.spawn_enemy()
	var nuke_target = main.get_node("Enemies").get_child(main.get_node("Enemies").get_child_count() - 1)
	nuke_target.set_physics_process(false)
	nuke_target.get_node("MeleeAttack").set_physics_process(false)
	var stamina_before_nuke: float = stamina.current
	abilities.request_action(&"cross_nuke", Vector2.ZERO)
	check(nuke_target.get_node("Health").dead, "Cross nuke must kill enemies anywhere on the map")
	check(stamina.current == stamina_before_nuke, "Cross nuke must not spend stamina")
	spawner.spawn_enemy()
	check(not spawner.enabled and spawner.get_node("SpawnTimer").is_stopped(), "Exhausting the finite quota must stop spawning")
	health._invulnerability = 0.0
	player.take_damage(1000.0)
	check(session.ended and not spawner.enabled, "Death must end match and spawning")
	check(abilities.disabled and not player.is_physics_processing(), "Death must stop player and abilities")
	var count: int = main.get_node("Enemies").get_child_count()
	spawner.spawn_enemy()
	check(main.get_node("Enemies").get_child_count() == count, "Game over must block spawn")
	main.free()
	print("Gameplay tests: ", failures, " failures")
	quit(1 if failures else 0)
