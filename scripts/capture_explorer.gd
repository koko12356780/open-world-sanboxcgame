extends SceneTree
func _initialize() -> void:call_deferred("capture")
func shot(file: String) -> void:
	for i in 35:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://"+file)
func capture() -> void:
	root.set_meta("testing",true);root.size=Vector2i(1280,720)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.progress.save_path="user://explorer_capture.cfg";game.progress.hints_used={"night":true,"view":true,"garage":true}
	for i in 45:await physics_frame
	game.walker.toggle();game.walker.position=Vector3(4,.12,96);game.walker.rotation.y=-PI/2
	game.set_night(false)
	await shot("preview-walking-day.png")
	game.set_night(true)
	await shot("preview-walking-night.png")
	game.walker.enter();game.car.position=Vector3(3.5,.06,104);game.car.set_physics_process(false)
	var camera:=Camera3D.new();game.add_child(camera);camera.fov=66;camera.cull_mask=1
	camera.position=Vector3(-5,3.5,115);camera.look_at(Vector3(5,2,90));camera.current=true
	await shot("preview-street-shops.png")
	DirAccess.remove_absolute(game.progress.save_path);quit()
