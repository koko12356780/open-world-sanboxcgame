extends Node3D
## Arcade impact reactions with real rigid-body breakaway debris.
const Geo = preload("res://scripts/geometry.gd")
var car: CharacterBody3D
var smoke: CPUParticles3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	smoke = CPUParticles3D.new()
	smoke.position = Vector3(0,0.95,-1.25)
	smoke.amount = 20
	smoke.lifetime = 1.5
	smoke.direction = Vector3.UP
	smoke.spread = 25
	smoke.gravity = Vector3(0,0.2,0)
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.4
	smoke.scale_amount_min = 0.4
	smoke.scale_amount_max = 2.0
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	sphere.radial_segments = 8
	sphere.rings = 4
	smoke.mesh = sphere
	var material := Geo.material(Color(0.12,0.14,0.15,0.55))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.material_override = material
	add_child(smoke)
	smoke.emitting = false

func hit(inward: float, normal: Vector3, location: Vector3) -> void:
	car.damage = clampf(car.damage+(inward-5)*1.7,0,100)
	car.camera_shake = minf(1.0,inward/35)
	car.crash_stun = minf(1.2,inward/55)
	car.engine_sound.effect("impact.wav",minf(0.85,inward/40))
	deform()
	if inward < 15: return
	for i in clampi(int(inward/12),1,6):
		var body := RigidBody3D.new()
		body.name = "CrashDebris"
		body.mass = 1.5
		body.collision_layer = 4
		body.collision_mask = 1
		body.continuous_cd = true
		var size := Vector3(rng.randf_range(0.15,0.35),0.07,rng.randf_range(0.2,0.55))
		var collider := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collider.shape = bounds
		body.add_child(collider)
		Geo.box(body,Vector3.ZERO,size,car.paint if i%2 == 0 else Color("252c30"))
		car.get_parent().add_child(body)
		body.global_position = location+normal*0.4+Vector3.UP*0.4
		body.add_collision_exception_with(car)
		body.linear_velocity = normal*inward*0.10+Vector3(rng.randf_range(-3,3),rng.randf_range(2,6),rng.randf_range(-3,3))
		body.angular_velocity = Vector3(rng.randf_range(-6,6),rng.randf_range(-6,6),rng.randf_range(-6,6))
		get_tree().create_timer(8).timeout.connect(body.queue_free)

func deform() -> void:
	var shell: MeshInstance3D = car.visual.get_node_or_null("BodyShell")
	if shell != null:
		shell.scale = Vector3(1+car.damage*0.0005,1-car.damage*0.001,1-car.damage*0.0022)
		shell.position.z = car.damage*0.001
	smoke.emitting = car.damage > 55

func repair() -> void:
	car.damage = 0
	car.camera_shake = 0
	car.crash_stun = 0
	deform()
