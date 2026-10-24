extends Control
## Current room minimap: floor layout, player, exits, and living enemies.

@export var transition: Node
@export var player: Node2D
@export var enemies: Node2D
@export var background_color := Color(0.035, 0.045, 0.07, 0.75)
@export var floor_color := Color(0.75, 0.79, 0.85, 0.9)
@export var wall_color := Color(0.34, 0.41, 0.51, 0.9)
@export var player_color := Color(0.3, 0.75, 1.0, 1.0)
@export var enemy_color := Color(1.0, 0.3, 0.3, 1.0)
@export var exit_locked_color := Color(0.55, 0.55, 0.55, 1.0)
@export var exit_open_color := Color(0.35, 1.0, 0.48, 1.0)
@export_range(1.0, 8.0) var dot_radius: float = 3.0
@export_range(0.0, 24.0) var padding: float = 6.0

var _room: Node2D
var _layout: ImageTexture
var _used := Rect2i()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	transition.room_entered.connect(_show_room)


func _process(_delta: float) -> void:
	if is_instance_valid(_room):
		queue_redraw()
	elif visible:
		visible = false


func _show_room(room: Node2D) -> void:
	_room = room
	var floor_layer: TileMapLayer = room.floor_layer
	var wall_layer: TileMapLayer = room.wall_layer
	_used = floor_layer.get_used_rect().merge(wall_layer.get_used_rect())
	# One pixel per tile; upscale the image without filtering.
	var image := Image.create(maxi(1, _used.size.x), maxi(1, _used.size.y), false, Image.FORMAT_RGBA8)
	for cell in wall_layer.get_used_cells():
		image.set_pixelv(cell - _used.position, wall_color)
	for cell in floor_layer.get_used_cells():
		image.set_pixelv(cell - _used.position, floor_color)
	_layout = ImageTexture.create_from_image(image)
	visible = true
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_room) or _layout == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	var area := size - Vector2.ONE * padding * 2.0
	var scale_factor := minf(area.x / _used.size.x, area.y / _used.size.y)
	var map_size := Vector2(_used.size) * scale_factor
	var origin := Vector2.ONE * padding + (area - map_size) * 0.5
	draw_texture_rect(_layout, Rect2(origin, map_size), false)
	for portal: Area2D in _room.exit_doors:
		draw_circle(_to_map(portal.global_position, origin, scale_factor), dot_radius + 1.0,
			exit_locked_color if portal.locked else exit_open_color)
	for enemy in enemies.get_children():
		if enemy is Node2D and not enemy.get_node("Health").dead:
			draw_circle(_to_map(enemy.global_position, origin, scale_factor), dot_radius, enemy_color)
	draw_circle(_to_map(player.global_position, origin, scale_factor), dot_radius + 0.5, player_color)


func _to_map(world: Vector2, origin: Vector2, scale_factor: float) -> Vector2:
	var floor_layer: TileMapLayer = _room.floor_layer
	var cell := floor_layer.to_local(world) / Vector2(floor_layer.tile_set.tile_size)
	return origin + (cell - Vector2(_used.position)) * scale_factor
