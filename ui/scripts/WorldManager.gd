extends Spatial

# Configuración del mapa optimizada
export(PackedScene) var tile_scene = preload("res://ui/scenes/GroundTile.tscn")
export var tile_size = 150.0
export var render_distance = 4 # Más amplio para evitar ver el borde

onready var player = get_parent().get_node("Player")

var active_tiles = {}
var spawn_queue = [] 

var noise = OpenSimplexNoise.new()
var height_noise = OpenSimplexNoise.new()
var biome_noise = OpenSimplexNoise.new()
var road_system = RoadSystem.new()
var last_player_tile = Vector2.INF
var update_timer = 0.0
var _lod_upgrade_timer = 0.0 # Timer para upgrades de LOD

var shared_res = {
	"ground_mat": ShaderMaterial.new(),
	"tree_parts": [],
	"cactus_parts": [],
	"rock_mesh": SphereMesh.new(),
	"rock_mat": SpatialMaterial.new(),
	"bush_mesh": CubeMesh.new(),
	"bush_mat": SpatialMaterial.new(),
	"height_noise": null,
	"biome_noise": null,
	"H_SNOW": GameConfig.H_SNOW,
	"H_JUNGLE": GameConfig.H_JUNGLE,
	"H_DESERT": GameConfig.H_DESERT,
	"H_PRAIRIE": GameConfig.H_PRAIRIE,
	"wood_mat": null, # Cached
	"sign_mat": null, # Cached
	"cow_scene": null,
	"goat_scene": null,
	"chicken_scene": null
}

var current_seed = 0
var beehive_harvests = {} # Persistencia de colmenas: { "global_pos_str": day_of_harvest }
var last_egg_harvest_day = 0 

# Object Pool
var tile_pool = []

func _ready():
	ServiceLocator.register_service("world", self)
	
	# Safety Check for exported variables
	if tile_size == null: tile_size = GameConfig.TILE_SIZE
	if render_distance == null: render_distance = GameConfig.RENDER_DISTANCE
	
	randomize()
	var common_seed = randi()
	var saved_data = null
	
	if ServiceLocator.has_service("save_manager"):
		var sm = ServiceLocator.get_save_manager()
		if sm.has_pending_load:
			saved_data = sm.get_pending_data()
			if saved_data and saved_data.has("world_seed"):
				common_seed = int(saved_data["world_seed"])
	
	current_seed = common_seed
	noise.seed = common_seed
	noise.octaves = 3
	noise.period = 15.0
	noise.persistence = 0.5
	
	height_noise.seed = common_seed + 1
	height_noise.octaves = 3
	height_noise.period = 60.0
	height_noise.persistence = 0.25
	
	biome_noise.seed = common_seed + 2
	biome_noise.octaves = 2
	biome_noise.period = 600.0
	biome_noise.persistence = 0.5
	
	shared_res["height_noise"] = height_noise
	shared_res["biome_noise"] = biome_noise
	
	road_system.init(common_seed, tile_size)
	setup_shared_resources()
	
	# Aplicar posición del jugador si hay carga
	if saved_data and saved_data.has("player_pos"):
		var p = saved_data["player_pos"]
		player.global_transform.origin = Vector3(p.x, p.y, p.z)
		if saved_data.has("player_rot_y"):
			player.rotation.y = saved_data["player_rot_y"]
		
		# Cargar Inventario
		if saved_data.has("inventory") and ServiceLocator.has_service("inventory"):
			ServiceLocator.get_inventory_manager().load_save_data(saved_data["inventory"])
		
		# Restaurar Rotación de Cámara y Dirección de Mirada
		if saved_data.has("player_cam_rot_x") and player.has_node("CameraPivot"):
			player.get_node("CameraPivot").rotation.x = saved_data["player_cam_rot_x"]
		if saved_data.has("player_look_dir"):
			player.look_dir = Vector2(saved_data["player_look_dir"].x, saved_data["player_look_dir"].y)
	else:
		# 1. Calcular altura exacta del terreno en (0,0) para spawn seguro
		var h_val = height_noise.get_noise_2d(0, 0)
		var b_noise_val = biome_noise.get_noise_2d(0, 0)
		var deg = rad2deg(atan2(0, 0)) + (b_noise_val * 120.0)
		var h_mult = GameConfig.H_PRAIRIE
		if deg > 45 and deg <= 135: h_mult = GameConfig.H_JUNGLE
		elif deg > -45 and deg <= 45: h_mult = GameConfig.H_DESERT
		elif deg > -135 and deg <= -45: h_mult = GameConfig.H_SNOW
		
		var spawn_y = h_val * h_mult + 5.0
		player.global_transform.origin = Vector3(0, spawn_y, 0)
	
	# 2. Desactivar física temporalmente para que no caiga mientras cargan los tiles
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	
	# 3. Generar área Inicial INMEDIATA (3x3)
	# CRÍTICO: Los tiles inmediatos deben ser LOD.HIGH (0) para tener física y no caer al vacío
	var p_coords = get_tile_coords(player.global_transform.origin)
	for x in range(int(p_coords.x) - 1, int(p_coords.x) + 2):
		for z in range(int(p_coords.y) - 1, int(p_coords.y) + 2):
			var is_player_tile = (x == int(p_coords.x) and z == int(p_coords.y))
			spawn_tile(x, z, 0 if is_player_tile else 1)
	
	# 4. ESPERAR a que la colisión del tile central esté lista
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame") # 2 frames son suficientes para el setup inicial
	
	last_player_tile = p_coords
	
	# NUEVO: El jugador permanece en pausa física hasta que world_ready se emita al final
	# de la secuencia de spawn.
	
	_start_spawn_sequence()

func _start_spawn_sequence():
	# Sin esperas arbitrarias
	
	# Shader Warmup (Renderizar materiales una vez fuera de cámara)
	_warmup_shaders()
	yield(get_tree(), "idle_frame")
	
	# Carga escalonada de animales iniciales
	var horse_scene = load("res://ui/scenes/Horse.tscn")
	var saved_data = null
	if ServiceLocator.get_save_manager().has_pending_load:
		saved_data = ServiceLocator.get_save_manager().get_pending_data()

	if horse_scene:
		yield(get_tree(), "idle_frame")
		if not is_instance_valid(self): return
		var horse = horse_scene.instance()
		add_child(horse)
		
		var h_pos = Vector3(10, 0, -10)
		var h_rot = 0.0
		var should_mount = false
		
		if saved_data and saved_data.has("is_riding") and saved_data["is_riding"]:
			if saved_data.has("horse_pos"):
				var hp = saved_data["horse_pos"]
				h_pos = Vector3(hp.x, hp.y, hp.z)
				should_mount = true
			if saved_data.has("horse_rot_y"):
				h_rot = saved_data["horse_rot_y"]
		
		var h_y = get_terrain_height_at(h_pos.x, h_pos.z)
		horse.global_transform.origin = Vector3(h_pos.x, h_y + 0.8, h_pos.z)
		horse.rotation.y = h_rot
		
		if should_mount:
			# Esperar un frame extra para que el caballo se asiente
			yield(get_tree(), "idle_frame")
			if is_instance_valid(player) and player.has_method("mount"):
				player.mount(horse)
		
	if shared_res["cow_scene"]:
		for i in range(2):
			var cow = shared_res["cow_scene"].instance()
			add_child(cow)
			cow.speed = 4.0
			var offset = 15 if i == 0 else -15
			var h = get_terrain_height_at(offset, -offset)
			cow.global_transform.origin = Vector3(offset, h + 0.8, -offset)
			cow.is_night_cow = true
			# Definir posición del establo (basado en StructureBuilder.add_stable)
			cow.night_target_pos = Vector3(18.0, 2.0, 18.0)
			cow.night_waypoint_pos = Vector3(18.0, 2.0, 10.0) # Frente a la entrada
		yield(get_tree(), "idle_frame")
			
	if shared_res["goat_scene"]:
		for i in range(3):
			var goat = shared_res["goat_scene"].instance()
			add_child(goat)
			var angle = i * (TAU / 3.0)
			var cluster_offset = Vector3(cos(angle), 0, sin(angle)) * 3.0
			var spawn_pos = Vector3(10, 0, 0) + cluster_offset
			var hg = get_terrain_height_at(spawn_pos.x, spawn_pos.z)
			goat.global_transform.origin = Vector3(spawn_pos.x, hg + 0.8, spawn_pos.z)
		yield(get_tree(), "idle_frame")
			
	if shared_res["chicken_scene"]:
		for i in range(4):
			var chicken = shared_res["chicken_scene"].instance()
			add_child(chicken)
			chicken.size_unit = 0.28
			var angle = i * (TAU / 4.0)
			var offset = Vector3(cos(angle), 0, sin(angle)) * 4.0
			var spawn_pos = Vector3(-18, 0, 18) + offset
			var hc = get_terrain_height_at(spawn_pos.x, spawn_pos.z)
			chicken.global_transform.origin = Vector3(spawn_pos.x, hc + 0.5, spawn_pos.z)
			chicken.is_night_chicken = true
			# Posición del gallinero (basado en StructureBuilder.add_chicken_coop)
			chicken.night_target_pos = Vector3(-18.0, 2.0, 18.0)
			chicken.night_waypoint_pos = Vector3(-18.0, 2.0, 14.0) # Frente a la rampa
		yield(get_tree(), "idle_frame")
	
	update_tiles()
	
	# Restaurar física del jugador al final de TODO (Garantiza suelo sólido)
	if is_instance_valid(player) and player.has_method("set_physics_process"):
		player.set_physics_process(true)
		
	GameEvents.emit_signal("world_ready")
	
	if ServiceLocator.has_service("save_manager"):
		ServiceLocator.get_save_manager().clear_pending_load()

func _warmup_shaders():
	# Crear un nodo temporal para forzar la compilación de shaders
	var cam = get_viewport().get_camera()
	if not cam: return
	
	var warmup_node = Spatial.new()
	warmup_node.translation = cam.global_transform.origin - cam.global_transform.basis.z * 2.0
	add_child(warmup_node)
	
	# Renderizar una esfera con cada material importante
	var mats = [
		shared_res["ground_mat"],
		shared_res["rock_mat"],
		shared_res["wood_mat"]
	]
	
	for mat in mats:
		if not mat: continue
		var mi = MeshInstance.new()
		mi.mesh = SphereMesh.new()
		mi.mesh.radius = 0.01 # Muy pequeño
		mi.material_override = mat
		warmup_node.add_child(mi)
	
	# Dejar que se renderice por 1 frame y luego borrar
	yield(get_tree(), "idle_frame")
	warmup_node.queue_free()

# ... (Previous code remains same until update_tiles loop) ...

func update_tiles():
	var p_pos = player.global_transform.origin
	var player_coords = get_tile_coords(p_pos)
	var new_active_coords = []
	var x_int = int(player_coords.x)
	var z_int = int(player_coords.y)
	

	# Clean re-implementation of update_tiles loop
	for x in range(x_int - render_distance, x_int + render_distance + 1):
		for z in range(z_int - render_distance, z_int + render_distance + 1):
			var coords = Vector2(x, z)
			new_active_coords.append(coords)
			
			if not active_tiles.has(coords):
				if not spawn_queue.has(coords):
					# Insertar al principio para priorizar cercanía si no hay ordenamiento
					spawn_queue.push_back(coords)
	
	# LIMPIEZA DE COLA
	var filtered_queue = []
	for c in spawn_queue:
		if abs(c.x - x_int) <= render_distance and abs(c.y - z_int) <= render_distance:
			filtered_queue.append(c)
	spawn_queue = filtered_queue
	
	# Ordenar por distancia solo si la cola es grande
	if spawn_queue.size() > 5:
		spawn_queue.sort_custom(self, "_sort_by_dist")
	
	# RECYCLE TILES (Pooling)
	var coords_to_remove = []
	for coords in active_tiles.keys():
		if not coords in new_active_coords:
			coords_to_remove.append(coords)
	
	for coords in coords_to_remove:
		var tile = active_tiles[coords]
		if is_instance_valid(tile):
			remove_child(tile)
			tile_pool.append(tile)
		active_tiles.erase(coords)

func _sort_by_dist(a, b):
	var p_coords = get_tile_coords(player.global_transform.origin)
	return a.distance_to(p_coords) < b.distance_to(p_coords)



func setup_shared_resources():
	# OPTIMIZACIÓN: preload = carga en compilación (instantáneo)
	# load = carga en runtime (bloquea 100-200ms)
	var shader = preload("res://ui/shaders/biome_blending.shader")
	shared_res["ground_mat"].shader = shader
	
	var t_grass = preload("res://ui/textures/grass.jpg")
	var t_sand = preload("res://ui/textures/sand.jpg")
	var t_snow = preload("res://ui/textures/snow.jpg")
	var t_jungle = preload("res://ui/textures/jungle.jpg")
	var t_gravel = preload("res://ui/textures/gravel.jpg")
	
	shared_res["ground_mat"].set_shader_param("grass_tex", t_grass)
	shared_res["ground_mat"].set_shader_param("sand_tex", t_sand)
	shared_res["ground_mat"].set_shader_param("snow_tex", t_snow)
	shared_res["ground_mat"].set_shader_param("jungle_tex", t_jungle)
	shared_res["ground_mat"].set_shader_param("gravel_tex", t_gravel)
	shared_res["ground_mat"].set_shader_param("uv_scale", 0.04)  # Escala optimizada para triplanar
	shared_res["ground_mat"].set_shader_param("triplanar_sharpness", 6.0)  # Suavidad de transición en pendientes
	
	var tree_scene = preload("res://ui/tree.glb")
	if tree_scene:
		var tree_inst = tree_scene.instance()
		shared_res["tree_parts"] = find_meshes_recursive(tree_inst)
		tree_inst.queue_free()
		
	var cactus_scene = preload("res://ui/cactus.glb")
	if cactus_scene:
		var cactus_inst = cactus_scene.instance()
		shared_res["cactus_parts"] = find_meshes_recursive(cactus_inst)
		cactus_inst.queue_free()
		
		# FIX: Desactivar emisión en materiales importados del cactus
		for part in shared_res["cactus_parts"]:
			if part and part.has("mat") and part.mat and part.mat is SpatialMaterial:
				part.mat.emission_enabled = false
				part.mat.flags_unshaded = false # Asegurar que reaccione a luz

	# CACHED MATERIALS (Fence)
	var wood_mat = SpatialMaterial.new()
	wood_mat.albedo_color = Color(0.4, 0.25, 0.1)
	wood_mat.roughness = 0.9
	shared_res["wood_mat"] = wood_mat
	
	var sign_mat = SpatialMaterial.new()
	sign_mat.albedo_color = Color(0.8, 0.7, 0.5)
	shared_res["sign_mat"] = sign_mat

	# CACHE ANIMAL SCENES
	shared_res["cow_scene"] = load("res://ui/scenes/Cow.tscn")
	shared_res["goat_scene"] = load("res://ui/scenes/Goat.tscn")
	shared_res["chicken_scene"] = load("res://ui/scenes/Chicken.tscn")

	create_water_plane()

func find_meshes_recursive(node, results = []):
	if node is MeshInstance:
		var mat = node.material_override
		if not mat:
			mat = node.get_surface_material(0)
		if not mat and node.mesh:
			mat = node.mesh.surface_get_material(0)
		results.append({"mesh": node.mesh, "mat": mat})
		
	for child in node.get_children():
		find_meshes_recursive(child, results)
	return results

func create_water_plane():
	var water_mesh = MeshInstance.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(tile_size * 8, tile_size * 8)
	plane.subdivide_depth = 15 # Aún más bajo para estabilidad
	plane.subdivide_width = 15
	
	water_mesh.mesh = plane
	water_mesh.name = "WaterPlane"
	add_child(water_mesh)
	
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://ui/shaders/water.shader")
	water_mesh.set_surface_material(0, mat)
	water_mesh.translation.y = -8.0

func _process(delta):
	var p_pos = player.global_transform.origin
	
	# OPTIMIZACIÓN: Solo chequear cambio de tile/LOD con intervalos más largos
	update_timer -= delta
	if update_timer <= 0:
		update_timer = 0.5 # 2 veces por segundo es suficiente
		var current_tile_coords = get_tile_coords(p_pos)
		if current_tile_coords.distance_to(last_player_tile) > 0.5:
			last_player_tile = current_tile_coords
			update_tiles()
	
	# LOD UPGRADE: Separado del update_tiles y con menor frecuencia
	_lod_upgrade_timer -= delta
	if _lod_upgrade_timer <= 0:
		_lod_upgrade_timer = 2.0 # Solo cada 2 segundos - muy costoso
		for coords in active_tiles.keys():
			var tile = active_tiles[coords]
			if tile.has_method("upgrade_to_high_lod") and tile.current_lod == tile.TileLOD.LOW:
				var dist = p_pos.distance_to(tile.global_transform.origin)
				if dist < 200.0: # Reducido aún más
					tile.upgrade_to_high_lod()
					break # Solo 1 por ciclo
 
	
	# SPAWN QUEUE: 1 tile por frame (reducido a 4 candidatos de búsqueda)
	if spawn_queue.size() > 0:
		var best_idx = 0
		var min_d = 99999.0
		for i in range(min(spawn_queue.size(), 4)): # Reducido de 8 a 4
			var d = p_pos.distance_to(Vector3(spawn_queue[i].x * tile_size, 0, spawn_queue[i].y * tile_size))
			if d < min_d:
				min_d = d
				best_idx = i
		
		var coords = spawn_queue[best_idx]
		spawn_queue.remove(best_idx)
		spawn_tile(int(coords.x), int(coords.y))
	
	# Agua (Cacheada para evitar get_node_or_null cada frame)
	if _cached_water == null:
		_cached_water = get_node_or_null("WaterPlane")
	if _cached_water:
		_cached_water.translation.x = p_pos.x
		_cached_water.translation.z = p_pos.z

var _cached_water = null

func spawn_tile(x, z, forced_lod = -1):
	var coords = Vector2(x, z)
	if active_tiles.has(coords): return
	
	var tile = null
	# Intentar reciclar del pool
	if tile_pool.size() > 0:
		tile = tile_pool.pop_back()
	else:
		tile = tile_scene.instance()
	
	tile.translation = Vector3(x * tile_size, 0, z * tile_size)
	tile.visible = true
	add_child(tile)
	
	var is_spawn = (x == 0 and z == 0) or road_system.is_settlement_tile(x, z)
	
	# LOD logic: 0 = HIGH (con física), 1 = LOW (sin física)
	var lod = forced_lod if forced_lod != -1 else 1
	
	if tile.has_method("setup_biome"):
		tile.setup_biome(0, shared_res, 0, is_spawn, lod)
	active_tiles[coords] = tile

func get_tile_coords(pos):
	# POSICIÓN GLOBAL: Usamos global_transform para ignorar el parentesco
	return Vector2(floor((pos.x + tile_size*0.5) / tile_size), floor((pos.z + tile_size*0.5) / tile_size))


func get_terrain_height_at(x, z):
	if not shared_res.has("biome_noise") or not shared_res.has("height_noise"):
		return 0.0
		
	var b_noise = shared_res["biome_noise"]
	var h_noise = shared_res["height_noise"]
	var noise_val = b_noise.get_noise_2d(x, z)
	var deg = rad2deg(atan2(z, x)) + (noise_val * 120.0)
	
	while deg > 180: deg -= 360
	while deg <= -180: deg += 360
	
	var hn = shared_res["H_SNOW"]; var hs = shared_res["H_JUNGLE"]
	var he = shared_res["H_DESERT"]; var hw = shared_res["H_PRAIRIE"]
	var h_mult = 0.0
	
	if deg >= -90 and deg <= 0:
		var t = (deg + 90) / 90.0
		h_mult = lerp(hn, he, t)
	elif deg > 0 and deg <= 90:
		var t = deg / 90.0
		h_mult = lerp(he, hs, t)
	elif deg > 90 and deg <= 180:
		var t = (deg - 90) / 90.0
		h_mult = lerp(hs, hw, t)
	else:
		var t = (deg + 180) / 90.0
		h_mult = lerp(hw, hn, t)
		
	var y = h_noise.get_noise_2d(x, z) * h_mult
	
	# Spawn Area flattening (Approximation of GroundTile logic)
	if abs(x) < 50 and abs(z) < 50:
		var dist = max(abs(x), abs(z))
		var blend = clamp(1.0 - (dist - 33.0) / 20.0, 0.0, 1.0)
		y = lerp(y, 2.0, blend)
		
	var road_info = road_system.get_road_influence(x, z)
	if road_info.is_road:
		y = lerp(y, road_info.height, road_info.weight)
		
	return y

# --- PROXY METHODS (Para compatibilidad con GroundTile y otros) ---
func is_settlement_tile(x: int, z: int) -> bool:
	return road_system.is_settlement_tile(x, z)

func get_road_influence(gx: float, gz: float) -> Dictionary:
	return road_system.get_road_influence(gx, gz)
