extends StaticBody

enum Biome { PRAIRIE, DESERT, SNOW, JUNGLE }
enum TileLOD { HIGH, LOW }

# Configuración del plano
# LOD System: LOW = 4 res, no physics, no decos. HIGH = 12 res, full.
const GRID_RES_HIGH = 12
const GRID_RES_LOW = 4
const TILE_SIZE = 150.0
var harvested_instances = {} # Persistencia de tala: { "tree_mmi": [indices], ... }

var current_lod = TileLOD.LOW
var current_shared_res = null
var current_is_spawn = false

func setup_biome(_dummy_type, shared_resources, _dummy_height = 0, is_spawn = false, lod_level = TileLOD.LOW):
	current_shared_res = shared_resources
	current_is_spawn = is_spawn
	current_lod = lod_level
	
	var mesh_instance = get_node_or_null("MeshInstance")
	var deco_container = get_node_or_null("Decos")
	if not mesh_instance or not deco_container: return
	
	# 1. Aplicar Material de Bioma (Instantáneo)
	mesh_instance.set_surface_material(0, shared_resources["ground_mat"])
	
	# LIMPIEZA: Eliminar decoraciones de su "vida anterior" si el tile es reciclado
	for child in deco_container.get_children():
		child.queue_free()
	
	# 2. Geometría (resolución depende de LOD)
	var grid_res = GRID_RES_LOW if lod_level == TileLOD.LOW else GRID_RES_HIGH
	
	visible = false 
	# Esperar a que la malla y el trimesh estén creados
	var state = _rebuild_mesh_and_physics(mesh_instance, shared_resources, is_spawn, grid_res, lod_level)
	if state is GDScriptFunctionState:
		yield(state, "completed")
	
	if not is_instance_valid(self): return
	visible = true
	
	# LOD_LOW: Skip decorations for speed
	if lod_level == TileLOD.HIGH:
		_add_decos_final(deco_container, shared_resources, is_spawn)
		if is_spawn:
			_add_fence(deco_container, shared_resources)
			# Solo añadir la casa y el establo si es el tile central (0,0)
			if abs(translation.x) < 1.0 and abs(translation.z) < 1.0:
				_add_farmhouse(deco_container, shared_resources)
				_add_stable(deco_container, shared_resources)

func upgrade_to_high_lod():
	if current_lod == TileLOD.HIGH: return
	if current_shared_res == null: return
	
	current_lod = TileLOD.HIGH
	var mesh_instance = get_node_or_null("MeshInstance")
	var deco_container = get_node_or_null("Decos")
	if not mesh_instance or not deco_container: return
	
	var state = _rebuild_mesh_and_physics(mesh_instance, current_shared_res, current_is_spawn, GRID_RES_HIGH, TileLOD.HIGH)
	if state is GDScriptFunctionState:
		yield(state, "completed")
	
	if not is_instance_valid(self): return
	
	_add_decos_final(deco_container, current_shared_res, current_is_spawn)
	if current_is_spawn:
		_add_fence(deco_container, current_shared_res)
		if abs(translation.x) < 1.0 and abs(translation.z) < 1.0:
			_add_farmhouse(deco_container, current_shared_res)
			_add_stable(deco_container, current_shared_res)

func _add_fence(container, shared_res):
	# OPTIMIZACIÓN: Material Cacheado
	var wood_mat = shared_res.get("wood_mat")
	if not wood_mat: # Fallback
		wood_mat = SpatialMaterial.new()
		wood_mat.albedo_color = Color(0.4, 0.25, 0.1)
	
	# Mallas
	var post_mesh = CubeMesh.new()
	post_mesh.size = Vector3(0.4, 2.5, 0.4) # Más altos para enterrarlos mejor
	
	var rail_mesh = CubeMesh.new()
	rail_mesh.size = Vector3(3.0, 0.3, 0.15) # Tablas horizontales
	
	# Generar transformaciones
	var posts = []
	var rails = []
	
	var half = 33.0 # 33.0 * 2 = 66m. (Cercano a 65, divisible por 3)
	var perimeter_y = 2.0 # Altura base del spawn
	
	# 4 Lados: Norte, Sur, Este, Oeste
	# Lado Norte (Z = -half) y Sur (Z = half)
	for x in range(-half, half + 1, 3): # Cada 3 metros
		# Norte
		var t_n = Transform()
		t_n.origin = Vector3(x, perimeter_y + 0.5, -half) # Bajamos centro a Y=2.5 (Fondo en 1.25)
		posts.append(t_n)
		
		# Sur
		var t_s = Transform()
		t_s.origin = Vector3(x, perimeter_y + 0.5, half)
		posts.append(t_s)
		
		# Tablas (entre este poste y el siguiente)
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

	# Lado Este (X = half) y Oeste (X = -half)
	# Nota: Saltamos las esquinas para no duplicar demasiado, o superponemos simple
	for z in range(-half, half + 1, 3):
		# LOGICA DE HUECO PARA PORTICOS (Z entre -6 y 6)
		# Rango de hueco agrandado para encajar con grid (12m ancho: -6 a 6)
		
		# 1. Postes (Solo si están fuera del hueco estricto)
		# Los postes de -6 y 6 son reemplazados por el marco del pórtico
		if abs(z) > 6.0:
			# Oeste
			var t_w = Transform()
			t_w.origin = Vector3(-half, perimeter_y + 0.5, z)
			posts.append(t_w)
			
			# Este
			var t_e = Transform()
			t_e.origin = Vector3(half, perimeter_y + 0.5, z)
			posts.append(t_e)
		
		# 2. Tablas (rotadas 90 grados)
		if z < half:
			# Evitar generar tablas DENTRO del hueco
			# -6: saltar (iría a -3)
			# -3, 0, 3: saltar
			# 6: generar (va a 9)
			# -9: generar (va a -6)
			if z >= -6 and z < 6: continue
			
			var rot = Basis(Vector3.UP, deg2rad(90))
			
			# Oeste
			var tr_w = Transform(rot, Vector3(-half, perimeter_y + 1.5, z + 1.5))
			rails.append(tr_w)
			var tr_w2 = Transform(rot, Vector3(-half, perimeter_y + 1.0, z + 1.5))
			rails.append(tr_w2)
			
			# Este
			var tr_e = Transform(rot, Vector3(half, perimeter_y + 1.5, z + 1.5))
			rails.append(tr_e)
			var tr_e2 = Transform(rot, Vector3(half, perimeter_y + 1.0, z + 1.5))
			rails.append(tr_e2)
			
	# Crear MultiMeshes
	var mmi_posts = MultiMeshInstance.new()
	var mm_posts = MultiMesh.new()
	mm_posts.transform_format = MultiMesh.TRANSFORM_3D
	mm_posts.mesh = post_mesh
	mm_posts.instance_count = posts.size()
	for i in range(posts.size()):
		mm_posts.set_instance_transform(i, posts[i])
	mmi_posts.multimesh = mm_posts
	mmi_posts.material_override = wood_mat
	mmi_posts.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	container.add_child(mmi_posts)
	
	var mmi_rails = MultiMeshInstance.new()
	var mm_rails = MultiMesh.new()
	mm_rails.transform_format = MultiMesh.TRANSFORM_3D
	mm_rails.mesh = rail_mesh
	mm_rails.instance_count = rails.size()
	for i in range(rails.size()):
		mm_rails.set_instance_transform(i, rails[i])
	mmi_rails.multimesh = mm_rails
	mmi_rails.material_override = wood_mat
	mmi_rails.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	container.add_child(mmi_rails)
	
	# Añadir Pórticos en las Salidas (Oeste y Este)
	# Oeste
	_add_gate(container, Vector3(-half, perimeter_y, 0), 0.0, shared_res)
	# Este
	_add_gate(container, Vector3(half, perimeter_y, 0), 0.0, shared_res)

func _add_gate(container, pos, rot_deg, shared_res):
	var mat = shared_res.get("wood_mat")
	if not mat: 
		mat = SpatialMaterial.new()
		mat.albedo_color = Color(0.35, 0.2, 0.1)
	
	var sign_mat = shared_res.get("sign_mat")
	if not sign_mat:
		sign_mat = SpatialMaterial.new()
		sign_mat.albedo_color = Color(0.8, 0.7, 0.5)
	
	var rot = Basis(Vector3.UP, deg2rad(rot_deg))
	
	# 1. Postes Altos (Izquierda y Derecha del hueco de 12m -> +/- 6m)
	var post_mesh = CubeMesh.new()
	post_mesh.size = Vector3(0.6, 7.0, 0.6) # 7m de alto (antes 5m)
	
	for offset_z in [-6.0, 6.0]: # Ajustado a 6m para coincidir con fence grid
		var p = MeshInstance.new()
		p.mesh = post_mesh
		p.material_override = mat
		p.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		# Posición relativa rotada (Centro en 3.5m)
		var local_pos = rot.xform(Vector3(0, 3.5, offset_z)) 
		p.translation = pos + local_pos
		container.add_child(p)
		
	# 2. Viga Superior (Marco)
	var beam = MeshInstance.new()
	beam.mesh = CubeMesh.new()
	beam.mesh.size = Vector3(0.5, 0.6, 13.0) # Cubre los 12m + margen
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	# Rotar la viga según la orientación del pórtico
	beam.transform.basis = rot
	beam.translation = pos + Vector3(0, 6.5, 0) # Subimos a 6.5m
	container.add_child(beam)
	
	# 3. Letrero Colgante
	var sign_board = MeshInstance.new()
	sign_board.mesh = CubeMesh.new()
	sign_board.mesh.size = Vector3(0.3, 1.5, 4.0)
	sign_board.material_override = sign_mat
	sign_board.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	sign_board.transform.basis = rot
	sign_board.translation = pos + Vector3(0, 5.5, 0) # Colgando en 5.5m
	container.add_child(sign_board)

	# --- COLISIONES INVISIBLES DE LA VALLA ---
	_add_fence_collisions(container)

func _add_farmhouse(container, shared_res):
	var house_node = Spatial.new()
	# Posicionamiento: Un poco más alejada para dar espacio al porche y escaleras
	house_node.translation = Vector3(-18.0, 1.9, -18.0) 
	house_node.rotation_degrees.y = 45.0
	container.add_child(house_node)
	
	# --- PALETA DE MATERIALES SOFISTICADA ---
	var mat_wall = SpatialMaterial.new()
	mat_wall.albedo_color = Color(0.98, 0.98, 0.95) # Crema premium
	mat_wall.roughness = 0.85
	
	var mat_base = SpatialMaterial.new()
	mat_base.albedo_color = Color(0.3, 0.3, 0.32) # Piedra/Cemento oscuro
	mat_base.roughness = 0.9
	
	var mat_roof = SpatialMaterial.new()
	mat_roof.albedo_color = Color(0.45, 0.12, 0.12) # Rojo terracota
	mat_roof.roughness = 0.6
	
	var mat_wood_dark = shared_res.get("wood_mat")
	if not mat_wood_dark:
		mat_wood_dark = SpatialMaterial.new()
		mat_wood_dark.albedo_color = Color(0.25, 0.15, 0.08)
	
	var mat_trim = SpatialMaterial.new()
	mat_trim.albedo_color = Color(0.9, 0.9, 0.85)
	
	var mat_window = SpatialMaterial.new()
	mat_window.albedo_color = Color(0.1, 0.15, 0.25)
	mat_window.metallic = 0.9
	mat_window.roughness = 0.1
	
	var mat_shutter = SpatialMaterial.new()
	mat_shutter.albedo_color = Color(0.15, 0.25, 0.15) # Verde granja elegante
	
	# 1. CIMENTACIÓN (Base de piedra)
	var base = MeshInstance.new()
	base.mesh = CubeMesh.new()
	base.mesh.size = Vector3(10.5, 0.8, 8.5)
	base.translation = Vector3(0, 0.4, 0)
	base.material_override = mat_base
	house_node.add_child(base)
	
	# 2. CUERPO PRINCIPAL (Ajustado para evitar Z-fighting con el tejado)
	var body = MeshInstance.new()
	body.mesh = CubeMesh.new()
	body.mesh.size = Vector3(10, 6.6, 8) # Aumentado de 6.5 a 6.6
	body.translation = Vector3(0, 4.0, 0) # El tope queda en 7.3
	body.material_override = mat_wall
	body.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON
	house_node.add_child(body)
	
	# 3. MOLDURAS DE ESQUINA (Trim)
	for x in [-5.05, 5.05]:
		for z in [-4.05, 4.05]:
			var trim = MeshInstance.new()
			trim.mesh = CubeMesh.new()
			trim.mesh.size = Vector3(0.4, 6.5, 0.4)
			trim.translation = Vector3(x, 4.0, z)
			trim.material_override = mat_trim
			house_node.add_child(trim)
			
	# 4. TEJADO PRINCIPAL (Bajado ligeramente para solaparse y evitar Z-fighting)
	var roof = MeshInstance.new()
	var prism = PrismMesh.new()
	prism.size = Vector3(11.5, 3.5, 9)
	roof.mesh = prism
	roof.translation = Vector3(0, 8.95, 0) # Bajado de 9.0 a 8.95. Base queda en 7.2
	roof.material_override = mat_roof
	roof.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON
	house_node.add_child(roof)
	
	# Bordes del tejado (Fascia)
	var fascia_f = MeshInstance.new()
	fascia_f.mesh = CubeMesh.new()
	fascia_f.mesh.size = Vector3(11.6, 0.2, 0.2)
	fascia_f.translation = Vector3(0, 7.3, 4.4)
	fascia_f.material_override = mat_trim
	house_node.add_child(fascia_f)
	
	# 5. PORCHE ELEGANTE
	var porch_deck = MeshInstance.new()
	porch_deck.mesh = CubeMesh.new()
	porch_deck.mesh.size = Vector3(10, 0.3, 3.5)
	porch_deck.translation = Vector3(0, 0.7, 5.75)
	porch_deck.material_override = mat_wood_dark
	house_node.add_child(porch_deck)
	
	# Escalones
	for i in range(2):
		var step = MeshInstance.new()
		step.mesh = CubeMesh.new()
		step.mesh.size = Vector3(3, 0.2, 0.4)
		step.translation = Vector3(0, 0.5 - (i*0.25), 7.7 + (i*0.4))
		step.material_override = mat_wood_dark
		house_node.add_child(step)
		
	# Techo del Porche (Inclinado) - Subido a 4.1m para cubrir pilares
	var p_roof = MeshInstance.new()
	p_roof.mesh = CubeMesh.new()
	p_roof.mesh.size = Vector3(11, 0.2, 4)
	p_roof.translation = Vector3(0, 4.1, 5.8)
	p_roof.rotation_degrees.x = 12
	p_roof.material_override = mat_roof
	house_node.add_child(p_roof)
	
	# Columnas del Porche (con base y capitel) - Acortadas aún más en la parte superior
	for x in [-4.5, 4.5]:
		var col = MeshInstance.new()
		col.mesh = CubeMesh.new()
		col.mesh.size = Vector3(0.3, 3.2, 0.3)
		col.translation = Vector3(x, 2.15, 7.3)
		col.material_override = mat_trim
		house_node.add_child(col)
		
	# Barandilla del Porche
	for x_side in [-1, 1]:
		var rail = MeshInstance.new()
		rail.mesh = CubeMesh.new()
		rail.mesh.size = Vector3(3.5, 0.1, 0.1)
		rail.translation = Vector3(x_side * 3.0, 1.8, 7.4)
		rail.material_override = mat_trim
		house_node.add_child(rail)
		# Barrotillos (mini balusters)
		for off in range(-15, 16, 5):
			var b = MeshInstance.new()
			b.mesh = CubeMesh.new()
			b.mesh.size = Vector3(0.05, 1.0, 0.05)
			b.translation = Vector3(x_side * 3.0 + (off*0.1), 1.3, 7.4)
			b.material_override = mat_trim
			house_node.add_child(b)

	# 6. PUERTA PRINCIPAL (Con marco y pomo) - Tamaño ajustado
	var door_frame = MeshInstance.new()
	door_frame.mesh = CubeMesh.new()
	door_frame.mesh.size = Vector3(2.0, 3.5, 0.2)
	door_frame.translation = Vector3(0, 2.45, 4.01)
	door_frame.material_override = mat_trim
	house_node.add_child(door_frame)
	
	var door = MeshInstance.new()
	door.mesh = CubeMesh.new()
	door.mesh.size = Vector3(1.6, 3.2, 0.1)
	door.translation = Vector3(0, 2.3, 4.05)
	door.material_override = mat_wood_dark
	house_node.add_child(door)
	
	var knob = MeshInstance.new()
	var sph = SphereMesh.new()
	sph.radius = 0.08; sph.height = 0.16
	knob.mesh = sph
	knob.translation = Vector3(0.5, 2.3, 4.15)
	var gold = SpatialMaterial.new()
	gold.albedo_color = Color(0.8, 0.6, 0.2); gold.metallic = 1.0; gold.roughness = 0.2
	knob.material_override = gold
	house_node.add_child(knob)

	# 7. VENTANAS DETALLADAS (Corrección de vidrios y Atico circular)
	var win_configs = [
		{"pos": Vector3(-2.8, 5.8, 4.1), "rot": 0, "shutters": true, "w": 1.6, "h": 2.0},
		{"pos": Vector3(2.8, 5.8, 4.1), "rot": 0, "shutters": true, "w": 1.6, "h": 2.0},
		{"pos": Vector3(-5.1, 4.8, 0.0), "rot": 90, "shutters": true, "w": 1.6, "h": 2.0},
		{"pos": Vector3(5.1, 4.8, 0.0), "rot": -90, "shutters": true, "w": 1.6, "h": 2.0}, # Rotación corregida
		{"pos": Vector3(0, 8.2, 4.6), "rot": 0, "shutters": false, "w": 1.1, "h": 1.1, "round": true} # Atico corregido offset
	]
	
	for cfg in win_configs:
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
			cyl.top_radius = ww * 0.5; cyl.bottom_radius = ww * 0.5; cyl.height = 0.05
			glass.mesh = cyl
			glass.rotation_degrees.x = 90
		else:
			glass.mesh = CubeMesh.new()
			glass.mesh.size = Vector3(ww, wh, 0.05)
		glass.material_override = mat_window
		w_node.add_child(glass)
		
		# Marco de la ventana
		var frame = MeshInstance.new()
		if is_round:
			var f_cyl = CylinderMesh.new()
			f_cyl.top_radius = ww * 0.55; f_cyl.bottom_radius = ww * 0.55; f_cyl.height = 0.1
			frame.mesh = f_cyl
			frame.rotation_degrees.x = 90
			frame.translation.z = -0.04
		else:
			frame.mesh = CubeMesh.new()
			frame.mesh.size = Vector3(ww + 0.2, wh + 0.2, 0.1)
			frame.translation.z = -0.04
		frame.material_override = mat_trim
		w_node.add_child(frame)
		
		# Cruceta (+)
		var cross_h = MeshInstance.new()
		cross_h.mesh = CubeMesh.new(); cross_h.mesh.size = Vector3(ww, 0.08, 0.1)
		cross_h.material_override = mat_trim
		w_node.add_child(cross_h)
		
		var cross_v = MeshInstance.new()
		cross_v.mesh = CubeMesh.new(); cross_v.mesh.size = Vector3(0.08, wh, 0.1)
		cross_v.material_override = mat_trim
		w_node.add_child(cross_v)
		
		if cfg.shutters:
			for side in [-1, 1]:
				var shutter = MeshInstance.new()
				shutter.mesh = CubeMesh.new()
				shutter.mesh.size = Vector3(0.8, wh, 0.05)
				shutter.translation = Vector3(side * (ww*0.5 + 0.5), 0, 0)
				shutter.material_override = mat_shutter
				w_node.add_child(shutter)

	# 8. CHIMENEA TRABAJADA
	var chimney = MeshInstance.new()
	chimney.mesh = CubeMesh.new()
	chimney.mesh.size = Vector3(1.4, 6, 1.4)
	chimney.translation = Vector3(3.5, 9, -2)
	chimney.material_override = mat_base # Estilo piedra
	house_node.add_child(chimney)
	
	var chim_top = MeshInstance.new()
	chim_top.mesh = CubeMesh.new()
	chim_top.mesh.size = Vector3(1.6, 0.3, 1.6)
	chim_top.translation = Vector3(3.5, 12, -2)
	chim_top.material_override = mat_trim
	house_node.add_child(chim_top)

	# --- COLISIONES ---
	_add_house_collision(house_node)

func _add_house_collision(house_node):
	var sb = StaticBody.new()
	house_node.add_child(sb)
	
	# Cuerpo (incluyendo base)
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
	
	# Tejado (simplificado con otra caja o cuña si se prefiere, aquí caja alta)
	var cs_roof = CollisionShape.new()
	var shape_roof = BoxShape.new()
	shape_roof.extents = Vector3(5.5, 1.5, 4.5)
	cs_roof.shape = shape_roof
	cs_roof.translation = Vector3(0, 8.5, 0)
	sb.add_child(cs_roof)

func _add_stable(container, shared_res):
	var stable_node = Spatial.new()
	# Ubicación: Esquina opuesta a la casa (18, 18)
	stable_node.translation = Vector3(18.0, 2.0, 18.0)
	stable_node.rotation_degrees.y = 225.0
	container.add_child(stable_node)
	
	var mat_wood = shared_res.get("wood_mat")
	var mat_roof = SpatialMaterial.new()
	mat_roof.albedo_color = Color(0.35, 0.2, 0.15) # Tejo más rústico
	mat_roof.roughness = 0.8
	
	# 1. POSTES PRINCIPALES (Estructura abierta)
	var post_mesh = CubeMesh.new()
	post_mesh.size = Vector3(0.5, 5, 0.5)
	
	var posts_pos = [
		Vector3(-5, 2.5, -4), Vector3(5, 2.5, -4),
		Vector3(-5, 2.5, 4), Vector3(5, 2.5, 4),
		Vector3(0, 2.5, -4)
	]
	
	for p_pos in posts_pos:
		var p = MeshInstance.new()
		p.mesh = post_mesh
		p.translation = p_pos
		p.material_override = mat_wood
		stable_node.add_child(p)
		
	# 2. TECHO (Gran cobertizo)
	var roof = MeshInstance.new()
	var prism = PrismMesh.new()
	prism.size = Vector3(12, 3, 10)
	roof.mesh = prism
	roof.translation = Vector3(0, 6.5, 0)
	roof.material_override = mat_roof
	stable_node.add_child(roof)
	
	# 3. BARANDAS BAJAS (Tranqueras laterales)
	var rail_mesh = CubeMesh.new()
	rail_mesh.size = Vector3(5, 0.2, 0.2)
	
	var rails_configs = [
		# Lateral Izquierdo
		{"pos": Vector3(-5, 0.8, 0), "rot": 90, "size": Vector3(8, 0.2, 0.2)},
		{"pos": Vector3(-5, 1.8, 0), "rot": 90, "size": Vector3(8, 0.2, 0.2)},
		# Trasera
		{"pos": Vector3(0, 0.8, -4), "rot": 0, "size": Vector3(10, 0.2, 0.2)},
		{"pos": Vector3(0, 1.8, -4), "rot": 0, "size": Vector3(10, 0.2, 0.2)},
		# Lateral Derecho
		{"pos": Vector3(5, 0.8, 0), "rot": 90, "size": Vector3(8, 0.2, 0.2)},
		{"pos": Vector3(5, 1.8, 0), "rot": 90, "size": Vector3(8, 0.2, 0.2)}
	]
	
	for r_cfg in rails_configs:
		var r = MeshInstance.new()
		r.mesh = CubeMesh.new()
		r.mesh.size = r_cfg.size
		r.translation = r_cfg.pos
		r.rotation_degrees.y = r_cfg.rot
		r.material_override = mat_wood
		stable_node.add_child(r)
		
	# 4. COMEDERO DIVIDIDO (2 compartimentos)
	var mat_trough = SpatialMaterial.new()
	mat_trough.albedo_color = Color(0.2, 0.15, 0.1)
	
	var mat_hay = SpatialMaterial.new()
	mat_hay.albedo_color = Color(0.8, 0.7, 0.2)
	
	for side in [-1, 1]:
		var trough = MeshInstance.new()
		trough.mesh = CubeMesh.new()
		trough.mesh.size = Vector3(3.5, 0.8, 1.2)
		trough.translation = Vector3(side * 2.2, 0.4, -3.2)
		trough.material_override = mat_trough
		stable_node.add_child(trough)
		
		# Paja
		var hay = MeshInstance.new()
		hay.mesh = CubeMesh.new()
		hay.mesh.size = Vector3(3.3, 0.2, 1.0)
		hay.translation = Vector3(side * 2.2, 0.85, -3.2)
		hay.material_override = mat_hay
		stable_node.add_child(hay)
		
	# Divisor central
	var divider = MeshInstance.new()
	divider.mesh = CubeMesh.new()
	divider.mesh.size = Vector3(0.5, 1.2, 1.4)
	divider.translation = Vector3(0, 0.6, -3.2)
	divider.material_override = mat_wood
	stable_node.add_child(divider)

	# 5. COLISIONES DEL ESTABLO
	_add_stable_collision(stable_node)

func _add_stable_collision(stable_node):
	var sb = StaticBody.new()
	stable_node.add_child(sb)
	
	# Colisiones de los 3 lados cerrados por barandas
	var col_configs = [
		{"pos": Vector3(-5, 1.5, 0), "size": Vector3(0.5, 3.0, 8)}, # Izq
		{"pos": Vector3(5, 1.5, 0), "size": Vector3(0.5, 3.0, 8)},  # Der
		{"pos": Vector3(0, 1.5, -4), "size": Vector3(10, 3.0, 0.5)} # Tras
	]
	
	for c in col_configs:
		var cs = CollisionShape.new()
		var shape = BoxShape.new()
		shape.extents = c.size * 0.5
		cs.shape = shape
		cs.translation = c.pos
		sb.add_child(cs)
	
	# Colisión del comedero dividido
	for side in [-1, 1]:
		var cs_t = CollisionShape.new()
		var shape_t = BoxShape.new()
		shape_t.extents = Vector3(1.75, 0.4, 0.6)
		cs_t.shape = shape_t
		cs_t.translation = Vector3(side * 2.2, 0.4, -3.2)
		sb.add_child(cs_t)
	
	var cs_div = CollisionShape.new()
	var shape_div = BoxShape.new()
	shape_div.extents = Vector3(0.25, 0.6, 0.7)
	cs_div.shape = shape_div
	cs_div.translation = Vector3(0, 0.6, -3.2)
	sb.add_child(cs_div)

func _add_fence_collisions(container):
	var half = 33.0
	var height = 3.0
	var thickness = 1.0
	var y_center = 2.0 + height/2.0
	
	# Norte (Z = -33) - Completo (-33 a 33 en X)
	_add_col_box(container, Vector3(0, y_center, -half), Vector3(half*2, height, thickness))
	
	# Sur (Z = 33) - Completo
	_add_col_box(container, Vector3(0, y_center, half), Vector3(half*2, height, thickness))
	
	# Oeste (X = -33) - Con hueco en Z (-6 a 6)
	# Muro 1: Z < -6 (De -33 a -6 -> Centro -19.5, Largo 27)
	_add_col_box(container, Vector3(-half, y_center, -19.5), Vector3(thickness, height, 27.0))
	# Muro 2: Z > 6 (De 6 a 33 -> Centro 19.5, Largo 27)
	_add_col_box(container, Vector3(-half, y_center, 19.5), Vector3(thickness, height, 27.0))
	
	# Este (X = 33) - Con hueco en Z (-6 a 6)
	_add_col_box(container, Vector3(half, y_center, -19.5), Vector3(thickness, height, 27.0))
	_add_col_box(container, Vector3(half, y_center, 19.5), Vector3(thickness, height, 27.0))

func _add_col_box(parent, pos, size):
	var sb = StaticBody.new()
	var cs = CollisionShape.new()
	var shape = BoxShape.new()
	shape.extents = size * 0.5
	cs.shape = shape
	sb.add_child(cs)
	sb.translation = pos
	parent.add_child(sb)


func _rebuild_mesh_and_physics(mesh_instance, shared_res, is_spawn, grid_res = GRID_RES_HIGH, lod_level = TileLOD.HIGH):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var h_noise = shared_res["height_noise"]
	var b_noise = shared_res["biome_noise"]
	var hn = shared_res["H_SNOW"]; var hs = shared_res["H_JUNGLE"]
	var he = shared_res["H_DESERT"]; var hw = shared_res["H_PRAIRIE"]
	
	var step = TILE_SIZE / grid_res
	var offset = TILE_SIZE / 2.0
	
	var fixed_noise = null
	if is_spawn:
		fixed_noise = OpenSimplexNoise.new()
		fixed_noise.seed = 1337
		fixed_noise.period = 60.0 # Match consistency
	
	var world_manager = get_parent()
	
	for z in range(grid_res + 1):
		var lz = (z * step) - offset
		var gz = translation.z + lz
		
		for x in range(grid_res + 1):
			var lx = (x * step) - offset
			var gx = translation.x + lx
			
			var noise_val = b_noise.get_noise_2d(gx, gz)
			var deg = rad2deg(atan2(gz, gx)) + (noise_val * 120.0)
			
			var blend = 0.0
			if is_spawn:
				var dist = max(abs(lx), abs(lz))
				blend = clamp(1.0 - (dist - 33.0) / 20.0, 0.0, 1.0)
				if abs(translation.x) < 1.0 and abs(translation.z) < 1.0:
					deg = rad2deg(lerp_angle(deg2rad(deg), deg2rad(180.0), blend))
			
			while deg > 180: deg -= 360
			while deg <= -180: deg += 360
			
			var wr = 0.0; var wg = 0.0; var wb = 0.0; var wa = 0.0
			var h_mult = 0.0
			
			# Biome weights math (Slightly faster without too many branches)
			if deg >= -90 and deg <= 0:
				var t = (deg + 90) / 90.0
				wb = 1.0 - t; wg = t; h_mult = lerp(hn, he, t)
			elif deg > 0 and deg <= 90:
				var t = deg / 90.0
				wg = 1.0 - t; wa = t; h_mult = lerp(he, hs, t)
			elif deg > 90 and deg <= 180:
				var t = (deg - 90) / 90.0
				wa = 1.0 - t; wr = t; h_mult = lerp(hs, hw, t)
			else:
				var t = (deg + 180) / 90.0
				wr = 1.0 - t; wb = t; h_mult = lerp(hw, hn, t)
			
			if is_spawn and abs(translation.x) < 1.0 and abs(translation.z) < 1.0:
				var tex_n = fixed_noise.get_noise_2d(gx * 8.0, gz * 8.0)
				var patch_mix = clamp((tex_n + 0.2) * 3.0, 0.0, 1.0) 
				wr = lerp(wr, patch_mix, blend)
				wg = lerp(wg, 1.0 - patch_mix, blend)
				wb = lerp(wb, 0.0, blend)
				wa = lerp(wa, 0.0, blend)
			
			var y = h_noise.get_noise_2d(gx, gz) * h_mult
			if is_spawn: 
				y = lerp(y, 2.0, blend)
			
			var road_info = world_manager.get_road_influence(gx, gz)
			if road_info.is_road:
				y = lerp(y, road_info.height, road_info.weight)
				var road_w = road_info.weight
				if road_w > 0.1:
					wr = lerp(wr, 0.4, road_w); wg = lerp(wg, 0.6, road_w)
					wb = lerp(wb, 0.0, road_w); wa = lerp(wa, 0.0, road_w)
					
			var v = Vector3(lx, y, lz)
			st.add_color(Color(wr, wg, wb, wa))
			st.add_uv(Vector2(x / float(grid_res), z / float(grid_res)))
			st.add_vertex(v)
		
		# OPTIMIZACIÓN: Solo yield en HIGH LOD para evitar paroneos
		# En LOW LOD queremos que sea instantáneo para el horizonte
		if lod_level == TileLOD.HIGH and z % 6 == 0:
			yield(get_tree(), "idle_frame")
			if not is_instance_valid(self): return

	# Indices
	for z in range(grid_res):
		for x in range(grid_res):
			var i = x + z * (grid_res + 1)
			st.add_index(i); st.add_index(i + 1); st.add_index(i + grid_res + 1)
			st.add_index(i + 1); st.add_index(i + grid_res + 2); st.add_index(i + grid_res + 1)
			
	st.generate_normals()
	var new_mesh = st.commit()
	mesh_instance.mesh = new_mesh
	
	# PHYSICS OPTIMIZATION: Use static collision only if needed
	if lod_level == TileLOD.HIGH or is_spawn:
		yield(get_tree(), "idle_frame") # Extra wait
		if not is_instance_valid(self): return
		
		var collision_shape = get_node_or_null("CollisionShape")
		if not collision_shape:
			collision_shape = CollisionShape.new()
			collision_shape.name = "CollisionShape"
			add_child(collision_shape)
		
		# trimesh is heavy, can we simplify? 
		# For теперь we keep it but ensure it's the last thing done.
		collision_shape.shape = new_mesh.create_trimesh_shape()

func _add_decos_final(deco_container, shared_res, is_spawn):
	# Limpieza previa
	for child in deco_container.get_children():
		child.queue_free()
		
	seed(int(translation.x) + int(translation.z) + 123)
	var tree_instances = []
	var cactus_instances = []
	
	# OPTIMIZACIÓN: Grid balanceado (10x10) para capturar bordes de camino
	# Con grid_size 6 (25m entre muestras), es muy probable saltarse los bordes de la carretera (15m de ancho)
	var grid_size = 10 
	var spacing = TILE_SIZE / grid_size
	
	for x in range(grid_size):
		for z in range(grid_size):
			
			var lx = (x * spacing) - 75.0 + rand_range(-2, 2)
			var lz = (z * spacing) - 75.0 + rand_range(-2, 2)
			var gx = translation.x + lx
			var gz = translation.z + lz
			
			var noise_val = shared_res["biome_noise"].get_noise_2d(gx, gz)
			var deg = rad2deg(atan2(gz, gx)) + (noise_val * 120.0) # Unified with terrain math (120.0)
			
			if is_spawn:
				var dist = max(abs(lx), abs(lz))
				var blend_s = clamp(1.0 - (dist - 33.0) / 20.0, 0.0, 1.0)
				
				# Only start tile has mandatory Prairie biome
				if abs(translation.x) < 1.0 and abs(translation.z) < 1.0:
					deg = lerp_angle(deg2rad(deg), deg2rad(180.0), blend_s)
					deg = rad2deg(deg)
			
			while deg > 180: deg -= 360
			while deg <= -180: deg += 360
			
			var type = Biome.PRAIRIE
			if deg > -135 and deg <= -45: type = Biome.SNOW
			elif deg > 45 and deg <= 135: type = Biome.JUNGLE
			elif deg > -45 and deg <= 45: type = Biome.DESERT
			
			# DENSIDAS POR BIOMA (Ajustada para rendimiento)
			var spawn_chance = 0.20 # Antes 0.25
			if type == Biome.JUNGLE: spawn_chance = 0.6 # Antes 0.7
			elif type == Biome.DESERT: spawn_chance = 0.10 # Antes 0.12
			
			if is_spawn:
				var dist = max(abs(lx), abs(lz))
				if dist < 33.0: continue # Limpiar interior de la cerca
				
				# Bonus de densidad para el perímetro (efecto seto)
				if dist < 43.0:
					spawn_chance = 0.95
			
			if randf() > spawn_chance: continue
			
			var h_mult = 0.0
			if deg >= -90 and deg <= 0: h_mult = lerp(shared_res["H_SNOW"], shared_res["H_DESERT"], (deg + 90) / 90.0)
			elif deg > 0 and deg <= 90: h_mult = lerp(shared_res["H_DESERT"], shared_res["H_JUNGLE"], deg / 90.0)
			elif deg > 90 and deg <= 180: h_mult = lerp(shared_res["H_JUNGLE"], shared_res["H_PRAIRIE"], (deg - 90) / 90.0)
			else: h_mult = lerp(shared_res["H_PRAIRIE"], shared_res["H_SNOW"], (deg + 180) / 90.0)
			
			var y_h = shared_res["height_noise"].get_noise_2d(gx, gz) * h_mult
			
			# --- SETTLEMENT FLATTENING ---
			if is_spawn:
				var dist = max(abs(lx), abs(lz))
				var blend_s = clamp(1.0 - (dist - 33.0) / 20.0, 0.0, 1.0)
				var spawn_y = 2.0 # EXACT match with terrain flattening
				y_h = lerp(y_h, spawn_y, blend_s)
			
			# --- ROAD INFLUENCE ---
			var road_info = get_parent().get_road_influence(gx, gz)
			if road_info.is_road:
				y_h = lerp(y_h, road_info.height, road_info.weight)
			
			# LÓGICA DE ÁRBOLES EN EL BORDE DEL CAMINO
			var is_road_tree = false
			if road_info.dist < 20.0 and road_info.dist > 13.0: 
				# Solo poner árboles si el terreno no es agua
				if y_h > -6.0:
					# Espaciado determinista basado en la posición en el mundo
					var tree_spacing = 15.0 # Un poco más cerca (antes 18)
					var grid_gx = round(gx / tree_spacing) * tree_spacing
					var grid_gz = round(gz / tree_spacing) * tree_spacing
					
					# Si estamos cerca de un nodo de la cuadrícula, intentamos spawnear
					if Vector2(gx, gz).distance_to(Vector2(grid_gx, grid_gz)) < 8.0:
						# Usar un hash simple para decidir si este nodo específico tiene árbol (90% chance)
						var node_hash = (int(grid_gx) * 31 + int(grid_gz) * 97) % 100
						if node_hash < 90:
							is_road_tree = true
							type = Biome.JUNGLE
			
			# Don't spawn random objects on the road, but allow our "road trees"
			if not is_road_tree and road_info.is_road and road_info.weight > 0.3:
				continue
			
			if not is_road_tree and randf() > spawn_chance: continue
			
			if y_h < -7.0: continue
			
			var tf = Transform().rotated(Vector3.RIGHT, deg2rad(-90))
			tf = tf.rotated(Vector3.UP, rand_range(0, TAU))
			
			if type == Biome.JUNGLE and shared_res["tree_parts"].size() > 0:
				var s = rand_range(1.0, 2.0)
				tf = tf.scaled(Vector3(s, s, s))
				tf.origin = Vector3(lx, y_h - 1.1, lz)
				tree_instances.append(tf)
			elif type == Biome.DESERT and shared_res["cactus_parts"].size() > 0:
				var s = rand_range(0.7, 1.4)
				tf = tf.scaled(Vector3(s, s, s))
				tf.origin = Vector3(lx, y_h + 1.3, lz)
				cactus_instances.append(tf)

	if tree_instances.size() > 0:
		yield(get_tree(), "idle_frame")
		if not is_instance_valid(self): return
		_apply_mmi_final(deco_container, shared_res["tree_parts"], tree_instances, "tree_mmi")
		
	if cactus_instances.size() > 0:
		yield(get_tree(), "idle_frame")
		if not is_instance_valid(self): return
		_apply_mmi_final(deco_container, shared_res["cactus_parts"], cactus_instances, "cactus_mmi")
	
	# AGREGAR ANIMALES (Escalonado)
	_add_animals(deco_container, shared_res)

func _add_animals(container, shared_res):
	seed(int(translation.x) * 73 + int(translation.z) * 31)
	
	var b_noise = shared_res["biome_noise"]
	var noise_val = b_noise.get_noise_2d(translation.x, translation.z)
	var deg = rad2deg(atan2(translation.z, translation.x)) + (noise_val * 120.0)
	
	while deg > 180: deg -= 360
	while deg <= -180: deg += 360
	
	if deg > 135 or deg <= -135: # PRAIRIE
		if randf() < 0.12: # OPTIMIZADO: Reducido de 0.25 para menos entidades en móviles
			var cow_scene = shared_res["cow_scene"]
			if cow_scene:
				var count = randi() % 2 + 1 # Grupos más pequeños (1-2 en lugar de 2-4)
				for _i in range(count):
					yield(get_tree(), "idle_frame")
					if not is_instance_valid(self): return
					var cow = cow_scene.instance()
					var pos = Vector3(rand_range(-35, 35), 0, rand_range(-35, 35))
					var gx = translation.x + pos.x
					var gz = translation.z + pos.z
					cow.translation = pos + Vector3(0, shared_res["height_noise"].get_noise_2d(gx, gz) * shared_res["H_PRAIRIE"] + 0.5, 0)
					container.add_child(cow)
	
	elif deg > -135 and deg <= -45: # SNOW
		if randf() < 0.10: # OPTIMIZADO: Reducido de 0.20
			var goat_scene = shared_res["goat_scene"]
			if goat_scene:
				var count = randi() % 2 + 1 # Reducido de 3+1
				for _i in range(count):
					yield(get_tree(), "idle_frame")
					if not is_instance_valid(self): return
					var goat = goat_scene.instance()
					var pos = Vector3(rand_range(-40, 40), 0, rand_range(-40, 40))
					var gx = translation.x + pos.x
					var gz = translation.z + pos.z
					goat.translation = pos + Vector3(0, shared_res["height_noise"].get_noise_2d(gx, gz) * shared_res["H_SNOW"] + 0.5, 0)
					container.add_child(goat)

func mark_instance_as_harvested(group_name, index):
	if not harvested_instances.has(group_name):
		harvested_instances[group_name] = []
	if not index in harvested_instances[group_name]:
		harvested_instances[group_name].append(index)

func _apply_mmi_final(container, parts, instances, group_name = ""):
	if instances.size() == 0: return
	
	# Verificar qué instancias de este grupo ya han sido cosechadas
	var dead_list = []
	if group_name != "" and harvested_instances.has(group_name):
		dead_list = harvested_instances[group_name]
	
	for part in parts:
		var mmi = MultiMeshInstance.new()
		if group_name != "":
			mmi.add_to_group(group_name)
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part.mesh
		mm.instance_count = instances.size()
		for i in range(instances.size()):
			var tf = instances[i]
			# Si esta instancia fue talada, la hacemos invisible (Escala 0)
			if i in dead_list:
				tf = tf.scaled(Vector3.ZERO)
			mm.set_instance_transform(i, tf)
		mmi.multimesh = mm
		if part.mat: mmi.material_override = part.mat
		mmi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON
		container.add_child(mmi)
