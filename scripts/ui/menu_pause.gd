extends Node
## Settings and inventory share one pause so closing one cannot resume the other.
var _settings_open: bool = false
var _backpack_open: bool = false
var _owns_pause: bool = false
var _previous_pause: bool = false
@onready var _stroke_pad: Control = $"../HUD/StrokePad"
@onready var _gesture: Node = $"../StrokeGesture"

func set_settings_open(open: bool) -> void:
	_settings_open = open
	_update_pause()

func set_backpack_open(open: bool) -> void:
	_backpack_open = open
	_update_pause()

func _update_pause() -> void:
	var requested := _settings_open or _backpack_open
	if requested and not _owns_pause:
		_previous_pause = get_tree().paused
		_owns_pause = true
		_stroke_pad.reset()
		_gesture.reset()
		get_tree().paused = true
	elif not requested and _owns_pause:
		_owns_pause = false
		get_tree().paused = _previous_pause
