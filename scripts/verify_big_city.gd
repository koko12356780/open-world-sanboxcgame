extends SceneTree
var failures: int = 0

func _initialize() -> void:
	call_deferred("verify")

func frames(count: int = 3) -> void:
	for i in count: await process_frame

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1

func key(code: int, physical: bool = false, echo: bool = false) -> void:
	var event := InputEventKey.new()
	if physical: event.physical_keycode = code
	else: event.keycode = code
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	await frames()
	event = event.duplicate()
	event.pressed = false
	event.echo = false
	Input.parse_input_event(event)
	await frames()

func click(button: Button) -> void:
	var pos := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	Input.parse_input_event(motion)
	await frames()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pos
	event.global_position = pos
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
	await frames(10)
	for physical in [false,true]:
		game.set_night(false)
		game.chase.set_mode(0)
		await key(KEY_N,physical)
		check(game.night,"N enables night with %s key event" % ("physical" if physical else "logical"))
		await key(KEY_V,physical)
		check(game.chase.mode == 2 and game.chase.driver_camera.current,"V enables first person with %s key event" % ("physical" if physical else "logical"))
		await key(KEY_G,physical)
		check(game.garage_open and paused and game.hud.garage_panel.visible,"G opens garage with %s key event" % ("physical" if physical else "logical"))
		await key(KEY_V,physical)
		check(game.chase.mode == 0,"Camera shortcut works while garage pauses world")
		await key(KEY_G,physical)
		check(not game.garage_open and not paused,"G closes garage while paused")
	game.set_night(false)
	await key(KEY_N,false,true)
	check(not game.night,"Held-key echo does not repeat toggle")
	game.progress.restore_hints()
	await frames()
	await click(game.hud.night_button)
	check(game.night,"Actual mouse click toggles night button")
	game.chase.set_mode(0)
	await click(game.hud.view_button)
	check(game.chase.mode == 2,"Actual mouse click toggles first-person button")
	await click(game.hud.garage_button)
	check(game.garage_open and paused,"Actual mouse click opens garage")
	await key(KEY_ESCAPE)
	check(not game.garage_open and not paused,"Escape closes garage")
	await key(KEY_N)
	check(not game.night,"Keyboard still works after clicking HUD")
	game.set_night(true)
	var lamp = null
	for candidate in game.city.lamps:
		if candidate.nearby:
			lamp = candidate
			break
	check(lamp != null,"Nearby streetlamp found")
	if lamp != null:
		lamp.rng.seed = 1234
		lamp.next_fault = 0.001
		lamp._process(0.01)
		lamp._process(0.15)
		check(lamp.remaining > 0 and lamp.light_energy < 2 and lamp.fixture.emission_energy_multiplier < 0.5,"Scheduled fault dims both light pool and fixture")
		for i in 15: lamp._process(0.15)
		check(is_equal_approx(lamp.light_energy,5) and lamp.next_fault >= 20,"Flicker recovers and waits before another fault")
		game.set_night(false)
		check(not lamp.visible and lamp.fixture.emission_energy_multiplier == 0,"Day disables streetlight and fixture glow")
	var layout = load("res://scripts/world_layout.gd")
	check(layout.ROADS.size() == 17 and layout.BLOCKS.size()*layout.BLOCKS.size() == 256,"Expanded grid has 256 blocks and seventeen roads each way")
	check(is_equal_approx(layout.MAP_FIT.x*layout.WORLD_X,77) and is_equal_approx(layout.MAP_FIT.y*layout.WORLD_Z,77),"Minimap scale matches expanded boundary")
	game.chase.set_mode(0)
	game.car.global_position = Vector3(3.5,0.1,-245)
	game.car.velocity = Vector3.ZERO
	var start: Vector3 = game.car.global_position
	Input.action_press("accelerate")
	for i in 120: await physics_frame
	Input.action_release("accelerate")
	check(game.car.global_position.z < start.z-10 and game.car.is_on_floor(),"Car drives beyond old recovery boundary")
	var before: int = game.progress.coins
	game.set_garage(true)
	game.progress.coins = 120
	await key(KEY_2)
	check(game.progress.selected == 1 and game.progress.coins == 0,"Key 2 buys a car inside paused garage")
	game.progress.coins = before
	game.set_garage(false)
	DirAccess.remove_absolute(game.progress.save_path)
	print("RESULT: %d failures" % failures)
	quit(failures)
