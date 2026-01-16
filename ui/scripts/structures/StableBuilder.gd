# =============================================================================
# StableBuilder.gd - CONSTRUCTOR DEL ESTABLO
# =============================================================================
# Maneja la generación del establo para caballos y ganado.
# =============================================================================

extends Reference
class_name StableBuilder

# =============================================================================
# CONFIGURACIÓN
# =============================================================================

const STABLE_POSITION = Vector3(18.0, 2.0, 18.0)
const STABLE_ROTATION = 225.0  # grados

# =============================================================================
# API PÚBLICA
# =============================================================================

static func build(container: Node, shared_res: Dictionary) -> void:
	"""Construye el establo completo."""
	var stable_node = Spatial.new()
	stable_node.translation = STABLE_POSITION
	stable_node.rotation_degrees.y = STABLE_ROTATION
	container.add_child(stable_node)
	
	var wood_mat = BuilderUtils.get_wood_mat(shared_res)
	var mat_roof = BuilderUtils.create_material(Color(0.35, 0.2, 0.15), 0.0, 0.8)
	
	_build_posts(stable_node, wood_mat)
	_build_roof(stable_node, mat_roof)
	_build_rails(stable_node, wood_mat)
	_build_troughs(stable_node, wood_mat)
	_add_collision(stable_node)

# =============================================================================
# COMPONENTES DEL ESTABLO
# =============================================================================

static func _build_posts(stable_node: Node, wood_mat: Material) -> void:
	"""Construye los postes de soporte."""
	var post_mesh = CubeMesh.new()
	post_mesh.size = Vector3(0.5, 5, 0.5)
	
	var posts_pos = [
		Vector3(-5, 2.5, -4),
		Vector3(5, 2.5, -4),
		Vector3(-5, 2.5, 4),
		Vector3(5, 2.5, 4),
		Vector3(0, 2.5, -4)
	]
	
	for p_pos in posts_pos:
		var p = MeshInstance.new()
		p.mesh = post_mesh
		p.translation = p_pos
		p.material_override = wood_mat
		stable_node.add_child(p)

static func _build_roof(stable_node: Node, mat_roof: Material) -> void:
	"""Construye el techo del establo."""
	var roof = BuilderUtils.create_prism_mesh(Vector3(12, 3, 10), mat_roof)
	roof.translation = Vector3(0, 6.5, 0)
	stable_node.add_child(roof)

static func _build_rails(stable_node: Node, wood_mat: Material) -> void:
	"""Construye las barandillas laterales."""
	var rails_configs = [
		{"pos": Vector3(-5, 0.8, 0), "rot": 90, "size": Vector3(8, 0.2, 0.2)},
		{"pos": Vector3(-5, 1.8, 0), "rot": 90, "size": Vector3(8, 0.2, 0.2)},
		{"pos": Vector3(0, 0.8, -4), "rot": 0, "size": Vector3(10, 0.2, 0.2)},
		{"pos": Vector3(0, 1.8, -4), "rot": 0, "size": Vector3(10, 0.2, 0.2)},
		{"pos": Vector3(5, 0.8, 0), "rot": 90, "size": Vector3(8, 0.2, 0.2)},
		{"pos": Vector3(5, 1.8, 0), "rot": 90, "size": Vector3(8, 0.2, 0.2)}
	]
	
	for r_cfg in rails_configs:
		var r = BuilderUtils.create_cube_mesh(r_cfg.size, wood_mat)
		r.translation = r_cfg.pos
		r.rotation_degrees.y = r_cfg.rot
		stable_node.add_child(r)

static func _build_troughs(stable_node: Node, wood_mat: Material) -> void:
	"""Construye los comederos y el divisor."""
	var mat_trough = BuilderUtils.create_material(Color(0.2, 0.15, 0.1))
	var mat_hay = BuilderUtils.create_material(Color(0.8, 0.7, 0.2))
	
	for side in [-1, 1]:
		# Comedero
		var trough = BuilderUtils.create_cube_mesh(Vector3(3.5, 0.8, 1.2), mat_trough)
		trough.translation = Vector3(side * 2.2, 0.4, -3.2)
		stable_node.add_child(trough)
		
		# Heno
		var hay = BuilderUtils.create_cube_mesh(Vector3(3.3, 0.2, 1.0), mat_hay)
		hay.translation = Vector3(side * 2.2, 0.85, -3.2)
		stable_node.add_child(hay)
	
	# Divisor central
	var divider = BuilderUtils.create_cube_mesh(Vector3(0.5, 1.2, 1.4), wood_mat)
	divider.translation = Vector3(0, 0.6, -3.2)
	stable_node.add_child(divider)

static func _add_collision(stable_node: Node) -> void:
	"""Añade colisiones al establo."""
	var sb = StaticBody.new()
	stable_node.add_child(sb)
	
	var col_configs = [
		{"pos": Vector3(-5, 1.5, 0), "size": Vector3(0.5, 3.0, 8)},
		{"pos": Vector3(5, 1.5, 0), "size": Vector3(0.5, 3.0, 8)},
		{"pos": Vector3(0, 1.5, -4), "size": Vector3(10, 3.0, 0.5)}
	]
	
	for c in col_configs:
		var cs = CollisionShape.new()
		var shape = BoxShape.new()
		shape.extents = c.size * 0.5
		cs.shape = shape
		cs.translation = c.pos
		sb.add_child(cs)
	
	# Colisiones para comederos
	for side in [-1, 1]:
		var cs_t = CollisionShape.new()
		var shape_t = BoxShape.new()
		shape_t.extents = Vector3(1.75, 0.4, 0.6)
		cs_t.shape = shape_t
		cs_t.translation = Vector3(side * 2.2, 0.4, -3.2)
		sb.add_child(cs_t)
	
	# Colisión del divisor
	var cs_div = CollisionShape.new()
	var shape_div = BoxShape.new()
	shape_div.extents = Vector3(0.25, 0.6, 0.7)
	cs_div.shape = shape_div
	cs_div.translation = Vector3(0, 0.6, -3.2)
	sb.add_child(cs_div)
