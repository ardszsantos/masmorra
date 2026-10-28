extends RefCounted
## A half-ellipse turns the outbound heading through 180 degrees before recall.

static func offset(progress: float, direction: Vector2, reach: float, width: float, side: float) -> Vector2:
	var angle := clampf(progress, 0.0, 1.0) * PI
	return direction * sin(angle) * reach + direction.orthogonal() * side * (1.0 - cos(angle)) * width

static func tangent(progress: float, direction: Vector2, reach: float, width: float, side: float) -> Vector2:
	var angle := clampf(progress, 0.0, 1.0) * PI
	return (direction * cos(angle) * reach + direction.orthogonal() * side * sin(angle) * width).normalized()
