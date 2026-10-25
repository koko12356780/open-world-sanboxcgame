extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func shot(path: String) -> void:
	for i in 25: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://"+path)
func capture() -> void:
	root.set_meta("testing",true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_night(true)
	await shot("preview-night.png")
	game.chase.set_mode(2)
	await shot("preview-cockpit.png")
	game.chase.set_mode(0)
	game.set_garage(true)
	await shot("preview-garage.png")
	quit()
