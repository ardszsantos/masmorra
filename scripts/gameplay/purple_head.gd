extends "res://scripts/gameplay/enemy.gd"
## Pursue, commit to three separately aimed dashes, then expose a recovery window.
enum Phase { HUNT, WINDUP, RUSH, RECOVER, STOPPED }

@export_group("Visual")
@export var visual_height: float = 90.0

@export_group("Hunt")
@export_range(50.0, 600.0, 10.0) var pursuit_speed: float = 220.0
@export_range(80.0, 600.0, 10.0) var attack_range: float = 300.0
@export_range(0.05, 1.0, 0.05) var wall_reposition_time: float = 0.2

@export_group("Dash burst")
@export_range(1, 6, 1) var dashes_per_burst: int = 3
@export_range(0.1, 1.5, 0.05) var first_windup: float = 0.35
@export_range(0.1, 1.5, 0.05) var followup_windup: float = 0.22
@export_range(0.1, 2.0, 0.05) var recovery_duration: float = 0.65
@export_range(100.0, 10000.0, 50.0) var acceleration: float = 5000.0
@export_range(0.0, 250.0, 10.0) var overshoot_distance: float = 100.0
@export_range(40.0, 600.0, 10.0) var minimum_dash_distance: float = 140.0
@export_range(80.0, 1000.0, 10.0) var maximum_dash_distance: float = 480.0

var phase: Phase = Phase.HUNT
var _dash_count: int = 0
var _remaining: float = 0.0
var _rush_speed: float = 0.0
var _dash_distance: float = 0.0
var _dash_direction := Vector2.RIGHT
var _dash_start := Vector2.ZERO
var _facing_angle: float = 0.0
@onready var _collision: CollisionShape2D = $Collision
@onready var _feedback = $RouteFeedback
@onready var _contact = $MeleeAttack
@onready var _visual: AnimatedSprite2D = $Visual
@onready var _dash_particles: CPUParticles2D = $DashParticles


func _ready() -> void:
	super._ready()
	_visual.stop()
	_visual.animation = &"default"
	_visual.frame = 0
	_facing_angle = _visual.global_rotation
	phase = Phase.RECOVER
	_remaining = recovery_duration
	_update_visual(0.0)


func _physics_process(delta: float) -> void:
	if health.dead or phase == Phase.STOPPED:
		return
	if is_frozen():
		_dash_particles.emitting = false
		velocity = Vector2.ZERO
		return
	if not is_instance_valid(target):
		_enter_hunt()
		return
	match phase:
		Phase.HUNT:
			_remaining = maxf(0.0, _remaining - delta)
			_hunt(delta)
		Phase.WINDUP:
			_remaining = maxf(0.0, _remaining - delta)
			if _remaining <= 0.0:
				phase = Phase.RUSH
				_visual.frame = 2
				_feedback.set_contracting(false)
				_dash_start = global_position
				_rush_speed = 0.0
		Phase.RUSH:
			_rush(delta)
		Phase.RECOVER:
			_remaining = maxf(0.0, _remaining - delta)
			if _remaining <= 0.0:
				_dash_count = 0
				_enter_hunt()
	_update_visual(delta)
	_dash_particles.position = -_dash_direction * 14.0
	_dash_particles.direction = -_dash_direction
	_dash_particles.emitting = phase == Phase.RUSH


func _update_visual(_delta: float) -> void:
	_visual.rotation = 0.0
	_visual.flip_v = false
	var direction := velocity.normalized() if phase == Phase.HUNT else _dash_direction
	if phase == Phase.RECOVER or phase == Phase.STOPPED or direction.is_zero_approx():
		_visual.frame = 0
	elif absf(direction.x) > absf(direction.y):
		_visual.frame = 3 if direction.x > 0.0 else 2
	else:
		_visual.frame = 1 if direction.y > 0.0 else 4
	var texture := _visual.sprite_frames.get_frame_texture(&"default", _visual.frame)
	_visual.scale = Vector2.ONE * visual_height / texture.get_height()


func _can_attack() -> bool:
	if not is_instance_valid(target):
		return false
	var offset := target.global_position - global_position
	# Check the actual body width, not just a ray that can fit through a crack.
	return offset.length() <= attack_range and not test_move(global_transform, offset)


func _hunt(delta: float) -> void:
	if _remaining <= 0.0 and _can_attack():
		_prepare_dash()
		return
	var destination := target.global_position
	if is_instance_valid(navigation_room):
		destination = navigation_room.pursuit_point(global_position, destination)
	var offset := destination - global_position
	velocity = offset.normalized() * minf(pursuit_speed, offset.length() / maxf(delta, 0.001))
	if not velocity.is_zero_approx():
		_facing_angle = velocity.angle()
	move_and_slide()


func _prepare_dash() -> void:
	# Aim once. Neither the wind-up nor the rush tracks subsequent player movement.
	var offset := target.global_position - global_position
	_dash_direction = offset.normalized() if not offset.is_zero_approx() else Vector2.from_angle(_facing_angle)
	_dash_distance = clampf(offset.length() + overshoot_distance, minimum_dash_distance, maxf(minimum_dash_distance, maximum_dash_distance))
	_facing_angle = _dash_direction.angle()
	_remaining = first_windup if _dash_count == 0 else followup_windup
	phase = Phase.WINDUP
	velocity = Vector2.ZERO
	_visual.frame = 1
	_feedback.announce(global_position + _dash_direction * _dash_distance)


func _rush(delta: float) -> void:
	_rush_speed = move_toward(_rush_speed, speed, acceleration * delta)
	var travel := minf(_dash_distance, _rush_speed * delta)
	velocity = _dash_direction * _rush_speed
	var start_transform := _collision.global_transform
	var start_position := global_position
	var collision := move_and_collide(_dash_direction * travel)
	_contact.sweep(start_transform, global_position - start_position)
	# Damage may synchronously end the encounter.
	if health.dead or phase == Phase.STOPPED:
		return
	_dash_distance = maxf(0.0, _dash_distance - travel)
	_feedback.rush(_dash_start, global_position)
	if collision != null or _dash_distance <= 0.0:
		_finish_dash(collision != null)


func _finish_dash(hit_wall: bool) -> void:
	_dash_count += 1
	velocity = Vector2.ZERO
	_rush_speed = 0.0
	_feedback.clear()
	if _dash_count >= dashes_per_burst:
		phase = Phase.RECOVER
		_visual.frame = 0
		_remaining = recovery_duration
	elif hit_wall or not _can_attack():
		_enter_hunt(wall_reposition_time if hit_wall else 0.0)
	else:
		_prepare_dash()


func _enter_hunt(delay: float = 0.0) -> void:
	_dash_particles.emitting = false
	phase = Phase.HUNT
	_remaining = delay
	velocity = Vector2.ZERO
	_visual.frame = 0
	_feedback.clear()


func stop_combat() -> void:
	super.stop_combat()
	_dash_particles.emitting = false
	phase = Phase.STOPPED
	_visual.frame = 0
	_feedback.clear()


func _die() -> void:
	stop_combat()
	super._die()
