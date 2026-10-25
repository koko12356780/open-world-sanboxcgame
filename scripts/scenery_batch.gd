extends RefCounted
## Group matching stationary meshes by city block, retaining all collision bodies.
## Emissive/animated fixtures, shaders, labels and foliage stay independent.
static func build(city: Node3D) -> void:
	var groups: Dictionary = {}
	collect(city,city,groups)
	var container:=Node3D.new()
	container.name="BatchedScenery"
	city.add_child(container)
	var saved: int=0
	for key in groups:
		var sources: Array=groups[key]
		if sources.size()<3: continue
		var first: MeshInstance3D=sources[0]
		var batch:=MultiMesh.new()
		batch.transform_format=MultiMesh.TRANSFORM_3D
		batch.mesh=first.mesh
		batch.instance_count=sources.size()
		for i in sources.size():
			batch.set_instance_transform(i,city.global_transform.affine_inverse()*sources[i].global_transform)
			sources[i].visible=false
		var node:=MultiMeshInstance3D.new()
		node.multimesh=batch
		node.material_override=first.material_override
		node.visibility_range_end=220
		container.add_child(node)
		saved+=sources.size()-1
	print("CITYLIGHT: batched scenery removes %d individual draw submissions" % saved)

static func collect(node: Node, city: Node3D, groups: Dictionary) -> void:
	for child in node.get_children(): collect(child,city,groups)
	if not node is MeshInstance3D: return
	var mat: Material=node.material_override
	var material_key: String
	if mat is StandardMaterial3D:
		if mat.emission_enabled or mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED: return
		material_key="%s/%s/%s/%s" % [mat.albedo_color,mat.metallic,mat.roughness,mat.cull_mode]
	elif mat is ShaderMaterial:
		material_key=str(mat.get_rid())
	else: return
	var shape_key: String
	if node.mesh is BoxMesh:
		if node.mesh.size.length()>65: return
		shape_key="box"+str(node.mesh.size)
	elif node.mesh is CylinderMesh:
		shape_key="cylinder%s/%s/%s/%s" % [node.mesh.top_radius,node.mesh.bottom_radius,node.mesh.height,node.mesh.radial_segments]
	else: return
	var p: Vector3=node.global_position
	var key: String="%s/%s/%s/%s" % [int(floor(p.x/72)),int(floor(p.z/72)),shape_key,material_key]
	if not groups.has(key): groups[key]=[]
	groups[key].append(node)
