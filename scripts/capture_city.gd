extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func shot(path: String) -> void:
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://"+path)
func capture() -> void:
	root.set_meta("testing",true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await shot("preview.png")
	# Use the normal near/far culling for street views; lift it for the overview.
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.position = Vector3(470,670,505)
	camera.look_at(Vector3.ZERO)
	camera.fov = 60
	camera.current = true
	game.hud.get_parent().visible = false
	game.env.fog_enabled = false
	for mesh in game.city.get_children():
		if mesh is GeometryInstance3D: mesh.visibility_range_end = 0
	await shot("preview-city.png")
	DirAccess.remove_absolute(game.progress.save_path)
	quit()
