extends Camera2D
## Adjust zoom so each world pixel occupies an integer number of screen pixels.
## Fractional scaling (e.g. 0.625×) creates pixel-art seams that move with the camera.

## Minimum integer scale (1 = one art pixel becomes one screen pixel).
@export_range(1, 8) var min_pixel_scale: int = 1

var _base_position := Vector2.ZERO


func _ready() -> void:
	_base_position = position
	get_viewport().size_changed.connect(_update_zoom)
	_update_zoom()


func _update_zoom() -> void:
	var window := get_window()
	var base_size := Vector2(window.content_scale_size)
	if base_size.x <= 0.0 or base_size.y <= 0.0:
		return
	var window_size := Vector2(window.size)
	# Scale applied to the base resolution by "canvas_items" stretch and "expand" aspect.
	var stretch := minf(window_size.x / base_size.x, window_size.y / base_size.y) * window.content_scale_factor
	var pixel_scale := maxf(min_pixel_scale, roundf(stretch))
	zoom = Vector2.ONE * (pixel_scale / stretch)
	# Preserve the player's screen offset from the original scene.
	position = _base_position / zoom.x
