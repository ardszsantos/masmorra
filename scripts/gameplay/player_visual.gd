extends AnimatedSprite2D
## Presents locomotion and dash without changing the player's movement.

signal attachment_pose_changed

const DashAbility = preload("res://scripts/abilities/dash_ability.gd")
const DIRECTIONS: Array[StringName] = [&"e", &"se", &"s", &"sw", &"w", &"nw", &"n", &"ne"]
const DIRECTION_STEP: float = TAU / 8.0

var _facing_index: int = 2
var _dash: DashAbility
var _action_pose: bool = false
@onready var _body: CharacterBody2D = get_parent() as CharacterBody2D
@onready var _abilities: Node = $"../Abilities"
@onready var _back_socket: Node2D = $BackSocket
@onready var _hand_socket: Node2D = $HandSocket
@onready var _eye_socket: Node2D = $EyeSocket


func _ready() -> void:
	set_notify_transform(true)
	frame_changed.connect(_update_attachment_pose)
	_abilities.connect("ability_started", _on_ability_started)
	_play_directional_animation(&"idle")
	_update_attachment_pose()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_node_ready():
		attachment_pose_changed.emit()


func facing_direction() -> Vector2:
	return Vector2.from_angle(float(_facing_index) * DIRECTION_STEP)


func _update_attachment_pose() -> void:
	var direction := facing_direction()
	var side := -1.0 if direction.x < -0.1 else 1.0
	var bob := -1.0 if String(animation).begins_with("walk_") and frame % 4 in [1, 2] else 0.0
	if String(animation).begins_with("dash_") and frame in [1, 2]:
		bob += 2.0
	_back_socket.position = Vector2(-direction.x * 5.0, 1.0 - direction.y * 3.0 + bob)
	_back_socket.scale = Vector2(0.5 * lerpf(0.55, 1.0, absf(direction.y)), 0.5)
	_back_socket.z_index = 1 if direction.y < -0.1 else -1
	_hand_socket.position = Vector2(side * 6.0, 3.0 + direction.y * 2.0 + bob)
	_hand_socket.scale = Vector2.ONE * 0.5
	_hand_socket.z_index = -1 if direction.y < -0.1 else 2
	_eye_socket.position = Vector2(direction.x * 3.0, -19.0 + bob)
	_eye_socket.scale = Vector2.ONE * 0.5
	_eye_socket.z_index = 2
	attachment_pose_changed.emit()


func _physics_process(_delta: float) -> void:
	if _dash == null and not _action_pose:
		_update_locomotion()

func begin_action_pose(direction: Vector2) -> void:
	_action_pose = true
	_face_direction(direction)
	_play_directional_animation(&"idle")
	pause()

func end_action_pose() -> void:
	_action_pose = false
	_update_locomotion()
	play()


func _update_locomotion() -> void:
	# Actual displacement keeps the walk cycle from playing against a wall.
	var movement: Vector2 = _body.get_real_velocity()
	if movement.is_zero_approx():
		_play_directional_animation(&"idle")
		return
	_face_direction(movement)
	_play_directional_animation(&"walk")


func _face_direction(direction: Vector2) -> void:
	if not direction.is_zero_approx():
		var next_index := wrapi(roundi(direction.angle() / DIRECTION_STEP), 0, DIRECTIONS.size())
		if next_index != _facing_index:
			_facing_index = next_index
			_update_attachment_pose()


func _play_directional_animation(action: StringName) -> void:
	var animation_name := StringName("%s_%s" % [action, DIRECTIONS[_facing_index]])
	if animation != animation_name:
		play(animation_name)


func _on_ability_started(ability: Node) -> void:
	var dash := ability as DashAbility
	if dash == null:
		return
	_disconnect_dash()
	_dash = dash
	_dash.dash_finished.connect(_on_dash_finished)
	_dash.tree_exiting.connect(_on_dash_finished)
	_face_direction(_dash.get_dash_direction())
	_play_directional_animation(&"dash")
	# Fit the entire sequence to the ability's duration, including Inspector tuning.
	var frame_count: int = sprite_frames.get_frame_count(animation)
	var frames_per_second: float = sprite_frames.get_animation_speed(animation)
	speed_scale = float(frame_count) / (frames_per_second * _dash.duration)


func _on_dash_finished() -> void:
	_disconnect_dash()
	speed_scale = 1.0
	_update_locomotion()


func _disconnect_dash() -> void:
	if is_instance_valid(_dash):
		if _dash.dash_finished.is_connected(_on_dash_finished):
			_dash.dash_finished.disconnect(_on_dash_finished)
		if _dash.tree_exiting.is_connected(_on_dash_finished):
			_dash.tree_exiting.disconnect(_on_dash_finished)
	_dash = null


func _exit_tree() -> void:
	if is_instance_valid(_abilities) and _abilities.is_connected("ability_started", _on_ability_started):
		_abilities.disconnect("ability_started", _on_ability_started)
	_disconnect_dash()
