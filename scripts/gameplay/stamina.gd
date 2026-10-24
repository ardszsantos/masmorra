extends Node
signal changed(current: float, maximum: float)
@export var maximum: float = 100.0
@export var regeneration: float = 20.0
@export var regeneration_delay: float = 1.0
var current: float
var _delay: float = 0.0

func _ready() -> void:
	current = maximum

func can_spend(amount: float) -> bool:
	return current + 0.00001 >= amount

func increase_maximum(amount: float) -> void:
	if amount <= 0.0:
		return
	maximum += amount
	changed.emit(current, maximum)

func spend(amount: float) -> bool:
	if not can_spend(amount):
		return false
	current = maxf(0.0, current - amount)
	_delay = regeneration_delay
	changed.emit(current, maximum)
	return true

func _physics_process(delta: float) -> void:
	var recovery_delta := maxf(0.0, delta - _delay)
	_delay = maxf(0.0, _delay - delta)
	if recovery_delta > 0.0 and current < maximum:
		current = minf(maximum, current + regeneration * recovery_delta)
		changed.emit(current, maximum)
