extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.set_meta("testing",true)
	root.add_child(load("res://scenes/main.tscn").instantiate())
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview.png")
	quit()
