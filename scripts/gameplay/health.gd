extends Node
signal changed(current: float, maximum: float)
signal died
@export var maximum: float = 100.0
@export var invulnerability_time: float = 0.0
var current: float
var dead: bool = false
var _invulnerability: float = 0.0
var _damage_blocks: Dictionary = {}

func set_damage_blocked(source: Node, blocked: bool) -> void:
	if blocked:
		_damage_blocks[source.get_instance_id()] = true
	else:
		_damage_blocks.erase(source.get_instance_id())

func _ready() -> void:
	current = maximum

func _physics_process(delta: float) -> void:
	_invulnerability = maxf(0.0, _invulnerability - delta)

func heal(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	current = minf(maximum, current + amount)
	changed.emit(current, maximum)

func increase_maximum(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	maximum += amount
	changed.emit(current, maximum)

func take_damage(amount: float) -> bool:
	if dead or amount <= 0.0 or _invulnerability > 0.0 or not _damage_blocks.is_empty():
		return false
	current = maxf(0.0, current - amount)
	_invulnerability = invulnerability_time
	changed.emit(current, maximum)
	if current <= 0.0:
		dead = true
		died.emit()
	return true
