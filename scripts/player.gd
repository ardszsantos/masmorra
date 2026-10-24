extends CharacterBody2D

@export var speed: float = 300.0
var movement_direction := Vector2.ZERO
@onready var abilities: Node = $Abilities

func take_damage(amount: float, source: Vector2 = global_position, flash_only: bool = false) -> void:
	if $Health.take_damage(amount) and not $Health.dead:
		if flash_only:
			$HitReaction.flash()
		else:
			$HitReaction.apply(source)


func set_movement_direction(direction: Vector2) -> void:
	movement_direction = direction


func request_action(trigger: StringName, direction: Vector2) -> void:
	abilities.request_action(trigger, direction)


func _physics_process(delta: float) -> void:
	var direction := movement_direction
	velocity = abilities.resolve_velocity(direction * speed, delta)
	velocity = $HitReaction.resolve_velocity(velocity, delta)
	move_and_slide()
	abilities.step(delta)
