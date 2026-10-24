extends Button

const Reward = preload("res://scripts/gameplay/room_reward.gd")
const MENU_FONT = preload("res://assets/fonts/biz-udmincho/BIZUDMincho-Regular.ttf")
const ICON_CENTER := Vector2(100.0, 34.0)
const BUBBLE_SIZE := Vector2(200.0, 124.0)

var door: Node2D
var reward: Reward
var _direction := Vector2.ZERO
var _placed: bool = false
var _center := Vector2.ZERO


func configure(offer: Dictionary) -> void:
	door = offer.door as Node2D
	reward = offer.reward as Reward
	size = BUBBLE_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var caption := Label.new()
	caption.position = Vector2(0.0, 80.0)
	caption.size = Vector2(200.0, 44.0)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font", MENU_FONT)
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", reward.color)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 6)
	var detail := "Nv. %d" % int(offer.level) if reward.kind == Reward.Kind.UPGRADE else "+%d" % int(reward.amount)
	caption.text = "%s\n%s · %s" % [reward.display_name, reward.world_name(), detail]
	add_child(caption)


func place(target: Vector2, center: Vector2, display_scale: float, delta: float) -> void:
	var weight := 1.0 - exp(-12.0 * delta)
	if not _placed:
		_center = center
		scale = Vector2.ONE * display_scale
		_placed = true
	else:
		_center = _center.lerp(center, weight)
		scale = scale.lerp(Vector2.ONE * display_scale, weight)
	position = _center - ICON_CENTER * scale
	_direction = (target - _center).normalized() if target.distance_to(_center) > 8.0 else Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if reward == null:
		return
	draw_circle(ICON_CENTER, 30.0, Color(0.025, 0.025, 0.03, 0.93))
	draw_arc(ICON_CENTER, 30.0, 0.0, TAU, 48, reward.color, 2.5, true)
	if reward.icon != null:
		var icon_size := reward.icon.get_size()
		icon_size *= 40.0 / maxf(icon_size.x, icon_size.y)
		draw_texture_rect(reward.icon, Rect2(ICON_CENTER - icon_size * 0.5, icon_size), false)
	if not _direction.is_zero_approx():
		var side := _direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([
			ICON_CENTER + _direction * 42.0,
			ICON_CENTER + _direction * 32.0 + side * 6.0,
			ICON_CENTER + _direction * 32.0 - side * 6.0,
		]), reward.color)
