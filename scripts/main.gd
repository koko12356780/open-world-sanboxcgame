extends Node3D
const Car = preload("res://scripts/car.gd")
const City = preload("res://scripts/city.gd")
const Chase = preload("res://scripts/chase_camera.gd")
const Hud = preload("res://scripts/hud.gd")
const Geo = preload("res://scripts/geometry.gd")
var car: CharacterBody3D
var hud: Control
var beacon: Node3D
var route: Array[Vector3] = [Vector3(3.5,0,-72),Vector3(144,0,-284),Vector3(284,0,-144),Vector3(284,0,216),Vector3(-144,0,284),Vector3(-284,0,-216)]
var route_index: int = 0
var progress = preload("res://scripts/progression.gd").new()
var city: Node3D
var env: Environment
var atmosphere: ShaderMaterial
var sun: DirectionalLight3D
var chase: Node3D
var night: bool = false
var garage_open: bool = false
var save_timer: float = 0.0
var previous_distance: float = 0.0
var title_open: bool = false
var options_open: bool = false
var session_started: bool = false
var title_camera: Camera3D
var title_time: float = 0.0
var mouse_captured: bool = false
var window_focused: bool = true
var presence_timer: float = 0
var regions: Node3D
var walker: CharacterBody3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in {"interact":KEY_E,"sprint":KEY_SHIFT}:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key:=InputEventKey.new();key.physical_keycode={"interact":KEY_E,"sprint":KEY_SHIFT}[action];InputMap.action_add_event(action,key)
	if get_tree().root.has_meta("testing"):
		progress.save_path = "user://test_garage.cfg"
	else:
		progress.load_game()
	progress.apply_audio()
	get_tree().auto_accept_quit = false
	var world := Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	var environment := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	atmosphere = ShaderMaterial.new()
	atmosphere.shader = preload("res://shaders/city_sky.gdshader")
	sky.sky_material = atmosphere
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a3b2c6")
	env.ambient_light_sky_contribution = 0.65
	env.ambient_light_energy = 0.30
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	# Forward+ visual pass. Compatibility fallback skips unsupported effects.
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.ssao_enabled = true
		env.ssao_radius = 1.1
		env.ssao_intensity = 1.35
		env.ssr_enabled = true
		env.ssr_max_steps = 48
		env.glow_enabled = true
		env.glow_intensity = .55
		env.glow_bloom = .08
	env.fog_enabled = true
	env.fog_light_color = Color("b8b9b0")
	env.fog_density = 0.0018
	env.fog_sky_affect = 0.25
	environment.environment = env
	world.add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-17, -29, 0)
	sun.light_color = Color("ffe4bb")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	world.add_child(sun)
	city = City.new()
	world.add_child(city)
	car = Car.new()
	car.name = "PlayerCar"
	world.add_child(car)
	city.player = car
	car.equip(progress.selected)
	car.apply_mods(progress.build_for())
	car.crash_physics_enabled = progress.crash_enabled
	chase = Chase.new()
	chase.target = car
	world.add_child(chase)
	car.reset_performed.connect(chase.snap)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Hud.new()
	hud.car = car
	hud.game = self
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(hud)
	beacon = Node3D.new()
	world.add_child(beacon)
	for x in [-4.5, 4.5]:
		Geo.box(beacon, Vector3(x, 2.5, 0), Vector3(0.25, 5, 0.25), Color("8ff0cb"))
	Geo.box(beacon, Vector3(0, 5, 0), Vector3(9.25, 0.25, 0.25), Color("8ff0cb"))
	update_checkpoint()
	regions=preload("res://scripts/regions.gd").new()
	regions.game=self
	world.add_child(regions)
	walker=preload("res://scripts/walker.gd").new();walker.game=self;world.add_child(walker)
	title_camera = Camera3D.new()
	title_camera.cull_mask = 1
	title_camera.fov = 52
	add_child(title_camera)
	if not get_tree().root.has_meta("testing") or get_tree().root.get_meta("show_title",false):
		set_night(true)
		show_title()
	else:
		session_started = true

func toggle_night() -> void:
	set_night(not night)
	progress.mark_hint("night")

func toggle_garage() -> void:
	set_garage(not garage_open)

func toggle_first_person() -> void:
	chase.set_mode(0 if chase.mode == 2 else 2)
	progress.mark_hint("view")

func set_paused(enabled: bool) -> void:
	options_open = false
	garage_open = false
	hud.paused = enabled
	get_tree().paused = enabled
	if enabled: save_now()
	hud.refresh_menus()
	sync_mouse()

func install_mod(category: String, index: int) -> void:
	if not garage_open: return
	hud.garage_message = progress.choose_mod(category,index)
	car.apply_mods(progress.build_for())
	hud.refresh_garage()

func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.is_action_pressed("mouse_lock") and not title_open:
		set_mouse_lock(not progress.mouse_lock)
		get_viewport().set_input_as_handled()
		return
	if title_open:
		if event.is_action_pressed("pause"):
			options_open = false
			hud.credits_panel.visible = false
			hud.refresh_menus()
			sync_mouse()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and not get_tree().paused:
		walker.toggle()
	elif event.is_action_pressed("night"): toggle_night()
	elif event.is_action_pressed("garage"): toggle_garage()
	elif event.is_action_pressed("first_person") and not walker.active: toggle_first_person()
	elif event.is_action_pressed("camera") and not walker.active:
		chase.set_mode((chase.mode+1)%3)
		progress.mark_hint("view")
	elif event.is_action_pressed("flight") and not walker.active:
		car.toggle_flight()
	elif event.is_action_pressed("pause"):
		if options_open:
			options_open = false
			hud.refresh_menus()
			sync_mouse()
		elif garage_open: set_garage(false)
		else: set_paused(not hud.paused)
	elif garage_open:
		for i in progress.CARS.size():
			if event.is_action_pressed("car_%d" % (i+1)):
				choose_car(i)
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("quit"): quit_game()
		else: return
	elif get_tree().paused and event.is_action_pressed("quit"): quit_game()
	else: return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	sync_mouse()
	presence_timer += delta
	if presence_timer >= 2:
		presence_timer = 0
		if not get_tree().root.has_meta("testing"):
			var file := FileAccess.open("user://presence.json",FileAccess.WRITE)
			if file: file.store_string(JSON.stringify(preload("res://scripts/presence_state.gd").describe(self)))
	if title_open:
		title_time += delta*0.12
		title_camera.global_position = car.global_position+Vector3(sin(title_time+0.8)*7,2.4,cos(title_time+0.8)*7)
		title_camera.look_at(car.global_position+Vector3.UP*0.7)
	if get_tree().paused:
		return
	var driven: float = maxf(0, car.distance - previous_distance)
	previous_distance = car.distance
	if car.is_on_floor() or car.flight_active: progress.add_distance(driven)
	save_timer += delta
	if save_timer >= 5:
		save_timer = 0
		save_now()
	if not walker.active and not regions.in_ice and car.position.distance_to(route[route_index]) < 6:
		hud.collected += 1
		route_index = (route_index + 1) % route.size()
		update_checkpoint()

func set_garage(enabled: bool) -> void:
	if enabled and walker!=null:walker.enter()
	if title_open: start_session()
	options_open = false
	garage_open = enabled
	hud.paused = false
	get_tree().paused = enabled
	if enabled:
		progress.mark_hint("garage")
		car.velocity = Vector3.ZERO
		progress.save_game()
	hud.refresh_garage()
	hud.refresh_menus()
	sync_mouse()

func choose_car(index: int) -> void:
	if not garage_open: return
	hud.garage_message = progress.choose(index)
	if progress.selected == index:
		car.equip(index)
		car.apply_mods(progress.build_for())
		chase.snap()
	hud.refresh_garage()

func set_night(enabled: bool) -> void:
	night = enabled
	atmosphere.set_shader_parameter("night_amount",1.0 if night else 0.0)
	sun.light_color = Color("8ba8df") if night else Color("ffe4bb")
	sun.light_energy = 0.09 if night else 1.15
	env.ambient_light_color = Color("7189ad") if night else Color("a3b2c6")
	env.ambient_light_energy = 0.22 if night else 0.30
	env.fog_light_color = Color("111d30") if night else Color("baa18b")
	env.fog_density = 0.0021 if night else 0.0018
	city.set_night(night)
	car.set_night(night)
	if regions!=null:regions.apply_environment()

func save_now() -> void:
	if session_started:
		progress.snapshot = {"position":car.global_position,"yaw":car.rotation.y,"night":night,"camera":chase.mode,"flight":car.flight_active,"region":"ice" if regions.in_ice else "city"}
	progress.save_game()

func show_title() -> void:
	if session_started: save_now()
	else: car.position.y = 0.06
	title_open = true
	options_open = false
	garage_open = false
	hud.paused = false
	get_tree().paused = true
	chase.cockpit.set_active(false)
	car.visual.visible = true
	title_camera.current = true
	hud.refresh_menus()
	sync_mouse()

func start_session(load_saved: bool = true) -> void:
	title_open = false
	options_open = false
	garage_open = false
	hud.paused = false
	get_tree().paused = false
	if load_saved and not session_started: restore_snapshot()
	session_started = true
	chase.set_mode(chase.mode)
	chase.snap()
	if walker.active:walker.camera.current=true
	hud.refresh_menus()
	sync_mouse()

func restore_snapshot() -> void:
	walker.enter()
	var data: Dictionary = progress.snapshot
	regions.set_region(str(data.get("region","city")),false)
	var position = data.get("position",car.spawn.origin)
	const Layout = preload("res://scripts/world_layout.gd")
	if position is Vector3 and position.is_finite() and absf(position.x) < Layout.WORLD_X and absf(position.z) < Layout.WORLD_Z and position.y >= 0 and position.y <= 165:
		car.global_position = position
	var yaw := float(data.get("yaw",0))
	car.rotation.y = yaw if is_finite(yaw) else 0
	car.velocity = Vector3.ZERO
	car.flight_active = bool(data.get("flight",false)) and car.model_index == 4
	car.floor_snap_length = 0 if car.flight_active else 0.4
	set_night(bool(data.get("night",false)))
	chase.set_mode(clampi(int(data.get("camera",0)),0,2))
	previous_distance = car.distance
	regions.sync_position()

func load_saved_game() -> void:
	progress.load_game()
	car.equip(progress.selected)
	car.apply_mods(progress.build_for())
	car.crash_physics_enabled = progress.crash_enabled
	restore_snapshot()
	start_session(false)
	hud.refresh_garage()

func new_game() -> void:
	walker.enter()
	var old_path: String = progress.save_path
	var volume: float = progress.volume
	var muted: bool = progress.muted
	var lock_mouse: bool = progress.mouse_lock
	var crashes: bool = progress.crash_enabled
	progress = preload("res://scripts/progression.gd").new()
	progress.save_path = old_path
	progress.volume = volume
	progress.muted = muted
	progress.mouse_lock = lock_mouse
	progress.crash_enabled = crashes
	regions.set_region("city",false)
	car.equip(0)
	car.crash_physics_enabled = crashes
	set_night(false)
	chase.set_mode(0)
	start_session(false)
	save_now()
	hud.refresh_garage()

func set_crashes(enabled: bool) -> void:
	progress.crash_enabled = enabled
	car.crash_physics_enabled = enabled
	if not enabled: car.crash_effects.repair()
	progress.save_game()

func quit_game() -> void:
	save_now()
	get_tree().quit()

func set_mouse_lock(enabled: bool) -> void:
	progress.mouse_lock = enabled
	progress.save_game()
	sync_mouse()

func sync_mouse() -> void:
	if chase == null: return
	mouse_captured = progress.mouse_lock and window_focused and not get_tree().paused and not title_open and not garage_open and not options_open
	chase.mouse_look_enabled = mouse_captured and (walker==null or not walker.active)
	if walker!=null:walker.mouse_look_enabled=mouse_captured
	if not get_tree().root.has_meta("testing"):
		var desired := Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE
		if Input.mouse_mode != desired: Input.mouse_mode = desired

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not get_tree().root.has_meta("testing"):
		DirAccess.remove_absolute("user://presence.json")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		window_focused = false
		sync_mouse()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		window_focused = true
		sync_mouse()
	if what == NOTIFICATION_WM_CLOSE_REQUEST: quit_game()

func update_checkpoint() -> void:
	beacon.position = route[route_index]
	hud.checkpoint = route[route_index]
