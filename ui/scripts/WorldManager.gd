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
var last_player_tile = Vector2.INF

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
	"H_PRAIRIE": H_PRAIRIE
}

func _ready():
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
	biome_noise.period = 40.0
	biome_noise.persistence = 0.5
	
	shared_res["height_noise"] = height_noise
	shared_res["biome_noise"] = biome_noise
	
	setup_shared_resources()
	
	# Generar área Inicial INMEDIATA (3x3)
	# Generar área Inicial INMEDIATA (3x3)
	var p_coords = get_tile_coords(player.global_transform.origin)
	for x in range(int(p_coords.x) - 1, int(p_coords.x) + 2):
		for z in range(int(p_coords.y) - 1, int(p_coords.y) + 2):
			spawn_tile(x, z)
	
	# Colocar al jugador a salvo ligeramente por encima del suelo
	player.translation.y = 2.0
	
	# SPAWN CABALLO DE PRUEBA
	var horse_scene = load("res://ui/scenes/Horse.tscn")
	if horse_scene:
		var horse = horse_scene.instance()
		add_child(horse)
		horse.translation = Vector3(10, 2.5, -10) # Cerca del jugador, elevado a 2.5 para evitar hundimiento
	
	last_player_tile = p_coords
	update_tiles()

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

func _process(_delta):
	var p_pos = player.global_transform.origin
	var current_tile_coords = get_tile_coords(p_pos)
	if current_tile_coords.distance_to(last_player_tile) > 0.5:
		last_player_tile = current_tile_coords
		update_tiles()
	
	# Procesar spawn MUY rápido (4 por frame) al galopar
	for _i in range(4):
		if spawn_queue.size() > 0:
			var coords = spawn_queue.pop_front()
			spawn_tile(int(coords.x), int(coords.y))
	
	var water = get_node_or_null("WaterPlane")
	if water:
		water.translation.x = p_pos.x
		water.translation.z = p_pos.z

func get_tile_coords(pos):
	# POSICIÓN GLOBAL: Usamos global_transform para ignorar el parentesco
	return Vector2(floor((pos.x + tile_size*0.5) / tile_size), floor((pos.z + tile_size*0.5) / tile_size))

func update_tiles():
	var p_pos = player.global_transform.origin
	var player_coords = get_tile_coords(p_pos)
	var new_active_keys = []
	var x_int = int(player_coords.x)
	var z_int = int(player_coords.y)
	
	for x in range(x_int - render_distance, x_int + render_distance + 1):
		for z in range(z_int - render_distance, z_int + render_distance + 1):
			var coords = Vector2(x, z)
			var coord_key = str(x) + "," + str(z)
			new_active_keys.append(coord_key)
			
			if not active_tiles.has(coord_key):
				if not spawn_queue.has(coords):
					spawn_queue.append(coords)
	
	# LIMPIEZA DE COLA: Eliminar tiles que ya no están en rango para evitar backlog
	var filtered_queue = []
	for c in spawn_queue:
		if abs(c.x - x_int) <= render_distance and abs(c.y - z_int) <= render_distance:
			filtered_queue.append(c)
	spawn_queue = filtered_queue
	
	# Ordenar por cercanía
	spawn_queue.sort_custom(self, "_sort_by_dist")
	
	# Borrar tiles lejanos
	var keys_to_remove = []
	for key in active_tiles.keys():
		if not key in new_active_keys:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		active_tiles[key].queue_free()
		active_tiles.erase(key)

func _sort_by_dist(a, b):
	var p_coords = get_tile_coords(player.global_transform.origin)
	return a.distance_to(p_coords) < b.distance_to(p_coords)

func spawn_tile(x, z):
	var key = str(x) + "," + str(z)
	if active_tiles.has(key): return
	
	var tile = tile_scene.instance()
	tile.translation = Vector3(x * tile_size, 0, z * tile_size)
	add_child(tile)
	
	var is_spawn = (x == 0 and z == 0)
	if tile.has_method("setup_biome"):
		tile.setup_biome(0, shared_res, 0, is_spawn)
	active_tiles[key] = tile
