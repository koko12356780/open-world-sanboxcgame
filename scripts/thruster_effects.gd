extends Node3D
## Factory rear jets on the Roadster; purchasable gas jets on Aurora RS only.
## Particles stay in world space to form trails while the car moves.
const Geo = preload("res://scripts/geometry.gd")
var car: CharacterBody3D
var smoke: Array[CPUParticles3D] = []
var flames: Array[MeshInstance3D] = []
var cores: Array[MeshInstance3D] = []
var lights: Array[OmniLight3D] = []
var ports: Node3D
var sound: AudioStreamPlayer3D
var available: bool = false
var power: float = 0.0

func _ready() -> void:
	name = "ThrusterEffects"
	var radial := GradientTexture2D.new()
	radial.width = 64
	radial.height = 64
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(.5,.5)
	radial.fill_to = Vector2(1,.5)
	radial.gradient = Gradient.new()
	radial.gradient.offsets = PackedFloat32Array([0,.25,.65,1])
	radial.gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,.8),Color(1,1,1,.18),Color(1,1,1,0)])
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = radial
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0,.12,.5,1])
	fade.colors = PackedColorArray([Color(.78,.85,.9,0),Color(.7,.76,.82,.12),Color(.46,.51,.57,.07),Color(.35,.4,.45,0)])
	var growth := Curve.new()
	growth.add_point(Vector2(0,.2))
	growth.add_point(Vector2(.35,.65))
	growth.add_point(Vector2(1,1.4))
	for side in [-1,1]:
		var p := CPUParticles3D.new()
		p.position = Vector3(side*.70,.56,2.42)
		p.amount = 52
		p.lifetime = 1.55
		p.local_coords = false
		p.emitting = false
		p.direction = Vector3.BACK
		p.spread = 17
		p.initial_velocity_min = 4
		p.initial_velocity_max = 8
		p.gravity = Vector3(0,.65,0)
		p.damping_min = .3
		p.damping_max = .7
		p.scale_amount_min = .65
		p.scale_amount_max = 1.2
		p.scale_amount_curve = growth
		p.color_ramp = fade
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh := QuadMesh.new()
		mesh.size = Vector2(1.6,1.6)
		mesh.material = mat
		p.mesh = mesh
		add_child(p)
		smoke.append(p)
	sound = AudioStreamPlayer3D.new()
	var audio: AudioStreamWAV = preload("res://audio/thruster.wav")
	audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
	audio.loop_begin = 0
	audio.loop_end = audio.data.size()/2
	sound.stream = audio
	sound.position = Vector3(0,.6,2.3)
	sound.max_distance = 45
	sound.unit_size = 4
	sound.volume_db = -60
	add_child(sound)
	configure()

func glow(color: Color, alpha: float) -> StandardMaterial3D:
	var mat := Geo.material(Color(color,alpha))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func configure() -> void:
	reset_effects()
	if is_instance_valid(ports):
		if ports.get_parent() != null: ports.get_parent().remove_child(ports)
		ports.queue_free()
	ports = null
	flames.clear()
	cores.clear()
	lights.clear()
	available = car.model_index == 4 or (car.model_index == 3 and car.tune.get("thrusters",false))
	for p in smoke: p.visible = available
	if not available:
		set_process(false)
		return
	ports = Node3D.new()
	ports.name = "RearThrusterAssembly"
	car.visual.add_child(ports)
	var jet_color := Color("65d8ff") if car.model_index == 4 else Color("ffb05c")
	for side in [-1,1]:
		var pos := Vector3(side*.70,.56,2.20)
		var mount := Geo.box(ports,pos-Vector3(0,0,.10),Vector3(.58,.48,.25),Color("18232a"))
		mount.material_override.metallic = .6
		var nozzle := Geo.cylinder(ports,pos,.22,.32,Color("69767d"))
		nozzle.rotation.x = PI/2
		nozzle.mesh.radial_segments = 32
		nozzle.material_override.metallic = .85
		nozzle.material_override.roughness = .24
		var opening := Geo.cylinder(ports,pos+Vector3(0,0,.173),.172,.025,Color("08141b"))
		opening.rotation.x = PI/2
		var core := Geo.cylinder(ports,pos+Vector3(0,0,.19),.115,.015,jet_color)
		core.rotation.x = PI/2
		core.material_override = glow(jet_color,.8)
		cores.append(core)
		var flame := Geo.cylinder(ports,pos+Vector3(0,0,.50),.15,.6,jet_color)
		flame.rotation.x = PI/2
		flame.mesh.top_radius = .008
		var jet := ShaderMaterial.new()
		jet.shader = preload("res://shaders/jet.gdshader")
		jet.set_shader_parameter("jet_color",jet_color)
		flame.material_override = jet
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.visible = false
		flames.append(flame)
		var light := OmniLight3D.new()
		light.position = pos+Vector3(0,0,.4)
		light.light_color = jet_color
		light.omni_range = 3.0
		light.light_energy = 0
		light.shadow_enabled = false
		ports.add_child(light)
		lights.append(light)
	set_process(true)

func _process(delta: float) -> void:
	if not available: return
	var pressing_forward: bool = Input.get_axis("reverse","accelerate") > .1 and car.crash_stun <= 0
	var hover: bool = car.model_index == 4 and car.flight_active
	var target: float = 1.0 if pressing_forward else .24 if hover else 0.0
	power = move_toward(power,target,delta*8)
	var pulse := 1.0+sin(Time.get_ticks_msec()*.083)*.055
	for i in smoke.size():
		var p := smoke[i]
		p.emitting = power > .08
		p.initial_velocity_min = 2+power*5
		p.initial_velocity_max = 4+power*8
		var length: float = (.18+power*.95)*pulse
		flames[i].mesh.height = length
		flames[i].position.z = 2.39+length*.5
		flames[i].visible = power > .07
		cores[i].material_override.emission_energy_multiplier = .12+power*1.8
		lights[i].light_energy = power*.8
	if power > .03:
		if not sound.playing: sound.play()
		sound.volume_linear = power*(.16 if car.interior_view else .30)
		sound.pitch_scale = .8+power*.3
	elif sound.playing: sound.stop()

func reset_effects() -> void:
	power = 0
	for p in smoke:
		p.emitting = false
		p.restart()
		p.emitting = false
	for flame in flames:
		if is_instance_valid(flame): flame.visible = false
	for light in lights:
		if is_instance_valid(light): light.light_energy = 0
	if is_instance_valid(sound): sound.stop()

func _exit_tree() -> void:
	if is_instance_valid(sound):
		sound.stop()
		sound.stream = null
