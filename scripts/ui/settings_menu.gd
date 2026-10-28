extends Control

signal pause_changed(open: bool)

@onready var panel: PanelContainer = $SettingsPanel
var _character_info: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$SettingsButton.pressed.connect(_toggle_panel)
	$SettingsPanel/Margin/Options/ReturnToMenu.pressed.connect(_return_to_menu)
	$SettingsPanel/Margin/Options/CharacterInfo.pressed.connect(_open_character_info)
	$"../../RoomTransition".room_entered.connect(_on_room_entered)


func _on_room_entered(_room: Node2D) -> void:
	show()


func _toggle_panel() -> void:
	panel.visible = not panel.visible
	pause_changed.emit(panel.visible)

func _open_character_info() -> void:
	_character_info = $"../StartMenu".create_selected_character_info()
	if _character_info == null:
		return
	_character_info.connect("closed", _close_character_info)
	$GuideLayer.add_child(_character_info)
	panel.hide()
	$SettingsButton.hide()
	_character_info.show()
	pause_changed.emit(true)

func _close_character_info() -> void:
	if is_instance_valid(_character_info):
		_character_info.queue_free()
	_character_info = null
	panel.show()
	$SettingsButton.show()
	pause_changed.emit(true)


func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
