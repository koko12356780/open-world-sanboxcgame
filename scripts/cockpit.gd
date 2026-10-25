extends Node3D
## Interior on layer 2, shared world on layer 1. Mirrors never see themselves.
const Geo = preload("res://scripts/geometry.gd")
const Display = preload("res://scripts/dashboard_display.gd")
var car: CharacterBody3D
var driver_camera: Camera3D
var wheel_pivot: Node3D
var hood: MeshInstance3D
var gauge_display: Node2D
var gauge_view: SubViewport
var radio_view: SubViewport
var mirror_views: Array[SubViewport] = []
var mirror_cameras: Array[Camera3D] = []
var mirror_offsets: Array[Vector3] = []
var hand_nodes: Array[Node3D] = []
var forearms: Array[MeshInstance3D] = []
var leather: ShaderMaterial
var active: bool = false
var cabin_light: OmniLight3D

func _ready() -> void:
	leather = ShaderMaterial.new()
	leather.shader = preload("res://shaders/interior.gdshader")
	leather.set_shader_parameter("leather",Color("171c1e"))
	# Wide, sloped dashboard, instrument hood and passenger glove compartment.
	trim(Vector3(0,0.91,-1.15),Vector3(2.25,0.29,0.72))
	var dash_top := trim(Vector3(0,1.08,-1.25),Vector3(2.25,0.12,0.63))
	dash_top.rotation.x = deg_to_rad(-9)
	trim(Vector3(-0.33,1.225,-0.91),Vector3(0.81,0.055,0.26))
	trim(Vector3(-0.33,0.98,-0.80),Vector3(0.82,0.36,0.09))
	trim(Vector3(0.72,0.92,-1.0),Vector3(0.76,0.23,0.07))
	Geo.box(self,Vector3(0.72,0.92,-0.955),Vector3(0.54,0.01,0.012),Color("515858"))
	Geo.box(self,Vector3(0.72,0.94,-0.944),Vector3(0.12,0.025,0.015),Color("747975"))
	gauge_view = display_view(false,Vector3(-0.33,1.015,-0.735),Vector2(0.73,0.33))
	gauge_display = gauge_view.get_child(0)
	radio_view = display_view(true,Vector3(0.38,0.91,-0.755),Vector2(0.43,0.23))
	# Vent slats, hazard button and lower centre console.
	for x in [-0.89,0.25,0.53,0.98]: vent(Vector3(x,1.11,-0.92))
	trim(Vector3(0.39,0.64,-0.83),Vector3(0.51,0.44,0.36))
	Geo.box(self,Vector3(0.39,1.10,-0.891),Vector3(0.065,0.055,0.025),Color("973c32"))
	for x in [0.24,0.39,0.54]:
		var dial := Geo.cylinder(self,Vector3(x,0.72,-0.63),0.041,0.03,Color("555e61"))
		dial.rotation.x = PI/2
	Geo.ellipsoid(self,Vector3(0.39,0.57,-0.45),Vector3(0.10,0.06,0.10),Color("20272a"))
	beam(self,Vector3(0.39,0.51,-0.45),Vector3(0.39,0.69,-0.44),0.014,Color("747b7e"))
	Geo.ellipsoid(self,Vector3(0.39,0.70,-0.44),Vector3(0.055,0.04,0.055),Color("242a2d"))
	# Windshield pillars slope back towards the roof, leaving the view ahead open.
	for side in [-1,1]:
		var x: float = side*1.08
		beam(self,Vector3(x,1.05,-1.43),Vector3(x,1.90,-0.63),0.078,Color("13191c"))
		trim(Vector3(x,0.82,-0.15),Vector3(0.13,0.29,1.8))
		trim(Vector3(x,1.00,-0.18),Vector3(0.16,0.07,1.8))
		Geo.box(self,Vector3(x-side*0.08,0.86,-0.2),Vector3(0.025,0.06,0.27),Color("71797c"))
	trim(Vector3(0,1.91,-0.35),Vector3(2.3,0.15,1.0))
	trim(Vector3(0,1.86,-0.68),Vector3(2.25,0.10,0.15))
	# Painted hood and resting windshield wipers.
	hood = Geo.box(self,Vector3(0,0.94,-1.90),Vector3(1.9,0.08,0.85),car.paint)
	hood.material_override.metallic = 0.55
	hood.material_override.roughness = 0.3
	for x in [-0.47,0.42]:
		beam(self,Vector3(x-0.27,1.015,-1.57),Vector3(x+0.27,1.015,-1.62),0.009,Color("101719"))
	build_wheel()
	# A rear-view mirror and a driver's side mirror, both with live rear-facing cameras.
	mirror(Vector3(0.63,1.64,-0.86),Vector2(0.57,0.16),Vector3(0,1.45,1.9),Vector2i(320,96))
	mirror(Vector3(-1.13,1.19,-0.83),Vector2(0.25,0.19),Vector3(-1.02,1.26,0.2),Vector2i(192,144))
	cabin_light = OmniLight3D.new()
	cabin_light.position = Vector3(-0.33,1.56,0.10)
	cabin_light.light_color = Color("b8c8d9")
	cabin_light.light_energy = 0.8
	cabin_light.omni_range = 3.5
	cabin_light.light_cull_mask = 2
	add_child(cabin_light)
	set_layers(self)
	set_active(false)

func trim(pos: Vector3, size: Vector3) -> MeshInstance3D:
	var mesh := Geo.box(self,pos,size,Color.WHITE)
	mesh.material_override = leather
	return mesh

func vent(pos: Vector3) -> void:
	Geo.box(self,pos,Vector3(0.20,0.085,0.035),Color("080e11"))
	for i in 5:
		Geo.box(self,pos+Vector3(0,(i-2)*0.014,0.021),Vector3(0.18,0.004,0.008),Color("616a6c"))

func beam(parent: Node3D, start: Vector3, end: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = maxf(start.distance_to(end),radius*2.01)
	capsule.radial_segments = 16
	capsule.rings = 4
	mesh.mesh = capsule
	mesh.material_override = Geo.material(color)
	parent.add_child(mesh)
	align_beam(mesh,start,end)
	return mesh

func align_beam(mesh: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	mesh.position = (start+end)/2
	mesh.quaternion = Quaternion(Vector3.UP,(end-start).normalized())
	mesh.mesh.height = maxf(start.distance_to(end),mesh.mesh.radius*2.01)

func display_view(is_radio: bool, pos: Vector3, size: Vector2) -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(512,256)
	view.disable_3d = true
	view.gui_disable_input = true
	add_child(view)
	var drawing := Display.new()
	drawing.car = car
	drawing.radio = is_radio
	view.add_child(drawing)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = view.get_texture()
	quad(pos,size,mat)
	return view

func quad(pos: Vector3, size: Vector2, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = size
	mesh.mesh = plane
	mesh.material_override = mat
	add_child(mesh)
	mesh.position = pos
	return mesh

func mirror(pos: Vector3, size: Vector2, offset: Vector3, resolution: Vector2i) -> void:
	Geo.box(self,pos-Vector3(0,0,0.015),Vector3(size.x+0.045,size.y+0.045,0.05),Color("171e21"))
	var view := SubViewport.new()
	view.size = resolution
	view.world_3d = car.get_world_3d()
	view.gui_disable_input = true
	add_child(view)
	var camera := Camera3D.new()
	camera.fov = 65
	camera.far = 240
	camera.cull_mask = 1
	view.add_child(camera)
	camera.current = true
	mirror_views.append(view)
	mirror_cameras.append(camera)
	mirror_offsets.append(offset)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/mirror.gdshader")
	material.set_shader_parameter("view_texture",view.get_texture())
	quad(pos+Vector3(0,0,0.018),size,material)

func build_wheel() -> void:
	wheel_pivot = Node3D.new()
	wheel_pivot.position = Vector3(-0.33,1.04,-0.42)
	add_child(wheel_pivot)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.218
	torus.outer_radius = 0.252
	torus.rings = 64
	torus.ring_segments = 12
	ring.mesh = torus
	ring.material_override = leather
	ring.rotation.x = PI/2
	wheel_pivot.add_child(ring)
	for angle in [0.0,PI,-PI/2]:
		var end := Vector3(cos(angle)*0.224,sin(angle)*0.224,0)
		beam(wheel_pivot,Vector3.ZERO,end,0.022,Color("1a2024"))
	Geo.ellipsoid(wheel_pivot,Vector3(0,0,0.01),Vector3(0.22,0.13,0.06),Color("242c31"))
	var emblem := Label3D.new()
	emblem.text = "S"
	emblem.position = Vector3(0,0,0.055)
	emblem.font_size = 60
	emblem.pixel_size = 0.0008
	wheel_pivot.add_child(emblem)
	for side in [-1,1]:
		var hand := Node3D.new()
		hand.position = Vector3(side*0.231,0.045,0.028)
		wheel_pivot.add_child(hand)
		hand_nodes.append(hand)
		var skin := Color("b17c5e")
		Geo.ellipsoid(hand,Vector3.ZERO,Vector3(0.052,0.075,0.033),skin)
		for finger in 4:
			var y := -0.029+finger*0.018
			beam(hand,Vector3(side*0.014,y,0.020),Vector3(-side*0.031,y,0.003),0.010,skin)
			beam(hand,Vector3(-side*0.031,y,0.003),Vector3(-side*0.034,y,-0.024),0.009,skin)
		beam(hand,Vector3(-side*0.01,-0.04,0.028),Vector3(-side*0.064,-0.012,0.016),0.015,skin)
		var forearm := beam(self,Vector3(-0.33+side*0.36,0.48,0.09),Vector3(-0.33+side*0.24,0.96,-0.39),0.042,skin)
		forearms.append(forearm)

func set_layers(node: Node) -> void:
	if node is GeometryInstance3D:
		node.layers = 2
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children(): set_layers(child)

func set_active(enabled: bool) -> void:
	active = enabled
	visible = enabled
	if cabin_light != null: cabin_light.visible = enabled
	for view in mirror_views + [gauge_view,radio_view]:
		if view != null: view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
	if enabled: update_pose(1.0)

func _physics_process(delta: float) -> void:
	if not active: return
	update_pose(delta)

func update_pose(delta: float) -> void:
	wheel_pivot.rotation.z = lerp_angle(wheel_pivot.rotation.z,car.steering*0.9,1-exp(-12*delta))
	hood.material_override.albedo_color = car.paint
	cabin_light.light_energy = 0.75 if car.night else 0.25
	for i in mirror_cameras.size():
		mirror_cameras[i].global_transform = car.global_transform*Transform3D(Basis(Vector3.UP,PI),mirror_offsets[i])
	for i in forearms.size():
		var side := -1 if i == 0 else 1
		var elbow := Vector3(-0.33+side*0.36,0.48,0.09)
		var wrist := to_local(hand_nodes[i].global_position)-Vector3(0,0.035,-0.01)
		align_beam(forearms[i],elbow,wrist)
