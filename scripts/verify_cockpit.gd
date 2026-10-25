extends SceneTree
var failures: int = 0
func _initialize() -> void:
	call_deferred("verify")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
func frames(count: int = 10) -> void:
	for i in count: await process_frame
	await RenderingServer.frame_post_draw
func signature(image: Image) -> PackedColorArray:
	var result := PackedColorArray()
	for x in 16:
		for y in 8:
			result.append(image.get_pixel(x*image.get_width()/16,y*image.get_height()/8))
	return result
func verify() -> void:
	root.set_meta("testing",true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	var cabin = game.chase.cockpit
	check(cabin.hand_nodes.size() == 2 and cabin.forearms.size() == 2,"Two hands and connected forearms exist")
	check(cabin.mirror_views.size() == 2,"Rear and driver-side live mirrors exist")
	check(cabin.mirror_views[0].render_target_update_mode == SubViewport.UPDATE_DISABLED,"Mirrors stop rendering outside cockpit")
	game.set_garage(true)
	game.chase.set_mode(2)
	await frames()
	check(cabin.active and cabin.visible and not game.car.visual.visible,"First person activates interior and hides exterior")
	check(cabin.mirror_cameras[0].global_position.distance_to(game.car.to_global(cabin.mirror_offsets[0])) < 0.01,"Mirrors initialize correctly even while paused")
	game.set_garage(false)
	await frames()
	check(game.chase.camera.cull_mask == 1 and game.chase.driver_camera.cull_mask == 3,"Interior layer is exclusive to driver camera")
	check(cabin.mirror_cameras[0].cull_mask == 1 and cabin.mirror_views[0].world_3d == game.car.get_world_3d(),"Mirrors share world and exclude interior recursion")
	var before := signature(cabin.mirror_views[0].get_texture().get_image())
	game.car.position += Vector3(0,0,-20)
	game.car.rotation.y += 0.35
	await frames(20)
	var after := signature(cabin.mirror_views[0].get_texture().get_image())
	var changed: int = 0
	for i in before.size():
		if before[i].is_equal_approx(after[i]) == false: changed += 1
	check(changed > 20,"Rendered rear mirror changes with vehicle position and heading")
	game.car.speed_kmh = 80
	cabin.gauge_display._process(1)
	check(cabin.gauge_display.indicated_speed > 70,"Gauge responds to speed")
	game.car.steering = 0.8
	cabin.update_pose(0.5)
	var wrist_before: Vector3 = cabin.hand_nodes[0].global_position
	game.car.steering = -0.8
	cabin.update_pose(0.5)
	check(cabin.wheel_pivot.rotation.z < -0.5 and cabin.hand_nodes[0].global_position.distance_to(wrist_before) > 0.15,"Hands rotate with steering wheel")
	var wrist: Vector3 = cabin.to_local(cabin.hand_nodes[0].global_position)-Vector3(0,0.035,-0.01)
	var arm = cabin.forearms[0]
	var arm_end: Vector3 = arm.position+arm.basis.y*(arm.mesh.height/2)
	check(arm_end.distance_to(wrist) < 0.01,"Forearm stays connected to moving wrist")
	game.set_night(true)
	cabin.update_pose(0.1)
	check(cabin.cabin_light.light_energy > 0.7 and cabin.cabin_light.light_cull_mask == 2,"Night interior fill lights only cabin")
	game.car.equip(1)
	cabin.update_pose(0.1)
	check(cabin.hood.material_override.albedo_color.is_equal_approx(game.car.paint),"Interior hood tracks selected car paint")
	game.chase.set_mode(0)
	check(not cabin.visible and cabin.gauge_view.render_target_update_mode == SubViewport.UPDATE_DISABLED and game.car.visual.visible,"Leaving cockpit restores exterior and stops display rendering")
	DirAccess.remove_absolute(game.progress.save_path)
	print("RESULT: %d failures" % failures)
	quit(failures)
