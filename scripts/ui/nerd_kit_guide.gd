extends VBoxContainer

const Preview = preload("res://scripts/ui/nerd_skill_preview.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 12)
	_add_skill("Dash", Preview.Move.DASH, "Repita a direção para avançar.")
	_add_skill("Super esquadro", Preview.Move.SET_SQUARE, "Vire o segundo traço para mirar. Ele curva e busca inimigos.")
	_add_skill("Livro bonk", Preview.Move.BONK, "Inverta para mirar o golpe. Pule, bata e solte a onda.")
	_add_skill("Força da mente · passiva", Preview.Move.KNOWLEDGE, "Carrega no combate. Parado, leia para carregar mais rápido.")

func _add_skill(title: String, move: int, caption: String) -> void:
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("211f23")
	style.border_color = Color("555054")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	card.add_child(column)
	_label(column, title, 26)
	var preview := Preview.new()
	preview.move = move
	preview.custom_minimum_size.y = 128
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(preview)
	_label(column, caption, 19)

func _label(parent: Control, value: String, font_size: int) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f0eeee"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
