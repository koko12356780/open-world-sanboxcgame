extends SceneTree
const Mods = preload("res://scripts/mods.gd")
var failures: int = 0
func _initialize() -> void:
	call_deferred("verify")
func check(ok: bool, caption: String) -> void:
	print(("PASS " if ok else "FAIL ")+caption)
	if not ok: failures += 1
func frames(count: int = 5) -> void:
	for i in count: await process_frame
func click(node: Control) -> void:
	var pos := node.get_global_rect().get_center()
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
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
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
	await frames(15)
	var p = game.progress
	p.save_path = "user://workshop_verification.cfg"
	check(game.hud.night_button.visible,"Unused shortcut is initially visible")
	await click(game.hud.night_button)
	check(game.night and not game.hud.night_button.visible,"Using night button works then hides its hint")
	await click(game.hud.view_button)
	check(game.chase.mode == 2 and not game.hud.view_button.visible,"First-person hint disappears after use")
	await key(KEY_G)
	check(game.garage_open and p.hints_used.get("garage",false),"Garage key records discovery")
	await key(KEY_ESCAPE)
	await click(game.hud.menu_button)
	check(game.hud.pause_nav.visible and paused,"Menu button opens proper paused menu")
	game.hud.open_options()
	game.hud.pause_tabs.current_tab = 0
	await frames()
	check(game.hud.controls_night.visible,"Used night control remains available in Controls tab")
	await click(game.hud.controls_night)
	check(not game.night and paused,"Controls tab can toggle night while paused")
	await click(game.hud.controls_view)
	check(game.chase.mode == 0,"Controls tab can switch back to chase")
	game.hud.pause_tabs.current_tab = 1
	await frames()
	game.hud.volume_slider.value = 37
	await frames()
	check(is_equal_approx(p.volume,0.37),"Audio slider changes actual stored master volume")
	await click(game.hud.mute_button)
	check(p.muted and AudioServer.is_bus_mute(0),"Mute control mutes the audio bus")
	game.hud.mute_button.button_pressed = false
	game.set_garage(true)
	game.hud.garage_tabs.current_tab = 1
	p.coins = 2000
	game.hud.refresh_garage()
	var stock_accel: float = game.car.acceleration
	var stock_speed: float = game.car.max_speed
	game.hud.mod_choices.engine.select(2)
	game.hud.refresh_part("engine")
	await frames(10)
	check(is_equal_approx(game.car.acceleration,stock_accel),"Selecting a part does not equip or charge it")
	await click(game.hud.mod_buttons.engine)
	check(p.coins == 1600 and p.build_for().engine == "v8" and game.car.acceleration > stock_accel,"Actual buy button installs V8, charges coins and increases acceleration")
	check(game.car.engine_sound.sound_key == "8_stock","V8 selects different cylinder sound profile")
	var v8_data: PackedByteArray = game.car.engine_sound.loaded.stream.data
	game.hud.mod_choices.exhaust.select(2)
	game.hud.refresh_part("exhaust")
	await frames(10)
	await click(game.hud.mod_buttons.exhaust)
	check(p.coins == 1460 and game.car.max_speed > stock_speed and p.build_for().exhaust == "straight_pipe","Straight pipe changes actual speed cap and costs coins")
	check(game.car.engine_sound.loaded.stream.data != v8_data and game.car.engine_sound.exhaust_gain > 1,"Straight pipe changes waveform and loudness")
	game.install_mod("induction",1)
	check(p.coins == 1240 and game.car.engine_sound.induction_id == "turbo","Turbo changes boost performance and audio configuration")
	game.install_mod("engine",0)
	var coins: int = p.coins
	game.install_mod("engine",2)
	check(p.coins == coins and p.build_for().engine == "v8","Owned engine can be refitted without paying twice")
	game.install_mod("engine",5)
	check(p.coins == coins and p.build_for().engine == "v8","Unaffordable engine cannot be installed")
	p.coins += 2000
	game.install_mod("engine",5)
	check(p.build_for().engine == "v16" and game.car.tune.engine.cyl == 16 and game.car.grip < 9,"V16 has distinct sound, more power and heavier handling")
	game.choose_car(1)
	check(p.build_for().engine == "stock" and game.car.engine_sound.sound_key == "6_stock","Other car retains its own factory build")
	game.choose_car(0)
	check(p.build_for().engine == "v16" and game.car.engine_sound.sound_key == "16_straight_pipe","Returning to a car restores its installed mods")
	check(p.save_game(),"Extended save writes successfully")
	var loaded = load("res://scripts/progression.gd").new()
	loaded.save_path = p.save_path
	loaded.load_game()
	check(loaded.build_for().engine == "v16" and loaded.owns_part("engine","v8") and loaded.hints_used.get("night",false) and is_equal_approx(loaded.volume,0.37),"Save reload preserves parts, equipped build, used hints and audio preference")
	game.set_garage(false)
	game.car.set_physics_process(false)
	var sound = game.car.engine_sound
	game.car.rpm = 3600
	game.car.throttle_amount = 1
	await frames(10)
	check(sound.idle.playing and sound.loaded.playing and sound.loaded.pitch_scale > 1.8,"Engine plays and follows RPM")
	check(sound.turbo.volume_linear > 0.05,"Boosted engine enables turbo whistle")
	game.car.throttle_amount = 0
	await frames()
	check(sound.effects.playing and sound.effects.stream.resource_path.ends_with("blowoff.wav"),"Releasing throttle triggers turbo blow-off")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1
	AudioServer.add_bus_effect(0,capture)
	await create_timer(0.25).timeout
	var mixed: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
	var peak: float = 0
	for sample in mixed: peak = maxf(peak,absf(sample.x))
	check(mixed.size() > 100 and peak > 0.001,"Engine produces non-silent audio through the actual mixer")
	game.set_paused(true)
	await frames()
	check(sound.idle.stream_paused and sound.loaded.stream_paused,"Engine loops pause in menus")
	await create_timer(0.1).timeout
	capture.clear_buffer()
	await create_timer(0.15).timeout
	mixed = capture.get_buffer(capture.get_frames_available())
	peak = 0
	for sample in mixed: peak = maxf(peak,absf(sample.x))
	check(peak < 0.0001,"Paused menu audio mixer is silent")
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	game.set_paused(false)
	game.car.set_physics_process(true)
	game.car.equip(0)
	game.car.reset_car()
	for i in 30: await physics_frame
	Input.action_press("accelerate")
	for i in 90: await physics_frame
	Input.action_release("accelerate")
	var baseline: float = game.car.speed_kmh
	game.car.apply_mods({"engine":"v16","exhaust":"straight_pipe","induction":"turbo"})
	game.car.reset_car()
	for i in 30: await physics_frame
	Input.action_press("accelerate")
	for i in 90: await physics_frame
	Input.action_release("accelerate")
	check(game.car.speed_kmh > baseline*1.4,"Modified car accelerates faster in actual physics")
	var signatures: Dictionary = {}
	for engine in [4,6,8,10,12,16]:
		for exhaust in Mods.EXHAUSTS:
			var stream: AudioStreamWAV = load("res://audio/%d_%s_load.wav" % [engine,exhaust.id])
			signatures[stream.data.hex_encode().sha256_text()] = true
	check(signatures.size() == 30,"All engine/exhaust load combinations contain distinct audio")
	var legacy_path := "user://legacy_verification.cfg"
	var legacy := ConfigFile.new()
	legacy.set_value("garage","coins",77)
	legacy.set_value("garage","owned",[0,1])
	legacy.set_value("garage","selected",1)
	legacy.save(legacy_path)
	var older = load("res://scripts/progression.gd").new()
	older.save_path = legacy_path
	older.load_game()
	check(older.coins == 77 and older.selected == 1 and older.build_for().engine == "stock","Older save format retains coins and cars with safe stock mods")
	legacy.set_value("workshop","builds",{"1":{"engine":"v16"}})
	legacy.set_value("workshop","parts",{})
	legacy.save(legacy_path)
	older.load_game()
	check(older.build_for().engine == "stock","Unowned or invalid saved upgrades cannot be equipped")
	DirAccess.remove_absolute(legacy_path)
	DirAccess.remove_absolute(p.save_path)
	DirAccess.remove_absolute("user://test_garage.cfg")
	print("RESULT: %d failures" % failures)
	quit(failures)
