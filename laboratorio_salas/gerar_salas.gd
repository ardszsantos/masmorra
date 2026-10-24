extends SceneTree

const SALA = preload("res://scenes/generated_room.tscn")
const RoomDeck = preload("res://scripts/gameplay/room_deck.gd")
const DECKS_FOLDER := "res://room-decks"
const QUANTIDADE := 10
const PIXELS_POR_TILE := 12


func _init() -> void:
	gerar.call_deferred()


func gerar() -> void:
	var deck = RoomDeck.new()
	if not deck.load_folder(DECKS_FOLDER):
		push_error(deck.last_error)
		quit(1)
		return
	var pasta := ProjectSettings.globalize_path("res://laboratorio_salas/imagens")
	var erro := DirAccess.make_dir_recursive_absolute(pasta)
	if erro != OK:
		push_error("Não foi possível criar a pasta de imagens: %s" % error_string(erro))
		quit(1)
		return
	var sala = SALA.instantiate()
	root.add_child(sala)
	# Use the same scale and framing to compare the sizes of all ten rooms.
	var tamanho := Vector2i.ZERO
	for layout: Dictionary in deck.layouts:
		tamanho.x = maxi(tamanho.x, layout.width + 4)
		tamanho.y = maxi(tamanho.y, layout.height + 4)
	for indice in range(QUANTIDADE):
		if not sala.build_from_layout(deck.draw_room()):
			sala.free()
			quit(1)
			return
		var imagem := Image.create(tamanho.x * PIXELS_POR_TILE, tamanho.y * PIXELS_POR_TILE, false, Image.FORMAT_RGB8)
		imagem.fill(Color.BLACK)
		for celula: Vector2i in sala.floor_layer.get_used_cells():
			var pixel := (celula + Vector2i(2, 2)) * PIXELS_POR_TILE
			imagem.fill_rect(Rect2i(pixel, Vector2i.ONE * PIXELS_POR_TILE), Color.WHITE)
		var arquivo := pasta.path_join("sala_%02d.png" % (indice + 1))
		erro = imagem.save_png(arquivo)
		if erro != OK:
			push_error("Não foi possível salvar %s: %s" % [arquivo, error_string(erro)])
			sala.free()
			quit(1)
			return
		print("%s | sala: %s" % [arquivo, sala.layout_id])
	sala.free()
	print("Pronto: %d imagens em %s" % [QUANTIDADE, pasta])
	quit()
