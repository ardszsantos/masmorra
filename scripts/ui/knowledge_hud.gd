extends Control

const Knowledge = preload("res://scripts/abilities/nerd_knowledge.gd")
@export var knowledge: Knowledge
var _stacks: int = 0
var _progress: float = 0.0
var _reading: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bind_knowledge.call_deferred()

func _bind_knowledge() -> void:
	if knowledge == null:
		knowledge = get_node_or_null("../../../../Player/Knowledge") as Knowledge
	if knowledge == null:
		push_error("KnowledgeHud: player knowledge is unavailable")
		return
	if not knowledge.changed.is_connected(_update):
		knowledge.changed.connect(_update)
	_update(knowledge.stacks, knowledge.progress, knowledge.reading)

func _update(stacks: int, progress: float, reading: bool) -> void:
	_stacks = stacks
	_progress = progress
	_reading = reading
	queue_redraw()

func _draw() -> void:
	for index in range(Knowledge.MAX_STACKS):
		var center := Vector2(18.0 + index * 43.0, 18.0)
		var lit := index < _stacks
		var color := Color("ffe49a") if lit else Color("5e5a50")
		if lit:
			draw_circle(center, 17.0, Color(1.0, 0.85, 0.4, 0.14))
		draw_circle(center, 10.0, color)
		draw_rect(Rect2(center + Vector2(-5, 8), Vector2(10, 8)), color)
		draw_line(center + Vector2(-4, 19), center + Vector2(4, 19), color, 3.0)
		if index == _stacks:
			draw_arc(center, 15.0, -PI * 0.5, -PI * 0.5 + TAU * _progress, 32, Color("ffe49a"), 3.0, true)
	var caption := "Lendo" if _reading else "Conhecimento"
	draw_string(ThemeDB.fallback_font, Vector2(139, 26), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f0eeee"))
