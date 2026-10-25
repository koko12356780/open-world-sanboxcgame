extends SceneTree
func _initialize() -> void:call_deferred("capture")
func shot(filename: String) -> void:
	for i in 35:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://"+filename)
func capture() -> void:
	root.set_meta("testing",true);root.size=Vector2i(1280,720)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.progress.save_path="user://ice_capture.cfg"
	game.progress.selected=4;game.progress.owned.append(4)
	game.progress.hints_used={"night":true,"view":true,"garage":true}
	game.car.equip(4);game.car.set_physics_process(false)
	game.regions.set_physics_process(false)
	var camera:=Camera3D.new();game.add_child(camera);camera.fov=68;camera.cull_mask=1;camera.current=true
	game.set_night(true)
	game.car.global_position=game.regions.ROOF_GATE+Vector3(0,-2,14);game.car.flight_active=true
	camera.position=game.car.position+Vector3(-13,7,22);camera.look_at(game.regions.ROOF_GATE)
	await shot("preview-blue-tower.png")
	game.regions.set_region("ice");game.regions.transition_time=0;game.car.set_physics_process(false)
	game.car.position=Vector3(3.5,.06,240)
	game.set_night(false)
	camera.position=Vector3(10,5.5,250);camera.look_at(Vector3(0,6,160))
	await shot("preview-ice-city.png")
	game.set_night(true)
	camera.position=Vector3(11,7,253);camera.look_at(Vector3(0,11,150))
	await shot("preview-ice-night.png")
	DirAccess.remove_absolute(game.progress.save_path);quit()
