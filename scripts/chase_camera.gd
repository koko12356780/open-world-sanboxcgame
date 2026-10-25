extends Node3D
## Separate rig avoids inheriting the car's body roll. Arm prevents wall clipping.
var target: CharacterBody3D
var arm: SpringArm3D
var camera: Camera3D
var driver_camera: Camera3D
var cockpit: Node3D
var mode: int = 0
var mouse_look_enabled: bool = false
var look_yaw: float = 0
var look_pitch: float = 0

func _ready() -> void:
	arm = SpringArm3D.new()
	arm.spring_length = 7.2
	arm.margin = 0.3
	arm.rotation.x = deg_to_rad(-14)
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	arm.shape = probe
	arm.add_excluded_object(target.get_rid())
	add_child(arm)
	camera = Camera3D.new()
	camera.current = true
	camera.cull_mask = 1
	camera.fov = 64
	arm.add_child(camera)
	driver_camera = Camera3D.new()
	driver_camera.position = Vector3(-0.33,1.39,0.23)
	driver_camera.fov = 70
	driver_camera.rotation.x = deg_to_rad(-2)
	driver_camera.cull_mask = 3
	driver_camera.near = 0.04
	target.add_child(driver_camera)
	cockpit = preload("res://scripts/cockpit.gd").new()
	cockpit.car = target
	cockpit.driver_camera = driver_camera
	target.add_child(cockpit)
	set_mode(0)
	snap()

func snap() -> void:
	look_yaw = 0
	look_pitch = 0
	global_position = target.global_position + Vector3.UP * 1.8
	rotation.y = target.rotation.y

func _physics_process(delta: float) -> void:
	global_position = global_position.lerp(target.global_position + Vector3.UP * 1.8, 1 - exp(-12 * delta))
	rotation.y = lerp_angle(rotation.y, target.rotation.y, 1 - exp(-5 * delta))
	camera.fov = lerpf(camera.fov, 64 + target.velocity.length() * 0.25, delta * 2)
	camera.fov = minf(camera.fov,92)
	arm.rotation.y = look_yaw
	arm.rotation.x = deg_to_rad(-14)+look_pitch
	driver_camera.rotation = Vector3(deg_to_rad(-2)+look_pitch,look_yaw,0)
	var t := Time.get_ticks_msec()/1000.0
	var shake: float = target.camera_shake*0.055
	camera.h_offset = sin(t*43)*shake
	camera.v_offset = cos(t*57)*shake
	driver_camera.h_offset = camera.h_offset*0.5
	driver_camera.v_offset = camera.v_offset*0.5

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_look_enabled:
		look_yaw -= event.relative.x*0.0025
		if mode == 2: look_yaw = clampf(look_yaw,deg_to_rad(-115),deg_to_rad(115))
		look_pitch = clampf(look_pitch-event.relative.y*0.0025,deg_to_rad(-25),deg_to_rad(20))

func set_mode(next: int) -> void:
	look_yaw = 0
	look_pitch = 0
	mode = next
	var inside := mode == 2
	target.interior_view = inside
	target.visual.visible = not inside
	cockpit.set_active(inside)
	camera.current = not inside
	driver_camera.current = inside
	arm.spring_length = 13.0 if mode == 1 else 7.2
