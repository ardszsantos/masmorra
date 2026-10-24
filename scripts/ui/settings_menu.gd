extends Control

@onready var panel: PanelContainer = $SettingsPanel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$SettingsButton.pressed.connect(_toggle_panel)
	$SettingsPanel/Margin/Options/ReturnToMenu.pressed.connect(_return_to_menu)
	$"../../RoomTransition".room_entered.connect(_on_room_entered)


func _on_room_entered(_room: Node2D) -> void:
	show()


func _toggle_panel() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		$"../StrokePad".reset()
		$"../../StrokeGesture".reset()
	get_tree().paused = panel.visible


func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
