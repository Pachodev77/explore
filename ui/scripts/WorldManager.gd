extends Spatial

# Configuración del mapa optimizada
export(PackedScene) var tile_scene = preload("res://ui/scenes/GroundTile.tscn")
export var tile_size = 150.0
export var render_distance = 2

onready var player = get_parent().get_node("Player")

var active_tiles = {}
var spawn_queue = [] # Cola de tiles pendientes de generar
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
	"ground_mat": ShaderMaterial.new(), # SHADER para todo el suelo
	"tree_mesh": CylinderMesh.new(),
	"tree_mat": SpatialMaterial.new(),
	"cactus_mesh": CubeMesh.new(),
	"cactus_mat": SpatialMaterial.new(),
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
	update_tiles()

func setup_shared_resources():
	# Cargar Shader y Texturas
	var shader = preload("res://ui/shaders/biome_blending.shader")
	shared_res["ground_mat"].shader = shader
	
	# Intentar cargar las texturas JPG
	var t_grass = load("res://ui/textures/grass.jpg")
	var t_sand = load("res://ui/textures/sand.jpg")
	var t_snow = load("res://ui/textures/snow.jpg")
	var t_jungle = load("res://ui/textures/jungle.jpg")
	
	shared_res["ground_mat"].set_shader_param("grass_tex", t_grass)
	shared_res["ground_mat"].set_shader_param("sand_tex", t_sand)
	shared_res["ground_mat"].set_shader_param("snow_tex", t_snow)
	shared_res["ground_mat"].set_shader_param("jungle_tex", t_jungle)
	
	shared_res["ground_mat"].set_shader_param("uv_scale", 0.025)
	
	# Crear Plano de Agua
	create_water_plane()

func create_water_plane():
	var water_mesh = MeshInstance.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(tile_size * 5, tile_size * 5) # Cubre el área visible con margen
	plane.subdivide_depth = 50
	plane.subdivide_width = 50
	
	water_mesh.mesh = plane
	water_mesh.name = "WaterPlane"
	add_child(water_mesh)
	
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://ui/shaders/water.shader")
	water_mesh.set_surface_material(0, mat)
	
	# Nivel del agua: Donde empiezan los valles
	water_mesh.translation.y = -8.0

func _process(_delta):
	var current_tile_coords = get_tile_coords(player.translation)
	if current_tile_coords != last_player_tile:
		last_player_tile = current_tile_coords
		update_tiles()
	
	# Procesar solo un tile por frame para evitar lag
	if spawn_queue.size() > 0:
		var coords = spawn_queue.pop_front()
		spawn_tile(coords.x, coords.y)
	
	# Mover el agua con el jugador para que siempre parezca infinita
	var water = get_node_or_null("WaterPlane")
	if water:
		water.translation.x = player.translation.x
		water.translation.z = player.translation.z

func get_tile_coords(pos):
	return Vector2(floor(pos.x / tile_size), floor(pos.z / tile_size))

func update_tiles():
	var player_coords = get_tile_coords(player.translation)
	var new_active_keys = []
	for x in range(player_coords.x - render_distance, player_coords.x + render_distance + 1):
		for z in range(player_coords.y - render_distance, player_coords.y + render_distance + 1):
			var coord_key = str(int(x)) + "," + str(int(z))
			new_active_keys.append(coord_key)
			if not active_tiles.has(coord_key):
				# Añadir a la cola en lugar de generar inmediatamente
				var coords = Vector2(int(x), int(z))
				if not spawn_queue.has(coords):
					spawn_queue.append(coords)
	for key in active_tiles.keys():
		if not key in new_active_keys:
			active_tiles[key].queue_free()
			active_tiles.erase(key)

func spawn_tile(x, z):
	var tile = tile_scene.instance()
	tile.translation = Vector3(x * tile_size, 0, z * tile_size)
	add_child(tile)
	
	if tile.has_method("setup_biome"):
		tile.setup_biome(0, shared_res)
	active_tiles[str(x) + "," + str(z)] = tile
