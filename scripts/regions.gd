extends Node3D
const Geo=preload("res://scripts/geometry.gd")
const ICE=preload("res://scripts/ice_city.gd")
const ROOF_GATE=Vector3(-108,68,-176)
const RETURN_GATE=Vector3(0,6,330)
const ICE_SPAWN=Vector3(3.5,1,250)
const CITY_RETURN=Vector3(-140.5,1,-120)
var game: Node3D
var in_ice: bool=false
var ice_city: Node3D
var gate: Node3D
var cooldown: float=0
var transition_time: float=0
var last_position: Vector3
var default_spawn: Transform3D
var city_sky: Material
var ice_sky: ShaderMaterial
func _ready() -> void:
	name="Regions"
	default_spawn=game.car.spawn
	city_sky=game.env.sky.sky_material
	ice_sky=ShaderMaterial.new();ice_sky.shader=preload("res://shaders/ice_sky.gdshader")
	gate=portal(game.city,ROOF_GATE,"ICE CITY\nFLY THROUGH")
	# A luminous roof beacon is visible even before distant scenery is drawn.
	var beam:=Geo.cylinder(gate,Vector3(0,32,0),.35,64,Color("49cfff"))
	beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override.emission_enabled=true;beam.material_override.emission=Color("2cafff")
	last_position=game.walker.global_position if game.walker!=null and game.walker.active else game.car.global_position
	game.car.reset_performed.connect(sync_position)
func portal(parent: Node3D,center: Vector3,caption: String) -> Node3D:
	var root:=Node3D.new();parent.add_child(root);root.position=center
	var ring:=MeshInstance3D.new();var torus:=TorusMesh.new()
	torus.inner_radius=5.25;torus.outer_radius=6.15;torus.rings=40;torus.ring_segments=10
	ring.mesh=torus;ring.rotation.x=PI/2
	var mat:=Geo.material(Color("248dff"));mat.emission_enabled=true;mat.emission=Color("18a9ff");mat.emission_energy_multiplier=2
	ring.material_override=mat;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(ring)
	var disk:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(10.5,10.5);disk.mesh=quad
	var shader:=ShaderMaterial.new();shader.shader=preload("res://shaders/portal.gdshader");disk.material_override=shader
	disk.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(disk)
	var label:=Label3D.new();label.text=caption;label.font_size=64;label.pixel_size=.024;label.position=Vector3(0,9,0);label.modulate=Color("8deaff");root.add_child(label)
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	var light:=OmniLight3D.new();light.omni_range=20;light.light_color=Color("4bbcff");light.light_energy=1.1;root.add_child(light)
	return root
func ensure_ice() -> void:
	if is_instance_valid(ice_city):return
	ice_city=ICE.new();ice_city.player=game.car;add_child(ice_city)
	portal(ice_city,RETURN_GATE,"RETURN TO CITY\nDRIVE OR FLY THROUGH")
func set_region(region: String,teleport: bool=true) -> void:
	if game.walker!=null:game.walker.enter()
	var target: bool=region=="ice"
	if target:ensure_ice()
	in_ice=target
	# CollisionObject3D's default REMOVE mode removes bodies when inherited
	# processing is disabled. Root visibility preserves the batch visibility flags.
	game.city.visible=not target
	game.city.process_mode=Node.PROCESS_MODE_DISABLED if target else Node.PROCESS_MODE_INHERIT
	if is_instance_valid(ice_city):
		ice_city.visible=target
		ice_city.process_mode=Node.PROCESS_MODE_INHERIT if target else Node.PROCESS_MODE_DISABLED
	game.car.spawn=Transform3D(Basis.IDENTITY,ICE_SPAWN) if target else default_spawn
	game.car.surface_grip=.55 if target else 1.
	game.beacon.visible=not target
	game.set_night(game.night)
	if teleport:
		game.car.reset_car()
		game.car.global_position=ICE_SPAWN if target else CITY_RETURN
		game.chase.snap()
		game.previous_distance=game.car.distance
		transition_time=4
		cooldown=2
	sync_position()
func apply_environment() -> void:
	if in_ice:
		game.env.sky.sky_material=ice_sky
		ice_sky.set_shader_parameter("night_amount",1. if game.night else 0.)
		game.sun.light_color=Color("a1c8ef") if game.night else Color("d2efff")
		game.sun.light_energy=.15 if game.night else .7
		game.env.ambient_light_color=Color("91bdd8")
		game.env.ambient_light_energy=.34 if game.night else .48
		game.env.fog_light_color=Color("172d47") if game.night else Color("bedce9")
		game.env.fog_density=.0025
		ice_city.set_night(game.night)
	else:game.env.sky.sky_material=city_sky
func sync_position() -> void:
	last_position=game.walker.global_position if game.walker!=null and game.walker.active else game.car.global_position
func _physics_process(delta: float) -> void:
	transition_time=maxf(0,transition_time-delta)
	cooldown=maxf(0,cooldown-delta)
	var pos: Vector3=game.walker.global_position if game.walker!=null and game.walker.active else game.car.global_position
	if cooldown<=0:
		if in_ice and crossed(last_position,pos,RETURN_GATE,Vector3(6.5,7,4)):
			set_region("city");return
		if not in_ice and game.car.model_index==4 and game.car.flight_active and crossed(last_position,pos,ROOF_GATE,Vector3(7,5,6)):
			set_region("ice");return
	last_position=pos
static func crossed(from: Vector3,to: Vector3,center: Vector3,half: Vector3) -> bool:
	var direction:=to-from
	var low: float=0
	var high: float=1
	for axis in 3:
		if absf(direction[axis])<.00001:
			if from[axis]<center[axis]-half[axis] or from[axis]>center[axis]+half[axis]:return false
		else:
			var a: float=(center[axis]-half[axis]-from[axis])/direction[axis]
			var b: float=(center[axis]+half[axis]-from[axis])/direction[axis]
			low=maxf(low,minf(a,b));high=minf(high,maxf(a,b))
			if low>high:return false
	return true
