extends SceneTree
## Render a contact sheet for explicit visual verification of equipment poses.

const PLAYER = preload("res://scenes/player.tscn")
const Controller = preload("res://scripts/upgrades/upgrade_controller.gd")
const Reward = preload("res://scripts/gameplay/room_reward.gd")
const LABELS: Array[String] = ["Direita", "Baixo-direita", "Frente", "Baixo-esquerda", "Esquerda", "Cima-esquerda", "Costas", "Cima-direita"]


func _init() -> void:
	run.call_deferred()


func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_position(Vector2i(-10000, -10000))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(960, 600)
	backdrop.color = Color(0.1, 0.12, 0.16)
	viewport.add_child(backdrop)
	var room := Node2D.new()
	viewport.add_child(room)
	for index in range(8):
		var player := PLAYER.instantiate()
		player.scale = Vector2(2, 2)
		player.position = Vector2(120 + (index % 4) * 240, 115 + (index / 4) * 280)
		room.add_child(player)
		player.set_physics_process(false)
		player.get_node("Camera2D").enabled = false
		var visual := player.get_node("Visual")
		visual.set_physics_process(false)
		var upgrades := player.get_node("Upgrades") as Controller
		upgrades.set_combat_context(room, false)
		for id in [&"jetpack", &"laser", &"gorgon"]:
			var reward := load("res://resources/rewards/%s.tres" % id) as Reward
			upgrades.grant_upgrade(reward)
		var direction := Vector2.from_angle(float(index) * TAU / 8.0)
		visual._face_direction(direction)
		visual._play_directional_animation(&"idle")
		visual.stop()
		visual.frame = 0
		var label := Label.new()
		label.position = Vector2((index % 4) * 240, 200 + (index / 4) * 280)
		label.size = Vector2(240, 40)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = LABELS[index]
		viewport.add_child(label)
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tmp/tests")
	var result := viewport.get_texture().get_image().save_png("res://tmp/tests/player-equipment-poses.png")
	print("Equipment contact sheet: ", error_string(result))
	viewport.free()
	quit(0 if result == OK else 1)
