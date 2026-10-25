extends RefCounted
const Geo = preload("res://scripts/geometry.gd")
static func build(city: Node3D) -> void:
	var root := Node3D.new()
	root.name = "StreetDetails"
	city.add_child(root)
	for x in [-144,0,144]:
		for z in [-180,-108,-36,36,108,180]:
			var p := Vector3(x+9.5,0,z)
			# Bins, short bollards and drainage grilles along central pavements.
			Geo.cylinder(root,p+Vector3(0,0.48,0),0.26,0.96,Color("263b3c"))
			Geo.cylinder(root,p+Vector3(0,0.98,0),0.29,0.07,Color("111b22"))
			for dz in [-3,3]:
				Geo.cylinder(root,p+Vector3(-1.3,0.5,dz),0.07,0.8,Color("29333b"))
				Geo.cylinder(root,p+Vector3(-1.3,0.83,dz),0.08,0.07,Color("b7b6a1"))
			for k in 6: Geo.box(root,p+Vector3(-1.9,0.09,5+k*0.09),Vector3(0.65,0.025,0.035),Color("39434a"))
			var cover := Geo.cylinder(root,Vector3(x+3.5,0.069,z),0.45,0.012,Color("323a3d"))
			cover.mesh.radial_segments = 24
			for k in [-0.18,0,0.18]: Geo.box(root,Vector3(x+3.5+k,0.077,z),Vector3(0.02,0.005,0.5),Color("50575a"))
	for z in [-180,36,180]:
		var p := Vector3(11,0.2,z)
		Geo.box(root,p+Vector3(0,2.55,0),Vector3(2.8,0.15,5.6),Color("263c48"))
		for dz in [-2.5,2.5]:
			Geo.box(root,p+Vector3(1.1,1.3,dz),Vector3(0.09,2.6,0.09),Color("aab4b8"))
		var glass := Geo.box(root,p+Vector3(1.2,1.35,0),Vector3(0.04,2.15,4.9),Color("47616b"))
		glass.material_override.metallic = 0.4
		glass.material_override.roughness = 0.2
		Geo.box(root,p+Vector3(0.5,0.65,0),Vector3(0.65,0.12,3.8),Color("744d34"))
		Geo.box(root,p+Vector3(-1.1,1.6,-3.3),Vector3(0.08,3.2,0.08),Color("a6b0b4"))
		Geo.box(root,p+Vector3(-1.1,3.15,-3.3),Vector3(0.9,0.7,0.08),Color("3376a2"))
		var sign := Label3D.new()
		sign.text = "BUS"
		sign.font_size = 40
		sign.pixel_size = 0.012
		sign.position = p+Vector3(-1.1,3.15,-3.24)
		root.add_child(sign)
	for x in [-144,0,144]:
		for z in [-144,0,144]:
			for side in [-1,1]:
				var p := Vector3(x+side*8.6,0,z+side*8.6)
				Geo.cylinder(root,p+Vector3.UP*1.7,0.06,3.4,Color("263139"))
				Geo.box(root,p+Vector3(0,3.1,0),Vector3(0.42,1.2,0.32),Color("10171d"))
				for light in 3:
					var color: Color = [Color("e54845"),Color("e3a443"),Color("6bdba4")][light]
					var lamp := Geo.cylinder(root,p+Vector3(0,3.48-light*0.36,0.18),0.13,0.035,color)
					lamp.rotation.x = PI/2
					lamp.material_override.emission_enabled = true
					lamp.material_override.emission = color
					lamp.material_override.emission_energy_multiplier = 1.4 if light == (2 if side==1 else 0) else 0.04
	for child in root.get_children():
		if child is GeometryInstance3D: child.visibility_range_end = 155
