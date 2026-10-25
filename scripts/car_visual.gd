extends RefCounted
const Geo = preload("res://scripts/geometry.gd")

static func finish(color: Color, metal: float, rough: float) -> StandardMaterial3D:
	var mat := Geo.material(color)
	mat.metallic = metal
	mat.roughness = rough
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.7
	mat.clearcoat_roughness = 0.15
	return mat

# Eight-point sections produce bevelled shoulders and a sloped hood/windshield.
static func loft(parent: Node3D, sections: Array[Vector4], mat: Material) -> MeshInstance3D:
	var rings: Array[PackedVector3Array] = []
	for s in sections:
		var bevel := minf(0.13, (s.w-s.z)*0.3)
		rings.append(PackedVector3Array([
			Vector3(-s.y+bevel,s.z,s.x),Vector3(s.y-bevel,s.z,s.x),
			Vector3(s.y,s.z+bevel,s.x),Vector3(s.y,s.w-bevel,s.x),
			Vector3(s.y-bevel,s.w,s.x),Vector3(-s.y+bevel,s.w,s.x),
			Vector3(-s.y,s.w-bevel,s.x),Vector3(-s.y,s.z+bevel,s.x)]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(rings.size()-1):
		for j in 8:
			var k := (j+1)%8
			for v in [rings[i][j],rings[i+1][j],rings[i][k],rings[i][k],rings[i+1][j],rings[i+1][k]]:
				st.add_vertex(v)
	for end in [0,rings.size()-1]:
		for j in range(1,7):
			var tri := [rings[end][0],rings[end][j],rings[end][j+1]]
			if end == 0: tri.reverse()
			for v in tri: st.add_vertex(v)
	st.index()
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh

static func build(car: CharacterBody3D, parent: Node3D) -> void:
	var paint := finish(car.paint.darkened(.15),0.60,0.23)
	var glass := finish(Color("172630"),0.5,0.15)
	if car.model_index == 1:
		# GT: rear wing and wider splitter.
		Geo.box(parent,Vector3(0,1.13,1.83),Vector3(2.1,0.08,0.4),car.paint)
		for side in [-1,1]:
			Geo.box(parent,Vector3(side*0.65,0.98,1.83),Vector3(0.06,0.25,0.13),Color("22272b"))
		Geo.box(parent,Vector3(0,0.40,-2.13),Vector3(2.05,0.10,0.25),Color("1d2124"))
	elif car.model_index == 2:
		# Rally: roof rack, hood scoop and auxiliary rally lamps.
		Geo.box(parent,Vector3(0,1.69,0.15),Vector3(1.45,0.10,1.05),Color("252c2b"))
		Geo.box(parent,Vector3(0,1.02,-1.4),Vector3(0.65,0.16,0.4),Color("202c28"))
		for x in [-0.5,0,0.5]:
			var rally_lamp := Geo.cylinder(parent,Vector3(x,0.82,-2.18),0.18,0.10,Color("eee3bc"))
			rally_lamp.rotation.x = PI/2
	elif car.model_index == 3:
		Geo.box(parent,Vector3(0,1.05,1.94),Vector3(2.25,0.07,0.42),Color("151c23"))
		for side in [-1,1]:
			Geo.box(parent,Vector3(side*0.72,0.86,1.94),Vector3(0.06,0.36,0.17),Color("151c23"))
			Geo.box(parent,Vector3(side*1.05,0.67,0.48),Vector3(0.035,0.30,0.75),Color("101a20"))
			Geo.box(parent,Vector3(side*0.74,0.66,-2.22),Vector3(0.50,0.055,0.04),Color("d9f5ff"))
		Geo.box(parent,Vector3(0,0.33,-2.25),Vector3(2.15,0.07,0.24),Color("10181e"))
	elif car.model_index == 4:
		Geo.box(parent,Vector3(0,0.60,-2.12),Vector3(1.4,0.045,0.05),Color("c5ecff"))
		for x in [-0.72,0.72]:
			var nozzle := Geo.cylinder(parent,Vector3(x,0.28,1.3),0.20,0.16,Color("1c252b"))
			var glow := Geo.cylinder(parent,Vector3(x,0.19,1.3),0.14,0.025,Color("65dfff"))
			glow.material_override.emission_enabled = true
			glow.material_override.emission = Color("2ac7ff")
			nozzle.name = "FlightThruster"
	# Double-sided material keeps custom geometry visible on both face windings.
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shell: MeshInstance3D
	if car.model_index == 3:
		shell = loft(parent,[Vector4(-2.3,0.80,0.30,0.65),Vector4(-1.6,1.05,0.30,0.82),Vector4(-0.7,1.07,0.3,0.90),Vector4(1.35,1.07,0.3,0.87),Vector4(2.22,0.91,0.32,0.74)],paint)
	elif car.model_index == 4:
		shell = loft(parent,[Vector4(-2.15,0.78,0.31,0.67),Vector4(-1.4,0.99,0.30,0.87),Vector4(-0.8,1.02,0.30,0.93),Vector4(1.35,1.01,0.3,0.89),Vector4(2.1,0.9,0.32,0.76)],paint)
	else:
		shell = loft(parent,[Vector4(-2.12,0.78,0.43,0.75),Vector4(-1.65,0.96,0.40,0.92),Vector4(-0.9,0.97,0.40,1.0),Vector4(1.3,0.97,0.40,0.98),Vector4(2.10,0.86,0.44,0.85)],paint)
	shell.name = "BodyShell"
	var roof_height: float = [1.58,1.43,1.72,1.25,1.30][car.model_index]
	var rear_pillar: float = [0.65,0.45,1.0,0.55,0.70][car.model_index]
	loft(parent,[Vector4(-1.0,0.81,0.94,1.01),Vector4(-0.35,0.72,0.98,roof_height),Vector4(rear_pillar,0.72,0.98,roof_height),Vector4(1.35,0.81,0.94,1.0)],glass)
	loft(parent,[Vector4(-0.38,0.73,roof_height-0.06,roof_height+0.02),Vector4(rear_pillar+0.03,0.73,roof_height-0.06,roof_height+0.02)],paint)
	# Window pillars, mirrors, door handles, rocker panels and rear diffuser.
	for side in [-1,1]:
		var pillar := Geo.box(parent,Vector3(side*0.76,(roof_height+0.98)/2,0.27),Vector3(0.07,roof_height-0.98,0.09),car.paint)
		pillar.material_override = paint
		Geo.ellipsoid(parent,Vector3(side*1.04,1.04,-0.72),Vector3(0.23,0.10,0.14),car.paint)
		Geo.box(parent,Vector3(side*0.975,0.84,0.45),Vector3(0.025,0.045,0.20),Color("72777b"))
		Geo.box(parent,Vector3(side*0.97,0.39,0),Vector3(0.09,0.12,3.4),Color("1f2225"))
		Geo.box(parent,Vector3(side*0.65,0.73,-2.07),Vector3(0.43,0.09,0.04),Color("e7ece5"))
		var lamp := Geo.box(parent,Vector3(side*0.61,0.76,2.08),Vector3(0.48,0.065,0.045),Color("b2121c"))
		car.tail_lamps.append(lamp)
		lamp.material_override.emission_enabled = true
		lamp.material_override.emission = Color("aa1015")
		if car.model_index != 4:
			var exhaust := Geo.cylinder(parent,Vector3(side*0.64,0.43,2.10),0.085,0.16,Color("6c7175"))
			exhaust.name = "ExhaustTipLeft" if side < 0 else "ExhaustTipRight"
			exhaust.rotation.x = PI/2
	Geo.box(parent,Vector3(0,0.43,2.10),Vector3(1.6,0.13,0.08),Color("16191d"))
	Geo.box(parent,Vector3(0,0.67,2.12),Vector3(0.42,0.16,0.02),Color("dbded5"))
	var plate := Label3D.new()
	plate.text = "STREETS"
	plate.font_size = 40
	plate.pixel_size = 0.0018
	plate.modulate = Color("1c252e")
	plate.position = Vector3(0,0.67,2.135)
	parent.add_child(plate)
	for x in [-0.98,0.98]:
		for z in [-1.32,1.32]:
			var pivot := Node3D.new()
			parent.add_child(pivot)
			pivot.position = Vector3(x,0.42,z)
			if z<0: car.front_wheels.append(pivot)
			var spinning := Node3D.new()
			pivot.add_child(spinning)
			var tire := Geo.cylinder(spinning,Vector3.ZERO,0.42,0.25,Color("141516"))
			tire.mesh.radial_segments = 32
			tire.rotation.z = PI/2
			car.wheels.append(spinning)
			var rim := Geo.cylinder(spinning,Vector3(signf(x)*0.135,0,0),0.29,0.015,Color("373d43"))
			rim.material_override = finish(Color("485158"),.85,.2)
			rim.rotation.z = PI/2
			var disc := Geo.cylinder(spinning,Vector3(signf(x)*0.11,0,0),0.25,0.035,Color("8a8e91"))
			disc.rotation.z = PI/2
			Geo.box(pivot,Vector3(signf(x)*0.14,0.1,0.18),Vector3(0.055,0.18,0.12),Color("d14536"))
			for groove in [-0.07,0,0.07]:
				var tread := Geo.cylinder(spinning,Vector3(groove,0,0),0.422,0.013,Color("080c0e"))
				tread.rotation.z = PI/2
			for j in 5:
				var angle := j*TAU/5
				var spoke := Geo.box(spinning,Vector3(signf(x)*0.15,sin(angle)*0.14,cos(angle)*0.14),Vector3(0.02,0.06,0.28),Color("a9afb3"))
				spoke.rotation.x = -angle
				spoke.material_override = finish(Color("8f999f"),.8,.24)
	# Panel seams, gasket trim, badge, bumper strips and rear lamp lenses.
	for side in [-1,1]:
		for z in [-.74,.91]:
			Geo.box(parent,Vector3(side*.978,.72,z),Vector3(.009,.42,.012),Color("352f2c"))
		Geo.box(parent,Vector3(side*.82,.985,.18),Vector3(.025,.018,1.9),Color("101a20"))
		Geo.box(parent,Vector3(side*.65,.76,2.109),Vector3(.44,.014,.006),Color("f06c60"))
	Geo.box(parent,Vector3(0,.85,2.107),Vector3(.13,.07,.012),Color("aeb8bb"))
	Geo.box(parent,Vector3(0,.51,2.13),Vector3(1.73,.045,.04),Color("242c31"))
