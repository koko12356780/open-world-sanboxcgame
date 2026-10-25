extends CharacterBody3D
## First-person pedestrian with a parked, persistent car to return to.
var game: Node3D
var active: bool=false
var camera: Camera3D
var pitch: float=0
var mouse_look_enabled: bool=false
var message: String=""
var message_time: float=0
var step_timer: float=0
var footsteps: AudioStreamPlayer
func _ready() -> void:
	name="Walker"
	var capsule:=CapsuleShape3D.new();capsule.radius=.3;capsule.height=1.7
	var collider:=CollisionShape3D.new();collider.shape=capsule;collider.position.y=.85;add_child(collider)
	camera=Camera3D.new();camera.position.y=1.58;camera.fov=76;camera.cull_mask=1;camera.near=.08;add_child(camera)
	floor_snap_length=.3
	footsteps=AudioStreamPlayer.new();footsteps.stream=preload("res://audio/footstep.wav");footsteps.volume_db=-14;add_child(footsteps)
	set_collision(false)
func set_collision(enabled: bool) -> void:
	collision_layer=2 if enabled else 0
	collision_mask=1 if enabled else 0
func notify(text: String) -> void:
	message=text;message_time=3
func clear_at(pos: Vector3) -> bool:
	var shape:=CapsuleShape3D.new();shape.radius=.32;shape.height=1.7
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape
	query.transform=Transform3D(Basis.IDENTITY,pos+Vector3.UP*.87)
	query.exclude=[game.car.get_rid(),get_rid()];query.collision_mask=1
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func toggle() -> void:
	if active:
		if global_position.distance_to(game.car.global_position)>4.5:
			notify("Get closer to your car to drive / E");return
		enter();return
	if game.car.flight_active or game.car.speed_kmh>8 or not game.car.is_on_floor():
		notify("Stop on the ground before leaving the car");return
	var found: bool=false
	for offset in [Vector3(2.5,.06,0),Vector3(-2.5,.06,0),Vector3(0,.06,4.5),Vector3(0,.06,-4.5)]:
		var candidate: Vector3=game.car.global_transform*offset
		if clear_at(candidate):
			global_position=candidate;found=true;break
	if not found:notify("No room to open the door here");return
	active=true;set_collision(true);velocity=Vector3.ZERO;rotation.y=game.car.rotation.y;pitch=0
	game.car.parked=true;game.car.velocity=Vector3.ZERO;game.car.throttle_amount=0
	game.car.burnout_active=false;game.car.thruster_effects.reset_effects();game.car.tire_effects.reset_effects()
	game.chase.cockpit.set_active(false);game.car.interior_view=false;game.car.visual.visible=true;camera.current=true
	game.city.player=self
	if is_instance_valid(game.regions.ice_city):game.regions.ice_city.player=self
	game.sync_mouse();notify("ON FOOT / WASD walk / Shift run / Space jump / E drive")
func enter() -> void:
	if not active:return
	active=false;set_collision(false);velocity=Vector3.ZERO;footsteps.stop()
	game.car.parked=false;game.city.player=game.car
	if is_instance_valid(game.regions.ice_city):game.regions.ice_city.player=game.car
	game.chase.set_mode(game.chase.mode);game.chase.snap();game.sync_mouse()
func _unhandled_input(event: InputEvent) -> void:
	if not active or not mouse_look_enabled or get_tree().paused:return
	if event is InputEventMouseMotion:
		rotation.y-=event.relative.x*.0025
		pitch=clampf(pitch-event.relative.y*.0025,deg_to_rad(-80),deg_to_rad(80))
func _physics_process(delta: float) -> void:
	message_time=maxf(0,message_time-delta)
	if not active:return
	if Input.is_action_just_pressed("reset"):
		enter();game.car.reset_car();notify("Returned to your car");return
	var input:=Vector2(Input.get_axis("left","right"),Input.get_axis("accelerate","reverse"))
	var direction: Vector3=(global_basis*Vector3(input.x,0,input.y)).normalized()
	var pace: float=7.0 if Input.is_action_pressed("sprint") else 3.7
	velocity.x=move_toward(velocity.x,direction.x*pace,delta*24)
	velocity.z=move_toward(velocity.z,direction.z*pace,delta*24)
	if not is_on_floor():velocity.y-=22*delta
	elif Input.is_action_just_pressed("handbrake"):velocity.y=6
	move_and_slide()
	step_timer-=delta
	if is_on_floor() and direction.length()>.1 and step_timer<=0:
		step_timer=.3 if pace>4 else .46;footsteps.pitch_scale=randf_range(.9,1.1);footsteps.play()
	camera.rotation.x=pitch
	var moving: bool=is_on_floor() and direction.length()>.1
	camera.position.y=1.58+sin(Time.get_ticks_msec()*.012)*.025 if moving else 1.58
	if global_position.y < -12 or absf(global_position.x)>700 or absf(global_position.z)>1760:
		enter();game.car.reset_car()
