extends Control
## Presentation-only loops: input traces and their outcome share one timeline.
enum Move { DASH, SET_SQUARE, BONK, KNOWLEDGE }
const FRAMES: SpriteFrames = preload("res://resources/player/player_sprite_frames.tres")
const BOOK: Texture2D = preload("res://assets/abilities/nerd_book.svg")
const SQUARE: Texture2D = preload("res://assets/abilities/set_square.svg")
const ENEMY: Texture2D = preload("res://assets/sprites/triangular/triangle-idle.png")
const BonkPose = preload("res://scripts/abilities/bonk_pose.gd")
const SquareFlight = preload("res://scripts/abilities/set_square_flight.gd")
const LOOP_SECONDS: float = 4.8
const CAST_TIME: float = 1.5
const FLOOR_Y: float = 111.0
const GOLD := Color("ffe49a")
const BLUE := Color("a9dce5")
var move: Move = Move.DASH
var _time: float = 0.0
var _cycle: int = 0
var _bonk_pose := BonkPose.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()

func _on_visibility_changed() -> void:
	_time = 0.0
	_cycle = 0
	set_process(is_visible_in_tree())
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if _time >= LOOP_SECONDS:
		_time = fmod(_time, LOOP_SECONDS)
		_cycle += 1
	queue_redraw()

func _draw() -> void:
	# Normalize the illustration independently of the card's text layout.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(size.x / 640.0, size.y / 128.0))
	if move == Move.KNOWLEDGE:
		_draw_knowledge()
	else:
		_draw_gesture()
		draw_line(Vector2(211, 10), Vector2(211, 116), Color("555054"), 1.0)
		draw_line(Vector2(240, FLOOR_Y), Vector2(620, FLOOR_Y), Color("555054"), 2.0)
		match move:
			Move.DASH: _draw_dash()
			Move.SET_SQUARE: _draw_square()
			Move.BONK: _draw_bonk()
	draw_set_transform(Vector2.ZERO)

func _draw_gesture() -> void:
	var first := Vector2.RIGHT
	var second := Vector2.RIGHT
	if move == Move.SET_SQUARE:
		first = Vector2.DOWN if _cycle % 2 == 0 else Vector2.UP
		second = Vector2.RIGHT
	elif move == Move.BONK:
		first = Vector2.LEFT
	_stroke(Vector2(49, 58), first, clampf((_time - 0.15) / 0.45, 0, 1), GOLD, "1")
	_stroke(Vector2(151, 58), second, clampf((_time - 0.85) / 0.45, 0, 1), BLUE, "2")
	_text(Vector2(9, 116), "1: prepare · 2: mire" if move != Move.DASH else "Trace e solte", 17, Color("c8c3c6"))

func _stroke(center: Vector2, direction: Vector2, progress: float, color: Color, number: String) -> void:
	_text(center + Vector2(-5, -40), number, 18, color)
	var start := center - direction * 25.0
	var end := center + direction * 25.0
	draw_line(start, end, Color(color, 0.15), 3.0, true)
	if progress <= 0.0:
		return
	var tip := start.lerp(end, progress)
	draw_line(start, tip, color, 4.0, true)
	if progress < 1.0:
		draw_circle(tip, 9.0, Color(color, 0.2))
		draw_circle(tip, 4.0, Color.WHITE)
	else:
		var side := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([tip + direction * 6, tip - direction * 7 + side * 7, tip - direction * 7 - side * 7]), color)

func _hero(center: Vector2, animation: StringName = &"idle_e", tint: Color = Color.WHITE, pose_scale: Vector2 = Vector2.ONE) -> void:
	var frame := int(_time * FRAMES.get_animation_speed(animation)) % FRAMES.get_frame_count(animation)
	var texture := FRAMES.get_frame_texture(animation, frame)
	var dimensions := Vector2(80, 80) * pose_scale
	draw_texture_rect(texture, Rect2(center - dimensions * 0.5, dimensions), false, tint)

func _enemy(center: Vector2, hit: bool) -> void:
	draw_texture_rect(ENEMY, Rect2(center - Vector2(21, 21), Vector2(42, 42)), false, Color("ff8075") if hit else Color.WHITE)
	if hit:
		for index in range(5):
			var direction := Vector2.from_angle(TAU * float(index) / 5.0)
			draw_line(center + direction * 24, center + direction * 33, GOLD, 3.0)

func _draw_dash() -> void:
	var travel := clampf((_time - CAST_TIME) / 0.32, 0, 1)
	var center := Vector2(280 + travel * 270, FLOOR_Y - 40.0)
	if travel > 0 and travel < 1:
		for index in range(1, 4):
			_hero(center - Vector2(index * 28, 0), &"dash_e", Color(1, 1, 1, 0.35 / index))
	_hero(center, &"dash_e" if travel > 0 and travel < 1 else &"idle_e")

func _draw_square() -> void:
	_hero(Vector2(290, FLOOR_Y - 40.0))
	var flight := (_time - CAST_TIME) / 2.2
	var active := flight >= 0 and flight <= 1
	var enemy_position := _square_position(0.24)
	var projectile_position := _square_position(clampf(flight, 0.0, 1.0))
	_enemy(enemy_position, active and projectile_position.distance_to(enemy_position) < 30.0)
	if active:
		var trail := PackedVector2Array()
		for index in range(17):
			trail.append(_square_position(maxf(0.0, flight - float(16 - index) * 0.012)))
		draw_polyline(trail, Color(1, 0.85, 0.45, 0.4), 3.0, true)
		draw_set_transform(projectile_position * Vector2(size.x / 640.0, size.y / 128.0), flight * 24.0, Vector2(size.x / 640.0, size.y / 128.0))
		draw_texture_rect(SQUARE, Rect2(-22, -22, 44, 44), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(size.x / 640.0, size.y / 128.0))
	_text(Vector2(391, 23), "Voltou: pronto!" if flight > 1 else ("Ida" if flight < 0.5 else "Volta"), 18, BLUE)

func _square_position(progress: float) -> Vector2:
	var side := 1.0 if _cycle % 2 == 0 else -1.0
	var direction := Vector2.RIGHT
	var origin := Vector2(290, FLOOR_Y - 40.0)
	if progress <= 0.7:
		return origin + SquareFlight.offset(progress / 0.7, direction, 235.0, 18.0, side)
	var end := origin + SquareFlight.offset(1.0, direction, 235.0, 18.0, side)
	return end.bezier_interpolate(end - direction * 45.0, origin - direction * 45.0, origin, (progress - 0.7) / 0.3)

func _draw_bonk() -> void:
	var charged := _cycle % 2 == 1
	var elapsed := _time - CAST_TIME
	var contact_time := BonkPose.WINDUP + BonkPose.AIR_TIME
	var wave_time := elapsed - contact_time
	var center := Vector2(280, FLOOR_Y - 40.0)
	var performing := elapsed >= 0.0 and elapsed < contact_time + BonkPose.RECOVERY
	if performing:
		_bonk_pose.update(elapsed, Vector2.RIGHT, BonkPose.WINDUP, BonkPose.AIR_TIME, BonkPose.RECOVERY, 18.0)
		var body_center := center + _bonk_pose.body_offset + Vector2(0.0, (1.0 - _bonk_pose.body_scale.y) * 16.0)
		_hero(body_center, &"idle_e", Color.WHITE, _bonk_pose.body_scale)
		BonkPose.draw_grip(self, body_center, center + _bonk_pose.book_offset, _bonk_pose.book_rotation, BOOK)
	else:
		_hero(center)
	_lamps(Vector2(252, 15), 3.0 if charged and wave_time < 0 else 0.0)
	_text(Vector2(384, 22), "3 lâmpadas" if charged else "Sem lâmpadas", 18, GOLD)
	var reach := 230.0 if charged else 115.0
	var progress := clampf(wave_time / 0.65, 0, 1)
	_enemy(Vector2(350, 98), wave_time >= 0 and wave_time < 0.3)
	_enemy(Vector2(530, 98), charged and wave_time > 0.45 and wave_time < 0.8)
	if wave_time >= 0 and wave_time < 0.8:
		var radius := maxf(1.0, reach * progress)
		var half_arc := 0.48 if not charged else 0.85
		var impact := center + Vector2(BonkPose.IMPACT_DISTANCE, 18)
		var points := PackedVector2Array()
		for index in range(21):
			var radial := Vector2.from_angle(lerpf(-half_arc, half_arc, float(index) / 20.0))
			points.append(impact + radial * radius * Vector2(1.0, 0.12))
		draw_polyline(points, GOLD, 4.0, true)
		if wave_time < 0.2:
			draw_arc(impact, 16.0 + wave_time * 60.0, PI, TAU, 16, GOLD, 3.0, true)

func _draw_knowledge() -> void:
	draw_line(Vector2(320, 8), Vector2(320, 118), Color("555054"), 1.0)
	_text(Vector2(16, 25), "Em movimento", 19, BLUE)
	_text(Vector2(343, 25), "Lendo", 19, GOLD)
	_hero(Vector2(85 + sin(_time * 1.7) * 25, 83), &"walk_e")
	_hero(Vector2(409, 83), &"idle_s")
	draw_texture_rect(BOOK, Rect2(413, 85 + sin(_time * 3.0) * 2, 43, 30), false)
	# Both timelines use the same accelerated clock; reading fills six times faster.
	var slow := minf(_time / 8.0, 0.5)
	var fast := minf(_time * 0.75, 3.0)
	_lamps(Vector2(173, 65), slow)
	_lamps(Vector2(505, 65), fast)
	_text(Vector2(171, 110), "Devagar", 17, BLUE)
	_text(Vector2(501, 110), "Mais rápido", 17, GOLD)

func _lamps(origin: Vector2, charge: float) -> void:
	for index in range(3):
		var center := origin + Vector2(index * 29, 0)
		var fill := clampf(charge - index, 0, 1)
		draw_circle(center, 8, GOLD if fill >= 1 else Color("555054"))
		draw_rect(Rect2(center + Vector2(-4, 7), Vector2(8, 6)), GOLD if fill >= 1 else Color("555054"))
		if fill > 0 and fill < 1:
			draw_arc(center, 11, -PI * 0.5, -PI * 0.5 + fill * TAU, 24, GOLD, 2, true)

func _text(position: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
