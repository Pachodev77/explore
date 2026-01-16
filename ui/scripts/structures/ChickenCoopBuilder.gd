# =============================================================================
# ChickenCoopBuilder.gd - CONSTRUCTOR DEL GALLINERO
# =============================================================================
# Maneja la generación del gallinero con corral de malla.
# =============================================================================

extends Reference
class_name ChickenCoopBuilder

# =============================================================================
# CONFIGURACIÓN
# =============================================================================

const COOP_POSITION = Vector3(-18.0, 2.0, 18.0)
const COOP_ROTATION = 135.0  # grados

# =============================================================================
# API PÚBLICA
# =============================================================================

static func build(container: Node, shared_res: Dictionary) -> void:
	"""Construye el gallinero completo con corral."""
	var coop_node = Spatial.new()
	coop_node.translation = COOP_POSITION
	coop_node.rotation_degrees.y = COOP_ROTATION
	container.add_child(coop_node)
	
	var materials = _create_materials(shared_res)
	
	_build_posts(coop_node, materials)
	_build_house(coop_node, materials)
	_build_nests(coop_node, materials)
	_build_ramp(coop_node, materials)
	_build_run(coop_node, materials)
	_add_collision(coop_node)

# =============================================================================
# MATERIALES
# =============================================================================

static func _create_materials(shared_res: Dictionary) -> Dictionary:
	"""Crea los materiales del gallinero."""
	var mat_wood = BuilderUtils.get_wood_mat(shared_res)
	
	var mat_wood_light = SpatialMaterial.new()
	mat_wood_light.albedo_color = Color(0.6, 0.45, 0.3)
	
	var mat_roof = SpatialMaterial.new()
	mat_roof.albedo_color = Color(0.5, 0.2, 0.1)
	
	var mat_wire = SpatialMaterial.new()
	mat_wire.albedo_color = Color(0.4, 0.4, 0.45)
	mat_wire.metallic = 0.8
	mat_wire.roughness = 0.2
	
	return {
		"wood": mat_wood,
		"wood_light": mat_wood_light,
		"roof": mat_roof,
		"wire": mat_wire
	}

# =============================================================================
# COMPONENTES DEL GALLINERO
# =============================================================================

static func _build_posts(coop_node: Node, materials: Dictionary) -> void:
	"""Construye los postes de soporte."""
	var post_mesh = CubeMesh.new()
	post_mesh.size = Vector3(0.2, 1.5, 0.2)
	
	for px in [-1.4, 1.4]:
		for pz in [-1.2, 1.2]:
			var post = MeshInstance.new()
			post.mesh = post_mesh
			post.translation = Vector3(px, 0.75, pz)
			post.material_override = materials.wood
			coop_node.add_child(post)

static func _build_house(coop_node: Node, materials: Dictionary) -> void:
	"""Construye la casita del gallinero."""
	# Cuerpo
	var house_body = BuilderUtils.create_cube_mesh(Vector3(3.0, 2.0, 2.5), materials.wood_light)
	house_body.translation = Vector3(0, 2.5, 0)
	coop_node.add_child(house_body)
	
	# Techo
	var roof = BuilderUtils.create_prism_mesh(Vector3(3.5, 1.2, 3.0), materials.roof)
	roof.translation = Vector3(0, 4.1, 0)
	coop_node.add_child(roof)

static func _build_nests(coop_node: Node, materials: Dictionary) -> void:
	"""Construye los nidos laterales."""
	for side in [-1, 1]:
		# Caja del nido
		var nest = BuilderUtils.create_cube_mesh(Vector3(0.8, 0.8, 1.8), materials.wood)
		nest.translation = Vector3(side * 1.8, 2.2, 0)
		coop_node.add_child(nest)
		
		# Techo del nido
		var n_roof = BuilderUtils.create_cube_mesh(Vector3(1.0, 0.1, 2.0), materials.roof)
		n_roof.translation = Vector3(side * 1.9, 2.6, 0)
		n_roof.rotation_degrees.z = side * 20
		coop_node.add_child(n_roof)

static func _build_ramp(coop_node: Node, materials: Dictionary) -> void:
	"""Construye la rampa de acceso."""
	var ramp = BuilderUtils.create_cube_mesh(Vector3(1.2, 0.1, 2.5), materials.wood)
	ramp.translation = Vector3(0, 0.75, 2.0)
	ramp.rotation_degrees.x = 35
	coop_node.add_child(ramp)

static func _build_run(coop_node: Node, materials: Dictionary) -> void:
	"""Construye el corral de malla."""
	var run_structure = Spatial.new()
	run_structure.translation = Vector3(0, 0, -1.25)
	coop_node.add_child(run_structure)
	
	# Postes del corral
	var r_post_mesh = CubeMesh.new()
	r_post_mesh.size = Vector3(0.15, 2.0, 0.15)
	
	var r_posts = [
		Vector3(-3.0, 1.0, -6.0),
		Vector3(3.0, 1.0, -6.0),
		Vector3(-3.0, 1.0, 0),
		Vector3(3.0, 1.0, 0)
	]
	
	for rp in r_posts:
		var p = MeshInstance.new()
		p.mesh = r_post_mesh
		p.translation = rp
		p.material_override = materials.wood
		run_structure.add_child(p)
	
	# Malla de alambre (optimizado con menos instancias que el original)
	_build_wire_mesh(run_structure, materials.wire)

static func _build_wire_mesh(run_structure: Node, wire_mat: Material) -> void:
	"""Construye la malla de alambre del corral."""
	var wire_v = CubeMesh.new()
	wire_v.size = Vector3(0.02, 2.0, 0.02)
	
	# Alambres frontales y traseros
	for x in range(-30, 31, 4):
		for lz in [0.0, -6.0]:
			var w = MeshInstance.new()
			w.mesh = wire_v
			w.translation = Vector3(x * 0.1, 1.0, lz)
			w.material_override = wire_mat
			run_structure.add_child(w)
	
	# Alambres laterales
	for z in range(-60, 1, 4):
		for lx in [-3.0, 3.0]:
			var w = MeshInstance.new()
			w.mesh = wire_v
			w.translation = Vector3(lx, 1.0, z * 0.1)
			w.material_override = wire_mat
			run_structure.add_child(w)

static func _add_collision(coop_node: Node) -> void:
	"""Añade colisiones al gallinero."""
	var sb = StaticBody.new()
	coop_node.add_child(sb)
	
	# Colisión de la casita
	var cs_house = CollisionShape.new()
	var shape_house = BoxShape.new()
	shape_house.extents = Vector3(1.5, 1.0, 1.25)
	cs_house.shape = shape_house
	cs_house.translation = Vector3(0, 3.0, 0)
	sb.add_child(cs_house)
	
	# Colisiones del corral
	var run_col_pos = [
		{"pos": Vector3(-3.0, 1.0, -3.0), "size": Vector3(0.1, 2.0, 6.0)},
		{"pos": Vector3(3.0, 1.0, -3.0), "size": Vector3(0.1, 2.0, 6.0)},
		{"pos": Vector3(0, 1.0, -6.0), "size": Vector3(6.0, 2.0, 0.1)}
	]
	
	for col in run_col_pos:
		var cs = CollisionShape.new()
		var shape = BoxShape.new()
		shape.extents = col.size * 0.5
		cs.shape = shape
		cs.translation = col.pos
		sb.add_child(cs)
