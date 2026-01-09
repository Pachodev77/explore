extends StaticBody

enum Biome { PRAIRIE, DESERT, SNOW, JUNGLE }
enum TileLOD { HIGH, LOW }

# Configuración del plano
# LOD System: LOW = 4 res, no physics, no decos. HIGH = 12 res, full.
const GRID_RES_HIGH = 12
const GRID_RES_LOW = 4
const TILE_SIZE = 150.0

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
	
	var verts = []
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

	# Aplicar MultiMeshes de forma escalonada para evitar lag
	if tree_instances.size() > 0:
		yield(get_tree(), "idle_frame")
		if not is_instance_valid(self): return
		_apply_mmi_final(deco_container, shared_res["tree_parts"], tree_instances)
		
	if cactus_instances.size() > 0:
		yield(get_tree(), "idle_frame")
		if not is_instance_valid(self): return
		_apply_mmi_final(deco_container, shared_res["cactus_parts"], cactus_instances)
	
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
				for i in range(count):
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
				for i in range(count):
					yield(get_tree(), "idle_frame")
					if not is_instance_valid(self): return
					var goat = goat_scene.instance()
					var pos = Vector3(rand_range(-40, 40), 0, rand_range(-40, 40))
					var gx = translation.x + pos.x
					var gz = translation.z + pos.z
					goat.translation = pos + Vector3(0, shared_res["height_noise"].get_noise_2d(gx, gz) * shared_res["H_SNOW"] + 0.5, 0)
					container.add_child(goat)

func _apply_mmi_final(container, parts, instances):
	if instances.size() == 0: return
	for part in parts:
		var mmi = MultiMeshInstance.new()
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part.mesh
		mm.instance_count = instances.size()
		for i in range(instances.size()):
			mm.set_instance_transform(i, instances[i])
		mmi.multimesh = mm
		if part.mat: mmi.material_override = part.mat
		# Sombras activadas para vegetación (árboles y cactus)
		mmi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON
		container.add_child(mmi)
