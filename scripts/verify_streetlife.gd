extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("verify")
func check(ok: bool, caption: String) -> void:
	print(("PASS " if ok else "FAIL ")+caption)
	if not ok: failures += 1
func physics(n: int = 30) -> void:
	for i in n: await physics_frame
func frames(n: int = 5) -> void:
	for i in n: await process_frame
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()
func verify() -> void:
	root.set_meta("testing",true)
	root.size = Vector2i(1280,720)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics()
	var car = game.car
	var start: Vector3 = car.global_position
	var coins: int = game.progress.coins
	Input.action_press("accelerate")
	Input.action_press("handbrake")
	await physics(120)
	check(car.burnout_active and car.rpm > 3500,"W + Space produces high-rev burnout")
	check(car.global_position.distance_to(start) < 0.2 and car.speed_kmh < 0.2,"Held brakes keep a stationary burnout in place")
	check(game.progress.coins == coins,"Stationary wheelspin cannot farm driving coins")
	check(car.tire_effects.smoke.size() == 2 and car.tire_effects.smoke[0].emitting,"Both rear tires have active smoke effects")
	check(car.tire_effects.marks.size() == 2,"Stationary burnout creates one pair of dark tire marks")
	check(car.engine_sound.tires.playing and car.engine_sound.tires.volume_linear > 0.1,"Burnout mixes tire squeal audio")
	var rear_rotation: Vector3 = car.wheels[1].rotation
	await physics(10)
	check(car.wheels[1].rotation.distance_to(rear_rotation)>0.1 and car.wheels[0].rotation.length()<0.01,"Rear wheel assemblies spin while fronts stay braked")
	Input.action_release("handbrake")
	await physics(60)
	Input.action_release("accelerate")
	check(not car.burnout_active and car.speed_kmh > 15,"Releasing Space launches the car normally")
	await physics(5)
	check(not car.tire_effects.smoke[0].emitting,"Smoke emission stops after burnout")
	check(game.mouse_captured and game.chase.mouse_look_enabled,"Driving enables mouse capture and mouse look")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(120,40)
	Input.parse_input_event(motion)
	await frames()
	check(game.chase.look_yaw < -0.2 and game.chase.look_pitch < 0,"Mouse motion rotates driving view")
	await key(KEY_M)
	check(not game.mouse_captured and not game.progress.mouse_lock,"M releases the mouse and remembers the preference")
	var yaw: float = game.chase.look_yaw
	Input.parse_input_event(motion)
	await frames()
	check(game.chase.look_yaw == yaw,"Unlocked mouse does not rotate the camera")
	await key(KEY_M)
	game.set_paused(true)
	await frames()
	check(not game.mouse_captured,"Pause menu releases captured mouse")
	game.set_paused(false)
	await frames()
	check(game.mouse_captured,"Resume restores requested mouse capture")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.mouse_captured,"Alt-tab/focus loss releases mouse")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.set_garage(true)
	await frames()
	check(not game.mouse_captured,"Garage releases mouse for purchases")
	game.set_garage(false)
	game.toggle_first_person()
	game.chase._unhandled_input(motion)
	await physics(2)
	check(game.chase.driver_camera.rotation.y != 0,"Cockpit camera also supports mouse look")
	game.set_night(true)
	var presence = preload("res://scripts/presence_state.gd").describe(game)
	check(presence.details == "Driving at night in the Sunset Coupe","Discord text includes night and the equipped car")
	car.position.z = 900
	presence = preload("res://scripts/presence_state.gd").describe(game)
	check(presence.state == "South Test Highway","Discord area changes with map position")
	car.reset_car()
	game.set_garage(true)
	game.progress.coins = 12000
	game.choose_car(4)
	game.set_garage(false)
	car.toggle_flight()
	presence = preload("res://scripts/presence_state.gd").describe(game)
	check(presence.details == "Flying at night in the Volt Aero Roadster","Discord flight activity names the electric car")
	Input.action_press("handbrake")
	Input.action_press("accelerate")
	await physics(10)
	check(not car.burnout_active,"Flight climb cannot trigger a burnout")
	Input.action_release("handbrake")
	Input.action_release("accelerate")
	var details = game.city.get_node("StreetDetails")
	check(details.get_child_count() > 250,"Central city includes shelters, grilles, signs and street furniture")
	game.set_mouse_lock(false)
	var loaded = load("res://scripts/progression.gd").new()
	loaded.save_path = game.progress.save_path
	loaded.load_game()
	check(not loaded.mouse_lock,"Mouse lock preference survives save/reload")
	DirAccess.remove_absolute(game.progress.save_path)
	print("RESULT: %d failures" % failures)
	quit(failures)
