extends StaticBody

enum Biome { PRAIRIE, DESERT, SNOW, JUNGLE }
enum TileLOD { HIGH, LOW }

# Configuración del plano
# LOD System: LOW = 4 res, no physics, no decos. HIGH = 12 res, full.
const GRID_RES_HIGH = 16
const GRID_RES_LOW = 4
const TILE_SIZE = GameConfig.TILE_SIZE
var harvested_instances = {} # Persistencia de tala: { "tree_mmi": [indices], ... }

var current_lod = TileLOD.LOW
var current_shared_res = null
var current_is_spawn = false

# SISTEMA DE GENERACIÓN SEGURA (Anti-Crash)
var _generation_id = 0 # ID para abortar tareas asíncronas viejas

func setup_biome(_dummy_type, shared_resources, _dummy_height = 0, is_spawn = false, lod_level = TileLOD.LOW):
	_generation_id += 1
	var gid = _generation_id
	
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
	
	if not is_instance_valid(self) or gid != _generation_id: return
	visible = true
	
	# LOD_LOW: Skip decorations for speed
	if lod_level == TileLOD.HIGH:
		yield(get_tree(), "idle_frame")
		if not is_instance_valid(self) or gid != _generation_id: return
		
		var deco_state = _add_decos_final(deco_container, shared_resources, is_spawn)
		if deco_state is GDScriptFunctionState:
			yield(deco_state, "completed")
			
		if not is_instance_valid(self) or gid != _generation_id: return
		
		# Spawneo escalonado de estructuras (Función unificada)
		if is_spawn:
			var struct_state = _spawn_structures(deco_container, shared_resources, gid)
			if struct_state is GDScriptFunctionState:
				yield(struct_state, "completed")

# =============================================================================
# FUNCIÓN UNIFICADA DE ESTRUCTURAS (Evita duplicación de código)
# =============================================================================
func _spawn_structures(deco_container, shared_res, gid):
	yield(get_tree(), "idle_frame")
	if not is_instance_valid(self) or gid != _generation_id: return
	
	StructureBuilder.add_fence(deco_container, shared_res)
	
	# Estructuras del tile central (Granja principal)
	if abs(translation.x) < 1.0 and abs(translation.z) < 1.0:
		yield(get_tree(), "idle_frame")
		if not is_instance_valid(self) or gid != _generation_id: return
		StructureBuilder.add_farmhouse(deco_container, shared_res)
		
		yield(get_tree(), "idle_frame")
		if not is_instance_valid(self) or gid != _generation_id: return
		StructureBuilder.add_stable(deco_container, shared_res)
		
		yield(get_tree(), "idle_frame")
		if not is_instance_valid(self) or gid != _generation_id: return
		StructureBuilder.add_chicken_coop(deco_container, shared_res)
	else:
		# Estructuras de asentamientos remotos
		var wm = ServiceLocator.get_world_manager()
		if wm and wm.has_method("is_settlement_tile"):
			var tx = round(translation.x / TILE_SIZE)
			var tz = round(translation.z / TILE_SIZE)
			if wm.is_settlement_tile(int(tx), int(tz)):
				yield(get_tree(), "idle_frame")
				if not is_instance_valid(self) or gid != _generation_id: return
				
				# Determinar tipo de estructura por ubicación
				if abs(translation.x - 600.0) < 1.0 and abs(translation.z) < 1.0:
					StructureBuilder.add_market_base(deco_container, shared_res)
				elif abs(translation.x + 600.0) < 1.0 and abs(translation.z) < 1.0:
					StructureBuilder.add_livestock_fair(deco_container, shared_res)
				elif abs(translation.x) < 1.0 and abs(translation.z + 600.0) < 1.0:
					StructureBuilder.add_mine_base(deco_container, shared_res)

func upgrade_to_high_lod():
	if current_lod == TileLOD.HIGH: return
	if current_shared_res == null: return
	
	_generation_id += 1
	var gid = _generation_id
	
	current_lod = TileLOD.HIGH
	var mesh_instance = get_node_or_null("MeshInstance")
	var deco_container = get_node_or_null("Decos")
	if not mesh_instance or not deco_container: return
	
	var state = _rebuild_mesh_and_physics(mesh_instance, current_shared_res, current_is_spawn, GRID_RES_HIGH, TileLOD.HIGH)
	if state is GDScriptFunctionState:
		yield(state, "completed")
	
	if not is_instance_valid(self) or gid != _generation_id: return
	
	yield(get_tree(), "idle_frame")
	if not is_instance_valid(self) or gid != _generation_id: return
	
	var deco_state = _add_decos_final(deco_container, current_shared_res, current_is_spawn)
	if deco_state is GDScriptFunctionState:
		yield(deco_state, "completed")
	
	if not is_instance_valid(self) or gid != _generation_id: return
	
	if current_is_spawn:
		var struct_state = _spawn_structures(deco_container, current_shared_res, gid)
		if struct_state is GDScriptFunctionState:
			yield(struct_state, "completed")

func _rebuild_mesh_and_physics(mesh_instance, shared_res, is_spawn, grid_res = GRID_RES_HIGH, lod_level = TileLOD.HIGH):
	var gid = _generation_id
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Smooth groups ensure vertex normal sharing
	st.add_smooth_group(true)
	
	var h_noise = shared_res["height_noise"]
	var b_noise = shared_res["biome_noise"]
	var hn = GameConfig.H_SNOW; var hs = GameConfig.H_JUNGLE
	var he = GameConfig.H_DESERT; var hw = GameConfig.H_PRAIRIE
	
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
			
			# Mejora de Realismo: Micro-detalle en la altura (Ruido secundario)
			y += b_noise.get_noise_2d(gx * 8.0, gz * 8.0) * 0.4 
			
			if is_spawn: 
				y = lerp(y, 2.0, blend)
			
			var road_info = world_manager.get_road_influence(gx, gz)
			var road_w_val = 0.0
			if road_info.is_road:
				y = lerp(y, road_info.height, road_info.weight)
				road_w_val = road_info.weight
					
			# Mejora de Realismo: Vertex Jitter para romper la cuadrícula
			# No aplicamos jitter en los bordes para mantener la costura entre tiles perfecta
			var jitter_x = 0.0
			var jitter_z = 0.0
			if x > 0 and x < grid_res and z > 0 and z < grid_res:
				var j_noise = b_noise.get_noise_2d(gx * 5.0, gz * 5.0)
				jitter_x = j_noise * step * 0.45
				jitter_z = h_noise.get_noise_2d(gz * 5.0, gx * 5.0) * step * 0.45
					
			var v = Vector3(lx + jitter_x, y, lz + jitter_z)
			st.add_color(Color(wr, wg, wb, wa))
			st.add_uv(Vector2(x / float(grid_res), z / float(grid_res)))
			st.add_uv2(Vector2(road_w_val, 0)) # Pasar el peso del camino al shader
			st.add_vertex(v)
		
		# OPTIMIZACIÓN: Solo yield en HIGH LOD para evitar paroneos
		# En LOW LOD queremos que sea instantáneo para el horizonte
		if lod_level == TileLOD.HIGH and z % 6 == 0:
			yield(get_tree(), "idle_frame")
			if not is_instance_valid(self) or gid != _generation_id: return

	# Indices
	for z in range(grid_res):
		for x in range(grid_res):
			var i = x + z * (grid_res + 1)
			st.add_index(i); st.add_index(i + 1); st.add_index(i + grid_res + 1)
			st.add_index(i + 1); st.add_index(i + grid_res + 2); st.add_index(i + grid_res + 1)
			
	st.generate_normals()
	var new_mesh = st.commit()
	mesh_instance.mesh = new_mesh
	
	# PHYSICS: Usar trimesh para colisiones precisas en HIGH LOD
	if lod_level == TileLOD.HIGH or is_spawn:
		yield(get_tree(), "idle_frame")
		if not is_instance_valid(self) or gid != _generation_id: return
		
		var collision_shape = get_node_or_null("CollisionShape")
		if not collision_shape:
			collision_shape = CollisionShape.new()
			collision_shape.name = "CollisionShape"
			add_child(collision_shape)
		
		# Trimesh para colisiones precisas con el terreno
		collision_shape.shape = new_mesh.create_trimesh_shape()

func _add_decos_final(deco_container, shared_res, is_spawn):
	var gid = _generation_id
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
		# OPTIMIZACIÓN: Yield cada fila de la cuadrícula de decoración
		if x % 2 == 0:
			yield(get_tree(), "idle_frame")
			if not is_instance_valid(self) or gid != _generation_id: return
			
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

func _add_animals(container, shared_res):
	var world_manager = get_parent()
	if not world_manager: return
	
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
					var h = world_manager.get_terrain_height_at(gx, gz)
					cow.translation = pos + Vector3(0, h + 0.5, 0)
					container.add_child(cow)
	
	elif deg > -135 and deg <= -45: # SNOW
		if randf() < 0.10: 
			var goat_scene = shared_res["goat_scene"]
			if goat_scene:
				var count = randi() % 3 + 2 # Grupos de 2 a 4 cabras
				var center_pos = Vector3(rand_range(-30, 30), 0, rand_range(-30, 30))
				for i in range(count):
					yield(get_tree(), "idle_frame")
					if not is_instance_valid(self): return
					var goat = goat_scene.instance()
					# Spawn en cluster (radio de 4 metros)
					var angle = i * (TAU / count)
					var cluster = Vector3(cos(angle), 0, sin(angle)) * rand_range(2, 4)
					var pos = center_pos + cluster
					var gx = translation.x + pos.x
					var gz = translation.z + pos.z
					var h = world_manager.get_terrain_height_at(gx, gz)
					goat.translation = pos + Vector3(0, h + 0.5, 0)
					container.add_child(goat)

func mark_instance_as_harvested(group_name, index):
	if not harvested_instances.has(group_name):
		harvested_instances[group_name] = []
	if not index in harvested_instances[group_name]:
		harvested_instances[group_name].append(index)
