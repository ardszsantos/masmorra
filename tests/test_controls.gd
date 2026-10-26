extends SceneTree

var failures: int = 0

class DamageTarget extends StaticBody2D:
	var damage_received: float = 0.0
	func take_damage(amount: float, _source := Vector2.ZERO) -> void:
		damage_received += amount

func _init() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var smoother := preload("res://scripts/input/stroke_smoother.gd").new()
	for degree in range(360):
		smoother.begin(Vector2.ZERO)
		var target := Vector2.from_angle(deg_to_rad(degree)) * 140.0
		var result := smoother.sample(target)
		check(result.normalized().is_equal_approx(target.normalized()), "Smoothing must preserve every angle")
		check(result.distance_to(target) <= 3.01, "Smoothing must stay close to pointer")
	smoother.begin(Vector2(100, 0))
	for degree in range(1, 361):
		var target := Vector2.from_angle(deg_to_rad(degree)) * 100.0
		check(smoother.sample(target).distance_to(target) <= 3.01, "Curve must follow pointer without axis locking")
	smoother.smoothing_distance = 0.0
	smoother.begin(Vector2.ZERO)
	check(smoother.sample(Vector2(17, 43)) == Vector2(17, 43), "Zero smoothing must preserve raw input")
	var recognizer := preload("res://scripts/input/stroke_gesture.gd").new()
	var recognized: Array[Vector2] = []
	recognizer.action_requested.connect(func(_trigger: StringName, direction: Vector2): recognized.append(direction))
	for rotation in [0.0, PI / 2.0, PI, -PI / 2.0]:
		recognizer.begin(Vector2.ZERO)
		for step in range(1, 15):
			recognizer.sample(Vector2(0, -step * 10).rotated(rotation))
		recognizer.end()
		var before := recognized.size()
		recognizer.begin(Vector2(300, 300))
		for step in range(1, 13):
			recognizer.sample(Vector2(300, 300) + Vector2(step * 10, 0).rotated(rotation))
		recognizer.end()
		check(recognized.size() == before + 1, "Two separate perpendicular strokes must slash in each direction")
		check(recognized.back().dot(Vector2.RIGHT.rotated(rotation)) > cos(deg_to_rad(10.0)), "Slash must follow second leg within drawing tolerance")
	var count := recognized.size()
	recognizer.begin(Vector2.ZERO)
	recognizer.sample(Vector2(0, -60))
	recognizer.end()
	check(recognized.size() == count, "Short stroke must not enter the gesture queue")
	recognizer.begin(Vector2.ZERO)
	recognizer.sample(Vector2(120, 0))
	recognizer.end()
	recognizer.begin(Vector2.ZERO)
	recognizer.sample(Vector2(100, -100))
	recognizer.end()
	check(recognized.size() == count + 1, "Any clear direction change outside dash tolerance must slash")
	recognizer.reset()
	count = recognized.size()
	for pass_index in range(2):
		recognizer.begin(Vector2.ZERO)
		recognizer.sample(Vector2(20, 45))
		recognizer.sample(Vector2(45, -35))
		recognizer.sample(Vector2(75, 55))
		recognizer.sample(Vector2(120, 0))
		recognizer.end()
	check(recognized.size() == count + 1, "Strongly curved strokes with clear direction intent must still dash")
	var movement_samples: Array[Vector2] = []
	recognizer.direction_changed.connect(func(direction: Vector2): movement_samples.append(direction))
	recognizer.reset()
	recognizer.begin(Vector2(100, 100))
	recognizer.sample(Vector2(100, 160))
	recognizer.sample(Vector2(100, 360))
	check(movement_samples.back().dot(Vector2.DOWN) > 0.99, "Elastic anchor must preserve a stable held direction")
	check(recognizer._anchor.distance_to(Vector2(100, 360)) <= recognizer.movement_anchor_radius + 0.01, "Elastic anchor must follow before the player runs out of drag space")
	recognizer.free()
	await test_new_gestures()
	var main := preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var pad = main.get_node("HUD/StrokePad")
	var player = main.get_node("Player")
	var abilities = player.get_node("Abilities")
	var queue_hud = main.get_node("HUD/GestureQueueHud")
	var settings = main.get_node("HUD/SettingsMenu")
	player.set_physics_process(false)
	check(not settings.has_node("SettingsPanel/Margin/Options/MobSpawnToggle"), "Spawn disabling option must be removed")
	check(pad.size.is_equal_approx(root.get_visible_rect().size), "Gesture surface must fill the viewport")
	for fraction in [Vector2(0.05, 0.05), Vector2(0.95, 0.05), Vector2(0.05, 0.95), Vector2(0.95, 0.95)]:
		var screen_touch := InputEventScreenTouch.new()
		screen_touch.index = 3
		screen_touch.pressed = true
		screen_touch.position = pad.get_global_transform_with_canvas() * (pad.size * fraction)
		pad._unhandled_input(screen_touch)
		check(pad.touch_index == 3, "Touch must start in every screen corner")
		screen_touch.pressed = false
		pad._input(screen_touch)
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	touch.position = pad.get_global_transform_with_canvas() * Vector2(200, 250)
	pad._unhandled_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = touch.position + Vector2(0, -140)
	pad._input(drag)
	check(player.movement_direction.is_equal_approx(Vector2.UP), "Initial stroke must walk")
	check(not abilities.get_child(0).active, "Initial stroke must not attack")
	drag.index = 4
	drag.position += Vector2(120, 0)
	pad._input(drag)
	check(player.movement_direction == Vector2.UP, "Second finger changed direction")
	drag.index = 3
	touch.pressed = false
	pad._input(touch)
	check(player.movement_direction == Vector2.ZERO, "Release must stop walking")
	check(pad._queue_remaining > 0.0, "First stroke must show a queued-stroke marker")
	check(queue_hud.visible and queue_hud.queued_directions.size() == 1, "Bottom HUD must contain one queued stroke token")
	check(queue_hud.queued_directions[0].dot(Vector2.UP) > 0.99, "Queued token must preserve the stroke direction")
	touch.pressed = true
	touch.position = pad.get_global_transform_with_canvas() * Vector2(350, 350)
	pad._unhandled_input(touch)
	drag.position = touch.position + Vector2(140, 0)
	pad._input(drag)
	check(player.movement_direction.is_equal_approx(Vector2.RIGHT), "Second stroke must still move the player")
	touch.pressed = false
	pad._input(touch)
	check(abilities.get_child(0).active, "Two perpendicular strokes must activate slash")
	check(pad._points.is_empty() and pad.touch_index == -1, "Successful attack must consume the stroke")
	check(pad._queue_completed and pad._queued_directions.size() == 2, "Successful gesture must preserve both on-screen arrows in green")
	check(queue_hud.visible and queue_hud._completed and queue_hud.queued_directions.size() == 2, "Successful gesture must show both completed queue tokens in green")
	check(abilities.resolve_velocity(Vector2.ONE, 0.01) == Vector2.ZERO, "Slash must immobilize player")
	abilities.step(0.3)
	check(not abilities.get_child(0).active, "Slash failed to finish")
	queue_hud.show_queued_stroke(Vector2.UP, 1.0)
	queue_hud.complete_queued_gesture(Vector2.RIGHT, 0.8)
	pad.show_queued_stroke(Vector2.UP, 1.0)
	pad.complete_queued_gesture(Vector2.RIGHT, 0.8)
	var stamina = player.get_node("Stamina")
	var saved_stamina: float = stamina.current
	stamina.current = 0.0
	abilities.request_action(&"stroke_turn", Vector2.RIGHT)
	check(queue_hud._failed and not queue_hud._completed, "Rejected gesture tokens must turn red")
	check(pad._queue_failed and not pad._queue_completed, "Rejected on-screen arrows must turn red")
	stamina.current = saved_stamina
	check(player.movement_direction == Vector2.ZERO, "Holding after attack must stay stopped")
	drag.position += Vector2(0, 60)
	pad._input(drag)
	check(player.movement_direction == Vector2.ZERO, "Consumed touch must not resume movement")
	check(pad._points.is_empty(), "Consumed touch must not draw again")
	check(player.movement_direction == Vector2.ZERO and pad.touch_index == -1, "Release must reset")
	touch.pressed = true
	pad._unhandled_input(touch)
	drag.position = touch.position + Vector2(-60, 0)
	pad._input(drag)
	check(player.movement_direction == Vector2.LEFT, "Fresh stroke must walk independently")
	pad.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(player.movement_direction == Vector2.ZERO, "Focus loss must stop walking")
	pad._unhandled_input(touch)
	drag.position = pad.get_global_transform_with_canvas() * (pad.size + Vector2(10, 10))
	pad._input(drag)
	check(pad.touch_index == -1 and player.movement_direction == Vector2.ZERO, "Leaving screen must cancel")
	var original_touch_position := touch.position
	var circle_center: Vector2 = pad.get_global_transform_with_canvas() * Vector2(240, 240)
	touch.position = circle_center + Vector2(70, 0)
	pad._unhandled_input(touch)
	for degree in range(5, 1081, 5):
		drag.position = circle_center + Vector2.from_angle(deg_to_rad(degree)) * 70.0
		pad._input(drag)
		main.get_node("StrokeGesture")._process(0.016)
		abilities.step(0.016)
	check(pad.touch_index == 3 and not pad._points.is_empty(), "Circling must retain the touch and trail")
	check(abilities.get_node("Spin").active, "Pad circles must sustain spin across multiple revolutions")
	check(pad._stabilized_circle and pad._circle_radius > 0.0, "Engaged spin must replace the raw trail with a stabilized circle")
	check(not player.movement_direction.is_zero_approx(), "Circling must continue steering movement")
	check(not abilities.resolve_velocity(player.movement_direction * 300.0, 0.016).is_zero_approx(), "Spin must not immobilize player")
	touch.pressed = false
	pad._input(touch)
	check(not abilities.get_node("Spin").active and player.movement_direction == Vector2.ZERO, "Release must stop both movement and spin")
	check(not pad._stabilized_circle, "Stopping spin must restore the normal freehand trail")
	touch.pressed = true
	touch.position = original_touch_position
	abilities.remove_ability(&"slash")
	pad._unhandled_input(touch)
	drag.position = touch.position + Vector2(0, -140)
	pad._input(drag)
	touch.pressed = false
	pad._input(touch)
	touch.pressed = true
	touch.position += Vector2(200, 0)
	pad._unhandled_input(touch)
	drag.position = touch.position + Vector2(120, 0)
	pad._input(drag)
	touch.pressed = false
	pad._input(touch)
	check(pad.touch_index == -1 and pad._points.is_empty(), "Completed touch must end even when the ability is unavailable")
	check(pad._queue_failed and queue_hud._failed, "Missing ability must mark both gesture displays red")
	abilities.request_action(&"stroke_turn", Vector2.RIGHT)
	check(abilities.get_child_count() == 3, "Slash removal failed")
	abilities.grant_ability(preload("res://scenes/abilities/slash.tscn"))
	abilities.request_action(&"stroke_turn", Vector2.RIGHT)
	check(abilities.get_node("Slash").active, "Reequipped slash failed")
	check(pad._queue_completed and queue_hud._completed, "Accepted action must update both gesture displays together")
	main.free()
	await test_gesture_result_feedback()
	print("Controls tests: ", failures, " failures")
	quit(1 if failures else 0)


func complete_stroke(gesture: Node, origin: Vector2, direction: Vector2) -> void:
	gesture.begin(origin)
	gesture.sample(origin + direction * 120.0)
	gesture.end()


func test_gesture_result_feedback() -> void:
	var main := preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var player := main.get_node("Player")
	player.set_physics_process(false)
	player.get_node("Stamina").set_physics_process(false)
	var gesture := main.get_node("StrokeGesture")
	var abilities := player.get_node("Abilities")
	var pad := main.get_node("HUD/StrokePad")
	var hud := main.get_node("HUD/GestureQueueHud")

	complete_stroke(gesture, Vector2(180, 300), Vector2.UP)
	check(not pad._queue_completed and not pad._queue_failed, "Single pending stroke must stay neutral on screen")
	check(not hud._completed and not hud._failed, "Single pending stroke must stay neutral in the queue")
	complete_stroke(gesture, Vector2(350, 300), Vector2.UP)
	check(abilities.get_node("Dash").active, "Feedback fixture must activate the real dash")
	check(pad._queue_completed and not pad._queue_failed, "Successful dash arrows must turn green")
	check(hud._completed and not hud._failed, "Successful dash tokens must turn green")
	check(pad._queued_directions.size() == 2 and hud.queued_directions.size() == 2, "Dash feedback must retain both completed strokes")

	abilities.interrupt()
	gesture.reset()
	complete_stroke(gesture, Vector2(180, 300), Vector2.UP)
	complete_stroke(gesture, Vector2(350, 300), Vector2.UP)
	check(not abilities.get_node("Dash").active, "Dash cooldown must reject an immediate repeat")
	check(pad._queue_failed and not pad._queue_completed, "Cooldown rejection must turn arrows red")
	check(hud._failed and not hud._completed, "Cooldown rejection must turn queue tokens red")

	gesture.reset()
	abilities.disabled = true
	complete_stroke(gesture, Vector2(180, 300), Vector2.UP)
	complete_stroke(gesture, Vector2(350, 300), Vector2.UP)
	check(pad._queue_failed and not pad._queue_completed, "Disabled action must turn arrows red")
	check(hud._failed and not hud._completed, "Disabled action must turn tokens red")

	pad._process(2.0)
	hud._process(2.0)
	abilities.action_resolved.emit(true)
	check(pad._queue_remaining == 0.0, "Late action result must not revive expired arrows")
	check(not hud.visible and hud.queued_directions.is_empty(), "Late action result must not revive expired queue tokens")
	gesture.reset()
	complete_stroke(gesture, Vector2(180, 300), Vector2.RIGHT)
	check(not pad._queue_completed and not pad._queue_failed, "Fresh stroke must clear the previous result from arrows")
	check(not hud._completed and not hud._failed, "Fresh stroke must clear the previous result from queue tokens")
	main.free()


func test_new_gestures() -> void:
	var gesture := preload("res://scripts/input/stroke_gesture.gd").new()
	var triggers: Array[StringName] = []
	var spin_values: Array[float] = []
	gesture.action_requested.connect(func(trigger: StringName, _direction: Vector2): triggers.append(trigger))
	gesture.sustained_action_changed.connect(func(_trigger: StringName, value: float): spin_values.append(value))
	for sign_value in [-1.0, 1.0]:
		triggers.clear()
		gesture.begin(Vector2(70, 0))
		for degree in range(5, 601, 5):
			gesture.sample(Vector2.from_angle(deg_to_rad(degree) * sign_value) * 70.0)
			if degree <= 355:
				check(spin_values.is_empty() or spin_values.back() == 0.0, "Partial circle must not start spin")
		check(triggers.is_empty(), "Circle must not trigger a consuming attack")
		check(spin_values.back() * sign_value > 0.9, "Continuous circle must ramp spin in either direction")
		gesture._process(0.3)
		check(spin_values.back() == 0.0, "Pausing circular input must stop spin")
		gesture.end()
	for degree in range(0, 360, 30):
		triggers.clear()
		var heading := Vector2.from_angle(deg_to_rad(degree))
		gesture.begin(Vector2.ZERO)
		gesture.sample(heading * 100.0)
		gesture.end()
		gesture.begin(Vector2(300, 300))
		gesture.sample(Vector2(300, 300) + heading * 100.0)
		gesture.end()
		check(triggers == [&"double_flick"], "Two same-direction strokes must dash at every angle")
	triggers.clear()
	gesture.begin(Vector2.ZERO)
	for step in range(1, 30):
		gesture.sample(Vector2(step * 10, 0))
	check(triggers.is_empty(), "Walking straight must not attack")
	gesture.end()
	gesture.begin(Vector2.ZERO)
	gesture.sample(Vector2(0, -110))
	gesture.end()
	gesture.begin(Vector2.ZERO)
	gesture.sample(Vector2(100, 25))
	gesture.end()
	check(triggers == [&"stroke_turn"], "A forgiving two-stroke L should activate slash")
	gesture.free()
	var body := preload("res://scenes/player.tscn").instantiate()
	root.add_child(body)
	body.set_physics_process(false)
	var target := DamageTarget.new()
	target.collision_layer = 2
	target.position = Vector2(60, 0)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	collision.shape = shape
	target.add_child(collision)
	root.add_child(target)
	await physics_frame
	await physics_frame
	var abilities = body.get_node("Abilities")
	body.get_node("Stamina").maximum = 1000.0
	body.get_node("Stamina").current = 1000.0
	abilities.update_sustained_action(&"circle", 1.0)
	abilities.step(0.1)
	check(target.damage_received > 0.0, "Spin must damage nearby receivers")
	check(body.get_node("Visual").rotation != 0.0, "Spin must rotate player visual")
	check(abilities.resolve_velocity(Vector2(120, 80), 0.01) == Vector2(120, 80), "Spin must preserve walking velocity")
	for tick in range(40):
		abilities.update_sustained_action(&"circle", 1.0)
		abilities.step(0.1)
	check(abilities.get_node("Spin").active, "Continuing circles must sustain spin beyond old duration")
	abilities.update_sustained_action(&"circle", 0.0)
	check(not abilities.get_node("Spin").active, "Release must stop spin immediately")
	abilities.update_sustained_action(&"circle", 1.0)
	abilities.request_action(&"double_flick", Vector2.RIGHT)
	check(not abilities.get_node("Dash").active, "Active spin must block simultaneous dash")
	abilities.remove_ability(&"spin")
	check(is_zero_approx(body.get_node("Visual").rotation), "Removing spin must restore visual rotation")
	abilities.request_action(&"double_flick", Vector2.RIGHT)
	var traveled: float = 0.0
	for tick in range(20):
		traveled += abilities.resolve_velocity(Vector2.ZERO, 0.01).x * 0.01
		abilities.step(0.01)
	check(is_equal_approx(traveled, 200.0), "Dash must travel configured distance")
	body.free()
	target.free()





