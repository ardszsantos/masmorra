extends Control
## Numbered strokes are drawn as geometry so they do not depend on font glyphs.
@export var second_direction := Vector2.RIGHT

func _ready() -> void:
	custom_minimum_size = Vector2(0, 115)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	_draw_arrow(Vector2(85, 55), Vector2.RIGHT, Color("ffe49a"))
	_draw_arrow(Vector2(270, 55), second_direction, Color("a9dce5"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(30, 107), "1 · orientar", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffe49a"))
	draw_string(font, Vector2(215, 107), "2 · ativar", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("a9dce5"))
	draw_string(font, Vector2(170, 61), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("f0eeee"))

func _draw_arrow(center: Vector2, direction: Vector2, color: Color) -> void:
	var start := center - direction * 32.0
	var tip := center + direction * 32.0
	var side := direction.orthogonal()
	draw_line(start, tip, color, 6.0, true)
	draw_colored_polygon(PackedVector2Array([tip + direction * 9.0, tip - direction * 11.0 + side * 12.0, tip - direction * 11.0 - side * 12.0]), color)
