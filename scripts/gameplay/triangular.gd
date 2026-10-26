extends "res://scripts/gameplay/enemy.gd"
## Predictable obstacle: repeat a room-owned patrol without reacting to the player.

const PatrolRoute = preload("res://scripts/gameplay/triangular_patrol_route.gd")
const Room = preload("res://scripts/gameplay/generated_room.gd")
const ContactDamage = preload("res://scripts/gameplay/contact_damage.gd")
const Feedback = preload("res://scripts/gameplay/triangular_feedback.gd")
const MINIMUM_CIRCUIT_SIDE: float = 240.0
const ROUTE_RETRY_INTERVAL: float = 0.5
const WAYPOINT_EPSILON: float = 0.5

@export_range(240.0, 600.0, 10.0) var circuit_side: float = 280.0
@export_range(0.0, 360.0, 15.0) var circuit_angle: float = 0.0
@export var clockwise: bool = true

var _route: PatrolRoute = PatrolRoute.new()
var _waypoint_index: int = 0
var _joining_circuit: bool = false
var _retry_remaining: float = 0.0
var _stopped: bool = false
var _completed_laps: int = 0
@onready var _visual: AnimatedSprite2D = $Visual
@onready var _collision: CollisionShape2D = $Collision
@onready var _contact: ContactDamage = $MeleeAttack
@onready var _feedback: Feedback = $RouteFeedback


func _ready() -> void:
	super._ready()
	_visual.stop()
	_visual.frame = 0
	_feedback.clear()


func _physics_process(delta: float) -> void:
	if health.dead or _stopped or is_frozen():
		velocity = Vector2.ZERO
		return
	if _route.circuit.is_empty():
		_retry_remaining = maxf(0.0, _retry_remaining - delta)
		if _retry_remaining > 0.0 or not _build_route():
			return
	var remaining_distance := maxf(0.0, speed * delta)
	var waypoint_budget := _route.approach.size() + _route.circuit.size() + 1
	while remaining_distance > WAYPOINT_EPSILON and waypoint_budget > 0:
		var points := _route.approach if _joining_circuit else _route.circuit
		var offset := points[_waypoint_index] - global_position
		if offset.length() <= WAYPOINT_EPSILON:
			_advance_waypoint(points.size())
			waypoint_budget -= 1
			continue
		var direction := offset.normalized()
		var travel := minf(remaining_distance, offset.length())
		velocity = direction * speed
		_visual.rotation = direction.angle()
		var start_transform := _collision.global_transform
		var start_position := global_position
		var collision := move_and_collide(direction * travel)
		_contact.sweep(start_transform, global_position - start_position)
		if health.dead or _stopped or is_queued_for_deletion():
			return
		if collision != null:
			# Rebuild for changed geometry instead of repeatedly bumping the same wall.
			_route.circuit.clear()
			_route.approach.clear()
			_retry_remaining = ROUTE_RETRY_INTERVAL
			velocity = Vector2.ZERO
			return
		remaining_distance = maxf(0.0, remaining_distance - travel)
		if travel >= offset.length() - WAYPOINT_EPSILON:
			_advance_waypoint(points.size())
			waypoint_budget -= 1


func _build_route() -> bool:
	velocity = Vector2.ZERO
	# Resolve an initial overlap before using this position as a patrol origin.
	move_and_collide(Vector2.ZERO)
	var room := navigation_room as Room
	if not _route.build(self, room, maxf(MINIMUM_CIRCUIT_SIDE, circuit_side), deg_to_rad(circuit_angle), clockwise):
		_retry_remaining = ROUTE_RETRY_INTERVAL
		return false
	_waypoint_index = 0
	_joining_circuit = not _route.approach.is_empty()
	return true


func _advance_waypoint(point_count: int) -> void:
	_waypoint_index += 1
	if _waypoint_index < point_count:
		return
	_waypoint_index = 0
	if _joining_circuit:
		_joining_circuit = false
	else:
		_completed_laps += 1


func stop_combat() -> void:
	super.stop_combat()
	_stopped = true
	_visual.frame = 0
	_feedback.clear()


func _die() -> void:
	stop_combat()
	super._die()
