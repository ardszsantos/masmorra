extends "res://scripts/abilities/player_ability.gd"

const Knowledge = preload("res://scripts/abilities/nerd_knowledge.gd")
const WaveScene = preload("res://scenes/abilities/book_wave.tscn")
const Wave = preload("res://scripts/abilities/book_wave.gd")
const Pose = preload("res://scripts/abilities/bonk_pose.gd")
const Presentation = preload("res://scripts/gameplay/bonk_presentation.gd")
@export_range(0.1, 5.0) var cooldown: float = 0.8
@export_range(0.05, 0.5) var windup: float = Pose.WINDUP
@export_range(0.15, 0.8) var air_time: float = Pose.AIR_TIME
@export_range(0.05, 1.0) var recovery: float = Pose.RECOVERY
@export_range(10.0, 100.0) var jump_height: float = Pose.JUMP_HEIGHT
@export_range(20.0, 90.0) var impact_distance: float = Pose.IMPACT_DISTANCE
@export var impact_damage: float = 55.0
@export var impact_radius: float = 48.0
@export var wave_damage: float = 22.0
@export var base_reach: float = 150.0
@export var reach_per_stack: float = 65.0
@export var base_arc: float = 55.0
@export var arc_per_stack: float = 15.0
var _cooldown_remaining: float = 0.0
var _elapsed: float = 0.0
var _impacted: bool = false
var _direction := Vector2.RIGHT
var _waves: Array[Wave] = []
@onready var _actor: CharacterBody2D = get_parent().get_parent() as CharacterBody2D
@onready var _knowledge: Knowledge = _actor.get_node("Knowledge") as Knowledge
@onready var _presentation: Presentation = _actor.get_node("BonkPresentation") as Presentation

func try_activate(direction: Vector2) -> bool:
	if active or _cooldown_remaining > 0.0 or direction.is_zero_approx():
		return false
	_direction = direction.normalized()
	_elapsed = 0.0
	_impacted = false
	active = true
	_cooldown_remaining = cooldown
	_presentation.begin(_direction)
	_update_pose()
	return true

func step(delta: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if not active:
		return
	_elapsed += delta
	_update_pose()
	if not _impacted and _elapsed >= windup + air_time:
		_impacted = true
		_slam()
	if _elapsed >= windup + air_time + recovery:
		active = false
		_presentation.finish()

func _update_pose() -> void:
	_presentation.update_pose(_elapsed, windup, air_time, recovery, jump_height, impact_distance)

func _slam() -> void:
	var stacks := _knowledge.consume()
	var impact := _actor.global_position + _direction * impact_distance + Vector2(0, 18)
	var ray := PhysicsRayQueryParameters2D.create(_actor.global_position, impact, 1)
	var wall := _actor.get_world_2d().direct_space_state.intersect_ray(ray)
	if not wall.is_empty():
		var contact: Vector2 = wall.position
		impact = contact.move_toward(_actor.global_position, 4.0)
	var wave := WaveScene.instantiate() as Wave
	wave.actor = _actor
	wave.direction = _direction
	wave.reach = base_reach + reach_per_stack * stacks
	wave.arc_degrees = base_arc + arc_per_stack * stacks
	wave.damage = wave_damage
	wave.impact_damage = impact_damage
	wave.impact_radius = impact_radius
	_actor.get_parent().add_child(wave)
	wave.global_position = impact
	_waves.append(wave)
	wave.tree_exiting.connect(_forget_wave.bind(wave), CONNECT_ONE_SHOT)

func _forget_wave(wave: Wave) -> void:
	_waves.erase(wave)

func get_activation_failure(_direction: Vector2) -> StringName:
	return &"cooldown" if _cooldown_remaining > 0.0 else &"unavailable"

func cancel() -> void:
	super.cancel()
	_elapsed = 0.0
	if is_instance_valid(_presentation):
		_presentation.finish()
	for wave in _waves:
		if is_instance_valid(wave):
			wave.tree_exiting.disconnect(_forget_wave.bind(wave))
			wave.queue_free()
	_waves.clear()

func _exit_tree() -> void:
	cancel()
