extends RefCounted
## Shared choreography for the character and its tutorial illustration.
const WINDUP: float = 0.12
const AIR_TIME: float = 0.34
const RECOVERY: float = 0.18
const JUMP_HEIGHT: float = 44.0
const IMPACT_DISTANCE: float = 46.0
var body_offset := Vector2.ZERO
var body_scale := Vector2.ONE
var book_offset := Vector2.ZERO
var book_rotation: float = 0.0
var height: float = 0.0

func update(elapsed: float, direction: Vector2, windup: float = WINDUP,
		air_time: float = AIR_TIME, recovery: float = RECOVERY,
		jump_height: float = JUMP_HEIGHT, impact_distance: float = IMPACT_DISTANCE) -> void:
	var held := direction * 15.0 + Vector2(0, 2)
	var raised := -direction * 6.0 + Vector2(0, -43)
	var ground := direction * impact_distance + Vector2(0, 18)
	height = 0.0
	body_scale = Vector2.ONE
	if elapsed < windup:
		var progress := clampf(elapsed / windup, 0.0, 1.0)
		body_scale = Vector2(1.0 + progress * 0.12, 1.0 - progress * 0.18)
		book_offset = held.lerp(raised, progress)
	elif elapsed < windup + air_time:
		var progress := clampf((elapsed - windup) / air_time, 0.0, 1.0)
		height = sin(progress * PI) * jump_height
		var swing := smoothstep(0.45, 1.0, progress)
		book_offset = raised.lerp(ground, swing) + Vector2(0, -height)
		body_scale = Vector2(0.94, 1.06).lerp(Vector2.ONE, progress)
	else:
		var progress := clampf((elapsed - windup - air_time) / recovery, 0.0, 1.0)
		body_scale = Vector2(1.16, 0.78).lerp(Vector2.ONE, progress)
		book_offset = ground.lerp(held, smoothstep(0.25, 1.0, progress))
	body_offset = Vector2(0, -height + (1.0 - body_scale.y) * 24.0)
	book_rotation = direction.angle() + PI * 0.5

static func draw_grip(canvas: CanvasItem, body: Vector2, book: Vector2, rotation: float, texture: Texture2D) -> void:
	var side: Vector2 = Vector2.from_angle(rotation)
	for sign_value: float in [-1.0, 1.0]:
		var shoulder: Vector2 = body + Vector2(sign_value * 8.0, 2.0)
		var hand: Vector2 = book + side * sign_value * 15.0
		var elbow: Vector2 = shoulder.lerp(hand, 0.5) + Vector2(sign_value * 5.0, 5.0)
		var arm := PackedVector2Array([shoulder, elbow, hand])
		canvas.draw_polyline(arm, Color("292330"), 8.0, false)
		canvas.draw_polyline(arm, Color("59404a"), 5.0, false)
	# Rotate the corners explicitly to preserve any parent canvas transform.
	var corners := PackedVector2Array()
	for corner: Vector2 in [Vector2(-22, -15), Vector2(22, -15), Vector2(22, 15), Vector2(-22, 15)]:
		corners.append(book + corner.rotated(rotation))
	canvas.draw_polygon(corners, PackedColorArray([Color.WHITE]), PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]), texture)
	for sign_value: float in [-1.0, 1.0]:
		var hand: Vector2 = book + side * sign_value * 15.0
		canvas.draw_rect(Rect2(hand - Vector2(3, 3), Vector2(6, 6)), Color("c58e75"))
