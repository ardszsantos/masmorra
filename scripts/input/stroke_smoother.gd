extends RefCounted
## Light spatial smoothing without preferred angles or locked directions.
var smoothing_distance: float = 1.5
var _tip := Vector2.ZERO

func begin(position: Vector2) -> void:
	_tip = position

func sample(position: Vector2) -> Vector2:
	var distance := _tip.distance_to(position)
	if distance > 0.0:
		_tip = _tip.lerp(position, distance / (distance + smoothing_distance))
	return _tip
