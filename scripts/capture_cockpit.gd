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
	game.chase.set_mode(2)
	await shot("preview-cockpit-day.png")
	game.set_night(true)
	await shot("preview-cockpit.png")
	Input.action_press("left")
	for i in 40: await physics_frame
	await shot("preview-cockpit-steering.png")
	Input.action_release("left")
	DirAccess.remove_absolute(game.progress.save_path)
	quit()
