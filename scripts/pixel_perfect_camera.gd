extends Camera2D
## Keep the close PC framing on every viewport size.
const FIXED_ZOOM: float = 1.6

func _ready() -> void:
	zoom = Vector2.ONE * FIXED_ZOOM
