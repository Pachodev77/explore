# =============================================================================
# FarmhouseBuilder.gd - CONSTRUCTOR DE LA CASA PRINCIPAL
# =============================================================================
# Maneja la generación de la casa de la granja con todos sus detalles.
# =============================================================================

extends Reference
class_name FarmhouseBuilder

# =============================================================================
# CONFIGURACIÓN
# =============================================================================

const HOUSE_POSITION = Vector3(-18.0, 1.9, -18.0)
const HOUSE_ROTATION = 45.0  # grados

# =============================================================================
# API PÚBLICA
# =============================================================================

static func build(container: Node, shared_res: Dictionary) -> void:
	"""Construye la casa principal de la granja."""
	var house_node = Spatial.new()
	house_node.translation = HOUSE_POSITION
	house_node.rotation_degrees.y = HOUSE_ROTATION
	container.add_child(house_node)
	
	# Crear materiales
	var materials = _create_materials(shared_res)
	
	# Construir componentes
	_build_foundation(house_node, materials)
	_build_walls(house_node, materials)
	_build_roof(house_node, materials)
	_build_porch(house_node, materials)
	_build_door(house_node, materials)
	_build_windows(house_node, materials)
	_build_chimney(house_node, materials)
	_add_torches(house_node, shared_res)
	_add_collision(house_node)

# =============================================================================
# MATERIALES
# =============================================================================

static func _create_materials(shared_res: Dictionary) -> Dictionary:
	"""Crea todos los materiales necesarios para la casa."""
	var mat_wall = SpatialMaterial.new()
	mat_wall.albedo_color = Color(0.98, 0.98, 0.95)
	mat_wall.roughness = 0.85
	
	var mat_base = SpatialMaterial.new()
	mat_base.albedo_color = Color(0.3, 0.3, 0.32)
	mat_base.roughness = 0.9
	
	var mat_roof = SpatialMaterial.new()
	mat_roof.albedo_color = Color(0.45, 0.12, 0.12)
	mat_roof.roughness = 0.6
	
	var mat_wood_dark = BuilderUtils.get_wood_mat(shared_res)
	
	var mat_trim = SpatialMaterial.new()
	mat_trim.albedo_color = Color(0.9, 0.9, 0.85)
	
	var mat_window = SpatialMaterial.new()
	mat_window.albedo_color = Color(0.1, 0.15, 0.25)
	mat_window.metallic = 0.9
	mat_window.roughness = 0.1
	
	var mat_shutter = SpatialMaterial.new()
	mat_shutter.albedo_color = Color(0.15, 0.25, 0.15)
	
	return {
		"wall": mat_wall,
		"base": mat_base,
		"roof": mat_roof,
		"wood_dark": mat_wood_dark,
		"trim": mat_trim,
		"window": mat_window,
		"shutter": mat_shutter
	}

# =============================================================================
# COMPONENTES DE LA CASA
# =============================================================================

static func _build_foundation(house_node: Node, materials: Dictionary) -> void:
	"""Construye la base de piedra."""
	var base = BuilderUtils.create_cube_mesh(Vector3(10.5, 0.8, 8.5), materials.base)
	base.translation = Vector3(0, 0.4, 0)
	house_node.add_child(base)

static func _build_walls(house_node: Node, materials: Dictionary) -> void:
	"""Construye las paredes y molduras."""
	# Cuerpo principal
	var body = BuilderUtils.create_cube_mesh(Vector3(10, 6.6, 8), materials.wall)
	body.translation = Vector3(0, 4.0, 0)
	house_node.add_child(body)
	
	# Molduras de esquina
	for x in [-5.05, 5.05]:
		for z in [-4.05, 4.05]:
			var trim = BuilderUtils.create_cube_mesh(Vector3(0.4, 6.5, 0.4), materials.trim)
			trim.translation = Vector3(x, 4.0, z)
			house_node.add_child(trim)

static func _build_roof(house_node: Node, materials: Dictionary) -> void:
	"""Construye el techo principal."""
	var roof = BuilderUtils.create_prism_mesh(Vector3(11.5, 3.5, 9), materials.roof)
	roof.translation = Vector3(0, 8.95, 0)
	house_node.add_child(roof)
	
	# Fascia frontal
	var fascia_f = BuilderUtils.create_cube_mesh(Vector3(11.6, 0.2, 0.2), materials.trim)
	fascia_f.translation = Vector3(0, 7.3, 4.4)
	house_node.add_child(fascia_f)

static func _build_porch(house_node: Node, materials: Dictionary) -> void:
	"""Construye el porche con columnas y barandilla."""
	# Piso del porche
	var porch_deck = BuilderUtils.create_cube_mesh(Vector3(10, 0.3, 3.5), materials.wood_dark)
	porch_deck.translation = Vector3(0, 0.7, 5.75)
	house_node.add_child(porch_deck)
	
	# Escalones
	for i in range(2):
		var step = BuilderUtils.create_cube_mesh(Vector3(3, 0.2, 0.4), materials.wood_dark)
		step.translation = Vector3(0, 0.5 - (i * 0.25), 7.7 + (i * 0.4))
		house_node.add_child(step)
	
	# Techo del porche
	var p_roof = BuilderUtils.create_cube_mesh(Vector3(11, 0.2, 4), materials.roof)
	p_roof.translation = Vector3(0, 4.1, 5.8)
	p_roof.rotation_degrees.x = 12
	house_node.add_child(p_roof)
	
	# Columnas
	for x in [-4.5, 4.5]:
		var col = BuilderUtils.create_cube_mesh(Vector3(0.3, 3.2, 0.3), materials.trim)
		col.translation = Vector3(x, 2.15, 7.3)
		house_node.add_child(col)
	
	# Barandillas
	for x_side in [-1, 1]:
		var rail = BuilderUtils.create_cube_mesh(Vector3(3.5, 0.1, 0.1), materials.trim)
		rail.translation = Vector3(x_side * 3.0, 1.8, 7.4)
		house_node.add_child(rail)
		
		# Balaustres
		for off in range(-15, 16, 5):
			var b = BuilderUtils.create_cube_mesh(Vector3(0.05, 1.0, 0.05), materials.trim)
			b.translation = Vector3(x_side * 3.0 + (off * 0.1), 1.3, 7.4)
			house_node.add_child(b)

static func _build_door(house_node: Node, materials: Dictionary) -> void:
	"""Construye la puerta principal con marco y pomo."""
	# Marco
	var door_frame = BuilderUtils.create_cube_mesh(Vector3(2.0, 3.5, 0.2), materials.trim)
	door_frame.translation = Vector3(0, 2.45, 4.01)
	house_node.add_child(door_frame)
	
	# Puerta
	var door = BuilderUtils.create_cube_mesh(Vector3(1.6, 3.2, 0.1), materials.wood_dark)
	door.translation = Vector3(0, 2.3, 4.05)
	house_node.add_child(door)
	
	# Pomo dorado
	var knob = MeshInstance.new()
	var sph = SphereMesh.new()
	sph.radius = 0.08
	sph.height = 0.16
	knob.mesh = sph
	knob.translation = Vector3(0.5, 2.3, 4.15)
	
	var gold = SpatialMaterial.new()
	gold.albedo_color = Color(0.8, 0.6, 0.2)
	gold.metallic = 1.0
	gold.roughness = 0.2
	knob.material_override = gold
	house_node.add_child(knob)

static func _build_windows(house_node: Node, materials: Dictionary) -> void:
	"""Construye todas las ventanas de la casa."""
	var win_configs = [
		{"pos": Vector3(-2.8, 5.8, 4.1), "rot": 0, "shutters": true, "w": 1.6, "h": 2.0},
		{"pos": Vector3(2.8, 5.8, 4.1), "rot": 0, "shutters": true, "w": 1.6, "h": 2.0},
		{"pos": Vector3(-5.1, 4.8, 0.0), "rot": 90, "shutters": true, "w": 1.6, "h": 2.0},
		{"pos": Vector3(5.1, 4.8, 0.0), "rot": -90, "shutters": true, "w": 1.6, "h": 2.0},
		{"pos": Vector3(0, 8.2, 4.6), "rot": 0, "shutters": false, "w": 1.1, "h": 1.1, "round": true}
	]
	
	for cfg in win_configs:
		_build_single_window(house_node, cfg, materials)

static func _build_single_window(house_node: Node, cfg: Dictionary, materials: Dictionary) -> void:
	"""Construye una ventana individual."""
	var w_node = Spatial.new()
	w_node.translation = cfg.pos
	w_node.rotation_degrees.y = cfg.rot
	house_node.add_child(w_node)
	
	var is_round = cfg.get("round", false)
	var ww = cfg.w
	var wh = cfg.h
	
	# Cristal
	var glass = MeshInstance.new()
	if is_round:
		var cyl = CylinderMesh.new()
		cyl.top_radius = ww * 0.5
		cyl.bottom_radius = ww * 0.5
		cyl.height = 0.05
		glass.mesh = cyl
		glass.rotation_degrees.x = 90
	else:
		glass.mesh = CubeMesh.new()
		glass.mesh.size = Vector3(ww, wh, 0.05)
	glass.material_override = materials.window
	w_node.add_child(glass)
	
	# Marco
	var frame = MeshInstance.new()
	if is_round:
		var f_cyl = CylinderMesh.new()
		f_cyl.top_radius = ww * 0.55
		f_cyl.bottom_radius = ww * 0.55
		f_cyl.height = 0.1
		frame.mesh = f_cyl
		frame.rotation_degrees.x = 90
		frame.translation.z = -0.04
	else:
		frame.mesh = CubeMesh.new()
		frame.mesh.size = Vector3(ww + 0.2, wh + 0.2, 0.1)
		frame.translation.z = -0.04
	frame.material_override = materials.trim
	w_node.add_child(frame)
	
	# Cruz de la ventana
	var cross_h = BuilderUtils.create_cube_mesh(Vector3(ww, 0.08, 0.1), materials.trim)
	w_node.add_child(cross_h)
	var cross_v = BuilderUtils.create_cube_mesh(Vector3(0.08, wh, 0.1), materials.trim)
	w_node.add_child(cross_v)
	
	# Persianas
	if cfg.shutters:
		for side in [-1, 1]:
			var shutter = BuilderUtils.create_cube_mesh(Vector3(0.8, wh, 0.05), materials.shutter)
			shutter.translation = Vector3(side * (ww * 0.5 + 0.5), 0, 0)
			w_node.add_child(shutter)

static func _build_chimney(house_node: Node, materials: Dictionary) -> void:
	"""Construye la chimenea."""
	var chimney = BuilderUtils.create_cube_mesh(Vector3(1.4, 6, 1.4), materials.base)
	chimney.translation = Vector3(3.5, 9, -2)
	house_node.add_child(chimney)
	
	var chim_top = BuilderUtils.create_cube_mesh(Vector3(1.6, 0.3, 1.6), materials.trim)
	chim_top.translation = Vector3(3.5, 12, -2)
	house_node.add_child(chim_top)

static func _add_torches(house_node: Node, shared_res: Dictionary) -> void:
	"""Añade antorchas decorativas en el porche."""
	for tx in [-4.5, 4.5]:
		var side = 1.0 if tx > 0 else -1.0
		_build_torch(house_node, Vector3(tx, 2.5, 7.45), shared_res, side)

static func _build_torch(parent: Node, pos: Vector3, shared_res: Dictionary, side: float) -> void:
	"""Construye una antorcha individual."""
	var torch_node = Spatial.new()
	torch_node.translation = pos + Vector3(0, 0, 0.15)
	torch_node.rotation_degrees.x = 45.0
	parent.add_child(torch_node)
	
	# Palo
	var stick = BuilderUtils.create_cube_mesh(Vector3(0.08, 0.4, 0.08), BuilderUtils.get_wood_mat(shared_res))
	torch_node.add_child(stick)
	
	# Brasa
	var ember = MeshInstance.new()
	var ember_mesh = SphereMesh.new()
	ember_mesh.radius = 0.08
	ember_mesh.height = 0.16
	ember.mesh = ember_mesh
	
	var fire_mat = BuilderUtils.create_emissive_material(
		Color(1.0, 0.4, 0.1),
		Color(1.0, 0.4, 0.0),
		2.0
	)
	ember.material_override = fire_mat
	ember.translation.y = 0.25
	torch_node.add_child(ember)
	
	# Luz
	var light = OmniLight.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 0.0  # Controlado por ciclo día/noche
	light.omni_range = 10.0
	light.omni_attenuation = 2.0
	light.add_to_group("house_lights")
	light.translation.y = 0.3
	torch_node.add_child(light)

static func _add_collision(house_node: Node) -> void:
	"""Añade colisiones a la casa."""
	var sb = StaticBody.new()
	house_node.add_child(sb)
	
	# Cuerpo principal
	var cs_body = CollisionShape.new()
	var shape_body = BoxShape.new()
	shape_body.extents = Vector3(5, 4, 4)
	cs_body.shape = shape_body
	cs_body.translation = Vector3(0, 4, 0)
	sb.add_child(cs_body)
	
	# Porche
	var cs_porch = CollisionShape.new()
	var shape_porch = BoxShape.new()
	shape_porch.extents = Vector3(5, 0.4, 1.75)
	cs_porch.shape = shape_porch
	cs_porch.translation = Vector3(0, 0.7, 5.75)
	sb.add_child(cs_porch)
	
	# Techo
	var cs_roof = CollisionShape.new()
	var shape_roof = BoxShape.new()
	shape_roof.extents = Vector3(5.5, 1.5, 4.5)
	cs_roof.shape = shape_roof
	cs_roof.translation = Vector3(0, 8.5, 0)
	sb.add_child(cs_roof)
