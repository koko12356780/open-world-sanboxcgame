extends SceneTree
func _initialize() -> void: call_deferred("capture")
func shot(name: String) -> void:
	for i in 45: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://"+name)
func capture() -> void:
	root.set_meta("testing",true)
	root.size = Vector2i(1280,720)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.progress.save_path = "user://thruster_capture.cfg"
	game.progress.coins = 50000
	for model in [1,2,3,4]: game.progress.owned.append(model)
	game.progress.hints_used = {"night":true,"view":true,"garage":true}
	game.set_garage(true)
	game.choose_car(4)
	game.set_garage(false)
	game.set_night(true)
	game.car.global_position = Vector3(3.5,.06,36)
	game.car.set_physics_process(false)
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.fov = 52
	camera.cull_mask = 1
	camera.global_position = game.car.global_position+Vector3(-4.5,2.2,6.1)
	camera.look_at(game.car.global_position+Vector3(0,.65,.8))
	camera.current = true
	Input.action_press("accelerate")
	game.car.throttle_amount = 1
	await shot("preview-roadster-thrusters.png")
	Input.action_release("accelerate")
	game.set_garage(true)
	game.choose_car(3)
	game.install_mod("induction",3)
	game.set_garage(false)
	game.car.global_position = Vector3(3.5,.06,36)
	game.car.set_physics_process(false)
	Input.action_press("accelerate")
	game.car.throttle_amount = 1
	await shot("preview-aurora-gas-thrusters.png")
	Input.action_release("accelerate")
	game.set_garage(true)
	game.hud.garage_tabs.current_tab = 1
	await shot("preview-thruster-workshop.png")
	DirAccess.remove_absolute(game.progress.save_path)
	quit()
