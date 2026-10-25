extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("verify")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
func frames(count: int) -> void:
	for i in count: await physics_frame
func verify() -> void:
	root.set_meta("testing",true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(30)
	var p = game.progress
	p.save_path = "user://feature_verification.cfg"
	p.add_distance(9)
	check(p.coins == 0,"No coin before ten metres")
	p.add_distance(16)
	check(p.coins == 2 and is_equal_approx(p.remainder,5),"Distance coins and remainder")
	p.add_distance(-100)
	check(p.coins == 2,"Invalid distance cannot remove coins")
	game.set_garage(true)
	game.choose_car(1)
	check(p.selected == 0 and 1 not in p.owned and p.coins == 2,"Cannot buy unaffordable car")
	p.coins = 500
	game.choose_car(1)
	check(p.coins == 380 and p.selected == 1 and 1 in p.owned and game.car.max_speed == 48,"Purchase equips GT and deducts correct price")
	game.choose_car(0)
	game.choose_car(1)
	check(p.coins == 380,"Owned cars equip without repurchase")
	game.choose_car(2)
	check(p.coins == 30 and p.selected == 2 and game.car.grip == 13,"Rally purchase applies different handling")
	check(p.save_game(),"Save succeeds")
	var loaded = load("res://scripts/progression.gd").new()
	loaded.save_path = p.save_path
	loaded.load_game()
	check(loaded.coins == 30 and loaded.selected == 2 and loaded.owned.size() == 3 and is_equal_approx(loaded.remainder,5),"Save reload retains coins, cars, selection and partial distance")
	game.set_garage(false)
	game.set_night(true)
	check(game.sun.light_energy < 0.1 and game.car.headlights[0].visible,"Night changes lighting and enables headlights")
	var active: int = 0
	for lamp in game.city.lamps:
		if lamp.visible: active += 1
	check(active > 0 and active < game.city.lamps.size(),"Nearby streetlights illuminate while distant lights are culled")
	game.chase.set_mode(2)
	check(game.chase.driver_camera.current and not game.car.visual.visible and game.chase.cockpit.visible,"First person uses cockpit and hides opaque exterior")
	game.chase.set_mode(0)
	check(game.chase.camera.current and game.car.visual.visible and not game.chase.cockpit.visible,"Third person restores exterior")
	game.set_night(false)
	check(not game.car.headlights[0].visible,"Day turns off headlights")
	game.car.reset_car()
	await frames(30)
	var before: float = p.total_distance
	Input.action_press("accelerate")
	await frames(120)
	Input.action_release("accelerate")
	check(p.total_distance > before+5,"Actual driving feeds coin progression")
	game.set_garage(true)
	var stopped: Vector3 = game.car.position
	var saved_distance: float = p.total_distance
	Input.action_press("accelerate")
	await frames(30)
	Input.action_release("accelerate")
	check(game.car.position.is_equal_approx(stopped) and is_equal_approx(p.total_distance,saved_distance),"Garage pauses driving and coin earning")
	game.set_garage(false)
	DirAccess.remove_absolute(p.save_path)
	DirAccess.remove_absolute("user://test_garage.cfg")
	print("RESULT: %d failures" % failures)
	quit(failures)
