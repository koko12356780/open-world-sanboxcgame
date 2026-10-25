extends SceneTree
func _initialize() -> void: call_deferred("capture")
func shot(path: String) -> void:
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://"+path)
	print("CAPTURE %s / %s FPS / %s draw calls" % [path,Performance.get_monitor(Performance.TIME_FPS),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
func capture() -> void:
	root.set_meta("testing",true)
	root.size=Vector2i(1280,720)
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.progress.save_path="user://citylight-capture.cfg"
	game.progress.hints_used={"night":true,"view":true,"garage":true}
	game.car.global_position=Vector3(3.5,.06,35)
	game.chase.snap()
	game.set_night(false)
	await shot("preview-citylight-day.png")
	game.set_night(true)
	await shot("preview-citylight-night.png")
	game.chase.set_mode(2)
	await shot("preview-citylight-cockpit.png")
	game.chase.set_mode(0)
	var camera:=Camera3D.new()
	game.add_child(camera)
	camera.cull_mask=1
	camera.fov=52
	camera.position=Vector3(-1.5,2.1,41)
	camera.look_at(game.car.global_position+Vector3(0,.9,0))
	camera.current=true
	game.set_night(false)
	await shot("preview-citylight-car.png")
	game.car.global_position=Vector3(75.5,.06,145)
	game.chase.snap()
	game.chase.set_mode(0)
	await shot("preview-citylight-boulevard.png")
	game.set_night(true)
	await shot("preview-citylight-boulevard-night.png")
	DirAccess.remove_absolute(game.progress.save_path)
	quit()
