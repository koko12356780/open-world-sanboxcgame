extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("verify")
func check(ok: bool, caption: String) -> void:
	print(("PASS " if ok else "FAIL ")+caption)
	if not ok: failures += 1
func frames(n: int = 5) -> void:
	for i in n: await process_frame
func physics(n: int = 30) -> void:
	for i in n: await physics_frame
func click(node: Control) -> void:
	var pos := node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	Input.parse_input_event(motion)
	await frames()
	var event := InputEventMouseButton.new()
	event.position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()
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
	root.set_meta("show_title",true)
	root.size = Vector2i(1280,720)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(15)
	var hud = game.hud
	var car = game.car
	check(game.title_open and paused and hud.main_panel.visible,"Launch opens main menu and pauses world")
	check(hud.continue_button.disabled and hud.load_button.disabled,"Fresh session has no save to continue/load")
	await click(hud.main_buttons[1])
	check(game.session_started and not paused and not game.title_open,"New Game mouse click starts driving")
	game.set_paused(true)
	await frames()
	check(hud.pause_nav.visible and hud.pause_buttons.size() == 6,"Reference-style pause menu contains all six actions")
	await click(hud.pause_buttons[1])
	hud.pause_tabs.current_tab = 2
	await frames()
	check(game.options_open and hud.pause_panel.visible,"Options opens from pause menu")
	await click(hud.crash_toggle)
	check(not car.crash_physics_enabled and not game.progress.crash_enabled,"Gameplay switch actually disables crash effects")
	await key(KEY_ESCAPE)
	check(hud.pause_nav.visible and not game.options_open,"Escape returns from options to pause menu")
	await click(hud.pause_buttons[4])
	check(game.title_open and hud.main_panel.visible and not hud.continue_button.disabled,"Main Menu action saves and enables Continue")
	await click(hud.main_buttons[0])
	check(not paused and not game.title_open,"Continue mouse click resumes session")
	game.set_garage(true)
	game.progress.coins = 5999
	game.choose_car(3)
	check(game.progress.selected == 0 and game.progress.coins == 5999,"Premium car cannot be bought with insufficient coins")
	game.progress.coins = 20000
	game.choose_car(3)
	check(game.progress.selected == 3 and game.progress.coins == 14000 and car.model_index == 3,"Aurora costs 6000 and equips a different model")
	check(car.engine_sound.sound_key == "8_stock","Aurora has a factory V8 sound")
	game.set_garage(false)
	car.global_position = Vector3(3.5,0.06,1400)
	await physics()
	Input.action_press("accelerate")
	await physics(210)
	check(absf(car.speed_kmh/1.609344-300) < 0.15,"Actual factory hypercar reaches 300 mph")
	print("MEASURED hypercar MPH: ",car.speed_kmh/1.609344)
	Input.action_release("accelerate")
	game.set_garage(true)
	game.choose_car(4)
	check(game.progress.selected == 4 and game.progress.coins >= 2000 and car.model_index == 4,"Roadster costs 12000 and equips electric model")
	check(car.engine_sound.sound_key == "electric","Electric model uses its own electric audio")
	var balance: int = game.progress.coins
	game.install_mod("engine",5)
	check(game.progress.coins == balance and game.progress.build_for().engine == "stock","Incompatible combustion swaps cannot charge the EV owner")
	game.set_garage(false)
	car.global_position = Vector3(3.5,0.06,1000)
	await physics()
	var launch_frames: int = 0
	var prev: float = 0
	Input.action_press("accelerate")
	while car.speed_kmh < 96.56064 and launch_frames < 90:
		prev = car.speed_kmh
		await physics(1)
		launch_frames += 1
	var fraction: float = (96.56064-prev)/maxf(0.001,car.speed_kmh-prev)
	var launch_time: float = (launch_frames-1+fraction)/60.0
	Input.action_release("accelerate")
	print("MEASURED Roadster 0-60 MPH: ",launch_time," s")
	check(absf(launch_time-0.56) < 0.035,"Actual Roadster physics reaches 60 mph in approximately 0.56 seconds")
	car.velocity = Vector3.ZERO
	await key(KEY_F)
	check(car.flight_active,"Physical F key enables EV flight")
	var start_y: float = car.position.y
	Input.action_press("handbrake")
	Input.action_press("accelerate")
	var old_coins: int = game.progress.coins
	await physics(90)
	Input.action_release("handbrake")
	Input.action_release("accelerate")
	check(car.position.y > start_y+10 and car.position.z < 990,"Flying car climbs and drives through the air")
	await frames()
	check(game.progress.coins > old_coins,"Horizontal flight distance earns coins")
	start_y = car.position.y
	Input.action_press("descend")
	await physics(100)
	Input.action_release("descend")
	check(car.position.y < start_y-2,"Ctrl flight action descends")
	car.position.y = 159.8
	car.velocity.y = 22
	Input.action_press("handbrake")
	await physics(10)
	Input.action_release("handbrake")
	check(car.position.y <= 160 and car.velocity.y <= 0,"Flight ceiling caps position and velocity safely")
	await key(KEY_F)
	check(not car.flight_active and car.floor_snap_length > 0,"Flight off restores normal gravity mode")
	game.set_garage(true)
	game.choose_car(0)
	game.set_garage(false)
	check(not car.toggle_flight(),"Ordinary cars cannot fly")
	game.set_crashes(true)
	car.global_position = Vector3(3.5,0.06,1684)
	car.rotation.y = PI
	car.velocity = Vector3(0,0,70)
	await physics(20)
	check(car.damage > 20 and car.velocity.z < 20,"High-speed wall impact damages and rebounds the car")
	var debris: int = 0
	for child in car.get_parent().get_children():
		if child is RigidBody3D: debris += 1
	check(debris > 0,"Impact spawns physical breakaway debris")
	check(car.visual.get_node("BodyShell").scale.z < 0.96,"Impact visibly deforms the body shell")
	car.reset_car()
	check(car.damage == 0 and car.visual.get_node("BodyShell").scale == Vector3.ONE,"Reset repairs body and restores performance")
	game.set_crashes(false)
	car.global_position = Vector3(3.5,0.06,1684)
	car.rotation.y = PI
	car.velocity = Vector3(0,0,70)
	await physics(20)
	check(car.damage == 0 and car.position.z < 1700,"Disabled crash effects retain solid wall collision")
	car.reset_car()
	car.global_position = Vector3(3.5,0.06,1000)
	game.set_night(true)
	game.chase.set_mode(2)
	game.save_now()
	game.progress.coins = 0
	car.position.z = 1100
	game.set_night(false)
	game.load_saved_game()
	check(absf(car.position.z-1000) < 0.1 and game.night and game.chase.mode == 2,"Load restores saved location, lighting and camera")
	check(3 in game.progress.owned and 4 in game.progress.owned and not game.progress.crash_enabled,"Save reload preserves premium ownership and crash preference")
	game.show_title()
	await frames()
	await click(hud.main_buttons[1])
	check(hud.new_game_dialog.visible and game.progress.owned.size() > 1,"New Game asks before replacing existing progress")
	hud.new_game_dialog.hide()
	hud.new_game_dialog.confirmed.emit()
	check(game.progress.owned == [0] and game.progress.coins == 0 and not paused and not car.crash_physics_enabled,"Confirmed New Game resets progress and retains crash preference")
	DirAccess.remove_absolute(game.progress.save_path)
	print("RESULT: %d failures" % failures)
	quit(failures)
