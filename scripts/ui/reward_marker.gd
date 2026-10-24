extends Node2D

const Reward = preload("res://scripts/gameplay/room_reward.gd")


func show_reward(reward: Reward, next_level: int) -> void:
	$Icon.texture = reward.icon
	$Icon.modulate = Color.WHITE
	var icon_size: Vector2 = reward.icon.get_size()
	$Icon.scale = Vector2.ONE * 48.0 / maxf(icon_size.x, icon_size.y)
	var detail := "Nv. %d" % next_level if reward.kind == Reward.Kind.UPGRADE else "+%d" % int(reward.amount)
	$Title.text = "%s\n%s · %s" % [reward.display_name, reward.world_name(), detail]
	$Title.modulate = reward.color
