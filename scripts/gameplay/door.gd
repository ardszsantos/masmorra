extends Area2D

## A controller can prepare a room before transferring the player.
signal travel_requested(body: CharacterBody2D)

## Arrival point outside other door triggers to prevent chained teleports.
@export var destination: Marker2D
@export var enabled: bool = true
@export var locked: bool = false
@export var locked_color := Color(0.45, 0.45, 0.45, 1.0)

var _teleport_pending: bool = false
var _original_color := Color.WHITE


func _ready() -> void:
	var visual := get_node_or_null("Sprite2D") as Sprite2D
	if visual != null:
		_original_color = visual.modulate
	set_locked(locked)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not enabled or locked or _teleport_pending:
		return
	if not body is CharacterBody2D or not body.is_in_group("player"):
		return
	if travel_requested.has_connections():
		travel_requested.emit(body)
		return
	if not is_instance_valid(destination):
		push_warning("Door: configure Destination com um Marker2D no Inspector.")
		return
	_teleport_pending = true
	# Wait for the physics query to finish before repositioning the player.
	_teleport.call_deferred(body)


func _teleport(body: CharacterBody2D) -> void:
	if enabled and not locked and is_instance_valid(body) and is_instance_valid(destination):
		body.global_position = destination.global_position
		body.velocity = Vector2.ZERO
		body.reset_physics_interpolation()
	_teleport_pending = false


func set_locked(value: bool) -> void:
	locked = value
	var visual := get_node_or_null("Sprite2D") as Sprite2D
	if visual != null:
		visual.modulate = _original_color * locked_color if locked else _original_color
	var status := get_node_or_null("Status") as Label
	if status != null:
		status.text = "Trancada" if locked else "Próxima sala"
