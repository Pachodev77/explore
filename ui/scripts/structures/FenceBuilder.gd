# =============================================================================
# FenceBuilder.gd - CONSTRUCTOR DE CERCAS Y PUERTAS
# =============================================================================
# Maneja la generación de cercas perimetrales, postes, barandillas y puertas.
# =============================================================================

extends Reference
class_name FenceBuilder

const PERIMETER_HALF = 33.0

# =============================================================================
# API PÚBLICA
# =============================================================================

static func build_perimeter_fence(container: Node, shared_res: Dictionary, perimeter_y: float = 2.0) -> void:
	"""Construye la cerca perimetral completa con puertas."""
	var wood_mat = BuilderUtils.get_wood_mat(shared_res)
	
	# Crear meshes base
	var post_mesh = CubeMesh.new()
	post_mesh.size = Vector3(0.4, 2.5, 0.4)
	
	var rail_mesh = CubeMesh.new()
	rail_mesh.size = Vector3(3.0, 0.3, 0.15)
	
	# Recolectar transforms
	var posts = _generate_post_transforms(perimeter_y)
	var rails = _generate_rail_transforms(perimeter_y)
	
	# Crear MultiMeshInstances optimizados
	var mmi_posts = BuilderUtils.create_multimesh_instance(post_mesh, posts, wood_mat, false)
	container.add_child(mmi_posts)
	
	var mmi_rails = BuilderUtils.create_multimesh_instance(rail_mesh, rails, wood_mat, false)
	container.add_child(mmi_rails)
	
	# Agregar puertas
	build_gate(container, Vector3(-PERIMETER_HALF, perimeter_y, 0), 0.0, shared_res)
	build_gate(container, Vector3(PERIMETER_HALF, perimeter_y, 0), 0.0, shared_res)
	
	# Agregar colisiones
	_add_fence_collisions(container, perimeter_y)

static func build_gate(container: Node, pos: Vector3, rot_deg: float, shared_res: Dictionary) -> void:
	"""Construye una puerta con postes y cartel."""
	var wood_mat = BuilderUtils.get_wood_mat(shared_res)
	var sign_mat = BuilderUtils.get_sign_mat(shared_res)
	
	var rot = Basis(Vector3.UP, deg2rad(rot_deg))
	var post_mesh = CubeMesh.new()
	post_mesh.size = Vector3(0.6, 7.0, 0.6)
	
	# Postes de la puerta
	for offset_z in [-6.0, 6.0]:
		var p = MeshInstance.new()
		p.mesh = post_mesh
		p.material_override = wood_mat
		p.translation = pos + rot.xform(Vector3(0, 3.5, offset_z))
		container.add_child(p)
	
	# Viga superior
	var beam = BuilderUtils.create_cube_mesh(Vector3(0.5, 0.6, 13.0), wood_mat)
	beam.transform.basis = rot
	beam.translation = pos + Vector3(0, 6.5, 0)
	container.add_child(beam)
	
	# Cartel
	var sign_board = BuilderUtils.create_cube_mesh(Vector3(0.3, 1.5, 4.0), sign_mat)
	sign_board.transform.basis = rot
	sign_board.translation = pos + Vector3(0, 5.5, 0)
	container.add_child(sign_board)

# =============================================================================
# FUNCIONES PRIVADAS
# =============================================================================

static func _generate_post_transforms(perimeter_y: float) -> Array:
	"""Genera los transforms para los postes de la cerca."""
	var posts = []
	var half = PERIMETER_HALF
	
	# Postes Norte y Sur
	for x in range(-int(half), int(half) + 1, 3):
		var t_n = Transform()
		t_n.origin = Vector3(x, perimeter_y + 0.5, -half)
		posts.append(t_n)
		var t_s = Transform()
		t_s.origin = Vector3(x, perimeter_y + 0.5, half)
		posts.append(t_s)
	
	# Postes Este y Oeste (evitando zona de puerta)
	for z in range(-int(half), int(half) + 1, 3):
		if abs(z) > 6.0:
			var t_w = Transform()
			t_w.origin = Vector3(-half, perimeter_y + 0.5, z)
			posts.append(t_w)
			var t_e = Transform()
			t_e.origin = Vector3(half, perimeter_y + 0.5, z)
			posts.append(t_e)
	
	return posts

static func _generate_rail_transforms(perimeter_y: float) -> Array:
	"""Genera los transforms para las barandillas."""
	var rails = []
	var half = PERIMETER_HALF
	
	# Barandillas Norte y Sur
	for x in range(-int(half), int(half) + 1, 3):
		if x < half:
			# Norte
			var tr_n = Transform()
			tr_n.origin = Vector3(x + 1.5, perimeter_y + 1.5, -half)
			rails.append(tr_n)
			var tr_n2 = Transform()
			tr_n2.origin = Vector3(x + 1.5, perimeter_y + 1.0, -half)
			rails.append(tr_n2)
			
			# Sur
			var tr_s = Transform()
			tr_s.origin = Vector3(x + 1.5, perimeter_y + 1.5, half)
			rails.append(tr_s)
			var tr_s2 = Transform()
			tr_s2.origin = Vector3(x + 1.5, perimeter_y + 1.0, half)
			rails.append(tr_s2)
	
	# Barandillas Este y Oeste (evitando zona de puerta)
	for z in range(-int(half), int(half) + 1, 3):
		if z < half:
			if z >= -6 and z < 6:
				continue
			var rot = Basis(Vector3.UP, deg2rad(90))
			var tr_w = Transform(rot, Vector3(-half, perimeter_y + 1.5, z + 1.5))
			rails.append(tr_w)
			var tr_w2 = Transform(rot, Vector3(-half, perimeter_y + 1.0, z + 1.5))
			rails.append(tr_w2)
			var tr_e = Transform(rot, Vector3(half, perimeter_y + 1.5, z + 1.5))
			rails.append(tr_e)
			var tr_e2 = Transform(rot, Vector3(half, perimeter_y + 1.0, z + 1.5))
			rails.append(tr_e2)
	
	return rails

static func _add_fence_collisions(container: Node, perimeter_y: float) -> void:
	"""Añade colisiones invisibles para la cerca."""
	var half = PERIMETER_HALF
	var height = 3.0
	var thickness = 1.0
	var y_center = perimeter_y + height / 2.0
	
	# Norte y Sur
	BuilderUtils.add_collision_box(container, Vector3(0, y_center, -half), Vector3(half * 2, height, thickness))
	BuilderUtils.add_collision_box(container, Vector3(0, y_center, half), Vector3(half * 2, height, thickness))
	
	# Este y Oeste (con hueco para puerta)
	BuilderUtils.add_collision_box(container, Vector3(-half, y_center, -19.5), Vector3(thickness, height, 27.0))
	BuilderUtils.add_collision_box(container, Vector3(-half, y_center, 19.5), Vector3(thickness, height, 27.0))
	BuilderUtils.add_collision_box(container, Vector3(half, y_center, -19.5), Vector3(thickness, height, 27.0))
	BuilderUtils.add_collision_box(container, Vector3(half, y_center, 19.5), Vector3(thickness, height, 27.0))
