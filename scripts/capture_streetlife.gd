extends SceneTree
func _initialize() -> void: call_deferred("capture")
func shot(path: String) -> void:
	for i in 25: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://"+path)
func capture() -> void:
	root.set_meta("testing",true)
	root.set_meta("show_title",true)
	root.size = Vector2i(1280,720)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.progress.save_path = "user://v07_capture.cfg"
	await shot("preview-main-menu.png")
	game.new_game()
	game.set_night(false)
	game.progress.hints_used = {"night":true,"view":true,"garage":true}
	for i in 30: await physics_frame
	await shot("preview-streetlife-hud.png")
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.cull_mask = 1
	camera.fov = 55
	camera.global_position = game.car.global_position+Vector3(-4.2,2.4,5.0)
	camera.look_at(game.car.global_position+Vector3.UP*0.65)
	camera.current = true
	Input.action_press("accelerate")
	Input.action_press("handbrake")
	for i in 100: await physics_frame
	await shot("preview-burnout.png")
	Input.action_release("accelerate")
	Input.action_release("handbrake")
	game.chase.set_mode(0)
	game.set_paused(true)
	await shot("preview-pause.png")
	game.hud.open_options()
	game.hud.pause_tabs.current_tab = 2
	await shot("preview-gameplay.png")
	game.set_garage(true)
	game.progress.coins = 24000
	game.hud.garage_tabs.get_node("Cars").scroll_vertical = 1000
	await shot("preview-garage.png")
	game.set_garage(false)
	game.car.global_position = Vector3(3.5,0.06,5)
	camera.global_position = Vector3(-6,3,12)
	camera.look_at(Vector3(8,1.5,26))
	camera.current = true
	await shot("preview-city-details.png")
	game.chase.set_mode(2)
	game.set_night(true)
	await shot("preview-cockpit-v07.png")
	DirAccess.remove_absolute(game.progress.save_path)
	quit()
