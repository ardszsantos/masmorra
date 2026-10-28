extends Node
## Owns knowledge and reading independently of movement and attack execution.
signal changed(stacks: int, progress: float, reading: bool)

const MAX_STACKS: int = 3
const Player = preload("res://scripts/player.gd")
@export_range(1.0, 60.0) var passive_seconds_per_stack: float = 12.0
@export_range(0.2, 10.0) var reading_seconds_per_stack: float = 2.0
@export_range(0.1, 5.0) var reading_delay: float = 1.0
@export var book: Sprite2D
var stacks: int = 0
var progress: float = 0.0
var reading: bool = false
var _combat_active: bool = false
var _still_time: float = 0.0
@onready var _actor: Player = get_parent() as Player
@onready var _abilities: Node = $"../Abilities"
@onready var _health: Node = $"../Health"

func _ready() -> void:
	_abilities.combat_context_changed.connect(_set_combat_context)
	_abilities.ability_started.connect(_on_ability_started)
	_health.changed.connect(_on_health_changed)
	_health.died.connect(_stop)
	_publish()

func _physics_process(delta: float) -> void:
	if not _combat_active or _health.dead:
		return
	var stationary: bool = _actor.movement_direction.is_zero_approx() and _actor.velocity.length_squared() < 1.0
	for ability in _abilities.get_children():
		if ability.active and ability.blocks_other_actions:
			stationary = false
	_still_time = _still_time + delta if stationary else 0.0
	reading = _still_time >= reading_delay and stacks < MAX_STACKS
	if stacks < MAX_STACKS:
		progress += delta / (reading_seconds_per_stack if reading else passive_seconds_per_stack)
		while progress >= 1.0 and stacks < MAX_STACKS:
			progress -= 1.0
			stacks += 1
		if stacks == MAX_STACKS:
			progress = 0.0
			reading = false
	_publish()

func consume() -> int:
	var amount := stacks
	stacks = 0
	_interrupt_reading()
	return amount

func restore(stored_stacks: int, stored_progress: float) -> void:
	stacks = clampi(stored_stacks, 0, MAX_STACKS)
	progress = clampf(stored_progress, 0.0, 0.999) if stacks < MAX_STACKS else 0.0
	_interrupt_reading()

func _set_combat_context(_room: Node2D, active: bool) -> void:
	_combat_active = active
	_interrupt_reading()

func _on_ability_started(_ability: Node) -> void:
	_interrupt_reading()

func _on_health_changed(_current: float, _maximum: float) -> void:
	_interrupt_reading()

func _interrupt_reading() -> void:
	_still_time = 0.0
	reading = false
	_publish()

func _stop() -> void:
	_combat_active = false
	_interrupt_reading()

func _publish() -> void:
	if is_instance_valid(book):
		book.visible = reading
	changed.emit(stacks, progress, reading)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_interrupt_reading()
