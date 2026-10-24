extends "res://scripts/abilities/player_ability.gd"
## Instant map-wide attack granted as a regular runtime-removable ability.

@export var damage: float = 1000000.0
@export var flash_radius: float = 900.0

func try_activate(_direction: Vector2) -> bool:
	var player := get_parent().get_parent()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(damage, player.global_position)
	_show_flash(player)
	return true

func _show_flash(player: Node2D) -> void:
	var ring := Line2D.new()
	ring.width = 22.0
	ring.default_color = Color(0.75, 0.93, 1.0, 0.95)
	ring.global_position = player.global_position
	var points := PackedVector2Array()
	for index in range(65):
		points.append(Vector2.from_angle(float(index) / 64.0 * TAU) * flash_radius)
	ring.points = points
	ring.scale = Vector2.ONE * 0.03
	player.get_parent().add_child(ring)
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE, 0.35)
	tween.tween_property(ring, "modulate:a", 0.0, 0.45)
	tween.chain().tween_callback(ring.queue_free)
