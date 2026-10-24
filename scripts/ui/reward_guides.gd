extends Control
## Screen-space indicators revealed when exits unlock.

const Bubble = preload("res://scripts/ui/reward_bubble.gd")

@export var rewards: Node
@export var player: Node2D
@export_range(0.2, 1.0, 0.05) var distant_scale: float = 0.45
@export_range(0.2, 1.0, 0.05) var nearby_scale: float = 0.7
@export var nearby_distance: float = 120.0
@export var distant_distance: float = 900.0
var _bubbles: Array[Bubble] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rewards.choices_unlocked.connect(_show_offers)
	rewards.offers_cleared.connect(_clear)
	set_process(false)


func _show_offers() -> void:
	_clear()
	var offers: Array[Dictionary] = rewards.guide_offers()
	for offer in offers:
		var bubble := Bubble.new()
		add_child(bubble)
		bubble.configure(offer)
		bubble.pressed.connect(_approach_door.bind(bubble.door))
		bubble.hide()
		_bubbles.append(bubble)
		var marker := bubble.door.get_node_or_null("RewardMarker") as CanvasItem
		if marker != null:
			marker.hide()
	set_process(not _bubbles.is_empty())


func _approach_door(door: Node2D) -> void:
	var transition := rewards.get_parent().get_node("RoomTransition")
	transition.teleport_to_reward.call_deferred(door)


func _clear() -> void:
	for bubble in _bubbles:
		bubble.hide()
		bubble.queue_free()
	_bubbles.clear()
	set_process(false)


func _process(delta: float) -> void:
	if not is_instance_valid(player) or player.get_node("Health").dead:
		_clear()
		return
	# Reserve margins for the largest possible size so the edge stays fixed
	# as the distance changes.
	var largest := maxf(distant_scale, nearby_scale)
	var margin := Vector2(100.0, 44.0) * largest + Vector2(8.0, 8.0)
	var bottom := 90.0 * largest + 8.0
	var bounds := Rect2(margin, Vector2(maxf(1.0, size.x - margin.x * 2.0), maxf(1.0, size.y - margin.y - bottom)))
	var active: Array[Bubble] = []
	var targets: Array[Vector2] = []
	var centers: Array[Vector2] = []
	var scales: Array[float] = []
	var to_hud := get_global_transform_with_canvas().affine_inverse()
	for bubble in _bubbles:
		if not is_instance_valid(bubble.door) or bubble.door.is_queued_for_deletion():
			bubble.hide()
			continue
		if bubble.door.locked or not bubble.door.enabled:
			bubble.hide()
			continue
		bubble.show()
		var marker := bubble.door.get_node_or_null("RewardMarker") as Node2D
		var world_anchor: Node2D = marker if marker != null else bubble.door
		var target: Vector2 = to_hud * world_anchor.get_global_transform_with_canvas().origin
		var distance := player.global_position.distance_to(bubble.door.global_position)
		var proximity := 1.0 - smoothstep(nearby_distance, maxf(nearby_distance + 1.0, distant_distance), distance)
		active.append(bubble)
		targets.append(target)
		centers.append(_edge_position(target, bounds))
		scales.append(lerpf(distant_scale, nearby_scale, proximity))
	_separate(centers, scales, bounds)
	for index in range(active.size()):
		active[index].place(targets[index], centers[index], scales[index], delta)


func _edge_position(target: Vector2, bounds: Rect2) -> Vector2:
	if bounds.has_point(target):
		return target
	var center := bounds.get_center()
	var direction := target - center
	var half := bounds.size * 0.5
	var ratio := minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
	return center + direction * minf(1.0, ratio)


func _separate(centers: Array[Vector2], scales: Array[float], bounds: Rect2) -> void:
	# Small offsets between neighbors replace the old grid search,
	# which jumped between cells.
	for iteration in range(16):
		for a in range(centers.size()):
			for b in range(a + 1, centers.size()):
				var first := Rect2(centers[a] - Bubble.ICON_CENTER * scales[a], Bubble.BUBBLE_SIZE * scales[a]).grow(3.0)
				var second := Rect2(centers[b] - Bubble.ICON_CENTER * scales[b], Bubble.BUBBLE_SIZE * scales[b]).grow(3.0)
				if not first.intersects(second):
					continue
				var overlap := first.intersection(second).size
				var difference := second.get_center() - first.get_center()
				var push := Vector2.ZERO
				if overlap.x < overlap.y:
					push.x = (overlap.x + 1.0) * (1.0 if difference.x >= 0.0 else -1.0)
				else:
					push.y = (overlap.y + 1.0) * (1.0 if difference.y >= 0.0 else -1.0)
				var previous := centers[a]
				centers[a] = (centers[a] - push * 0.5).clamp(bounds.position, bounds.end)
				var remaining := push + (centers[a] - previous)
				var previous_b := centers[b]
				centers[b] = (centers[b] + remaining).clamp(bounds.position, bounds.end)
				centers[a] = (centers[a] - (remaining - (centers[b] - previous_b))).clamp(bounds.position, bounds.end)
