extends SceneTree

const Art = preload("res://scripts/gameplay/tile_art.gd")
const Room = preload("res://scenes/generated_room.tscn")
const Assembler = preload("res://scripts/gameplay/piece_assembler.gd")
var failures := 0


func _init() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run() -> void:
	var room = Room.instantiate()
	root.add_child(room)
	var tiles: TileSet = room.wall_layer.tile_set
	var directions: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT,
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	# Every local neighborhood must have drawable art and retain solid wall collision.
	for mask in range(1, 256):
		var floor_cells := {}
		for i in range(8):
			if mask & (1 << i):
				floor_cells[directions[i]] = true
		var id: int = Art._wall_source_for_cell(Vector2i.ZERO, floor_cells, tiles)
		var source := tiles.get_source(id) as TileSetAtlasSource
		check(source != null and source.has_tile(Vector2i.ZERO), "Missing art for neighborhood %d" % mask)
		check(source.get_tile_data(Vector2i.ZERO, 0).get_collision_polygons_count(0) == 1,
			"Missing collision for neighborhood %d" % mask)
		var pixels := source.texture.get_image()
		# No adjacent face may be erased by another face's opaque black background.
		for i in range(4):
			if not mask & (1 << i):
				continue
			var face := (tiles.get_source(i + 1) as TileSetAtlasSource).texture.get_image()
			var preserved := true
			for y in range(32):
				for x in range(32):
					var expected := face.get_pixel(x, y)
					var actual := pixels.get_pixel(x, y)
					if actual.g * actual.a + 0.005 < expected.g * expected.a:
						preserved = false
			check(preserved, "A wall face was erased: mask %d, face %d" % [mask, i + 1])
	# Reproduce a stepped contour, including all four orientations.
	var preview := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	preview.fill(Color.BLACK)
	for rotation in range(4):
		room.floor_layer.clear()
		room.wall_layer.clear()
		var cells := {}
		for y in range(10):
			for x in range(2 + (y / 3) * 2, 11):
				var cell := Vector2i(x, y)
				for turn in range(rotation):
					cell = Vector2i(-cell.y, cell.x)
				cells[cell] = true
				room.floor_layer.set_cell(cell, 0, Vector2i.ZERO)
		for cell: Vector2i in cells:
			for y in range(-1, 2):
				for x in range(-1, 2):
					var neighbor := cell + Vector2i(x, y)
					if not cells.has(neighbor):
						room.wall_layer.set_cell(neighbor, 1, Vector2i.ZERO)
		Art.apply(room.floor_layer, room.wall_layer)
		var before: int = room.wall_layer.get_used_cells().size()
		Art.apply(room.floor_layer, room.wall_layer)
		check(room.wall_layer.get_used_cells().size() == before, "Repeated application changed geometry")
		var bounds: Rect2i = room.wall_layer.get_used_rect()
		var origin := Vector2i(rotation % 2, rotation / 2) * 512 + Vector2i(16, 16)
		for layer: TileMapLayer in [room.floor_layer, room.wall_layer]:
			for cell: Vector2i in layer.get_used_cells():
				var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
				preview.blend_rect(source.texture.get_image(), Rect2i(0, 0, 32, 32),
					origin + (cell - bounds.position) * 32)
	check(preview.save_png("res://laboratorio_salas/cantos_preview.png") == OK, "Cannot save preview")
	var catalog = Assembler.new()
	check(catalog.load_folder("res://piece-libraries"), "Cannot load current room libraries")
	var generated_count := 0
	for file_name: String in catalog.available_libraries:
		var assembler = Assembler.new()
		check(assembler.load_file("res://piece-libraries/" + file_name), "Cannot load " + file_name)
		for seed_value in [12, 45, 78]:
			assembler.rng.seed = seed_value
			var layout: Dictionary = assembler.assemble()
			check(not layout.is_empty(), "Cannot assemble " + file_name)
			if layout.is_empty():
				continue
			check(room.build_from_layout(layout), "Cannot build " + file_name)
			generated_count += 1
			for y in range(layout.height):
				for x in range(layout.width):
					var cell := Vector2i(x, y)
					var authored: String = layout.rows[y].substr(x, 1)
					check((room.floor_layer.get_cell_source_id(cell) != -1) == (authored == "1"), "Changed floor geometry")
					check((room.wall_layer.get_cell_source_id(cell) != -1) == (authored == "2"), "Changed generated wall geometry")
			await physics_frame
			await physics_frame
			for cell: Vector2i in room.wall_layer.get_used_cells():
				if room.wall_layer.get_cell_source_id(cell) < 32:
					continue
				var point: Vector2 = room.wall_layer.to_global(room.wall_layer.map_to_local(cell))
				# A tiny body also covers internal triangulation seams of merged wall polygons.
				var query := PhysicsShapeQueryParameters2D.new()
				var probe := CircleShape2D.new()
				probe.radius = 1.0
				query.shape = probe
				query.transform = Transform2D(0.0, point)
				query.collision_mask = 1
				check(not room.get_world_2d().direct_space_state.intersect_shape(query).is_empty(),
					"Junction lacks runtime collision: %s seed %d cell %s source %d at %s" % [file_name, seed_value, cell, room.wall_layer.get_cell_source_id(cell), point])
	room.free()
	print("Wall corners: 255 neighborhoods, four stepped contours, ", generated_count, " generated rooms; ", failures, " failures")
	quit(1 if failures else 0)
