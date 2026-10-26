extends "res://scripts/abilities/player_ability.gd"
## Prototype slash; exposes an activation signal for future damage receivers.
signal slash_started(direction: Vector2)
@export_range(0.05, 1.0) var duration: float = 0.25
@export_range(10.0, 400.0) var reach: float = 230.0
@export_range(20.0, 220.0) var arc_degrees: float = 165.0
@export_range(1.0, 60.0) var slash_width: float = 28.0
var _remaining: float = 0.0
var _direction := Vector2.RIGHT
var _visual: Line2D
var _glow: Line2D
@export var damage: float = 20.0
var _hit: Array = []

func _ready() -> void:
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.0))
	taper.add_point(Vector2(0.18, 0.9))
	taper.add_point(Vector2(0.5, 1.0))
	taper.add_point(Vector2(0.82, 0.9))
	taper.add_point(Vector2(1.0, 0.0))
	_glow = Line2D.new()
	_glow.width = slash_width * 2.4
	_glow.width_curve = taper
	_glow.default_color = Color(0.35, 0.7, 1.0, 0.24)
	_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	_glow.antialiased = true
	add_child(_glow)
	_visual = Line2D.new()
	_visual.width = slash_width
	_visual.width_curve = taper
	_visual.default_color = Color(0.72, 0.93, 1.0, 0.98)
	_visual.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_visual.end_cap_mode = Line2D.LINE_CAP_ROUND
	_visual.antialiased = true
	add_child(_visual)
	_glow.visible = false
	_visual.visible = false

func try_activate(direction: Vector2) -> bool:
	if active or direction.is_zero_approx():
		return false
	_direction = direction.normalized()
	_remaining = duration
	active = true
	_hit.clear()
	_glow.visible = true
	_visual.visible = true
	_update_visual()
	slash_started.emit(_direction)
	return true

func get_activation_failure(direction: Vector2) -> StringName:
	return &"direction" if direction.is_zero_approx() else super.get_activation_failure(direction)

func _update_visual() -> void:
	var player_position: Vector2 = get_parent().get_parent().global_position
	_visual.global_position = player_position
	_glow.global_position = player_position
	var points := PackedVector2Array()
	var progress := 1.0 - _remaining / duration
	var sweep := deg_to_rad(arc_degrees)
	var swing := lerpf(-0.12, 0.12, progress) * sweep
	for index in range(33):
		var angle := _direction.angle() - sweep * 0.5 + swing + sweep * float(index) / 32.0
		points.append(Vector2.from_angle(angle) * reach)
	_visual.points = points
	_glow.points = points
	_visual.modulate.a = sin(progress * PI) * 0.35 + (1.0 - progress) * 0.65
	_glow.modulate.a = _visual.modulate.a

func step(delta: float) -> void:
	if not active:
		return
	preload("res://scripts/gameplay/damage_query.gd").hit(get_parent().get_parent(), reach, damage, _hit, _direction, arc_degrees)
	_remaining = maxf(0.0, _remaining - delta)
	_update_visual()
	if _remaining <= 0.0:
		cancel()

func cancel() -> void:
	super.cancel()
	_remaining = 0.0
	if is_instance_valid(_glow):
		_glow.visible = false
	if is_instance_valid(_visual):
		_visual.visible = false
