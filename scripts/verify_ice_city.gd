extends SceneTree
var failures: int=0
func _initialize() -> void:call_deferred("verify")
func check(ok: bool,caption: String) -> void:
	print(("PASS " if ok else "FAIL ")+caption)
	if not ok:failures+=1
func frames(n: int=5) -> void:
	for i in n:await physics_frame
func hit(pos: Vector3) -> bool:
	var world=root.get_node("OpenStreets").car.get_world_3d()
	var result=world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3.UP*60,pos+Vector3.UP*2))
	return not result.is_empty()
func verify() -> void:
	root.set_meta("testing",true)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await frames(12)
	game.progress.save_path="user://ice_verification.cfg"
	var r=game.regions
	check(not r.in_ice and not is_instance_valid(r.ice_city),"Ice city loads only when first visited")
	check(hit(Vector3(12.5,0,95)),"Original city building occupies the collision test location")
	game.car.set_physics_process(false)
	game.car.global_position=r.ROOF_GATE
	r.sync_position();r._physics_process(.016)
	check(not r.in_ice,"Ground car cannot activate the rooftop gate")
	game.car.equip(4);game.car.global_position=r.ROOF_GATE;r.sync_position();r._physics_process(.016)
	check(not r.in_ice,"Roadster must enable flight to enter")
	game.car.flight_active=true
	r.last_position=r.ROOF_GATE+Vector3(0,0,20)
	game.car.global_position=r.ROOF_GATE-Vector3(0,0,20)
	r._physics_process(.016)
	await frames(8)
	check(r.in_ice and game.car.global_position.distance_to(r.ICE_SPAWN)<.1,"Fast flight through the blue gate enters Ice City")
	check(r.ice_city.visible and not game.city.visible,"Ice scenery replaces the original city")
	check(not hit(Vector3(12.5,0,95)),"Hidden original city colliders are removed from the ice sidewalk")
	check(hit(Vector3(23,0,95)),"Ice district buildings retain real collision")
	check(game.car.surface_grip<1 and r.ice_city.snow.emitting,"Frozen district has lower grip and falling snow")
	game.car.set_physics_process(true);await frames(90)
	check(game.car.is_on_floor() and game.car.global_position.y>=-.05,"Car settles on the frozen road instead of falling through")
	check(game.progress.coins==0,"Portal travel does not award free distance coins")
	game.car.reset_car()
	check(game.car.global_position==r.ICE_SPAWN and r.in_ice,"Reset keeps the car in Ice City")
	game.set_night(true)
	check(game.env.sky.sky_material==r.ice_sky and r.ice_city.night,"Night mode uses the winter sky and icy window lighting")
	game.save_now();var saved=game.progress.snapshot.duplicate()
	r.set_region("city");await frames(5)
	check(hit(Vector3(12.5,0,95)) and game.car.surface_grip==1,"Returning restores original city colliders and normal grip")
	game.progress.snapshot=saved;game.restore_snapshot();await frames(5)
	check(r.in_ice and game.night,"Loading a saved ice visit restores the district and time of day")
	game.car.set_physics_process(false);r.cooldown=0
	game.car.equip(0);game.car.global_position=r.RETURN_GATE;r.sync_position()
	game.set_paused(true);await frames(10)
	check(r.in_ice,"Paused game cannot trigger a portal")
	game.set_paused(false);await frames(6)
	check(not r.in_ice,"Return gate also works for an ordinary non-flying car")
	game.progress.snapshot={"position":Vector3(3.5,1,35)};game.restore_snapshot()
	check(not r.in_ice and game.car.spawn.origin==r.default_spawn.origin,"Older saves without a region still load the original city")
	r.set_region("unknown",false)
	check(not r.in_ice,"Unknown saved region safely falls back to the city")
	DirAccess.remove_absolute(game.progress.save_path)
	print("ICE CITY: %d failures" % failures)
	quit(1 if failures else 0)


