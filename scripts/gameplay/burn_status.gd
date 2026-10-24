extends Node2D
## One burn per enemy: renewed contact refreshes duration without stacking damage.
@export var tick_interval: float = 0.5
var remaining: float = 0.0
var _damage_per_second: float = 0.0
var _elapsed: float = 0.0
var _age: float = 0.0
var _source: Node2D

func _ready() -> void:
	z_index = 3
	get_parent().get_node("Health").died.connect(clear)
	hide()

func apply(duration: float, damage_per_second: float, source: Node2D) -> void:
	if get_parent().get_node("Health").dead or duration <= 0.0:
		return
	remaining = maxf(remaining, duration)
	_damage_per_second = maxf(_damage_per_second, damage_per_second)
	_source = source
	show()

func clear() -> void:
	remaining = 0.0
	_elapsed = 0.0
	_damage_per_second = 0.0
	hide()

func _physics_process(delta: float) -> void:
	if remaining <= 0.0:
		return
	if not is_instance_valid(_source) or _source.get_node("Health").dead:
		clear()
		return
	_elapsed += minf(delta, remaining)
	remaining = maxf(0.0, remaining - delta)
	_age += delta
	if _elapsed >= maxf(0.05, tick_interval) or remaining <= 0.0:
		var damage := _damage_per_second * _elapsed
		_elapsed = 0.0
		# Damage over time does not apply knockback or interrupt the enemy's attack.
		get_parent().get_node("Health").take_damage(damage)
	if remaining <= 0.0:
		clear()
	queue_redraw()

func _draw() -> void:
	for index in range(5):
		var x := (index - 2) * 8.0
		var lift := fmod(_age * 22.0 + index * 7.0, 25.0)
		var center := Vector2(x + sin(_age * 9.0 + index) * 2.0, 10.0 - lift)
		draw_circle(center, 4.0, Color(1.0, 0.3, 0.04, 0.65))
		draw_circle(center + Vector2(0, 1), 2.0, Color(1.0, 0.8, 0.2, 0.85))
