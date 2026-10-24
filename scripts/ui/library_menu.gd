extends Control

@export var transition: Node
@export var active_color := Color(0.45, 1.0, 0.5, 1.0)
@export var inactive_color := Color(0.65, 0.65, 0.65, 1.0)

@onready var overlay: Control = $Overlay
@onready var library_list: VBoxContainer = $Overlay/Panel/Margin/Options/Scroll/Libraries
@onready var status: Label = $Overlay/Panel/Margin/Options/Status


func _ready() -> void:
	$LibrariesButton.pressed.connect(_open)
	$Overlay/Panel/Margin/Options/CloseButton.pressed.connect(_close)
	transition.room_entered.connect(_on_room_entered)


func _open() -> void:
	if not transition.can_select_libraries() or get_tree().paused:
		return
	for child in library_list.get_children():
		library_list.remove_child(child)
		child.queue_free()
	for file_name: String in transition.get_available_libraries():
		var checkbox := CheckBox.new()
		checkbox.text = file_name.trim_suffix(".piece_library.json")
		checkbox.tooltip_text = file_name
		checkbox.custom_minimum_size.y = 56.0
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		checkbox.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		checkbox.set_pressed_no_signal(transition.is_library_enabled(file_name))
		_style_checkbox(checkbox)
		checkbox.toggled.connect(_toggle_library.bind(file_name, checkbox))
		library_list.add_child(checkbox)
	status.text = "Selecione pelo menos uma biblioteca."
	if library_list.get_child_count() == 0:
		status.text = "Nenhuma biblioteca válida encontrada."
	transition.stroke_pad.reset()
	transition.stroke_gesture.reset()
	get_tree().paused = true
	overlay.show()
	$Overlay/Panel/Margin/Options/CloseButton.grab_focus()


func _toggle_library(enabled: bool, file_name: String, checkbox: CheckBox) -> void:
	if not transition.set_library_enabled(file_name, enabled):
		checkbox.set_pressed_no_signal(transition.is_library_enabled(file_name))
		status.text = "Mantenha pelo menos uma biblioteca selecionada."
	else:
		status.text = "Seleção aplicada à geração de salas."
	_style_checkbox(checkbox)


func _style_checkbox(checkbox: CheckBox) -> void:
	var color := active_color if checkbox.button_pressed else inactive_color
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "checkbox_checked_color", "checkbox_unchecked_color"]:
		checkbox.add_theme_color_override(state, color)


func _close() -> void:
	if not overlay.visible:
		return
	overlay.hide()
	get_tree().paused = false
	$LibrariesButton.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if overlay.visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _on_room_entered(_room: Node2D) -> void:
	_close()
	hide()
