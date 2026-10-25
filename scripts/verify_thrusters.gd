extends SceneTree
const Mods = preload("res://scripts/mods.gd")
var failures: int = 0
func _initialize() -> void: call_deferred("verify")
func check(ok: bool, caption: String) -> void:
	print(("PASS " if ok else "FAIL ")+caption)
	if not ok: failures += 1
func frames(n: int = 6) -> void:
	for i in n: await physics_frame
func verify() -> void:
	root.set_meta("testing",true)
	root.size = Vector2i(1280,720)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(20)
	var p = game.progress
	p.save_path = "user://thruster_verification.cfg"
	for model in [1,2,3,4]: p.owned.append(model)
	p.coins = 5000
	var index: int = Mods.INDUCTION.size()-1
	var part: Dictionary = Mods.INDUCTION[index]
	check(part.id == "gas_thrusters" and part.price == 2500,"Gas Thrusters is a priced workshop upgrade")
	for model in [0,1,2,4]:
		p.selected = model
		var coins: int = p.coins
		var message: String = p.choose_mod("induction",index)
		check(p.coins == coins and p.build_for().induction == "stock" and "Aurora RS only" in message,"Car %d cannot purchase Aurora-only thrusters" % model)
	p.selected = 3
	p.coins = 2499
	check("need" in p.choose_mod("induction",index) and p.coins == 2499,"Unaffordable thrusters do not charge coins")
	p.coins = 5000
	var message: String = p.choose_mod("induction",index)
	check(p.coins == 2500 and p.build_for().induction == "gas_thrusters" and "installed" in message,"Aurora purchase charges once and equips Gas Thrusters")
	p.choose_mod("induction",0)
	p.choose_mod("induction",index)
	check(p.coins == 2500,"Previously purchased thrusters can be re-equipped free")
	game.set_garage(true)
	game.choose_car(3)
	game.set_garage(false)
	check(game.car.tune.thrusters and is_equal_approx(game.car.acceleration,67.2),"Installed thrusters increase Aurora acceleration by 40 percent")
	check(is_equal_approx(game.car.max_speed,147.5232),"Factory Aurora with thrusters has a 330 MPH cap")
	var effects = game.car.thruster_effects
	check(effects.available and effects.ports.get_parent() == game.car.visual and effects.flames.size() == 2,"Aurora upgrade creates two exterior rear jets")
	check(not effects.smoke[0].emitting and not effects.sound.playing,"Thrusters are quiet and do not smoke at rest")
	game.car.crash_physics_enabled = false
	game.car.global_position = Vector3(3.5,.06,-700)
	await frames(15)
	Input.action_press("accelerate")
	await frames(30)
	check(effects.power > .8 and effects.smoke[0].emitting and effects.smoke[1].emitting,"Forward throttle emits smoke from both Aurora rear jets")
	check(effects.flames[0].visible and effects.lights[0].light_energy > .4,"Active jets have visible flame cones and local light")
	check(effects.sound.playing and effects.sound.volume_linear > .1,"Active gas jets play the thrust loop")
	check(game.car.engine_sound.turbo.volume_linear < .001,"Gas thrusters do not incorrectly play a turbo whistle")
	Input.action_release("accelerate")
	await frames(20)
	check(effects.power < .01 and not effects.smoke[0].emitting and not effects.sound.playing,"Lifting throttle stops smoke emission and thrust sound")
	Input.action_press("reverse")
	await frames(10)
	check(not effects.smoke[0].emitting,"Braking/reversing cannot fire forward thrusters")
	Input.action_release("reverse")
	Input.action_press("accelerate")
	await frames(10)
	game.car.reset_car()
	check(effects.power == 0 and not effects.smoke[0].emitting and not effects.flames[0].visible,"Reset clears jet power, smoke and flames immediately")
	Input.action_release("accelerate")
	check(p.save_game(),"Thruster ownership and equipped build save successfully")
	var loaded = load("res://scripts/progression.gd").new()
	loaded.save_path = p.save_path
	loaded.load_game()
	check(loaded.selected == 3 and loaded.coins == p.coins and loaded.build_for().induction == "gas_thrusters" and loaded.owns_part("induction","gas_thrusters"),"Save reload preserves coins, selected Aurora and purchased thrusters")
	game.set_garage(true)
	game.hud.garage_tabs.current_tab = 1
	game.hud.mod_choices.induction.select(index)
	game.hud.refresh_part("induction")
	check(not game.hud.mod_choices.induction.is_item_disabled(index) and game.hud.mod_buttons.induction.text == "INSTALLED","Aurora workshop exposes the installed upgrade")
	game.choose_car(0)
	check(game.hud.mod_choices.induction.is_item_disabled(index) and not game.car.thruster_effects.available,"Other cars show the restricted part disabled and no rear jets")
	game.choose_car(4)
	game.set_garage(false)
	effects = game.car.thruster_effects
	check(effects.available and effects.flames.size() == 2 and not game.car.tune.thrusters,"Roadster has factory rear jets without purchasing Aurora parts")
	check(is_equal_approx(game.car.acceleration,47.897142857) and is_equal_approx(game.car.max_speed,111.76),"Roadster factory acceleration and speed targets are preserved")
	Input.action_press("accelerate")
	await frames(12)
	check(effects.smoke[0].emitting and effects.sound.playing,"Roadster acceleration produces rear smoke and thrust sound")
	Input.action_release("accelerate")
	game.car.toggle_flight()
	await frames(20)
	check(effects.power > .15 and effects.smoke[0].emitting,"Roadster hover keeps a lighter thruster-vapor trail")
	game.car.toggle_flight()
	await frames(20)
	check(not effects.smoke[0].emitting,"Roadster jets shut off after landing with no throttle")
	game.set_garage(true)
	game.choose_car(3)
	game.set_garage(false)
	check(game.car.thruster_effects.available and game.car.tune.thrusters,"Switching cars restores the Aurora upgrade and rebuilds its ports")
	var invalid_build := Mods.stock_build()
	invalid_build.induction = "gas_thrusters"
	var tune: Dictionary = Mods.tune(p.CARS[0],invalid_build,0)
	check(not tune.thrusters and tune.induction.id == "stock","Direct invalid builds cannot grant thruster performance to other cars")
	# Compare actual on-road acceleration with identical car, route and input.
	game.set_garage(true)
	game.install_mod("induction",0)
	game.set_garage(false)
	game.car.reset_car()
	game.car.global_position = Vector3(3.5,.06,-700)
	await frames(15)
	Input.action_press("accelerate")
	await frames(60)
	var stock_speed: float = game.car.speed_kmh
	Input.action_release("accelerate")
	game.set_garage(true)
	game.install_mod("induction",index)
	game.set_garage(false)
	game.car.reset_car()
	game.car.global_position = Vector3(3.5,.06,-700)
	await frames(15)
	Input.action_press("accelerate")
	await frames(60)
	check(game.car.speed_kmh > stock_speed*1.25,"Gas Thrusters improve measured one-second road acceleration over the same stock Aurora")
	await frames(240)
	check(absf(game.car.speed_kmh/1.609344-330) < 2,"Upgraded Aurora actually reaches its 330 MPH road cap")
	Input.action_release("accelerate")
	# A forged non-Aurora ownership entry must not survive save sanitization.
	p.parts_owned["0"] = {"induction":["stock","gas_thrusters"]}
	p.builds["0"] = invalid_build
	p.save_game()
	loaded.load_game()
	loaded.selected = 0
	check(loaded.build_for().induction == "stock" and not loaded.owns_part("induction","gas_thrusters"),"Forged thruster ownership on other cars is removed at load")
	DirAccess.remove_absolute(p.save_path)
	print("RESULT: %d failures" % failures)
	quit(failures)
