extends Control

signal closed
@export var ui_font: Font

func _ready() -> void:
	$Back.pressed.connect(_close)
	set_ui_font(ui_font)

func set_ui_font(font: Font) -> void:
	ui_font = font
	if ui_font != null:
		$Title.add_theme_font_override("font", ui_font)
		$Back/Label.add_theme_font_override("font", ui_font)

func _close() -> void:
	hide()
	closed.emit()
