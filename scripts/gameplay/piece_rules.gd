extends RefCounted
## Contract shared by the editor and game. Source: RoomBuilder/app/piece_rules.gd.
## Changes are published to both projects by tools/publish_to_game.ps1.

const FORMAT := "masmorra.piece_library"
const DRAFT_FORMAT := "masmorra.piece_project"
const VERSION := 2
const RULES_VERSION := 1
const MAX_SIZE := 129
const MAX_PIECES := 500
const DEFAULT_SIZE := Vector2i(47, 37)
const BOUNDS := Vector2i(99, 81)
const CONNECTION_WIDTH := 13
const MAX_ASSEMBLY_PIECES := 2
const TILE_SIZE := 32
const PLAYER_DISTANCE := 140.0
const DOOR_DISTANCE := 96.0
const SIDES := {"top": Vector2i.UP, "right": Vector2i.RIGHT,
	"bottom": Vector2i.DOWN, "left": Vector2i.LEFT}
const OPPOSITE := {"top": "bottom", "right": "left", "bottom": "top", "left": "right"}
const LABELS := {"top": "Cima", "right": "Direita", "bottom": "Baixo", "left": "Esquerda"}
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))


static func shape_error(raw: Variant) -> String:
	if not raw is Dictionary or not raw.get("id") is String or raw.id.is_empty():
		return "A peça precisa de um identificador."
	if not raw.get("name") is String or raw.name.length() > 120:
		return "O nome deve ter até 120 caracteres."
	for field in ["width", "height"]:
		if not integer(raw.get(field)) or raw[field] < 5 or raw[field] > MAX_SIZE:
			return "Use uma grade entre 5 e %d tiles por lado." % MAX_SIZE
	if not raw.get("rows") is Array or raw.rows.size() != raw.height:
		return "Grade incompleta."
	for row: Variant in raw.rows:
		if not row is String or row.length() != raw.width:
			return "Linha da grade com tamanho incorreto."
		if not row.replace("0", "").replace("1", "").replace("2", "").is_empty():
			return "Use apenas vazio, chão e parede."
	for field: String in ["entry"]:
		if raw.has(field) and not valid_marker(raw[field], raw):
			return "O ponto de entrada precisa estar em um tile de chão."
	for field: String in ["exits", "enemy_spawns"]:
		if raw.has(field):
			if not raw[field] is Array:
				return "Pontos manuais inválidos."
			for point: Variant in raw[field]:
				if not valid_marker(point, raw):
					return "Saídas e spawns precisam estar em tiles de chão."
	return ""


static func valid_marker(point: Variant, piece: Dictionary) -> bool:
	if not point is Array or point.size() != 2 or not integer(point[0]) or not integer(point[1]): return false
	var x := int(point[0]); var y := int(point[1])
	if x < 0 or y < 0 or x >= piece.width or y >= piece.height or piece.rows[y][x] != "1": return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx := x + dx; var ny := y + dy
			if nx < 0 or ny < 0 or nx >= piece.width or ny >= piece.height or piece.rows[ny][nx] != "1": return false
	return true


static func document(pieces: Array, playable: bool = false) -> Dictionary:
	var clean: Array = []
	for piece: Dictionary in pieces:
		var saved := {"id": piece.id, "name": piece.name, "width": piece.width,
			"height": piece.height, "rows": piece.rows.duplicate()}
		for field: String in ["entry", "exits", "enemy_spawns"]:
			if piece.has(field): saved[field] = piece[field].duplicate(true)
		clean.append(saved)
	return {"format": FORMAT if playable else DRAFT_FORMAT, "version": VERSION,
		"rules_version": RULES_VERSION, "pieces": clean}


static func read_document(data: Variant, game_only: bool = false) -> Dictionary:
	if not data is Dictionary:
		return {"error": "Arquivo de peças inválido."}
	var formats := [FORMAT] if game_only else [FORMAT, DRAFT_FORMAT]
	if not formats.has(data.get("format")) or data.get("version") != VERSION or data.get("rules_version") != RULES_VERSION:
		return {"error": "Use o novo formato de peças v2. Projetos antigos não são compatíveis."}
	if not data.get("pieces") is Array or data.pieces.size() > MAX_PIECES:
		return {"error": "O arquivo deve conter até %d peças." % MAX_PIECES}
	var ids := {}
	for index in range(data.pieces.size()):
		var piece: Variant = data.pieces[index]
		var problem := shape_error(piece)
		if not problem.is_empty():
			return {"error": "Peça %d: %s" % [index + 1, problem]}
		if ids.has(piece.id):
			return {"error": "Há identificadores de peça repetidos."}
		ids[piece.id] = true
	return {"pieces": document(data.pieces).pieces}


static func connected(cells: Dictionary, start: Vector2i) -> Dictionary:
	if not cells.has(start):
		return {}
	var reached := {start: true}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction: Vector2i in DIRECTIONS:
			var next := cell + direction
			if cells.has(next) and not reached.has(next):
				reached[next] = true
				queue.append(next)
	return reached


static func spacious_cells(floor_cells: Dictionary) -> Dictionary:
	var result := {}
	for cell: Vector2i in floor_cells:
		var clear := true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if not floor_cells.has(cell + Vector2i(dx, dy)):
					clear = false
		if clear:
			result[cell] = true
	return result


static func passage_repair_cells(floor_cells: Dictionary, spacious: Dictionary) -> Dictionary:
	var components: Array[Dictionary] = []
	var remaining := spacious.duplicate()
	while not remaining.is_empty():
		var component := connected(remaining, remaining.keys()[0])
		components.append(component)
		for cell: Vector2i in component:
			remaining.erase(cell)
	if components.size() < 2:
		return {}
	var goals: Dictionary = components[0]
	var queue: Array[Vector2i] = []
	var parents := {}
	for cell: Vector2i in goals:
		queue.append(cell)
		parents[cell] = cell
	var destination := Vector2i(-1, -1)
	var cursor := 0
	while cursor < queue.size() and destination.x < 0:
		var cell := queue[cursor]
		cursor += 1
		for direction: Vector2i in DIRECTIONS:
			var next := cell + direction
			if not floor_cells.has(next) or parents.has(next):
				continue
			parents[next] = cell
			if spacious.has(next) and not goals.has(next):
				destination = next
				break
			queue.append(next)
	if destination.x < 0:
		return {}
	var repair := {}
	var step := destination
	while not goals.has(step):
		if not spacious.has(step):
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var candidate := step + Vector2i(dx, dy)
					if not floor_cells.has(candidate):
						repair[candidate] = true
		step = parents[step]
	return repair
 

static func analyze(raw: Dictionary) -> Dictionary:
	var problem := shape_error(raw)
	if not problem.is_empty():
		return {"error": problem}
	# Empty margins take no assembly space. The floor always gets a border.
	var occupied := Rect2i()
	var has_tiles := false
	var source_floor := {}
	for y in range(int(raw.height)):
		for x in range(int(raw.width)):
			var cell := Vector2i(x, y)
			if raw.rows[y][x] != "0":
				var cell_rect := Rect2i(cell, Vector2i.ONE)
				occupied = occupied.merge(cell_rect) if has_tiles else cell_rect
				has_tiles = true
			if raw.rows[y][x] == "1":
				source_floor[cell] = true
	if source_floor.is_empty():
		return {"error": "Pinte chão ou use Criar base retangular.", "_ports": {}, "_hints": {}}
	for cell: Vector2i in source_floor:
		occupied = occupied.merge(Rect2i(cell - Vector2i.ONE, Vector2i(3, 3)))
	var rows: Array = []
	var floor_cells := {}
	for y in range(occupied.size.y):
		var row := ""
		for x in range(occupied.size.x):
			var source := Vector2i(x, y) + occupied.position
			var tile := "0"
			if source.x >= 0 and source.y >= 0 and source.x < raw.width and source.y < raw.height:
				tile = raw.rows[source.y][source.x]
			row += tile
			if tile == "1":
				floor_cells[Vector2i(x, y)] = true
		rows.append(row)
	var spacious := spacious_cells(floor_cells)
	var piece := {"id": raw.id, "name": raw.name, "width": occupied.size.x,
		"height": occupied.size.y, "rows": rows, "_origin": occupied.position,
		"_floor_cells": floor_cells, "_walkable_cells": spacious, "_ports": {}, "_hints": {}, "_problem_cells": {}, "error": ""}
	for field: String in ["entry", "exits", "enemy_spawns"]:
		if raw.has(field): piece[field] = raw[field].duplicate(true)
	for side: String in SIDES:
		var hint := find_port(piece, side)
		if not hint.is_empty():
			piece._hints[side] = hint
			if hint.missing.is_empty():
				piece._ports[side] = hint
	if occupied.size.x + 2 > BOUNDS.x or occupied.size.y + 2 > BOUNDS.y:
		piece.error = "Desenho grande demais: a sala inteira deve caber em %d × %d tiles, com borda." % [BOUNDS.x, BOUNDS.y]
	elif connected(floor_cells, floor_cells.keys()[0]).size() != floor_cells.size():
		piece.error = "Há ilhas de chão. Ligue todas com passagens de pelo menos 3 tiles."
	elif spacious.is_empty():
		piece.error = "Crie uma área de chão livre de pelo menos 3 × 3 tiles."
	elif connected(spacious, spacious.keys()[0]).size() != spacious.size():
		piece._problem_cells = passage_repair_cells(floor_cells, spacious)
		piece.error = "Preencha os tiles laranja para alargar a passagem."
	elif piece._ports.is_empty():
		piece.error = "Sem abertura possível. Pinte chão nas faixas laranja junto ao contorno (13 × 3 tiles). Basta um lado utilizável."
		if piece._hints.is_empty():
			piece.error = "Desenho pequeno demais para uma abertura de 13 tiles. Alargue um lado para pelo menos 15 tiles, com chão livre atrás da borda."
	return piece


static func find_port(piece: Dictionary, side: String) -> Dictionary:
	var direction: Vector2i = SIDES[side]
	var tangent := Vector2i(-direction.y, direction.x)
	var horizontal: bool = direction.y != 0
	var length: int = piece.width if horizontal else piece.height
	var depth: int = piece.height if horizontal else piece.width
	if length < CONNECTION_WIDTH + 2 or depth < 5:
		return {}
	var half := floori(CONNECTION_WIDTH / 2.0)
	var best_score := INF
	var best := {}
	for coordinate in range(half + 1, length - half - 1):
		var edge := Vector2i(coordinate, 0) if horizontal else Vector2i(0, coordinate)
		if side == "bottom":
			edge.y = piece.height - 1
		elif side == "right":
			edge.x = piece.width - 1
		var missing: Array[Vector2i] = []
		for offset in range(-half, half + 1):
			for inset in range(1, 4):
				var cell := edge - direction * inset + tangent * offset
				if not piece._floor_cells.has(cell):
					missing.append(cell)
		var score := missing.size() * 1000.0 + absf(coordinate - (length - 1) * 0.5)
		if score < best_score:
			best_score = score
			best = {"edge": edge, "inside": edge - direction * 2, "missing": missing}
	return best


static func open_ports(placed: Array, used: Array) -> Array:
	var result: Array = []
	for owner in range(placed.size()):
		var placement: Dictionary = placed[owner]
		for side: String in placement.piece._ports:
			if used.has([owner, side]):
				continue
			var port: Dictionary = placement.piece._ports[side]
			result.append({"side": side, "owner": owner, "edge": port.edge + placement.offset,
				"inside": port.inside + placement.offset})
	return result


static func attach(placed: Array, socket: Dictionary, piece: Dictionary) -> Dictionary:
	var opposite: String = OPPOSITE[socket.side]
	if not piece._ports.has(opposite):
		return {}
	var port: Dictionary = piece._ports[opposite]
	var offset: Vector2i = socket.edge + SIDES[socket.side] - port.edge
	var rectangle := Rect2i(offset, Vector2i(piece.width, piece.height))
	var area := rectangle
	for other: Dictionary in placed:
		var footprint := Rect2i(other.offset, Vector2i(other.piece.width, other.piece.height))
		if footprint.intersects(rectangle):
			return {}
		area = area.merge(footprint)
	if area.size.x + 2 > BOUNDS.x or area.size.y + 2 > BOUNDS.y:
		return {}
	return {"placement": {"piece": piece, "offset": offset},
		"join": {"from": socket.inside, "to": port.inside + offset},
		"used": [[socket.owner, socket.side], [placed.size(), opposite]]}


static func prepare_library(raw_pieces: Array) -> Dictionary:
	if raw_pieces.is_empty() or raw_pieces.size() > MAX_PIECES:
		return {"error": "Adicione de 1 a %d peças." % MAX_PIECES, "index": -1}
	var pieces: Array = []
	var ids := {}
	for index in range(raw_pieces.size()):
		var shape_problem := shape_error(raw_pieces[index])
		if not shape_problem.is_empty():
			return {"error": shape_problem, "index": index}
		var piece := analyze(raw_pieces[index])
		if not piece.error.is_empty():
			return {"error": piece.error, "index": index}
		if ids.has(piece.id):
			return {"error": "Identificador repetido.", "index": index}
		ids[piece.id] = true
		pieces.append(piece)
	# Build a concrete assembly for each piece instead of sampling random attempts.
	# Every exported piece belongs to at least one playable pair within the bounds.
	var seeds: Array = []
	for index in range(pieces.size()):
		var placed := [{"piece": pieces[index], "offset": Vector2i.ZERO}]
		var found := {}
		for socket: Dictionary in open_ports(placed, []):
			for candidate in range(pieces.size()):
				var next := attach(placed, socket, pieces[(index + candidate) % pieces.size()])
				if next.is_empty():
					continue
				var pair := [placed[0], next.placement]
				var joins := [next.join]
				var layout := merge(pair, joins)
				if not layout.is_empty():
					found = {"placed": pair, "joins": joins, "used": next.used, "layout": layout}
					break
			if not found.is_empty():
				break
		if found.is_empty():
			return {"error": "Nenhuma peça desta biblioteca encaixa aqui dentro de 99 × 81 tiles. Crie uma peça com abertura no lado oposto ou reduza o desenho.", "index": index}
		seeds.append(found)
	return {"pieces": pieces, "seeds": seeds, "error": ""}


static func merge(placed: Array, joins: Array, rng: RandomNumberGenerator = null) -> Dictionary:
	var area := Rect2i(placed[0].offset, Vector2i(placed[0].piece.width, placed[0].piece.height))
	for placement: Dictionary in placed:
		area = area.merge(Rect2i(placement.offset, Vector2i(placement.piece.width, placement.piece.height)))
	var shift := Vector2i.ONE - area.position
	var floor_cells := {}
	var walls := {}
	for placement: Dictionary in placed:
		var piece: Dictionary = placement.piece
		for y in range(piece.height):
			for x in range(piece.width):
				var cell := Vector2i(x, y) + Vector2i(placement.offset) + shift
				match piece.rows[y][x]:
					"1": floor_cells[cell] = true
					"2": walls[cell] = true
	for join: Dictionary in joins:
		var cell: Vector2i = join.from + shift
		var destination: Vector2i = join.to + shift
		var direction := (destination - cell).sign()
		var tangent := Vector2i(-direction.y, direction.x)
		while true:
			for offset in range(-floori(CONNECTION_WIDTH / 2.0), floori(CONNECTION_WIDTH / 2.0) + 1):
				floor_cells[cell + tangent * offset] = true
			if cell == destination:
				break
			cell += direction
	for cell: Vector2i in floor_cells:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var neighbor := cell + Vector2i(dx, dy)
				if not floor_cells.has(neighbor):
					walls[neighbor] = true
	var walkable := spacious_cells(floor_cells)
	if walkable.is_empty() or connected(walkable, walkable.keys()[0]).size() != walkable.size():
		return {}
	var starts: Array = placed[0].piece._walkable_cells.keys()
	var start_index := 0 if rng == null else rng.randi_range(0, starts.size() - 1)
	var spawn: Vector2i = starts[start_index] + Vector2i(placed[0].offset) + shift
	var manual_entry := false
	var manual_exits: Array = []
	var enemy_spawns: Array = []
	for placement: Dictionary in placed:
		var source: Dictionary = placement.piece
		var origin: Vector2i = source._origin
		if source.has("entry") and not manual_entry:
			var marker: Array = source.entry
			spawn = Vector2i(marker[0], marker[1]) - origin + Vector2i(placement.offset) + shift
			manual_entry = true
		for marker: Array in source.get("exits", []):
			manual_exits.append(Vector2i(marker[0], marker[1]) - origin + Vector2i(placement.offset) + shift)
		for marker: Array in source.get("enemy_spawns", []):
			enemy_spawns.append(Vector2i(marker[0], marker[1]) - origin + Vector2i(placement.offset) + shift)
	var exit_cell := farthest(walkable, spawn)
	if not manual_exits.is_empty(): exit_cell = manual_exits[0]
	if not has_encounter_space(walkable, spawn, exit_cell):
		if manual_entry or not manual_exits.is_empty(): return {}
		# The starting layout approved during export remains available during gameplay.
		spawn = starts[0] + Vector2i(placed[0].offset) + shift
		exit_cell = farthest(walkable, spawn)
		if not has_encounter_space(walkable, spawn, exit_cell):
			return {}
	var size := area.size + Vector2i(2, 2)
	var rows: Array = []
	for y in range(size.y):
		var row := ""
		for x in range(size.x):
			var cell := Vector2i(x, y)
			row += "1" if floor_cells.has(cell) else ("2" if walls.has(cell) else "0")
		rows.append(row)
	return {"id": "assembled", "name": "Combinação de %d peças" % placed.size(),
		"width": size.x, "height": size.y, "rows": rows,
		"entry": [spawn.x, spawn.y], "exits": (points_as_arrays(manual_exits) if not manual_exits.is_empty() else [[exit_cell.x, exit_cell.y]]),
		"enemy_spawns": points_as_arrays(enemy_spawns),
		"_spawn_cell": spawn, "_floor_cells": floor_cells, "_walkable_cells": walkable,
		"piece_count": placed.size()}


static func points_as_arrays(points: Array) -> Array:
	var result: Array = []
	for point: Vector2i in points: result.append([point.x, point.y])
	return result


static func farthest(cells: Dictionary, start: Vector2i) -> Vector2i:
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction: Vector2i in DIRECTIONS:
			var next := cell + direction
			if cells.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return queue.back()


static func has_encounter_space(cells: Dictionary, spawn: Vector2i, exit_cell: Vector2i) -> bool:
	for cell: Vector2i in cells:
		if Vector2(cell - spawn).length() * TILE_SIZE >= PLAYER_DISTANCE and Vector2(cell - exit_cell).length() * TILE_SIZE >= DOOR_DISTANCE:
			return true
	return false


static func shuffled_indices(count: int, rng: RandomNumberGenerator) -> Array:
	var indices: Array = range(count)
	for index in range(count - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var saved: int = indices[index]
		indices[index] = indices[other]
		indices[other] = saved
	return indices


static func assemble(library: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if library.get("seeds", []).is_empty():
		return {}
	var pieces: Array = library.pieces
	var start: Dictionary = library.seeds[rng.randi_range(0, library.seeds.size() - 1)]
	# Vary the starting pair; the approved pair is always the fallback.
	var first: Array = [start.placed[0]]
	var sockets := open_ports(first, [])
	var chosen := false
	for slot: int in shuffled_indices(sockets.size(), rng):
		for candidate: int in shuffled_indices(pieces.size(), rng):
			var next := attach(first, sockets[slot], pieces[candidate])
			if next.is_empty():
				continue
			var pair := [first[0], next.placement]
			var layout := merge(pair, [next.join], rng)
			if not layout.is_empty():
				start = {"placed": pair, "joins": [next.join], "used": next.used, "layout": layout}
				chosen = true
				break
		if chosen:
			break
	var placed: Array = start.placed.duplicate()
	var joins: Array = start.joins.duplicate()
	var used: Array = start.used.duplicate()
	var result: Dictionary = start.layout
	var target := rng.randi_range(2, MAX_ASSEMBLY_PIECES)
	while placed.size() < target:
		sockets = open_ports(placed, used)
		var added := false
		for slot: int in shuffled_indices(sockets.size(), rng):
			for candidate: int in shuffled_indices(pieces.size(), rng):
				var next := attach(placed, sockets[slot], pieces[candidate])
				if next.is_empty():
					continue
				var trial := placed + [next.placement]
				var trial_joins := joins + [next.join]
				var layout := merge(trial, trial_joins, rng)
				if layout.is_empty():
					continue
				placed = trial
				joins = trial_joins
				used.append_array(next.used)
				result = layout
				added = true
				break
			if added:
				break
		if not added:
			break
	result = result.duplicate(true)
	result.id = "assembled_%d" % rng.randi()
	return result
