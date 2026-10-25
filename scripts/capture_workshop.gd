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
	for i in 30: await physics_frame
	game.set_night(true)
	game.set_paused(true)
	await shot("preview-pause.png")
	game.hud.open_options()
	game.hud.pause_tabs.current_tab = 0
	await shot("preview-controls.png")
	game.hud.pause_tabs.current_tab = 1
	await shot("preview-audio.png")
	game.set_garage(true)
	game.progress.coins = 2400
	game.hud.refresh_garage()
	game.hud.garage_tabs.current_tab = 1
	game.hud.mod_choices.engine.select(2)
	game.hud.refresh_part("engine")
	game.hud.mod_choices.exhaust.select(2)
	game.hud.refresh_part("exhaust")
	await shot("preview-workshop.png")
	game.set_garage(false)
	game.toggle_first_person()
	game.toggle_night()
	game.toggle_night()
	await shot("preview-clean-cockpit.png")
	DirAccess.remove_absolute(game.progress.save_path)
	quit()
