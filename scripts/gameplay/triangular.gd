extends "res://scripts/gameplay/enemy.gd"
## Obstacle that follows three fixed sides without chasing the player.
@export var circuit_side: float = 180.0
@export_range(0.0, 360.0, 5.0) var circuit_angle: float = 0.0
@export var corner_pause: float = 0.15
var _vertices: Array[Vector2] = []
var _next: int = 1
var _pause: float = 0.0
@onready var _visual: AnimatedSprite2D = $Visual

func _ready() -> void:
	super._ready()
	_visual.stop()
	_visual.frame = 0
	var origin := global_position
	var side := maxf(24.0, circuit_side)
	var angle := deg_to_rad(circuit_angle)
	# Shrink the circuit until all three sides fit within the existing walls.
	for attempt in range(8):
		_vertices = [origin, origin + Vector2(side, 0).rotated(angle),
			origin + Vector2(side * 0.5, side * sqrt(3.0) * 0.5).rotated(angle)]
		var clear := true
		for index in range(3):
			var start := global_transform
			start.origin = _vertices[index]
			if test_move(start, _vertices[(index + 1) % 3] - _vertices[index]):
				clear = false
				break
		if clear:
			break
		side *= 0.7

func _physics_process(delta: float) -> void:
	if health.dead or is_frozen():
		velocity = Vector2.ZERO
		return
	if _pause > 0.0:
		_pause -= delta
		return
	var offset := _vertices[_next] - global_position
	velocity = offset.normalized() * minf(speed, offset.length() / maxf(delta, 0.001))
	var start: Transform2D = $Collision.global_transform
	var previous := global_position
	var collision := move_and_collide(velocity * delta)
	$MeleeAttack.sweep(start, global_position - previous)
	if not velocity.is_zero_approx():
		_visual.rotation = velocity.angle()
	if collision != null or global_position.distance_to(_vertices[_next]) < 1.0:
		_next = (_next + 1) % 3
		_pause = corner_pause
		velocity = Vector2.ZERO
