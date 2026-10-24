extends ScrollContainer

@export var toggle_button: Button
@export var upgrades: Node
@export var transition: Node
@export_range(1, 12, 1) var minimum_slots: int = 6
var _slots: VBoxContainer
var _details_overlay: Control
var _details_title: Label
var _details_text: RichTextLabel
var _selected_id: StringName

func _ready() -> void:
	hide()
	toggle_button.hide()
	_slots = VBoxContainer.new()
	_slots.mouse_filter = Control.MOUSE_FILTER_PASS
	_slots.add_theme_constant_override("separation", 8)
	add_child(_slots)
	toggle_button.toggled.connect(_toggle_backpack)
	_build_details()
	transition.room_entered.connect(_room_entered)
	upgrades.changed.connect(_refresh)
	_refresh()

func _room_entered(_room: Node2D) -> void:
	toggle_button.show()

func _refresh() -> void:
	if is_instance_valid(_details_overlay) and _details_overlay.visible:
		_show_details(_selected_id)
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	var rewards: Array[Resource] = upgrades.equipped_rewards()
	for index in range(maxi(minimum_slots, rewards.size())):
		var slot := Button.new()
		slot.focus_mode = Control.FOCUS_NONE
		slot.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		slot.custom_minimum_size = Vector2(80, 80)
		slot.clip_contents = true
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.11, 0.12, 0.92)
		style.border_color = Color(0.5, 0.47, 0.48)
		style.set_border_width_all(2)
		for state in ["normal", "hover", "pressed", "disabled"]:
			slot.add_theme_stylebox_override(state, style)
		_slots.add_child(slot)
		if index >= rewards.size():
			slot.disabled = true
			continue
		var reward = rewards[index]
		var level: int = upgrades.level_of(reward.reward_id)
		slot.pressed.connect(_show_details.bind(reward.reward_id))
		slot.tooltip_text = "%s · Nv. %d\n%s" % [reward.display_name, level, reward.world_name()]
		var icon := TextureRect.new()
		# Disable the texture's native minimum size before assigning its bounds.
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = reward.icon
		icon.position = Vector2(12, 8)
		icon.size = Vector2(56, 56)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		var rank := Label.new()
		rank.text = "Nv. %d" % level
		rank.position = Vector2(4, 56)
		rank.size = Vector2(72, 22)
		rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank.add_theme_font_size_override("font_size", 16)
		rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(rank)


func _toggle_backpack(open: bool) -> void:
	visible = open
	if not open:
		_details_overlay.hide()


func _build_details() -> void:
	_details_overlay = Control.new()
	_details_overlay.name = "UpgradeDetails"
	_details_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_details_overlay.hide()
	# Keep the details outside the clipped inventory scroll area.
	get_parent().add_child.call_deferred(_details_overlay)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.65)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_details_overlay.add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.08
	panel.anchor_right = 0.92
	panel.anchor_top = 0.2
	panel.anchor_bottom = 0.8
	_details_overlay.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	_details_title = Label.new()
	_details_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details_title.add_theme_font_size_override("font_size", 26)
	column.add_child(_details_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	column.add_child(scroll)
	_details_text = RichTextLabel.new()
	_details_text.fit_content = true
	_details_text.scroll_active = false
	_details_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_text.mouse_filter = Control.MOUSE_FILTER_PASS
	_details_text.add_theme_font_size_override("normal_font_size", 22)
	scroll.add_child(_details_text)
	var close := Button.new()
	close.text = "Fechar"
	close.custom_minimum_size.y = 64
	close.pressed.connect(_details_overlay.hide)
	column.add_child(close)


func _show_details(id: StringName) -> void:
	_selected_id = id
	for reward in upgrades.equipped_rewards():
		if reward.reward_id == id:
			_details_title.text = "%s · Nv. %d\n%s" % [reward.display_name, upgrades.level_of(id), reward.world_name()]
			_details_text.text = upgrades.details_of(id)
			_details_overlay.show()
			return
	_details_overlay.hide()
