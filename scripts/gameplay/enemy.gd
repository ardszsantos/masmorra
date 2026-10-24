extends CharacterBody2D
signal defeated(enemy: Node)
@export var speed: float = 100.0
var target: CharacterBody2D
var navigation_room: Node2D
@onready var health = $Health

func _ready() -> void:
	add_to_group("enemies")
	health.died.connect(_die)

func _physics_process(delta: float) -> void:
	if is_frozen():
		velocity = Vector2.ZERO
		return
	if health.dead:
		velocity = $HitReaction.resolve_velocity(Vector2.ZERO, delta)
		move_and_slide()
		return
	if not is_instance_valid(target):
		return
	var destination := target.global_position
	if is_instance_valid(navigation_room):
		destination = navigation_room.pursuit_point(global_position, target.global_position)
	var offset := destination - global_position
	velocity = offset.normalized() * speed if global_position.distance_to(target.global_position) > 35.0 else Vector2.ZERO
	velocity = $HitReaction.resolve_velocity(velocity, delta)
	move_and_slide()

func take_damage(amount: float, source: Vector2 = global_position) -> void:
	if health.take_damage(amount):
		$HitReaction.apply(source)

func apply_freeze(duration: float) -> void:
	$FreezeStatus.apply(duration)
	velocity = Vector2.ZERO

func apply_burn(duration: float, damage_per_second: float, source: Node2D) -> void:
	var burn = get_node_or_null("BurnStatus")
	if burn == null:
		burn = preload("res://scripts/gameplay/burn_status.gd").new()
		burn.name = "BurnStatus"
		add_child(burn)
	burn.apply(duration, damage_per_second, source)

func is_frozen() -> bool:
	var status = get_node_or_null("FreezeStatus")
	return status != null and status.active()

func stop_combat() -> void:
	velocity = Vector2.ZERO
	set_physics_process(false)
	$MeleeAttack.set_physics_process(false)

func _die() -> void:
	$MeleeAttack.set_physics_process(false)
	defeated.emit(self)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 1)
	var tween := create_tween()
	tween.tween_property($Visual, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
