extends Node3D
var car: CharacterBody3D
var smoke: Array[CPUParticles3D] = []
var marks: Array[MeshInstance3D] = []
var mark_timer: float = 0
var last_mark_position := Vector3.INF
func _ready() -> void:
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0,0.15,0.65,1])
	fade.colors = PackedColorArray([Color(0.75,0.78,0.81,0),Color(0.75,0.78,0.81,0.08),Color(0.7,0.73,0.77,0.04),Color(0.65,0.69,0.73,0)])
	var radial := GradientTexture2D.new()
	radial.width = 64
	radial.height = 64
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5,0.5)
	radial.fill_to = Vector2(1,0.5)
	radial.gradient = Gradient.new()
	radial.gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0)])
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = radial
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.no_depth_test = false
	for side in [-1,1]:
		var p := CPUParticles3D.new()
		p.position = Vector3(side*0.98,0.27,1.32)
		p.amount = 42
		p.lifetime = 2.4
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.local_coords = false
		p.emitting = false
		p.direction = Vector3.UP
		p.spread = 45
		p.initial_velocity_min = 0.8
		p.initial_velocity_max = 2.0
		p.gravity = Vector3(0,0.6,0)
		p.scale_amount_min = 0.7
		p.scale_amount_max = 1.6
		p.color_ramp = fade
		var quad := QuadMesh.new()
		quad.size = Vector2(1.5,1.5)
		quad.material = mat
		p.mesh = quad
		add_child(p)
		smoke.append(p)
func _physics_process(delta: float) -> void:
	var sliding: bool = car.is_on_floor() and not car.flight_active and absf(car.velocity.dot(car.global_basis.x)) > 6
	var active: bool = car.burnout_active or sliding
	for p in smoke: p.emitting = active
	mark_timer -= delta
	if active and mark_timer <= 0 and car.global_position.distance_to(last_mark_position) > 0.5:
		mark_timer = 0.08
		last_mark_position = car.global_position
		for side in [-1,1]:
			var mark := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.25,0.005,0.6)
			mark.mesh = box
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.055,0.061,0.065)
			mat.roughness = 1
			mark.material_override = mat
			car.get_parent().add_child(mark)
			mark.global_position = car.to_global(Vector3(side*0.98,0.02,1.32))
			mark.global_position.y = 0.078
			mark.rotation.y = car.rotation.y
			marks.append(mark)
			if marks.size() > 192: marks.pop_front().queue_free()
func reset_effects() -> void:
	for p in smoke: p.emitting = false
	last_mark_position = Vector3.INF
