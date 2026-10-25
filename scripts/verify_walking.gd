extends SceneTree
var failures: int=0
func _initialize() -> void:call_deferred("verify")
func check(ok: bool,text: String) -> void:
	print(("PASS " if ok else "FAIL ")+text)
	if not ok:failures+=1
func frames(n: int=6) -> void:
	for i in n:await physics_frame
func press(key: Key) -> void:
	var event:=InputEventKey.new();event.physical_keycode=key;event.pressed=true;Input.parse_input_event(event)
	await frames(2)
	event=InputEventKey.new();event.physical_keycode=key;event.pressed=false;Input.parse_input_event(event)
	await frames(2)
func verify() -> void:
	root.set_meta("testing",true)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	game.progress.save_path="user://walking_verification.cfg"
	await frames(60)
	var w=game.walker;var car=game.car
	check(car.is_on_floor() and not w.active,"Game starts seated with real ground collision")
	await press(KEY_E)
	check(w.active and w.camera.current and car.parked and car.visual.visible,"E exits into first-person walking and leaves a visible parked car")
	var parked: Vector3=car.global_position;var start: Vector3=w.global_position
	Input.action_press("accelerate");await frames(30);Input.action_release("accelerate");await frames(8)
	check(w.global_position.distance_to(start)>1 and car.global_position.distance_to(parked)<.1,"W walks while the parked car remains stationary")
	check(game.progress.coins==0,"Walking does not generate driving coins")
	w.position=Vector3(3.5,.06,-700);w.velocity=Vector3.ZERO;await frames(20)
	start=w.position;Input.action_press("accelerate");await frames(30);Input.action_release("accelerate")
	var walked: float=w.position.distance_to(start)
	w.position=Vector3(3.5,.06,-700);w.velocity=Vector3.ZERO;await frames(20)
	start=w.position;Input.action_press("sprint");Input.action_press("accelerate");await frames(30);Input.action_release("accelerate");Input.action_release("sprint")
	check(w.position.distance_to(start)>walked*1.4,"Shift runs faster than walking")
	await frames(10);var floor_y: float=w.position.y
	Input.action_press("handbrake");await frames(5);Input.action_release("handbrake")
	check(w.position.y>floor_y+.2,"Space jumps on foot")
	await press(KEY_E)
	check(w.active,"E cannot enter the car from across the map")
	w.position=Vector3(21,.3,110);w.velocity=Vector3.ZERO;w.rotation.y=0
	await frames(20);start=w.position;Input.action_press("accelerate");await frames(150);Input.action_release("accelerate")
	check(w.position.z>102.5 and w.position.z<start.z-1,"Walking respects solid building walls")
	game.set_paused(true);start=w.position
	Input.action_press("accelerate");await frames(15);Input.action_release("accelerate")
	check(w.position==start,"Pause freezes pedestrian movement")
	game.set_paused(false);await press(KEY_R)
	check(not w.active and not car.parked and car.global_position.distance_to(car.spawn.origin)<1,"R returns to the car and safely resets it")
	await frames(30);await press(KEY_E);game.set_garage(true)
	check(not w.active and game.garage_open,"Opening the garage safely returns the player to the car")
	game.set_garage(false);await frames(20)
	car.flight_active=true;w.toggle()
	check(not w.active,"Cannot exit the car while flying")
	car.flight_active=false;car.reset_car();await frames(30)
	await press(KEY_E);w.position=car.position+Vector3(2,0,0);await press(KEY_E)
	check(not w.active and game.chase.camera.current,"E re-enters the nearby car and restores the driving camera")
	await frames(20);game.chase.set_mode(2);w.toggle()
	check(w.active and not car.interior_view and not game.chase.cockpit.active,"Leaving cockpit view stops the cabin and shows the parked exterior")
	game.set_paused(true);game.hud.reset_and_resume();await frames(5)
	check(not w.active and not car.parked and not paused,"Pause-menu Reset returns a pedestrian to the repaired car")
	game.regions.set_region("ice");await frames(30);w.toggle();await frames(20)
	check(w.active and w.is_on_floor() and game.regions.ice_city.player==w,"Walking also works on the frozen district with local scenery tracking")
	game.regions.set_region("city");await frames(10)
	check(not w.active and not car.parked,"Changing districts restores seated mode without stranding the pedestrian")
	check(game.city.find_children("Business_*","Node3D",true,false).size()>20,"City has visible named business storefronts")
	check(game.city.shop_materials.any(func(mat):return mat.albedo_texture!=null),"Shop windows use illustrated interior displays")
	DirAccess.remove_absolute(game.progress.save_path)
	print("WALKING: %d failures" % failures);quit(1 if failures else 0)

