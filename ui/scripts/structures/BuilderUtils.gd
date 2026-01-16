# =============================================================================
# BuilderUtils.gd - UTILIDADES COMUNES PARA CONSTRUCCIÓN
# =============================================================================
# Funciones auxiliares compartidas entre todos los módulos de construcción.
# =============================================================================

extends Reference
class_name BuilderUtils

# --- MATERIALES ESTÁNDAR ---

static func get_wood_mat(shared_res: Dictionary) -> SpatialMaterial:
	var mat = shared_res.get("wood_mat")
	if mat:
		return mat
	var default_mat = SpatialMaterial.new()
	default_mat.albedo_color = Color(0.4, 0.25, 0.1)
	return default_mat

static func get_sign_mat(shared_res: Dictionary) -> SpatialMaterial:
	var mat = shared_res.get("sign_mat")
	if mat:
		return mat
	var default_mat = SpatialMaterial.new()
	default_mat.albedo_color = Color(0.8, 0.7, 0.5)
	return default_mat

# --- COLISIONES ---

static func add_collision_box(parent: Node, pos: Vector3, size: Vector3) -> void:
	"""Añade una caja de colisión estática a un nodo."""
	var sb = StaticBody.new()
	var cs = CollisionShape.new()
	var shape = BoxShape.new()
	shape.extents = size * 0.5
	cs.shape = shape
	sb.add_child(cs)
	sb.translation = pos
	parent.add_child(sb)

static func create_static_body_with_shapes(parent: Node, shapes_config: Array) -> StaticBody:
	"""Crea un StaticBody con múltiples CollisionShapes."""
	var sb = StaticBody.new()
	parent.add_child(sb)
	
	for cfg in shapes_config:
		var cs = CollisionShape.new()
		var shape = BoxShape.new()
		shape.extents = cfg.size * 0.5 if cfg.has("size") else cfg.extents
		cs.shape = shape
		cs.translation = cfg.pos
		sb.add_child(cs)
	
	return sb

# --- CREACIÓN DE MESHES ---

static func create_cube_mesh(size: Vector3, material: Material = null) -> MeshInstance:
	"""Crea un MeshInstance con un CubeMesh."""
	var mi = MeshInstance.new()
	mi.mesh = CubeMesh.new()
	mi.mesh.size = size
	if material:
		mi.material_override = material
	return mi

static func create_cylinder_mesh(top_r: float, bottom_r: float, height: float, material: Material = null) -> MeshInstance:
	"""Crea un MeshInstance con un CylinderMesh."""
	var mi = MeshInstance.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = top_r
	cyl.bottom_radius = bottom_r
	cyl.height = height
	mi.mesh = cyl
	if material:
		mi.material_override = material
	return mi

static func create_prism_mesh(size: Vector3, material: Material = null) -> MeshInstance:
	"""Crea un MeshInstance con un PrismMesh (techo triangular)."""
	var mi = MeshInstance.new()
	var prism = PrismMesh.new()
	prism.size = size
	mi.mesh = prism
	if material:
		mi.material_override = material
	return mi

static func create_sphere_mesh(radius: float, material: Material = null) -> MeshInstance:
	"""Crea un MeshInstance con un SphereMesh."""
	var mi = MeshInstance.new()
	var sphere = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mi.mesh = sphere
	if material:
		mi.material_override = mi
	return mi

# --- MATERIALES ESPECIALES ---

static func create_material(color: Color, metallic: float = 0.0, roughness: float = 0.5) -> SpatialMaterial:
	"""Crea un material con los parámetros especificados."""
	var mat = SpatialMaterial.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat

static func create_emissive_material(color: Color, emission: Color, energy: float = 1.0) -> SpatialMaterial:
	"""Crea un material emisivo (para luces, fuego, etc.)."""
	var mat = SpatialMaterial.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy = energy
	return mat

# --- MULTIMESH HELPERS ---

static func create_multimesh_instance(mesh: Mesh, transforms: Array, material: Material = null, cast_shadow: bool = false) -> MultiMeshInstance:
	"""Crea un MultiMeshInstance optimizado para múltiples instancias."""
	var mmi = MultiMeshInstance.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	
	mmi.multimesh = mm
	if material:
		mmi.material_override = material
	mmi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance.SHADOW_CASTING_SETTING_OFF
	
	return mmi
