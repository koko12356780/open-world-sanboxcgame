extends CharacterBody3D
## Arcade bicycle steering with independent longitudinal/lateral grip.
## Forward is -Z. Distances are metres, velocity is metres per second.
const Geo = preload("res://scripts/geometry.gd")
signal reset_performed
signal crashed(intensity: float)
@export var acceleration: float = 14.0
@export var brake_force: float = 26.0
@export var max_speed: float = 38.0
@export var reverse_speed: float = 11.0
@export var grip: float = 9.0
@export var handbrake_grip: float = 2.0
@export var paint: Color = Color("ff603d")
var burnout_active: bool = false
var tire_effects: Node3D
var tail_lamps: Array[MeshInstance3D] = []
var spawn := Transform3D(Basis.IDENTITY, Vector3(3.5, 1.0, 35))
var steering: float = 0.0
var speed_kmh: float = 0.0
var distance: float = 0.0
var visual: Node3D
var front_wheels: Array[Node3D] = []
var wheels: Array[Node3D] = []
var model_index: int = 0
var headlights: Array[SpotLight3D] = []
var night: bool = false
var rpm: float = 850.0
var gear: int = 1
var throttle_amount: float = 0.0
var interior_view: bool = false
var tune: Dictionary
var engine_sound: Node
var crash_effects: Node3D
var crash_physics_enabled: bool = true
var damage: float = 0.0
var camera_shake: float = 0.0
var crash_stun: float = 0.0
var crash_cooldown: float = 0.0
var flight_active: bool = false
var flight_height_limit: float = 160.0
var thruster_effects: Node3D
var surface_grip: float = 1.0
var parked: bool = false

func _ready() -> void:
	floor_snap_length = 0.4
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.6, 3.8)
	collider.shape = shape
	collider.position.y = 0.8
	add_child(collider)
	visual = Node3D.new()
	add_child(visual)
	preload("res://scripts/car_visual.gd").build(self, visual)
	for side in [-1, 1]:
		var light := SpotLight3D.new()
		light.position = Vector3(side * 0.65, 0.85, -2.18)
		light.rotation.x = deg_to_rad(-7)
		light.light_color = Color("e1ebff")
		light.light_energy = 3.0
		light.spot_range = 42
		light.spot_angle = 29
		light.spot_attenuation = 0.7
		light.shadow_enabled = true
		add_child(light)
		headlights.append(light)
	set_night(false)
	engine_sound = preload("res://scripts/engine_audio.gd").new()
	engine_sound.car = self
	add_child(engine_sound)
	apply_mods(preload("res://scripts/mods.gd").stock_build())
	crash_effects = preload("res://scripts/crash_effects.gd").new()
	crash_effects.car = self
	add_child(crash_effects)
	tire_effects = preload("res://scripts/tire_effects.gd").new()
	tire_effects.car = self
	add_child(tire_effects)
	thruster_effects = preload("res://scripts/thruster_effects.gd").new()
	thruster_effects.car = self
	add_child(thruster_effects)
	reset_car()

func apply_mods(build: Dictionary) -> void:
	var base: Dictionary = preload("res://scripts/progression.gd").CARS[model_index]
	tune = preload("res://scripts/mods.gd").tune(base,build,model_index)
	acceleration = tune.acceleration
	max_speed = tune.speed
	grip = tune.grip
	for tip in visual.get_children():
		if tip.name.begins_with("ExhaustTip"):
			var radius := 0.11 if tune.exhaust.id in ["straight_pipe","race"] else 0.085
			tip.mesh.top_radius = radius
			tip.mesh.bottom_radius = radius
	if engine_sound != null: engine_sound.configure(tune)
	if thruster_effects != null: thruster_effects.configure()

func set_night(enabled: bool) -> void:
	night = enabled
	for light in headlights: light.visible = enabled

func equip(index: int) -> void:
	var spec: Dictionary = preload("res://scripts/progression.gd").CARS[index]
	model_index = index
	paint = spec.paint
	acceleration = spec.acceleration
	max_speed = spec.speed
	grip = spec.grip
	apply_mods(preload("res://scripts/mods.gd").stock_build())
	tail_lamps.clear()
	front_wheels.clear()
	wheels.clear()
	for child in visual.get_children():
		visual.remove_child(child)
		child.queue_free()
	preload("res://scripts/car_visual.gd").build(self, visual)
	if thruster_effects != null: thruster_effects.configure()
	reset_car()

func reset_car() -> void:
	burnout_active = false
	if tire_effects != null: tire_effects.reset_effects()
	if thruster_effects != null: thruster_effects.reset_effects()
	crash_cooldown = 0
	flight_active = false
	floor_snap_length = 0.4
	if visual != null: visual.rotation = Vector3.ZERO
	if crash_effects != null: crash_effects.repair()
	global_transform = spawn
	velocity = Vector3.ZERO
	steering = 0.0
	speed_kmh = 0
	rpm = 850
	gear = 1
	throttle_amount = 0
	reset_performed.emit()

func _physics_process(delta: float) -> void:
	if parked:
		velocity.x=0;velocity.z=0
		if not is_on_floor():velocity.y-=22*delta
		move_and_slide();speed_kmh=0;throttle_amount=0;rpm=850;return
	const Layout = preload("res://scripts/world_layout.gd")
	if Input.is_action_just_pressed("reset") or position.y < -12 or absf(position.x) > Layout.WORLD_X+60 or absf(position.z) > Layout.WORLD_Z+60:
		reset_car()
	crash_cooldown = maxf(0,crash_cooldown-delta)
	crash_stun = maxf(0,crash_stun-delta)
	camera_shake = move_toward(camera_shake,0,delta*1.7)
	var throttle := Input.get_axis("reverse", "accelerate")
	if crash_stun > 0: throttle = 0
	if flight_active:
		burnout_active = false
		flight_step(delta,throttle)
		return
	throttle_amount = absf(throttle)
	var steer_input := Input.get_axis("right", "left")
	var forward := -global_basis.z
	var speed := velocity.dot(forward)
	var previous_speed := speed
	var lateral := velocity.dot(global_basis.x)
	burnout_active = is_on_floor() and throttle > 0.5 and Input.is_action_pressed("handbrake") and absf(speed) < 8 and crash_stun <= 0
	steering = move_toward(steering, steer_input, delta * 3.8)
	if is_on_floor():
		if burnout_active:
			speed = move_toward(speed,0,35*delta)
		elif throttle != 0:
			var force := acceleration*(1-damage*0.004) if speed * throttle >= 0 else brake_force
			speed += throttle * force * delta
		else:
			speed = move_toward(speed, 0.0, (1.4 + speed * speed * 0.004) * delta)
		var sliding := Input.is_action_pressed("handbrake")
		if sliding: speed = move_toward(speed, 0.0, 9.0 * delta)
		speed = clampf(speed,-reverse_speed,max_speed*(1-damage*0.003))
		# Reduce steering lock at speed; reverse naturally reverses yaw.
		var lock := lerpf(0.5, 0.15, clampf(absf(speed) / max_speed, 0.0, 1.0))
		if model_index >= 3: lock = lerpf(0.45,0.014,clampf(absf(speed)/65,0,1))
		rotate_y(steering * speed / 2.8 * tan(lock) * delta)
		lateral = move_toward(lateral, 0.0, absf(lateral) * (handbrake_grip if sliding else grip) * surface_grip * delta + 0.03)
		var horizontal := -global_basis.z * previous_speed + global_basis.x * lateral
		# Blend keeps some momentum through corners; handbrake loosens the rear.
		var traction: float = (2.5 if sliding else grip)*surface_grip
		velocity.x = lerpf(velocity.x, horizontal.x, 1.0 - exp(-traction * delta))
		velocity.z = lerpf(velocity.z, horizontal.z, 1.0 - exp(-traction * delta))
		velocity += -global_basis.z * (speed - previous_speed)
	velocity.y -= 24.0 * delta
	var incoming := velocity
	move_and_slide()
	process_impact(incoming)
	speed_kmh = Vector2(velocity.x, velocity.z).length() * 3.6
	var span := max_speed*3.6/6.0
	gear = clampi(int(speed_kmh/span)+1,1,6)
	var target_rpm: float = 1600+fmod(speed_kmh,span)/span*(float(tune.engine.rpm)-1800)
	if speed_kmh < 8: target_rpm = 850+speed_kmh*110
	if burnout_active: target_rpm = float(tune.engine.rpm)*0.78+sin(Time.get_ticks_msec()*0.016)*180
	rpm = lerpf(rpm,target_rpm,1-exp(-8*delta))
	distance += Vector2(velocity.x, velocity.z).length() * delta
	visual.rotation.x = lerpf(visual.rotation.x,0.0,delta*5)
	visual.rotation.z = lerpf(visual.rotation.z, -steering * speed / max_speed * 0.045, delta * 5)
	for pivot in front_wheels: pivot.rotation.y = steering * 0.4
	for i in wheels.size():
		wheels[i].rotate_object_local(Vector3.RIGHT,(22.0 if burnout_active and i%2==1 else speed/0.43)*delta)
	for lamp in tail_lamps:
		lamp.material_override.emission_energy_multiplier = 3.5 if throttle < -0.1 or Input.is_action_pressed("handbrake") else 0.8 if night else 0.12

func toggle_flight() -> bool:
	if model_index != 4: return false
	flight_active = not flight_active
	if flight_active:
		velocity.y = 7.0
		floor_snap_length = 0
	else: floor_snap_length = 0.4
	return true

func flight_step(delta: float, throttle: float) -> void:
	throttle_amount = absf(throttle)
	steering = move_toward(steering,Input.get_axis("right","left"),delta*3)
	rotate_y(steering*1.0*delta)
	var forward := -global_basis.z
	var speed := velocity.dot(forward)
	speed = move_toward(speed,throttle*max_speed*0.75,delta*35)
	var vertical := Input.get_action_strength("handbrake")-Input.get_action_strength("descend")
	var lift := 0.0 if position.y >= flight_height_limit and vertical > 0 else vertical*22
	var horizontal := forward*speed
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = move_toward(velocity.y,lift,delta*35)
	var incoming := velocity
	move_and_slide()
	if position.y > flight_height_limit:
		position.y = flight_height_limit
		velocity.y = minf(0,velocity.y)
	process_impact(incoming)
	speed_kmh = Vector2(velocity.x,velocity.z).length()*3.6
	distance += Vector2(velocity.x,velocity.z).length()*delta
	rpm = lerpf(rpm,850+throttle_amount*7000,delta*5)
	visual.rotation.z = lerpf(visual.rotation.z,-steering*0.15,delta*4)
	visual.rotation.x = lerpf(visual.rotation.x,vertical*0.08,delta*4)

func process_impact(incoming: Vector3) -> void:
	if not crash_physics_enabled or crash_cooldown > 0: return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()
		var inward := maxf(0,-incoming.dot(normal))
		if inward < (15.0 if normal.y > 0.7 else 7.0): continue
		crash_cooldown = 0.55
		velocity = incoming.slide(normal)*0.50+normal*minf(14,inward*0.22)
		crash_effects.hit(inward,normal,collision.get_position())
		crashed.emit(inward)
		break
