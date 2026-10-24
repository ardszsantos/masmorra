extends Control

@export var transition: Node
@export var ui_font: Font

const BACKGROUND := Color("000000")
const STRIP := Color("898485")
const STRIP_HOVER := Color("a19b9c")
const STRIP_PRESSED := Color("706b6c")
const PAPER := Color("f0eeee")
# Coordinates from the 720 × 1280 design. Project stretching already applies
# device scaling; percentage anchors here would shift only the lists
# when expand mode adds height to the visible area.
const LIST_TOP: float = 410.0
const LIST_WIDTH: float = 621.0
const MAP_LIST_BOTTOM: float = 986.0

var _home: Control
var _characters: Control
var _maps: Control
var _map_rows: VBoxContainer
var _status: Label
var _selection_status: Label
var _selected_character: StringName = &"Nerd"
var _play_button: Button
var _all_maps_button: Button


func _ready() -> void:
	_build_pages()
	transition.room_entered.connect(_on_run_started)
	_show_page(_home)
	_update_play_state.call_deferred()


func _build_pages() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = BACKGROUND
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	_home = _new_page("Masmorra", "v01.  la ele")
	_play_button = _add_action(_home, "Play", 503.0, 77.0, _start_run)
	_add_action(_home, "Characters", 640.0, 77.0, _open_characters)
	_add_action(_home, "Maps", 775.0, 77.0, _open_maps)
	_status = _label(_home, "", 24, PAPER)
	_status.position = Vector2(24.0, 1120.0)
	_status.size = Vector2(610.0, 48.0)

	_characters = _new_page("Characters", "", true)
	var character_list := VBoxContainer.new()
	character_list.position = Vector2(0.0, LIST_TOP)
	character_list.size = Vector2(LIST_WIDTH, 502.0)
	character_list.add_theme_constant_override("separation", 18)
	_characters.add_child(character_list)
	_add_character_choice(character_list, "Nerd", true)
	_add_character_choice(character_list, "?", false)
	_add_character_choice(character_list, "?", false)
	_add_character_choice(character_list, "?", false)
	_add_action(_characters, "Back", 1060.0, 77.0, _open_home)

	_maps = _new_page("Maps", "", true)
	_all_maps_button = _add_action(_maps, "", LIST_TOP, 64.0, _toggle_all_maps, LIST_WIDTH)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0.0, LIST_TOP + 80.0)
	scroll.size = Vector2(LIST_WIDTH, MAP_LIST_BOTTOM - LIST_TOP - 80.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.scroll_deadzone = 12
	_maps.add_child(scroll)
	_map_rows = VBoxContainer.new()
	_map_rows.mouse_filter = Control.MOUSE_FILTER_PASS
	_map_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_rows.add_theme_constant_override("separation", 14)
	scroll.add_child(_map_rows)
	_add_action(_maps, "Back", 1060.0, 77.0, _open_home)
	_refresh_maps()

	for page in [_home, _characters, _maps]:
		add_child(page)
	_selection_status = _label(self, "%s Selected" % _selected_character, 26, PAPER)
	_selection_status.position = Vector2(70.0, 980.0)
	_selection_status.size = Vector2(530.0, 48.0)


func _new_page(title: String, subtitle: String, centered_title: bool = false) -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	var band := ColorRect.new()
	band.color = STRIP
	band.position = Vector2(0.0, 241.0)
	band.size = Vector2(621.0, 154.0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(band)
	var heading := _label(page, title, 72, PAPER)
	if centered_title:
		heading.position = band.position + Vector2(68.0, 0.0)
		heading.size = band.size - Vector2(82.0, 0.0)
	else:
		heading.position = Vector2(68.0, 242.0)
		heading.size = Vector2(530.0, 96.0)
	if not subtitle.is_empty():
		var subheading := _label(page, subtitle, 34, PAPER)
		subheading.position = Vector2(305.0, 337.0)
		subheading.size = Vector2(400.0, 56.0)
	return page


func _add_action(page: Control, text: String, top: float, height: float,
		action: Callable, width: float = 292.0) -> Button:
	var button := Button.new()
	button.position = Vector2(0.0, top)
	button.size = Vector2(width, height)
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", _strip_style(STRIP))
	button.add_theme_stylebox_override("hover", _strip_style(STRIP_HOVER))
	button.add_theme_stylebox_override("pressed", _strip_style(STRIP_PRESSED))
	button.add_theme_stylebox_override("focus", _strip_style(STRIP))
	button.add_theme_stylebox_override("disabled", _strip_style(Color("555152")))
	var title := _label(button, text, 38, PAPER)
	title.position = Vector2(70.0, (height - 56.0) * 0.5)
	title.size = Vector2(width - 84.0, 56.0)
	button.pressed.connect(action)
	page.add_child(button)
	return button


func _add_character_choice(parent: VBoxContainer, text: String, unlocked: bool) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, 112.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.disabled = not unlocked
	button.add_theme_font_size_override("font_size", 38)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", PAPER)
	button.add_theme_color_override("font_pressed_color", PAPER)
	button.add_theme_color_override("font_disabled_color", PAPER)
	if ui_font != null:
		button.add_theme_font_override("font", ui_font)
	button.add_theme_stylebox_override("normal", _strip_style(STRIP_HOVER if unlocked else STRIP))
	button.add_theme_stylebox_override("hover", _strip_style(STRIP_HOVER))
	button.add_theme_stylebox_override("pressed", _strip_style(STRIP_PRESSED))
	button.add_theme_stylebox_override("disabled", _strip_style(STRIP))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state) as StyleBoxFlat
		style.content_margin_left = 70.0
		style.content_margin_right = 14.0
	if unlocked:
		button.pressed.connect(_select_nerd)
	parent.add_child(button)


func _strip_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(0)
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style


func _label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if ui_font != null:
		label.add_theme_font_override("font", ui_font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _open_home() -> void:
	_show_page(_home)


func _open_characters() -> void:
	_show_page(_characters)


func _open_maps() -> void:
	_refresh_maps()
	_show_page(_maps)


func _show_page(page: Control) -> void:
	_home.hide()
	_characters.hide()
	_maps.hide()
	page.show()
	_selection_status.visible = page == _home or page == _characters
	_selection_status.text = "%s Selected" % _selected_character


func _select_nerd() -> void:
	_selected_character = &"Nerd"
	_show_page(_home)


func _refresh_maps() -> void:
	if _map_rows == null:
		return
	for child in _map_rows.get_children():
		_map_rows.remove_child(child)
		child.queue_free()
	var libraries: Array = transition.get_available_libraries()
	var all_selected := not libraries.is_empty()
	for file_name: String in libraries:
		if not transition.is_library_enabled(file_name):
			all_selected = false
	var all_label := _all_maps_button.get_child(0) as Label
	all_label.text = "Deselect all" if all_selected else "Select all"
	_all_maps_button.disabled = libraries.is_empty()
	if libraries.is_empty():
		var empty_label := _label(_map_rows, "No room libraries found.", 28, PAPER)
		empty_label.custom_minimum_size = Vector2(0.0, 76.0)
		return
	for file_name: String in libraries:
		var selected: bool = transition.is_library_enabled(file_name)
		var library_name: String = file_name.trim_suffix(".piece_library.json")
		while library_name.ends_with(".piece_library"):
			library_name = library_name.trim_suffix(".piece_library")
		var row_text := ("[x]   " if selected else "[ ]   ") + library_name
		_add_map_choice(row_text, file_name, selected)


func _add_map_choice(text: String, file_name: String, selected: bool) -> void:
	var button := Button.new()
	# Let the ScrollContainer receive drags that start over an option.
	# Native scrolling cancels the button press when scrolling begins.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.focus_mode = Control.FOCUS_NONE
	var lines: int = maxi(1, ceili(float(text.length()) / 30.0))
	button.custom_minimum_size = Vector2(0.0, maxf(76.0, 34.0 * lines + 22.0))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = ""
	button.add_theme_stylebox_override("normal", _strip_style(STRIP))
	button.add_theme_stylebox_override("hover", _strip_style(STRIP_HOVER))
	button.add_theme_stylebox_override("pressed", _strip_style(STRIP_PRESSED))
	var label := _label(button, text, 27, PAPER)
	label.position = Vector2(14.0, 0.0)
	label.size = Vector2(0.0, 0.0)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 70.0
	label.offset_right = -14.0
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.pressed.connect(_toggle_map.bind(file_name, selected))
	_map_rows.add_child(button)


func _toggle_map(file_name: String, was_selected: bool) -> void:
	transition.set_library_enabled(file_name, not was_selected)
	_refresh_maps()
	_update_play_state()


func _toggle_all_maps() -> void:
	var all_selected := true
	for file_name: String in transition.get_available_libraries():
		if not transition.is_library_enabled(file_name):
			all_selected = false
	transition.set_all_libraries_enabled(not all_selected)
	_refresh_maps()
	_update_play_state()


func _update_play_state() -> void:
	_play_button.disabled = not transition.can_start_run()
	if _play_button.disabled:
		_status.text = "Select at least one map to play."
	else:
		_status.text = ""


func _start_run() -> void:
	if transition.start_run():
		_play_button.disabled = true
		_status.text = "Preparing the first room…"


func _on_run_started(_room: Node2D) -> void:
	hide()
