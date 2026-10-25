extends SceneTree
## Run with: godot --headless --path . --script scripts/verify.gd
var failures: int = 0

func _initialize() -> void:
	call_deferred("verify")

func frames(count: int) -> void:
	for i in count: await physics_frame

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func verify() -> void:
	root.set_meta("testing",true)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await frames(30)
	var car = scene.car
	check(car.is_on_floor(), "Car settles on ground")
	var start: Vector3 = car.position
	Input.action_press("accelerate")
	await frames(180)
	Input.action_release("accelerate")
	check(car.position.z < start.z - 10 and car.speed_kmh > 10, "Forward acceleration moves down road")
	Input.action_press("handbrake")
	await frames(300)
	Input.action_release("handbrake")
	check(car.speed_kmh < 3, "Handbrake stops car")
	car.reset_car()
	await frames(30)
	Input.action_press("reverse")
	await frames(120)
	Input.action_release("reverse")
	check(car.position.z > start.z + 3, "Reverse moves backward")
	car.reset_car()
	await frames(30)
	Input.action_press("accelerate")
	Input.action_press("left")
	await frames(90)
	Input.action_release("accelerate")
	Input.action_release("left")
	check(car.rotation.y > 0.15, "Steering changes heading")
	car.reset_car()
	await frames(30)
	check(car.position.distance_to(car.spawn.origin) < 1.2 and car.speed_kmh < 1, "Reset restores spawn and clears speed")
	var edge: float = preload("res://scripts/world_layout.gd").WORLD_Z
	car.global_position = Vector3(3.5, 0.1, -edge+8)
	car.velocity = Vector3(0, 0, -30)
	Input.action_press("accelerate")
	await frames(120)
	Input.action_release("accelerate")
	check(car.position.z > -edge and car.speed_kmh < 3, "Perimeter collision blocks car")
	car.global_position = Vector3(-21, 0.1, 3)
	car.velocity = Vector3(0, 0, 30)
	Input.action_press("reverse")
	await frames(120)
	Input.action_release("reverse")
	check(car.position.z < 12 and car.speed_kmh < 3, "Building collision blocks car")
	car.position.y = -20
	await frames(3)
	check(car.position.y > -1, "Out-of-world recovery")
	print("RESULT: %d failures" % failures)
	quit(failures)
