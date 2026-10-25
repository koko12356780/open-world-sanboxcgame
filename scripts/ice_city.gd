extends Node3D
const Geo=preload("res://scripts/geometry.gd")
const ROADS=[-288,-216,-144,-72,0,72,144,216,288]
const BLOCKS=[-252,-180,-108,-36,36,108,180,252]
var player: Node3D
var snow: CPUParticles3D
var facades: Array[ShaderMaterial]=[]
var lamps: Array[OmniLight3D]=[]
var night: bool=false
var ice: ShaderMaterial
var powder: ShaderMaterial
var rng:=RandomNumberGenerator.new()
var timer: float=0
func _ready() -> void:
	name="IceCity"
	rng.seed=1010
	ice=ShaderMaterial.new();ice.shader=preload("res://shaders/ice.gdshader")
	powder=ShaderMaterial.new();powder.shader=ice.shader;powder.set_shader_parameter("snow",1.)
	var ground:=Geo.box(self,Vector3(0,-.5,0),Vector3(1280,1,3400),Color.WHITE,true)
	ground.material_override=powder
	for r in ROADS:
		for z in range(-324,325,36):
			road(Vector3(r,.027,z),Vector3(18,.05,36))
			road(Vector3(z,.029,r),Vector3(36,.05,18))
		for d in range(-318,319,18):
			var crossing: bool=false
			for cross in ROADS:
				if absf(d-cross)<12:crossing=true
			if not crossing:
				Geo.box(self,Vector3(r,.065,d),Vector3(.13,.01,5),Color("d7edf0"))
				Geo.box(self,Vector3(d,.066,r),Vector3(5,.01,.13),Color("d7edf0"))
	for z in range(-720,721,36):road(Vector3(0,.03,z),Vector3(18,.05,36))
	for x in BLOCKS:
		for z in BLOCKS:
			var curb:=Geo.box(self,Vector3(x,.12,z),Vector3(52,.24,52),Color("dcecf0"))
			curb.material_override=powder
			if Vector2(x,z)==Vector2(36,36):
				crystal(Vector3(x,0,z),13)
				for side in [-1,1]:pine(Vector3(x+side*18,0,z+18))
				continue
			for dx in [-13,13]:
				for dz in [-13,13]:
					if abs(x)>180 and dx!=dz:continue
					building(Vector3(x+dx,.25,z+dz),rng.randi_range(3,10)*4.)
			pine(Vector3(x-24,0,z))
	# Frozen lake and long glacier road are also drivable.
	road(Vector3(-365,.032,0),Vector3(76,.05,450))
	for z in range(-288,289,72):
		for x in [-11,11]:crystal(Vector3(x,0,z+24),3.5)
	for side in [-1,1]:
		Geo.box(self,Vector3(side*425,1,0),Vector3(3,2,1540),Color("81bed3"),true)
		Geo.box(self,Vector3(0,1,side*770),Vector3(850,2,3),Color("81bed3"),true)
		for z in range(-650,651,100):
			crystal(Vector3(side*390,0,z),rng.randf_range(18,37))
			pine(Vector3(side*24,0,z))
	for x in [-11,11]:
		for z in [-252,-108,36,180,300]:
			Geo.cylinder(self,Vector3(x,3,z),.1,6,Color("486e82"))
			var fixture:=Geo.box(self,Vector3(x,6,z),Vector3(.7,.3,.7),Color("b6efff"))
			fixture.material_override.emission_enabled=true
			fixture.material_override.emission=Color("69ccff")
			var light:=OmniLight3D.new();light.position=Vector3(x,5.8,z);light.light_color=Color("a7dcff");light.omni_range=17;light.light_energy=2
			add_child(light);lamps.append(light)
	make_snow()
	preload("res://scripts/scenery_batch.gd").build(self)
	set_night(false)
func road(pos: Vector3,size: Vector3) -> void:
	var mesh:=Geo.box(self,pos,size,Color.WHITE)
	mesh.material_override=ice
func building(pos: Vector3,height: float) -> void:
	var mat:=ShaderMaterial.new();mat.shader=preload("res://shaders/ice_facade.gdshader")
	mat.set_shader_parameter("tint",Color.from_hsv(.55+rng.randf()*.025,.32+rng.randf()*.2,.48+rng.randf()*.18))
	facades.append(mat)
	var block:=Geo.box(self,pos+Vector3.UP*height*.5,Vector3(18,height,18),Color.WHITE,true)
	block.material_override=mat
	Geo.box(self,pos+Vector3.UP*(height+.18),Vector3(19,.4,19),Color("e0f4fa"))
	for y in range(4,int(height),8):Geo.box(self,pos+Vector3.UP*y,Vector3(18.3,.16,18.3),Color("a1ccdb"))
	if height>30:
		var roof:=Geo.cylinder(self,pos+Vector3.UP*(height+4),7,8,Color("71acc7"))
		roof.mesh.top_radius=0;roof.mesh.radial_segments=4
func crystal(pos: Vector3,height: float) -> void:
	var mesh:=Geo.cylinder(self,pos+Vector3.UP*height*.5,height*.17,height,Color("69c3e7"))
	mesh.mesh.top_radius=0;mesh.mesh.radial_segments=5
	mesh.material_override.metallic=.2;mesh.material_override.roughness=.2
func pine(pos: Vector3) -> void:
	Geo.cylinder(self,pos+Vector3.UP, .12,2,Color("647883"))
	for i in 3:
		var crown:=Geo.cylinder(self,pos+Vector3.UP*(2.2+i*1.3),2.4-i*.5,3.3,Color("c1dfe4"))
		crown.mesh.top_radius=0;crown.mesh.radial_segments=8
func make_snow() -> void:
	snow=CPUParticles3D.new();snow.amount=380;snow.lifetime=6;snow.local_coords=false
	snow.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;snow.emission_box_extents=Vector3(42,4,42)
	snow.direction=Vector3.DOWN;snow.spread=12;snow.initial_velocity_min=3;snow.initial_velocity_max=6;snow.gravity=Vector3(.35,-.1,.1)
	var quad:=QuadMesh.new();quad.size=Vector2(.065,.065)
	var mat:=Geo.material(Color("e8faff"));mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material=mat;snow.mesh=quad;snow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	snow.position=Vector3(0,22,250);add_child(snow)
func set_night(value: bool) -> void:
	night=value
	for mat in facades:mat.set_shader_parameter("night_amount",1. if value else 0.)
	timer=0
func _process(delta: float) -> void:
	if player!=null:snow.global_position=player.global_position+Vector3.UP*22
	timer-=delta
	if timer<=0:
		timer=.4
		for lamp in lamps:lamp.visible=night and (player==null or lamp.global_position.distance_squared_to(player.global_position)<6400)
