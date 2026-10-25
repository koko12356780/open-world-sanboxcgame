extends Node3D
## Original mesh scenery. No imported GTA models, textures or game files.
const Geo = preload("res://scripts/geometry.gd")
const Body = preload("res://scripts/car_visual.gd")
var city: Node3D
var signs: Array[StandardMaterial3D] = []
var shop_lights: Array[OmniLight3D] = []
var evening: bool = false
var tick: float = 0
var probe: ReflectionProbe
static var window_cache: Dictionary={}
static func shop_material(kind: int,city_node: Node3D) -> StandardMaterial3D:
	# Shared once per city; facade duplicates stay cheap to render.
	var key: String="%d/%d" % [city_node.get_instance_id(),kind]
	if window_cache.has(key):return window_cache[key]
	var mat:=Geo.material(Color("acb6bb"))
	var textures=[preload("res://textures/shop-cafe.svg"),preload("res://textures/shop-market.svg"),preload("res://textures/shop-motors.svg")]
	mat.albedo_texture=textures[kind];mat.roughness=.4;mat.metallic_specular=.2
	mat.emission_enabled=true;mat.emission=Color.WHITE;mat.emission_texture=textures[kind];mat.emission_energy_multiplier=.1
	city_node.shop_materials.append(mat);window_cache[key]=mat;return mat

func _ready() -> void:
	name = "CitylightScenery"
	# A distinctive stepped downtown district; footprints stay inside existing blocks.
	for data in [Vector3(-108,62,-180),Vector3(108,88,-252),Vector3(-180,48,-252),Vector3(180,72,-324),Vector3(-108,110,-396)]:
		tower(data)
	for x in [-72,72]:
		for z in [-180,-108,-36,36,108,180]:
			palm(Vector3(x+10.1,.2,z))
	for x in [-144,0,144]:
		for z in [-178,-112,-38,104,176]:
			if x==0 and z==-38: continue
			parked_car(Vector3(x+9.1,.24,z),0.0,Color.from_hsv(fmod(absf(x+z)*.013,1.),.23,.27))
			parked_car(Vector3(x-9.1,.24,z+17),PI,Color("a4a8a6"))
	# Reflections include nearby buildings and lights, without a full-screen effect.
	probe = ReflectionProbe.new()
	probe.position = Vector3(3.5,3,35)
	probe.size = Vector3(65,28,90)
	probe.origin_offset = Vector3(0,1,0)
	probe.box_projection = true
	probe.max_distance = 105
	probe.intensity = .7
	probe.cull_mask = 1
	probe.enable_shadows = false
	add_child(probe)
	for x in [-11.0,11.0]:
		for z in [-21.0,21.0,93.0,-93.0]:
			var light:=OmniLight3D.new()
			light.position=Vector3(x,2.8,z)
			light.light_color=Color("ffc485")
			light.light_energy=1.3
			light.omni_range=9
			light.visible=false
			add_child(light)
			shop_lights.append(light)
	for child in get_children():
		if child is GeometryInstance3D: child.visibility_range_end = 260

func tower(data: Vector3) -> void:
	var p := Vector3(data.x,.2,data.z)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/facade.gdshader")
	mat.set_shader_parameter("masonry",Color("53616b"))
	mat.set_shader_parameter("style",1.0)
	city.facades.append(mat)
	for i in 3:
		var width: float = 30-i*5
		var h: float = data.y/3
		var block := Geo.box(self,p+Vector3(0,h*(i+.5),0),Vector3(width,h,width),Color.WHITE,true)
		block.material_override = mat
		for side in [-1,1]:
			Geo.box(self,p+Vector3(side*(width/2+.06),h*(i+.5),0),Vector3(.18,h,width),Color("59666c"))
		Geo.box(self,p+Vector3(0,h*(i+1),0),Vector3(width+.5,.35,width+.5),Color("899297"))
	Geo.cylinder(self,p+Vector3(0,data.y+5,0),.10,10,Color("808d95"))
	var crown := Geo.box(self,p+Vector3(0,data.y+.5,0),Vector3(18,.12,18),Color("38b8c8"))
	crown.material_override.emission_enabled = true
	crown.material_override.emission = Color("279fae")
	signs.append(crown.material_override)

func palm(p: Vector3) -> void:
	var trunk := Geo.cylinder(self,p+Vector3(.2,4.8,0),.19,9.6,Color("695c4b"))
	trunk.mesh.top_radius = .11
	trunk.rotation.z = -.045
	for ring in range(1,18):
		Geo.cylinder(self,p+Vector3(.02*ring,ring*.5,0),.195-ring*.003,.045,Color("4f493e"))
	var material := Geo.material(Color("354b35"))
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 9:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var angle := k*TAU/9
		for j in 8:
			var t: float = j/8.0
			var u: float = (j+1)/8.0
			var a := Vector3(t*4.5,9.7+sin(t*PI)*1.1-t*1.4,0)
			var b := Vector3(u*4.5,9.7+sin(u*PI)*1.1-u*1.4,0)
			var wa: float = sin(t*PI)*.42+.025
			var wb: float = sin(u*PI)*.42+.025
			for v in [a+Vector3(0,0,-wa),b+Vector3(0,0,-wb),a+Vector3(0,0,wa),a+Vector3(0,0,wa),b+Vector3(0,0,-wb),b+Vector3(0,0,wb)]:
				st.add_vertex(p+v.rotated(Vector3.UP,angle))
		st.generate_normals()
		var frond := MeshInstance3D.new()
		frond.mesh = st.commit()
		frond.material_override = material
		add_child(frond)

func parked_car(p: Vector3, yaw: float, color: Color) -> void:
	var car := Node3D.new()
	add_child(car)
	car.position=p
	car.rotation.y=yaw
	var paint := Body.finish(color,.45,.24)
	paint.cull_mode=BaseMaterial3D.CULL_DISABLED
	Body.loft(car,[Vector4(-2,.76,.38,.72),Vector4(-1.3,.94,.35,.92),Vector4(1.4,.94,.35,.9),Vector4(2,.83,.38,.78)],paint)
	var glass := Body.finish(Color("182a34"),.3,.12)
	glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	Body.loft(car,[Vector4(-.85,.8,.9,.96),Vector4(-.3,.68,.94,1.47),Vector4(.6,.68,.94,1.47),Vector4(1.25,.8,.9,.96)],glass)
	Geo.box(car,Vector3(.0,1.47,.15),Vector3(1.38,.06,.95),color).material_override=paint
	for x in [-.94,.94]:
		for z in [-1.25,1.25]:
			var wheel:=Geo.cylinder(car,Vector3(x,.4,z),.4,.22,Color("11171b"))
			wheel.rotation.z=PI/2
			var hub:=Geo.cylinder(car,Vector3(x*1.12,.4,z),.23,.02,Color("879196"))
			hub.rotation.z=PI/2
	for side in [-1,1]:
		Geo.box(car,Vector3(side*.62,.67,2.01),Vector3(.43,.12,.03),Color("86292a"))
		Geo.box(car,Vector3(side*.62,.67,-2.01),Vector3(.43,.10,.03),Color("b6bfbc"))
	var body:=StaticBody3D.new()
	var shape:=CollisionShape3D.new()
	var bounds:=BoxShape3D.new()
	bounds.size=Vector3(1.9,1.5,4)
	shape.shape=bounds
	shape.position.y=.75
	body.add_child(shape)
	car.add_child(body)
	for child in car.get_children():
		if child is GeometryInstance3D: child.visibility_range_end=145

func set_night(value: bool) -> void:
	evening=value
	for mat in signs: mat.emission_energy_multiplier=1.6 if value else .12
	# Recreate once when lighting changes; never capture six faces every frame.
	if is_instance_valid(probe):
		probe.update_mode=ReflectionProbe.UPDATE_ONCE
		probe.visible=false
		probe.visible=true
	update_lights()

func update_lights() -> void:
	for light in shop_lights:
		light.visible=evening and (city.player==null or light.global_position.distance_squared_to(city.player.global_position)<4900)

func _process(delta: float) -> void:
	tick-=delta
	if tick<=0:
		tick=.5
		update_lights()

static func storefront(city_node: Node3D, p: Vector3, h: float, tint: Color) -> void:
	if maxf(absf(p.x),absf(p.z))>235: return
	var kind: int=absi(int(p.x*3+p.z))%3
	var root := Node3D.new()
	root.name="Business_%d_%d" % [int(p.x),int(p.z)]
	city_node.add_child(root)
	root.position=p
	# Fronts oriented toward the nearest street, two per corner building.
	for angle in [0.0,PI/2,PI,PI*1.5]:
		var face:=Node3D.new()
		root.add_child(face)
		face.rotation.y=angle
		var display:=MeshInstance3D.new();var glass:=QuadMesh.new();glass.size=Vector2(16.8,2.35);display.mesh=glass
		display.material_override=shop_material(kind,city_node);display.position=Vector3(0,1.54,9.81);face.add_child(display)
		var canopy:=Geo.box(face,Vector3(0,2.93,10.15),Vector3(17.5,.13,1.1),tint.darkened(.25))
		canopy.rotation.x=-.1
		Geo.box(face,Vector3(0,2.85,10.7),Vector3(17.5,.2,.06),tint)
		Geo.box(face,Vector3(0,1.35,9.87),Vector3(1.4,2.35,.07),Color("263c41"))
		Geo.box(face,Vector3(.45,1.25,9.94),Vector3(.05,.32,.05),Color("d0c6a2"))
		var open_sign:=Label3D.new();open_sign.text="OPEN";open_sign.font_size=48;open_sign.pixel_size=.01;open_sign.position=Vector3(5.8,2.2,9.89);open_sign.modulate=Color("91f2cf");face.add_child(open_sign)
		var fascia:=Geo.box(face,Vector3(0,3.68,9.72),Vector3(17,.7,.22),tint)
		fascia.material_override.roughness=.6
		for x in [-6,-3,0,3,6]:
			Geo.box(face,Vector3(x,1.6,9.58),Vector3(.075,2.6,.12),Color("9b9b8c"))
		Geo.box(face,Vector3(0,.32,9.65),Vector3(17,.14,.25),Color("b9b1a0"))
		Geo.box(face,Vector3(0,2.65,9.65),Vector3(17,.07,.18),Color("7d817b"))
		# Window decals and display strips suggest interior furnishings at street level.
		for x in [-6,0,6]:
			var panel:=Geo.box(face,Vector3(x,1.55,9.56),Vector3(4.6,1.95,.035),Color("39494b"))
			panel.material_override.emission_enabled=true
			panel.material_override.emission=Color("8c6942")
			panel.material_override.emission_energy_multiplier=.1
			city_node.shop_materials.append(panel.material_override)
			for row in [1.0,1.8]:
				Geo.box(face,Vector3(x,row,9.60),Vector3(4.3,.05,.035),Color("a09578"))
			for k in [-1,0,1]:
				Geo.box(face,Vector3(x+k*1.1,1.30,9.62),Vector3(.5,.48,.05),tint.lightened(.17))
		var label:=Label3D.new()
		label.text=["NORTH COFFEE","GROVE MARKET","STREET MOTORS"][kind]
		label.font_size=64
		label.pixel_size=.013
		label.position=Vector3(0,3.68,9.86)
		label.modulate=Color("f2dec0")
		label.outline_size=0
		face.add_child(label)
		# A vertical neon blade sign makes streets readable from a moving car.
		if angle==0.0:
			Geo.box(face,Vector3(7.7,5.6,10.3),Vector3(.18,3.3,1.1),tint)
			var sign:=Geo.box(face,Vector3(7.81,5.6,10.3),Vector3(.03,2.7,.72),tint.lightened(.35))
			sign.material_override.emission_enabled=true
			sign.material_override.emission=tint.lightened(.3)
			sign.material_override.emission_energy_multiplier=1.8
		# Floor ledges and fire-escape rails add physical depth to flat facades.
		if absi(int(p.x+p.z))%3==0:
			for y in range(5,int(h)-1,4):
				Geo.box(face,Vector3(2,y,10.0),Vector3(5,.12,1.1),Color("3b4244"))
				Geo.box(face,Vector3(2,y+.85,10.48),Vector3(5,.055,.055),Color("434c50"))
				for x in [0,1,2,3,4]: Geo.box(face,Vector3(x,y+.43,10.48),Vector3(.04,.85,.04),Color("434c50"))
	for face in root.get_children():
		for child in face.get_children():
			if child is GeometryInstance3D: child.visibility_range_end=175
