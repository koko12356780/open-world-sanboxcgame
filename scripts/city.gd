extends Node3D
const Geo = preload("res://scripts/geometry.gd")
const Layout = preload("res://scripts/world_layout.gd")
const ROADS = Layout.ROADS
const Lamp = preload("res://scripts/streetlamp.gd")
var rng := RandomNumberGenerator.new()
var asphalt: ShaderMaterial
var pavement: ShaderMaterial
var lamps: Array[SpotLight3D] = []
var facades: Array[ShaderMaterial] = []
var night: bool = false
var player: Node3D
var light_timer: float = 0.0
var urban: Node3D
var shop_materials: Array[StandardMaterial3D] = []
var foliage: StandardMaterial3D
var facade_cache: Dictionary = {}

func _ready() -> void:
	rng.seed = 408
	asphalt = Geo.surface(Color("353638"))
	pavement = Geo.surface(Color("929187"), 1)
	Geo.box(self, Vector3(0,-0.5,0),Vector3(Layout.WORLD_X*2,1,Layout.WORLD_Z*2),Color("59634c"),true)
	var water := Geo.box(self,Vector3(625,0.01,0),Vector3(28,0.02,3300),Color("536d72"))
	water.material_override.roughness = 0.22
	water.material_override.metallic = 0.4
	for road in ROADS:
		# Short road meshes keep Compatibility's per-object light limit local.
		for segment in range(-576,577,36):
			var a := Geo.box(self,Vector3(road,0.025,segment),Vector3(14,0.05,36),Color.WHITE)
			a.material_override = asphalt
			var b := Geo.box(self,Vector3(segment,0.027,road),Vector3(36,0.05,14),Color.WHITE)
			b.material_override = asphalt
		for d in range(-590,591,12):
			var crossing := false
			for cross in ROADS:
				if abs(d-cross)<11: crossing = true
			if not crossing:
				for offset in [-0.18,0.18]:
					Geo.box(self,Vector3(road+offset,0.06,d),Vector3(0.10,0.012,4),Color("bda46e"))
					Geo.box(self,Vector3(d,0.061,road+offset),Vector3(4,0.012,0.10),Color("bda46e"))
		for d in Layout.BLOCKS:
			if abs(road) > 300 and abs(d) > 300: continue
			streetlight(Vector3(road+8.1,0,d))
			streetlight(Vector3(road-8.1,0,d+12),1.0)
			streetlight(Vector3(d,0,road+8.1))
			streetlight(Vector3(d+12,0,road-8.1),1.0)
	for x in ROADS:
		for z in ROADS:
			for side in [-1,1]:
				for stripe in range(-5,6,3):
					Geo.box(self,Vector3(x+stripe,0.067,z+side*9),Vector3(0.9,0.015,2.5),Color("c9c5b6"))
					Geo.box(self,Vector3(x+side*9,0.068,z+stripe),Vector3(2.5,0.015,0.9),Color("c9c5b6"))
	for bx in Layout.BLOCKS:
		for bz in Layout.BLOCKS:
			var sidewalk := Geo.box(self,Vector3(bx,0.08,bz),Vector3(56,0.16,56),Color.WHITE)
			sidewalk.material_override = pavement
			for side in [-1,1]:
				Geo.box(self,Vector3(bx+side*28,0.12,bz),Vector3(0.25,0.24,56),Color("aaa89d"))
				Geo.box(self,Vector3(bx,0.12,bz+side*28),Vector3(56,0.24,0.25),Color("aaa89d"))
			if Vector2(bx,bz) in [Vector2(36,36),Vector2(-180,-180),Vector2(180,180),Vector2(252,-180)]:
				park(Vector3(bx,0,bz))
				continue
			var outer := maxf(absf(bx),absf(bz)) > 300
			for dx in [-15,15]:
				for dz in [-15,15]:
					if outer and dx != dz: continue
					building(Vector3(bx+dx,0.16,bz+dz),outer)
			if not outer:
				for side in [-1,1]:
					tree(Vector3(bx+side*25,0,bz))
					bench(Vector3(bx,0,bz+side*25))
	# The full world includes a 3.35 km straight test highway through the city.
	for side in [-1,1]:
		Geo.box(self,Vector3(side*Layout.WORLD_X,0.7,0),Vector3(1,1.4,Layout.WORLD_Z*2+2),Color("85847d"),true)
		Geo.box(self,Vector3(0,0.7,side*Layout.WORLD_Z),Vector3(Layout.WORLD_X*2+2,1.4,1),Color("85847d"),true)
		for z in range(612,1680,36):
			var road := Geo.box(self,Vector3(0,0.026,side*z),Vector3(24,0.05,36),Color.WHITE)
			road.material_override = asphalt
			for x in [-12.5,12.5]:
				Geo.box(self,Vector3(x,0.55,side*z),Vector3(0.3,1.1,36),Color("8c9293"),true)
			for lane in [-5.8,5.8]: Geo.box(self,Vector3(lane,0.06,side*z),Vector3(0.12,0.02,10),Color("d6d2bd"))
			Geo.box(self,Vector3(0,0.061,side*z),Vector3(0.16,0.02,36),Color("cbb06d"))
			if z%108 == 72:
				streetlight(Vector3(13.5,0,side*z))
				streetlight(Vector3(-13.5,0,side*z),1.0)
				for x in [-32,32]: tree(Vector3(x,0,side*z))
	for z in [-1200,1200]:
		var sign := Label3D.new()
		sign.text = "TEST HIGHWAY / FLIGHT ZONE\nCITY CENTRE: STRAIGHT AHEAD"
		sign.position = Vector3(0,8,z)
		sign.font_size = 64
		sign.pixel_size = 0.035
		if z < 0: sign.rotation.y = PI
		add_child(sign)

	preload("res://scripts/city_details.gd").build(self)
	urban = preload("res://scripts/urban_visuals.gd").new()
	urban.city = self
	add_child(urban)
	for child in get_children():
		if child is GeometryInstance3D:
			if child is MeshInstance3D and child.mesh is BoxMesh and child.mesh.size.length() > 100:
				continue
			child.visibility_range_end = 240.0
	preload("res://scripts/scenery_batch.gd").build(self)

func building(pos: Vector3, simple: bool = false) -> void:
	var outskirts := maxf(absf(pos.x),absf(pos.z)) > 160
	var floors := rng.randi_range(2,4) if outskirts else rng.randi_range(3,8)
	var h := floors*3.6
	var palette := [Color("846b57"),Color("9e9480"),Color("75544b"),Color("a4a49b"),Color("676e70")]
	var color_index: int = rng.randi_range(0,4)
	var style: int = rng.randi_range(0,1)
	var key: int = color_index*2+style
	if not facade_cache.has(key):
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/facade.gdshader")
		material.set_shader_parameter("masonry",palette[color_index])
		material.set_shader_parameter("style",float(style))
		facade_cache[key] = material
		facades.append(material)
	var facade: ShaderMaterial = facade_cache[key]
	var shell := Geo.box(self,pos+Vector3(0,h/2,0),Vector3(19,h,19),Color.WHITE,true)
	shell.material_override = facade
	Geo.box(self,pos+Vector3(0,h+0.15,0),Vector3(19.5,0.3,19.5),Color("565753"))
	Geo.box(self,pos+Vector3(0,3.5,0),Vector3(19.3,0.22,19.3),Color("6d6d65"))
	if simple: return
	# Recessed storefronts, upper cornice, and roof ventilation equipment.
	for side in [-1,1]:
		for x in [-6,0,6]:
			Geo.box(self,pos+Vector3(x,1.6,side*9.52),Vector3(4.8,2.7,0.05),Color("263438"))
			Geo.box(self,pos+Vector3(side*9.52,1.6,x),Vector3(0.05,2.7,4.8),Color("263438"))
		var awning := Geo.box(self,pos+Vector3(0,3.0,side*10),Vector3(17,0.15,1.2),Color("3f5451"))
		awning.rotation.x = side*0.12
	Geo.box(self,pos+Vector3(2,h+0.8,1),Vector3(3,1.4,2.8),Color("878b88"))
	Geo.cylinder(self,pos+Vector3(-5,h+0.9,-3),0.55,1.8,Color("535958"))
	var shop_colors := [Color("263e43"),Color("713e32"),Color("35463a"),Color("333940")]
	preload("res://scripts/urban_visuals.gd").storefront(self,pos,h,shop_colors[rng.randi_range(0,3)])
	var label := Label3D.new()
	label.text = ["CORNER COFFEE","STREET MOTORS","MARKET & DELI","STUDIO 04","RIVERSIDE"][rng.randi_range(0,4)]
	label.font_size = 40
	label.pixel_size = 0.009
	label.modulate = Color("e0d6b9")
	label.position = pos+Vector3(0,3.24,9.72)
	label.visible = maxf(absf(pos.x),absf(pos.z))>235
	add_child(label)

func streetlight(pos: Vector3, arm_direction: float = -1.0) -> void:
	Geo.cylinder(self,pos+Vector3.UP*3.8,0.075,7.6,Color("414746"))
	Geo.box(self,pos+Vector3(arm_direction,7.6,0),Vector3(2.2,0.10,0.12),Color("414746"))
	var lamp := Geo.box(self,pos+Vector3(arm_direction*2,7.48,0),Vector3(0.7,0.12,0.35),Color("f1dfb2"))
	lamp.material_override.emission_enabled = true
	lamp.material_override.emission = Color("c8aa72")
	Geo.box(self,pos+Vector3(0,0.2,0),Vector3(0.35,0.4,0.35),Color("676c66"))
	var light := Lamp.new()
	light.fixture = lamp.material_override
	light.position = pos+Vector3(arm_direction*2,7.3,0)
	light.rotation.x = -PI/2
	light.light_color = Color("ffcd84")
	light.light_energy = 5.0
	light.spot_range = 22
	light.spot_angle = 65
	light.spot_attenuation = 0.6
	light.visible = false
	add_child(light)
	lamps.append(light)

func tree(pos: Vector3) -> void:
	Geo.cylinder(self,pos+Vector3.UP*2.5,0.17,5,Color("51483b"))
	for angle in [0.0,2.1,4.2]:
		var branch:=Geo.cylinder(self,pos+Vector3(sin(angle)*.5,4.4,cos(angle)*.5),.07,2.1,Color("51483b"))
		branch.rotation=Vector3(.55,angle,.2)
	if foliage==null:
		foliage=Geo.material(Color.WHITE)
		foliage.albedo_texture=preload("res://textures/leaves.png")
		foliage.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		foliage.alpha_scissor_threshold=.45
		foliage.cull_mode=BaseMaterial3D.CULL_DISABLED
		foliage.vertex_color_use_as_albedo=true
	var batch:=MultiMesh.new()
	batch.transform_format=MultiMesh.TRANSFORM_3D
	batch.use_colors=true
	var leaf:=QuadMesh.new()
	leaf.size=Vector2(1.6,1.6)
	batch.mesh=leaf
	batch.instance_count=100
	for i in 100:
		var offset:=Vector3(rng.randf_range(-2.5,2.5),rng.randf_range(-1.8,1.8),rng.randf_range(-2.5,2.5))
		offset=offset.limit_length(2.6)
		var basis:=Basis.from_euler(Vector3(rng.randf()*PI,rng.randf()*TAU,rng.randf()*PI))
		batch.set_instance_transform(i,Transform3D(basis,pos+Vector3(0,5.4,0)+offset))
		batch.set_instance_color(i,Color.WHITE.darkened(rng.randf_range(0,.25)))
	var crown:=MultiMeshInstance3D.new()
	crown.multimesh=batch
	crown.material_override=foliage
	crown.visibility_range_end=185
	add_child(crown)

func bench(pos: Vector3) -> void:
	for z in [-0.25,0,0.25]:
		Geo.box(self,pos+Vector3(0,0.6,z),Vector3(2.2,0.10,0.18),Color("72604b"))
	for x in [-0.8,0.8]:
		Geo.box(self,pos+Vector3(x,0.3,0),Vector3(0.08,0.6,0.6),Color("353b3a"))
	Geo.box(self,pos+Vector3(0,1.1,0.35),Vector3(2.2,0.5,0.09),Color("72604b"))

func park(pos: Vector3) -> void:
	Geo.box(self,pos+Vector3.UP*0.18,Vector3(51,0.06,51),Color("64704b"))
	Geo.box(self,pos+Vector3.UP*0.22,Vector3(5,0.04,51),Color("b6aa92"))
	Geo.box(self,pos+Vector3.UP*0.23,Vector3(51,0.04,5),Color("b6aa92"))
	for x in [-18,18]:
		for z in [-18,-9,9,18]: tree(pos+Vector3(x,0,z))
	for z in [-10,10]: bench(pos+Vector3(5,0,z))

func set_night(enabled: bool) -> void:
	night = enabled
	asphalt.set_shader_parameter("night_amount",1.0 if enabled else 0.0)
	if is_instance_valid(urban): urban.set_night(enabled)
	for mat in shop_materials: mat.emission_energy_multiplier = (.14 if enabled else .02) if mat.albedo_texture!=null else (.52 if enabled else .035)
	for facade in facades: facade.set_shader_parameter("night_amount",1.0 if night else 0.0)
	light_timer = 0.0
	update_lights()

func update_lights() -> void:
	for lamp in lamps:
		lamp.configure(night,player == null or lamp.global_position.distance_squared_to(player.global_position) < 85.0*85.0)

func _process(delta: float) -> void:
	light_timer -= delta
	if light_timer <= 0:
		light_timer = 0.35
		update_lights()
