extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func shot(path: String) -> void:
	for i in 25: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://"+path)
func capture() -> void:
	root.set_meta("testing",true)
	root.set_meta("show_title",true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await shot("preview-main-menu.png")
	game.hud.open_options()
	game.hud.pause_tabs.current_tab = 2
	await shot("preview-crash-options.png")
	game.new_game()
	for i in 30: await physics_frame
	game.set_paused(true)
	await shot("preview-pause.png")
	game.set_garage(true)
	game.progress.coins = 20000
	game.hud.refresh_garage()
	for i in 5: await process_frame
	game.hud.garage_tabs.get_node("Cars").scroll_vertical = 1000
	await shot("preview-garage.png")
	game.choose_car(3)
	game.set_garage(false)
	game.progress.hints_used = {"night":true,"view":true,"garage":true}
	for i in 30: await physics_frame
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.cull_mask = 1
	camera.fov = 55
	camera.global_position = game.car.global_position+Vector3(-5,2.5,-5)
	camera.look_at(game.car.global_position+Vector3.UP*0.7)
	camera.current = true
	await shot("preview-hypercar.png")
	game.set_garage(true)
	game.choose_car(4)
	game.set_garage(false)
	for i in 30: await physics_frame
	game.car.global_position = Vector3(3.5,20,800)
	game.car.toggle_flight()
	game.car.velocity = Vector3.ZERO
	camera.global_position = game.car.global_position+Vector3(-5,2.2,-5)
	camera.look_at(game.car.global_position+Vector3.UP*0.7)
	camera.current = true
	await shot("preview-flying-roadster.png")
	game.car.flight_active = false
	game.set_garage(true)
	game.choose_car(0)
	game.set_garage(false)
	game.car.global_position = Vector3(3.5,0.06,1684)
	game.car.rotation.y = PI
	game.car.velocity = Vector3(0,0,70)
	game.chase.set_mode(0)
	for i in 20: await physics_frame
	camera.global_position = game.car.global_position+Vector3(-5,4.5,-6)
	camera.look_at(game.car.global_position+Vector3.UP*0.7)
	camera.current = true
	await shot("preview-crash.png")
	DirAccess.remove_absolute(game.progress.save_path)
	quit()
