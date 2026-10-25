extends RefCounted
## Shared primitive builder. All artwork is generated locally; no asset downloads.

static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	return mat

static func surface(color: Color, kind: float = 0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/surface.gdshader")
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("kind", kind)
	mat.set_shader_parameter("road_tex", preload("res://textures/asphalt-albedo.png"))
	mat.set_shader_parameter("normal_tex", preload("res://textures/asphalt-normal.png"))
	mat.set_shader_parameter("concrete_tex", preload("res://textures/concrete.png"))
	return mat

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = pos
	return node

static func ellipsoid(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 16
	mesh.rings = 8
	node.mesh = mesh
	node.scale = size
	node.material_override = material(color)
	parent.add_child(node)
	node.position = pos

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	parent.add_child(mesh)
	mesh.position = pos
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collision.shape = bounds
		body.add_child(collision)
		mesh.add_child(body)
	return mesh
