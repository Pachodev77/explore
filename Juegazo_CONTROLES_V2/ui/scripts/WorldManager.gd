extends Spatial

# Configuración del mapa optimizada
export(PackedScene) var tile_scene = preload("res://ui/scenes/GroundTile.tscn")
export var tile_size = 150.0
export var render_distance = 1

onready var player = get_parent().get_node("Player")

var active_tiles = {}
var noise = OpenSimplexNoise.new()
var height_noise = OpenSimplexNoise.new()
var biome_noise = OpenSimplexNoise.new()
var last_player_tile = Vector2.INF

# Configuración de alturas base
const H_SNOW = 55.0
const H_JUNGLE = 30.0
const H_DESERT = 7.0
const H_PRAIRIE = 3.0

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
	height_noise.octaves = 4
	height_noise.period = 30.0
	height_noise.persistence = 0.4
	
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
	
	# Como no tenemos snow y jungle aún, usaremos Color liso como textura temporal o el mismo grass con tono
	shared_res["ground_mat"].set_shader_param("grass_tex", t_grass)
	shared_res["ground_mat"].set_shader_param("sand_tex", t_sand)
	shared_res["ground_mat"].set_shader_param("snow_tex", t_grass) # Temporal
	shared_res["ground_mat"].set_shader_param("jungle_tex", t_grass) # Temporal
	
	shared_res["ground_mat"].set_shader_param("uv_scale", 0.2)

	# Decoración
	shared_res["tree_mesh"].top_radius = 2.0
	shared_res["tree_mesh"].bottom_radius = 3.0
	shared_res["tree_mesh"].height = 8.0
	shared_res["cactus_mesh"].size = Vector3(1.5, 4, 1.5)
	shared_res["rock_mesh"].radius = 3.0
	shared_res["bush_mesh"].size = Vector3(2, 2, 2)
	shared_res["tree_mat"].albedo_color = Color(0.05, 0.2, 0.05)
	shared_res["cactus_mat"].albedo_color = Color(0.1, 0.5, 0.1)
	shared_res["rock_mat"].albedo_color = Color(0.6, 0.7, 0.8)
	shared_res["bush_mat"].albedo_color = Color(0.2, 0.4, 0.1)

func _process(_delta):
	var current_tile_coords = get_tile_coords(player.translation)
	if current_tile_coords != last_player_tile:
		last_player_tile = current_tile_coords
		update_tiles()

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
				spawn_tile(int(x), int(z))
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
