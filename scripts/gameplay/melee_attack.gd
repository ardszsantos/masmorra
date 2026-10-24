extends Node2D
@export var damage: float = 10.0

func _physics_process(_delta: float) -> void:
	if get_parent().has_method("is_frozen") and get_parent().is_frozen():
		return
	if get_parent().get_node("HitReaction").is_stunned() or not $AttackCooldown.is_stopped():
		return
	for body in $AttackRange.get_overlapping_bodies():
		if not body.has_method("take_damage"):
			continue
		var ray := PhysicsRayQueryParameters2D.create(get_parent().global_position, body.global_position, 1)
		if not body.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		body.take_damage(damage, get_parent().global_position)
		$AttackCooldown.start()
		break
