# =============================================================================
# WorldManager.gd - COORDINADOR PRINCIPAL DEL MUNDO
# =============================================================================
# Orquesta los subsistemas del mundo: tiles, animales, agua, terreno.
# 
# ARQUITECTURA MODULAR:
# - TileManager.gd     → Gestión de tiles (spawn, pool, LOD)
# - AnimalSpawner.gd   → Spawning de animales inicial
# - WaterManager.gd    → Plano de agua
# - TerrainUtils.gd    → Cálculo de altura/biomas
# - SharedResources.gd → Recursos compartidos
# =============================================================================

extends Spatial

# Configuración exportada
export var tile_size: float = 150.0
export var render_distance: int = 4

# Referencias principales
onready var player = get_parent().get_node("Player")

# Subsistemas (instanciados en _ready)
var tile_manager: TileManager
var terrain_utils: TerrainUtils
var water_manager: WaterManager
var animal_spawner: AnimalSpawner
var entity_cleaner: EntityCleaner

# Sistemas de ruido
var noise: OpenSimplexNoise = OpenSimplexNoise.new()
var height_noise: OpenSimplexNoise = OpenSimplexNoise.new()
var biome_noise: OpenSimplexNoise = OpenSimplexNoise.new()
var road_system: RoadSystem = RoadSystem.new()

# Recursos compartidos (acceso directo para compatibilidad)
var shared_res: Dictionary = {}

# Estado del mundo
var current_seed: int = 0
var beehive_harvests: Dictionary = {}  # { "global_pos_str": day_of_harvest }
var last_egg_harvest_day: int = 0

# Timers
var update_timer: float = 0.0

# =============================================================================
# INICIALIZACIÓN
# =============================================================================

func _ready():
	ServiceLocator.register_service("world", self)
	
	# Validar configuración
	if tile_size == null:
		tile_size = GameConfig.TILE_SIZE
	if render_distance == null:
		render_distance = GameConfig.RENDER_DISTANCE
	
	# Inicializar seed
	randomize()
	var common_seed = randi()
	var saved_data = _load_saved_data()
	
	if saved_data and saved_data.has("world_seed"):
		common_seed = int(saved_data["world_seed"])
	
	current_seed = common_seed
	
	# Configurar sistemas de ruido
	_setup_noise_systems(common_seed)
	
	# Inicializar recursos compartidos
	_init_shared_resources()
	
	# Inicializar subsistemas
	_init_subsystems()
	
	# Aplicar datos guardados o posición de spawn
	_apply_player_position(saved_data)
	
	# Desactivar física del jugador temporalmente
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	
	# Generar área inicial
	tile_manager.spawn_initial_area(player.global_transform.origin)
	
	# Esperar frames para colisiones
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	
	# Iniciar secuencia de spawn completa
	_start_spawn_sequence(saved_data)

func _load_saved_data():
	"""Carga datos guardados si existen."""
	if ServiceLocator.has_service("save_manager"):
		var sm = ServiceLocator.get_save_manager()
		if sm.has_pending_load:
			return sm.get_pending_data()
	return null

func _setup_noise_systems(seed_val: int) -> void:
	"""Configura los sistemas de ruido."""
	noise.seed = seed_val
	noise.octaves = 3
	noise.period = 15.0
	noise.persistence = 0.5
	
	height_noise.seed = seed_val + 1
	height_noise.octaves = 3
	height_noise.period = 60.0
	height_noise.persistence = 0.25
	
	biome_noise.seed = seed_val + 2
	biome_noise.octaves = 2
	biome_noise.period = 600.0
	biome_noise.persistence = 0.5
	
	road_system.init(seed_val, tile_size)

func _init_shared_resources() -> void:
	"""Inicializa el diccionario de recursos compartidos."""
	shared_res = {
		"ground_mat": ShaderMaterial.new(),
		"tree_parts": [],
		"cactus_parts": [],
		"rock_mesh": SphereMesh.new(),
		"rock_mat": SpatialMaterial.new(),
		"bush_mesh": CubeMesh.new(),
		"bush_mat": SpatialMaterial.new(),
		"height_noise": height_noise,
		"biome_noise": biome_noise,
		"H_SNOW": GameConfig.H_SNOW,
		"H_JUNGLE": GameConfig.H_JUNGLE,
		"H_DESERT": GameConfig.H_DESERT,
		"H_PRAIRIE": GameConfig.H_PRAIRIE,
		"wood_mat": null,
		"sign_mat": null,
		"cow_scene": null,
		"goat_scene": null,
		"chicken_scene": null
	}
	
	_setup_shared_resources_internal()

func _setup_shared_resources_internal() -> void:
	"""Carga todos los recursos compartidos."""
	# Shader de terreno
	var shader = preload("res://ui/shaders/biome_blending.shader")
	shared_res["ground_mat"].shader = shader
	
	# Texturas
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
	shared_res["ground_mat"].set_shader_param("uv_scale", 0.04)
	shared_res["ground_mat"].set_shader_param("triplanar_sharpness", 6.0)
	
	# Meshes de árboles y cactus
	var tree_scene = preload("res://ui/tree.glb")
	if tree_scene:
		var tree_inst = tree_scene.instance()
		shared_res["tree_parts"] = _find_meshes_recursive(tree_inst)
		tree_inst.queue_free()
	
	var cactus_scene = preload("res://ui/cactus.glb")
	if cactus_scene:
		var cactus_inst = cactus_scene.instance()
		shared_res["cactus_parts"] = _find_meshes_recursive(cactus_inst)
		cactus_inst.queue_free()
		
		for part in shared_res["cactus_parts"]:
			if part and part.has("mat") and part.mat and part.mat is SpatialMaterial:
				part.mat.emission_enabled = false
				part.mat.flags_unshaded = false
	
	# Materiales
	var wood_mat = SpatialMaterial.new()
	wood_mat.albedo_color = Color(0.4, 0.25, 0.1)
	wood_mat.roughness = 0.9
	shared_res["wood_mat"] = wood_mat
	
	var sign_mat = SpatialMaterial.new()
	sign_mat.albedo_color = Color(0.8, 0.7, 0.5)
	shared_res["sign_mat"] = sign_mat
	
	# Escenas de animales
	shared_res["cow_scene"] = load("res://ui/scenes/Cow.tscn")
	shared_res["goat_scene"] = load("res://ui/scenes/Goat.tscn")
	shared_res["chicken_scene"] = load("res://ui/scenes/Chicken.tscn")

func _init_subsystems() -> void:
	"""Inicializa los subsistemas modulares."""
	# Terrain Utils
	terrain_utils = TerrainUtils.new()
	terrain_utils.init(height_noise, biome_noise, road_system)
	
	# Water Manager
	water_manager = WaterManager.new()
	water_manager.init(self, tile_size)
	
	# Tile Manager
	tile_manager = TileManager.new()
	tile_manager.init(self, road_system, shared_res, tile_size, render_distance)
	
	# Entity Cleaner (limpieza de animales lejanos)
	entity_cleaner = EntityCleaner.new()
	entity_cleaner.init(self)

func _apply_player_position(saved_data) -> void:
	"""Aplica la posición del jugador desde datos guardados o spawn inicial."""
	if saved_data and saved_data.has("player_pos"):
		var p = saved_data["player_pos"]
		player.global_transform.origin = Vector3(p.x, p.y, p.z)
		
		if saved_data.has("player_rot_y"):
			player.rotation.y = saved_data["player_rot_y"]
		
		if saved_data.has("inventory") and ServiceLocator.has_service("inventory"):
			ServiceLocator.get_inventory_manager().load_save_data(saved_data["inventory"])
		
		if saved_data.has("player_cam_rot_x") and player.has_node("CameraPivot"):
			player.get_node("CameraPivot").rotation.x = saved_data["player_cam_rot_x"]
		
		if saved_data.has("player_look_dir"):
			player.look_dir = Vector2(saved_data["player_look_dir"].x, saved_data["player_look_dir"].y)
	else:
		var spawn_y = terrain_utils.calculate_spawn_height()
		player.global_transform.origin = Vector3(0, spawn_y, 0)

# =============================================================================
# SECUENCIA DE SPAWN
# =============================================================================

func _start_spawn_sequence(saved_data = null) -> void:
	"""Ejecuta la secuencia completa de spawn del mundo."""
	# Warmup de shaders
	_warmup_shaders()
	yield(get_tree(), "idle_frame")
	
	# Spawn de animales
	yield(_spawn_all_animals(saved_data), "completed")
	
	# Actualizar tiles
	tile_manager.update_tiles(player.global_transform.origin)
	tile_manager.mark_updated(player.global_transform.origin)
	
	# Restaurar física del jugador
	if is_instance_valid(player) and player.has_method("set_physics_process"):
		player.set_physics_process(true)
	
	GameEvents.emit_signal("world_ready")
	
	if ServiceLocator.has_service("save_manager"):
		ServiceLocator.get_save_manager().clear_pending_load()

func _spawn_all_animals(saved_data) -> void:
	"""Spawnea todos los animales iniciales."""
	# Caballo
	var horse_scene = load("res://ui/scenes/Horse.tscn")
	if horse_scene:
		yield(get_tree(), "idle_frame")
		if not is_instance_valid(self):
			return
		
		var horse = horse_scene.instance()
		add_child(horse)
		entity_cleaner.protect_animal(horse)  # Proteger de limpieza
		
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
			yield(get_tree(), "idle_frame")
			if is_instance_valid(player) and player.has_method("mount"):
				player.mount(horse)
	
	# Vacas
	if shared_res["cow_scene"]:
		for i in range(2):
			var cow = shared_res["cow_scene"].instance()
			add_child(cow)
			cow.speed = 4.0
			var offset = 15 if i == 0 else -15
			var h = get_terrain_height_at(offset, -offset)
			cow.global_transform.origin = Vector3(offset, h + 0.8, -offset)
			cow.is_night_cow = true
			cow.night_target_pos = Vector3(18.0, 2.0, 18.0)
			cow.night_waypoint_pos = Vector3(18.0, 2.0, 10.0)
			entity_cleaner.protect_animal(cow)  # Proteger de limpieza
		yield(get_tree(), "idle_frame")
	
	# Cabras
	if shared_res["goat_scene"]:
		for i in range(3):
			var goat = shared_res["goat_scene"].instance()
			add_child(goat)
			var angle = i * (TAU / 3.0)
			var cluster_offset = Vector3(cos(angle), 0, sin(angle)) * 3.0
			var spawn_pos = Vector3(10, 0, 0) + cluster_offset
			var hg = get_terrain_height_at(spawn_pos.x, spawn_pos.z)
			goat.global_transform.origin = Vector3(spawn_pos.x, hg + 0.8, spawn_pos.z)
			entity_cleaner.protect_animal(goat)  # Proteger de limpieza
		yield(get_tree(), "idle_frame")
	
	# Gallinas
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
			chicken.night_target_pos = Vector3(-18.0, 2.0, 18.0)
			chicken.night_waypoint_pos = Vector3(-18.0, 2.0, 14.0)
			entity_cleaner.protect_animal(chicken)  # Proteger de limpieza
		yield(get_tree(), "idle_frame")

func _warmup_shaders() -> void:
	"""Pre-compila shaders para evitar stuttering."""
	var cam = get_viewport().get_camera()
	if not cam:
		return
	
	var warmup_node = Spatial.new()
	warmup_node.translation = cam.global_transform.origin - cam.global_transform.basis.z * 2.0
	add_child(warmup_node)
	
	var mats = [shared_res["ground_mat"], shared_res["rock_mat"], shared_res["wood_mat"]]
	
	for mat in mats:
		if not mat:
			continue
		var mi = MeshInstance.new()
		mi.mesh = SphereMesh.new()
		mi.mesh.radius = 0.01
		mi.material_override = mat
		warmup_node.add_child(mi)
	
	yield(get_tree(), "idle_frame")
	warmup_node.queue_free()

# =============================================================================
# PROCESO
# =============================================================================

func _process(delta):
	var p_pos = player.global_transform.origin
	
	# Actualizar tiles SIEMPRE que cambie el tile del jugador
	update_timer -= delta
	if update_timer <= 0:
		update_timer = 0.3  # Más frecuente (era 0.5)
		# SIEMPRE actualizar tiles (sin condición should_update)
		tile_manager.update_tiles(p_pos)
		tile_manager.mark_updated(p_pos)
	
	# Procesar upgrades de LOD
	tile_manager.process_lod_upgrades(delta, p_pos)
	
	# Procesar cola de spawn
	tile_manager.process_spawn_queue(p_pos)
	
	# Limpiar entidades lejanas
	entity_cleaner.process(delta)
	
	# Actualizar posición del agua
	water_manager.update_position(p_pos)

# =============================================================================
# API PÚBLICA (Compatibilidad)
# =============================================================================

func get_terrain_height_at(x: float, z: float) -> float:
	"""Obtiene la altura del terreno en una posición."""
	return terrain_utils.get_terrain_height_at(x, z)

func get_tile_coords(pos: Vector3) -> Vector2:
	"""Convierte posición a coordenadas de tile."""
	return tile_manager.get_tile_coords(pos)

func is_settlement_tile(x: int, z: int) -> bool:
	"""Verifica si un tile es un asentamiento."""
	return road_system.is_settlement_tile(x, z)

func get_road_influence(gx: float, gz: float) -> Dictionary:
	"""Obtiene la influencia de carreteras en una posición."""
	return road_system.get_road_influence(gx, gz)

# Acceso a tiles activos (para compatibilidad)
var active_tiles: Dictionary setget , _get_active_tiles
func _get_active_tiles() -> Dictionary:
	return tile_manager.active_tiles if tile_manager else {}

# =============================================================================
# UTILIDADES
# =============================================================================

func _find_meshes_recursive(node: Node, results: Array = []) -> Array:
	if node is MeshInstance:
		var mat = node.material_override
		if not mat:
			mat = node.get_surface_material(0)
		if not mat and node.mesh:
			mat = node.mesh.surface_get_material(0)
		results.append({"mesh": node.mesh, "mat": mat})
	
	for child in node.get_children():
		_find_meshes_recursive(child, results)
	return results

# Alias para compatibilidad (funciones que otros scripts pueden llamar)
func update_tiles() -> void:
	tile_manager.update_tiles(player.global_transform.origin)

func setup_shared_resources() -> void:
	_setup_shared_resources_internal()
