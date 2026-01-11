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
var road_system = RoadSystem.new() # Nuevo Sistema Vial Modular
var last_player_tile = Vector2.INF
var update_timer = 0.0
var _lod_upgrade_timer = 0.0 # Timer para upgrades de LOD

# Configuración de alturas base
const H_SNOW = 45.0
const H_JUNGLE = 35.0
const H_DESERT = 4.0
const H_PRAIRIE = 2.0

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
	"H_SNOW": H_SNOW,
	"H_JUNGLE": H_JUNGLE,
	"H_DESERT": H_DESERT,
	"H_PRAIRIE": H_PRAIRIE,
	"wood_mat": null, # Cached
	"sign_mat": null, # Cached
	"cow_scene": null,
	"goat_scene": null,
	"chicken_scene": null
}

# Object Pool
var tile_pool = []

func _ready():
	# Safety Check for exported variables
	if tile_size == null: tile_size = 150.0
	if render_distance == null: render_distance = 4
	
	randomize()
	var common_seed = randi()
	
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
	
	# 1. Calcular altura exacta del terreno en (0,0) para spawn seguro
	var h_val = height_noise.get_noise_2d(0, 0)
	# Detectar bioma en 0,0 para saber el multiplicador de altura
	var b_noise_val = biome_noise.get_noise_2d(0, 0)
	var deg = rad2deg(atan2(0, 0)) + (b_noise_val * 120.0) # Simplificado para (0,0)
	var h_mult = H_PRAIRIE
	if deg > 45 and deg <= 135: h_mult = H_JUNGLE
	elif deg > -45 and deg <= 45: h_mult = H_DESERT
	elif deg > -135 and deg <= -45: h_mult = H_SNOW
	
	var spawn_y = h_val * h_mult + 5.0 # 5 metros por encima del suelo real
	player.global_transform.origin = Vector3(0, spawn_y, 0)
	
	# 2. Desactivar física temporalmente para que no caiga mientras cargan los tiles
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)

	# 3. Generar área Inicial INMEDIATA (3x3)
	var p_coords = get_tile_coords(player.global_transform.origin)
	for x in range(int(p_coords.x) - 1, int(p_coords.x) + 2):
		for z in range(int(p_coords.y) - 1, int(p_coords.y) + 2):
			spawn_tile(x, z)
	
	# 4. ESPERAR a que la colisión se genere (el GroundTile inicial tiene yields)
	yield(get_tree().create_timer(0.3), "timeout")
	
	# 5. Activar física y colocar al jugador
	if player.has_method("set_physics_process"):
		player.set_physics_process(true)
	
	# SPAWN CABALLO Y ANIMALES DE PRUEBA
	yield(get_tree(), "idle_frame")
	
	var horse_scene = load("res://ui/scenes/Horse.tscn")
	if horse_scene:
		var horse = horse_scene.instance()
		add_child(horse)
		var h = get_terrain_height_at(10, -10)
		horse.global_transform.origin = Vector3(10, h + 0.8, -10)
		
	var cow_scene = load("res://ui/scenes/Cow.tscn")
	if cow_scene:
		# Vaca 1
		var cow1 = cow_scene.instance()
		add_child(cow1)
		cow1.speed = 4.0
		var h1 = get_terrain_height_at(15, -15)
		cow1.global_transform.origin = Vector3(15, h1 + 0.8, -15)
		cow1.is_night_cow = true
		cow1.night_waypoint_pos = Vector3(11.8, 2.1, 13.0) 
		cow1.night_target_pos = Vector3(22.0, 2.1, 18.5)
		
		# Vaca 2
		var cow2 = cow_scene.instance()
		add_child(cow2)
		cow2.speed = 4.0
		var h2 = get_terrain_height_at(-15, 15)
		cow2.global_transform.origin = Vector3(-15, h2 + 0.8, 15)
		cow2.is_night_cow = true
		cow2.night_waypoint_pos = Vector3(13.0, 2.1, 11.8)
		cow2.night_target_pos = Vector3(18.5, 2.1, 22.0)
		
	var goat_scene = load("res://ui/scenes/Goat.tscn")
	if goat_scene:
		# Cabras iniciales en un círculo muy cerrado (Radio 3m)
		for i in range(3):
			var goat = goat_scene.instance()
			add_child(goat)
			var angle = i * (TAU / 3.0)
			var cluster_offset = Vector3(cos(angle), 0, sin(angle)) * 3.0
			var spawn_pos = Vector3(10, 0, 0) + cluster_offset
			var hg = get_terrain_height_at(spawn_pos.x, spawn_pos.z)
			goat.global_transform.origin = Vector3(spawn_pos.x, hg + 0.8, spawn_pos.z)
	
	var chicken_scene = load("res://ui/scenes/Chicken.tscn")
	if chicken_scene:
		for i in range(4):
			var chicken = chicken_scene.instance()
			add_child(chicken)
			chicken.size_unit = 0.28
			var angle = i * (TAU / 4.0)
			var offset = Vector3(cos(angle), 0, sin(angle)) * 4.0
			var spawn_pos = Vector3(-18, 0, 18) + offset
			var hc = get_terrain_height_at(spawn_pos.x, spawn_pos.z)
			chicken.global_transform.origin = Vector3(spawn_pos.x, hc + 0.5, spawn_pos.z)
			
			# Navegación nocturna
			chicken.is_night_chicken = true
			chicken.night_waypoint_pos = Vector3(-17.0, 2.22, 17.0) 
			var targets = [
				Vector3(-20.5, 2.22, 20.5),
				Vector3(-21.5, 2.22, 20.5),
				Vector3(-20.5, 2.22, 21.5),
				Vector3(-21.5, 2.22, 21.5)
			]
			chicken.night_target_pos = targets[i]
	
	last_player_tile = p_coords
	update_tiles()

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
	
	shared_res["ground_mat"].set_shader_param("grass_tex", t_grass)
	shared_res["ground_mat"].set_shader_param("sand_tex", t_sand)
	shared_res["ground_mat"].set_shader_param("snow_tex", t_snow)
	shared_res["ground_mat"].set_shader_param("jungle_tex", t_jungle)
	shared_res["ground_mat"].set_shader_param("uv_scale", 0.025)
	
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

func spawn_tile(x, z):
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
	
	# Always spawn as LOW LOD for speed. Will upgrade later.
	# Enum: LOD.LOW = 1
	if tile.has_method("setup_biome"):
		tile.setup_biome(0, shared_res, 0, is_spawn, 1) # 1 = LOD.LOW
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
