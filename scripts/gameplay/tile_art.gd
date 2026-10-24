extends RefCounted
## Apply the shared tile artwork to any room in the game.

# Source IDs map Var0..Var5 to 0, 2, 3, 4, 5, 6.
const QUIET_FLOOR_SOURCES: Array[int] = [3, 3, 3, 6]
const LIGHT_WEAR_SOURCES: Array[int] = [2, 5]
const HEAVY_WEAR_SOURCES: Array[int] = [0, 4]
const WALL_SOURCE_BY_FLOOR_NEIGHBOR := {
	Vector2i(0, 1): 1, # Floor below the wall: top wall
	Vector2i(0, -1): 2, # Floor above the wall: bottom wall
	Vector2i(1, 0): 3, # Floor to the right of the wall: left wall
	Vector2i(-1, 0): 4, # Floor to the left of the wall: right wall
}
const CORNER_SOURCE_BY_FLOOR_NEIGHBOR := {
	Vector2i(1, 1): 5, # Top-left corner
	Vector2i(-1, 1): 6, # Top-right corner
	Vector2i(1, -1): 7, # Bottom-left corner
	Vector2i(-1, -1): 8, # Bottom-right corner
}
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT,
]
const DIAGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
]


static func apply(floor_layer: TileMapLayer, wall_layer: TileMapLayer,
		art_seed: int = 0, wear_coverage: float = 0.2, patch_radius: int = 2) -> void:
	if floor_layer == null or wall_layer == null:
		return
	var random := RandomNumberGenerator.new()
	random.seed = art_seed
	var floor_cells: Array[Vector2i] = floor_layer.get_used_cells()
	floor_cells.sort()
	var floor_lookup := {}
	for cell: Vector2i in floor_cells:
		floor_lookup[cell] = true
	var wear := _build_wear(floor_cells, floor_lookup, random, wear_coverage, patch_radius)
	for cell: Vector2i in floor_cells:
		var sources: Array[int] = QUIET_FLOOR_SOURCES
		if wear.has(cell):
			sources = HEAVY_WEAR_SOURCES if wear[cell] else LIGHT_WEAR_SOURCES
		floor_layer.set_cell(cell, sources[random.randi_range(0, sources.size() - 1)], Vector2i.ZERO, 0)
	_fill_missing_corners(wall_layer, floor_cells, floor_lookup)
	for cell: Vector2i in wall_layer.get_used_cells():
		wall_layer.set_cell(cell, _wall_source_for_cell(cell, floor_lookup, wall_layer.tile_set), Vector2i.ZERO)


static func _build_wear(cells: Array[Vector2i], lookup: Dictionary,
		random: RandomNumberGenerator, coverage: float, radius: int) -> Dictionary:
	var wear := {}
	if cells.is_empty():
		return wear
	radius = maxi(1, radius)
	var edges: Array[Vector2i] = []
	for cell: Vector2i in cells:
		for direction: Vector2i in CARDINAL_DIRECTIONS:
			if not lookup.has(cell + direction):
				edges.append(cell)
				break
	# Vary the amount of wear per room while keeping the Inspector value as a baseline.
	var target := clampi(roundi(cells.size() * coverage * random.randf_range(0.75, 1.25)), 0, cells.size())
	var attempts := 0
	while wear.size() < target and attempts < cells.size() * 2:
		attempts += 1
		var candidates: Array[Vector2i] = edges if not edges.is_empty() and random.randf() < 0.7 else cells
		var center: Vector2i = candidates[random.randi_range(0, candidates.size() - 1)]
		if wear.has(center):
			continue
		var frontier: Array[Vector2i] = [center]
		var queued := {center: true}
		var patch_size := random.randi_range(radius + 1, 1 + 2 * radius * (radius + 1))
		var placed := 0
		while not frontier.is_empty() and placed < patch_size and wear.size() < target:
			var index := random.randi_range(0, frontier.size() - 1)
			var cell: Vector2i = frontier[index]
			frontier.remove_at(index)
			if wear.has(cell):
				continue
			var offset := cell - center
			wear[cell] = absi(offset.x) + absi(offset.y) < radius
			placed += 1
			for direction: Vector2i in CARDINAL_DIRECTIONS:
				var neighbor := cell + direction
				var distance := neighbor - center
				if absi(distance.x) + absi(distance.y) > radius:
					continue
				if lookup.has(neighbor) and not queued.has(neighbor) and not wear.has(neighbor):
					queued[neighbor] = true
					frontier.append(neighbor)
	return wear


static func _fill_missing_corners(walls: TileMapLayer, cells: Array[Vector2i], floor_cells: Dictionary) -> void:
	var missing := {}
	for floor_cell: Vector2i in cells:
		for offset: Vector2i in DIAGONAL_DIRECTIONS:
			var corner := floor_cell + offset
			if floor_cells.has(corner) or walls.get_cell_source_id(corner) != -1:
				continue
			var touches_floor := false
			for direction: Vector2i in CARDINAL_DIRECTIONS:
				if floor_cells.has(corner + direction):
					touches_floor = true
					break
			if touches_floor:
				continue
			# Complete only an existing wall junction, preserving openings and doors.
			if walls.get_cell_source_id(corner - Vector2i(offset.x, 0)) != -1 and walls.get_cell_source_id(corner - Vector2i(0, offset.y)) != -1:
				missing[corner] = CORNER_SOURCE_BY_FLOOR_NEIGHBOR[-offset]
	for corner: Vector2i in missing:
		walls.set_cell(corner, missing[corner], Vector2i.ZERO)


static func _wall_source_for_cell(cell: Vector2i, floor_cells: Dictionary, tile_set: TileSet) -> int:
	var sources: Array[int] = []
	var neighbor_mask := 0
	var bit := 1
	for direction: Vector2i in CARDINAL_DIRECTIONS:
		if floor_cells.has(cell + direction):
			sources.append(WALL_SOURCE_BY_FLOOR_NEIGHBOR[direction])
			neighbor_mask |= bit
		bit <<= 1
	for offset: Vector2i in DIAGONAL_DIRECTIONS:
		# A diagonal cap is needed only where neither adjoining face already covers it.
		if floor_cells.has(cell + offset) and not floor_cells.has(cell + Vector2i(offset.x, 0)) and not floor_cells.has(cell + Vector2i(0, offset.y)):
			sources.append(CORNER_SOURCE_BY_FLOOR_NEIGHBOR[offset])
			neighbor_mask |= bit
		bit <<= 1
	if sources.size() == 1:
		return sources[0]
	if sources.size() > 1:
		return _joined_wall_source(tile_set, sources, neighbor_mask)
	# Corners and thick walls use the direction of the nearest floor tile.
	for radius in range(1, 33):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if absi(x) != radius and absi(y) != radius:
					continue
				var offset := Vector2i(x, y)
				if not floor_cells.has(cell + offset):
					continue
				if absi(x) > absi(y):
					return WALL_SOURCE_BY_FLOOR_NEIGHBOR[Vector2i.RIGHT if x > 0 else Vector2i.LEFT]
				return WALL_SOURCE_BY_FLOOR_NEIGHBOR[Vector2i.DOWN if y > 0 else Vector2i.UP]
	return 1


static func _joined_wall_source(tile_set: TileSet, sources: Array[int], neighbor_mask: int) -> int:
	# Cache each junction in the existing TileSet; no extra nodes or collision bodies.
	var source_id := 32 + neighbor_mask
	if tile_set.has_source(source_id):
		return source_id
	var size := tile_set.tile_size
	var joined := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	joined.fill(Color.TRANSPARENT)
	for id: int in sources:
		var source := tile_set.get_source(id) as TileSetAtlasSource
		var pixels := source.texture.get_image()
		var region := source.get_tile_texture_region(Vector2i.ZERO)
		for y in range(size.y):
			for x in range(size.x):
				var incoming := pixels.get_pixelv(region.position + Vector2i(x, y))
				var current := joined.get_pixel(x, y)
				# The art fades toward black. Lighten preserves both brick faces instead
				# of letting an opaque black background erase the perpendicular face.
				var alpha := maxf(current.a, incoming.a)
				if alpha > 0.0:
					joined.set_pixel(x, y, Color(
						maxf(current.r * current.a, incoming.r * incoming.a) / alpha,
						maxf(current.g * current.a, incoming.g * incoming.a) / alpha,
						maxf(current.b * current.a, incoming.b * incoming.a) / alpha, alpha))
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(joined)
	atlas.texture_region_size = size
	atlas.create_tile(Vector2i.ZERO)
	tile_set.add_source(atlas, source_id)
	var data := atlas.get_tile_data(Vector2i.ZERO, 0)
	var template := (tile_set.get_source(sources[0]) as TileSetAtlasSource).get_tile_data(Vector2i.ZERO, 0)
	for layer in range(tile_set.get_physics_layers_count()):
		data.set_collision_polygons_count(layer, template.get_collision_polygons_count(layer))
		for polygon in range(template.get_collision_polygons_count(layer)):
			data.set_collision_polygon_points(layer, polygon, template.get_collision_polygon_points(layer, polygon))
	return source_id
