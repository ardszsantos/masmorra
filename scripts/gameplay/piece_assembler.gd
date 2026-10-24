extends RefCounted
## File adapter. Geometry, compatibility, and assembly belong to the shared contract.
const Rules = preload("res://scripts/gameplay/piece_rules.gd")

var pieces: Array = []
var last_error := ""
var rng := RandomNumberGenerator.new()
var _library: Dictionary = {}
var available_libraries: Dictionary = {}
var enabled_libraries: Array[String] = []


func _init() -> void:
	rng.randomize()


func load_text(text: String) -> bool:
	var parsed := JSON.new()
	if parsed.parse(text) != OK:
		last_error = "JSON inválido: linha %d." % parsed.get_error_line()
		return false
	var decoded := Rules.read_document(parsed.data, true)
	if decoded.has("error"):
		last_error = decoded.error
		return false
	var prepared := Rules.prepare_library(decoded.pieces)
	if not prepared.error.is_empty():
		var title: String = decoded.pieces[prepared.index].name if prepared.index >= 0 else "Biblioteca"
		last_error = "%s: %s" % [title, prepared.error]
		return false
	_library = prepared
	pieces = prepared.pieces
	last_error = ""
	return true


func load_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "Não foi possível abrir %s: %s" % [path, error_string(FileAccess.get_open_error())]
		return false
	if file.get_length() > 32 * 1024 * 1024:
		last_error = "Biblioteca maior que 32 MB."
		return false
	return load_text(file.get_as_text())


func load_folder(path: String) -> bool:
	var files := DirAccess.get_files_at(path)
	if DirAccess.get_open_error() != OK:
		last_error = "Pasta de peças não encontrada: " + path
		return false
	available_libraries.clear()
	enabled_libraries.clear()
	var problems: Array[String] = []
	for file_name: String in files:
		# Incomplete projects and legacy files never enter the game's selection.
		if not file_name.to_lower().ends_with(".piece_library.json"):
			continue
		var library = get_script().new()
		if library.load_file(path.path_join(file_name)):
			available_libraries[file_name] = library._library
			enabled_libraries.append(file_name)
		else:
			problems.append("%s: %s" % [file_name, library.last_error])
	if enabled_libraries.is_empty():
		problems.append("Exporte uma biblioteca v2 pelo Room Builder para " + path)
		last_error = "\n".join(problems)
		return false
	_rebuild_selection()
	last_error = "\n".join(problems)
	return true


func set_library_enabled(file_name: String, enabled: bool) -> bool:
	if not available_libraries.has(file_name):
		return false
	if enabled_libraries.has(file_name) == enabled:
		return true
	if enabled:
		enabled_libraries.append(file_name)
	else:
		enabled_libraries.erase(file_name)
	_rebuild_selection()
	return true


func set_all_libraries_enabled(enabled: bool) -> void:
	enabled_libraries.clear()
	if enabled:
		for file_name: String in available_libraries:
			enabled_libraries.append(file_name)
	_rebuild_selection()


func _rebuild_selection() -> void:
	var pooled: Array = []
	var seeds: Array = []
	for file_name: String in available_libraries:
		if enabled_libraries.has(file_name):
			pooled.append_array(available_libraries[file_name].pieces)
			seeds.append_array(available_libraries[file_name].seeds)
	pieces = pooled
	_library = {"pieces": pooled, "seeds": seeds}


func assemble() -> Dictionary:
	return Rules.assemble(_library, rng)
