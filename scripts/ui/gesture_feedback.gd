extends Node
## Connects ability outcomes to feedback independently of nested scene connections.

const AbilityController = preload("res://scripts/abilities/ability_controller.gd")
const StrokePad = preload("res://scripts/input/stroke_pad.gd")
const GestureQueueHud = preload("res://scripts/ui/gesture_queue_hud.gd")

@export var abilities: AbilityController
@export var stroke_pad: StrokePad
@export var queue_hud: GestureQueueHud
@export var failure_label: Label
@export var stamina_bar: ProgressBar
@export_range(0.5, 5.0) var message_duration: float = 2.0
@export_range(0.05, 0.5) var blink_interval: float = 0.15
@export var failure_color := Color(1.0, 0.18, 0.16, 1.0)

var _message_remaining: float = 0.0
var _blink: Tween
var _fill: StyleBoxFlat
var _background: StyleBoxFlat
var _fill_color: Color
var _background_color: Color

func _ready() -> void:
	_fill = stamina_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	_background = stamina_bar.get_theme_stylebox("background").duplicate() as StyleBoxFlat
	_fill_color = _fill.bg_color
	_background_color = _background.bg_color
	stamina_bar.add_theme_stylebox_override("fill", _fill)
	stamina_bar.add_theme_stylebox_override("background", _background)
	abilities.action_resolved.connect(_on_action_resolved)
	abilities.action_failed.connect(_on_action_failed)
	failure_label.hide()
	set_process(false)

func _on_action_resolved(success: bool) -> void:
	stroke_pad.resolve_queued_gesture(success)
	queue_hud.resolve_queued_gesture(success)
	_clear_message()

func _on_action_failed(reason: StringName) -> void:
	_clear_message()
	if reason == &"stamina":
		_blink_stamina()
		return
	match reason:
		&"cooldown":
			failure_label.text = "Aguarde a habilidade recarregar."
		&"stunned":
			failure_label.text = "Você está atordoado."
		&"busy":
			failure_label.text = "Aguarde a ação atual terminar."
		&"not_equipped":
			failure_label.text = "Habilidade não equipada."
		&"direction":
			failure_label.text = "Desenhe uma direção para a ação."
		_:
			failure_label.text = "Ação indisponível no momento."
	failure_label.show()
	_message_remaining = message_duration
	set_process(true)

func _blink_stamina() -> void:
	if _blink != null:
		_blink.kill()
	_restore_stamina_colors()
	_blink = create_tween()
	for pulse in range(3):
		_blink.tween_callback(_set_stamina_failure_colors)
		_blink.tween_interval(blink_interval)
		_blink.tween_callback(_restore_stamina_colors)
		_blink.tween_interval(blink_interval)

func _set_stamina_failure_colors() -> void:
	_fill.bg_color = failure_color
	# Flash the empty track too, so exhaustion is visible at zero stamina.
	_background.bg_color = failure_color.darkened(0.45)

func _restore_stamina_colors() -> void:
	_fill.bg_color = _fill_color
	_background.bg_color = _background_color

func _process(delta: float) -> void:
	_message_remaining = maxf(0.0, _message_remaining - delta)
	if _message_remaining <= 0.0:
		_clear_message()

func _clear_message() -> void:
	failure_label.hide()
	_message_remaining = 0.0
	set_process(false)

func reset() -> void:
	_clear_message()
	if _blink != null:
		_blink.kill()
	_restore_stamina_colors()

func _exit_tree() -> void:
	if _blink != null:
		_blink.kill()
	if is_instance_valid(abilities):
		abilities.action_resolved.disconnect(_on_action_resolved)
		abilities.action_failed.disconnect(_on_action_failed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		reset()
