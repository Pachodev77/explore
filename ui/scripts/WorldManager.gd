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
	"H_PRAIRIE": H_PRAIRIE,
	"wood_mat": null, # Cached
	"sign_mat": null  # Cached
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
	
	_init_settlement_seed()
	
	setup_shared_resources()
	
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

# ... (Previous code remains same until update_tiles loop) ...

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
	
	# LIMPIEZA DE COLA
	var filtered_queue = []
	for c in spawn_queue:
		if abs(c.x - x_int) <= render_distance and abs(c.y - z_int) <= render_distance:
			filtered_queue.append(c)
	spawn_queue = filtered_queue
	
	spawn_queue.sort_custom(self, "_sort_by_dist")
	
	# RECYCLE TILES (Pooling)
	var keys_to_remove = []
	for key in active_tiles.keys():
		if not key in new_active_keys:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		var tile = active_tiles[key]
		# Mover al pool en lugar de borrar
		remove_child(tile)
		tile_pool.append(tile)
		active_tiles.erase(key)

func _sort_by_dist(a, b):
	var p_coords = get_tile_coords(player.global_transform.origin)
	return a.distance_to(p_coords) < b.distance_to(p_coords)


# --- SETTLEMENT & ROAD LOGIC ---
const SUPER_CHUNK_SIZE = 5 # Increased from 3 to 5 (Lower density)
var settlement_seed = 0

func _init_settlement_seed():
	settlement_seed = noise.seed + 999

func get_settlement_coords(sc_x_in, sc_z_in):
	# Deterministic random based on super chunk coords
	var sc_x = int(sc_x_in)
	var sc_z = int(sc_z_in)
	
	# FORCE START SETTLEMENT NEAR (0,0)
	if sc_x == 0 and sc_z == 0:
		return Vector2(1, 0) # Fixed at (1,0) tile, visible from spawn
		
	var hash_val = (sc_x * 73856093) ^ (sc_z * 19349663) ^ settlement_seed
	var rng = RandomNumberGenerator.new()
	rng.seed = hash_val
	
	# Random position within the super chunk (keep away from edges for easier connection)
	var rel_x = rng.randi_range(0, SUPER_CHUNK_SIZE - 1)
	var rel_z = rng.randi_range(0, SUPER_CHUNK_SIZE - 1)
	
	return Vector2(sc_x * SUPER_CHUNK_SIZE + rel_x, sc_z * SUPER_CHUNK_SIZE + rel_z)

func is_settlement_tile(x, z):
	var sc_x = floor(float(x) / SUPER_CHUNK_SIZE)
	var sc_z = floor(float(z) / SUPER_CHUNK_SIZE)
	var sett_coords = get_settlement_coords(int(sc_x), int(sc_z))
	return int(sett_coords.x) == x and int(sett_coords.y) == z

func get_road_curve_points(x, z):
	# Used by MapRenderer ONLY? No, MapRenderer implements/copies this logic.
	# We should update MapRenderer separately.
	return [] 

func get_road_influence(gx, gz):
	# Calculate influence of roads at global position (gx, gz)
	# Returns { "is_road": bool, "weight": float, "height": float }
	
	var tile_x = floor(gx / tile_size)
	var tile_z = floor(gz / tile_size)
	
	var sc_x = floor(tile_x / SUPER_CHUNK_SIZE)
	var sc_z = floor(tile_z / SUPER_CHUNK_SIZE)
	
	var dist = 9999.0
	
	# --- HORIZONTAL ROADS ---
	# Previous -> Current
	var s_prev = get_settlement_coords(sc_x - 1, sc_z)
	var s_curr = get_settlement_coords(sc_x, sc_z)
	dist = min(dist, _dist_to_road_segment(gx, gz, s_prev, s_curr, true))
	
	# Current -> Next
	var s_next = get_settlement_coords(sc_x + 1, sc_z)
	dist = min(dist, _dist_to_road_segment(gx, gz, s_curr, s_next, true))
	
	# --- VERTICAL ROADS (Intersections) ---
	# We add vertical roads with 50% chance per SC column/row
	# Check Vertical: Up -> Current
	if _has_vertical_road(sc_x, sc_z - 1):
		var s_up = get_settlement_coords(sc_x, sc_z - 1)
		dist = min(dist, _dist_to_road_segment(gx, gz, s_up, s_curr, false))
		
	# Check Vertical: Current -> Down
	if _has_vertical_road(sc_x, sc_z):
		var s_down = get_settlement_coords(sc_x, sc_z + 1)
		dist = min(dist, _dist_to_road_segment(gx, gz, s_curr, s_down, false))
	
	var road_width = 12.0 # Wider (was 8.0)
	var falloff = 6.0 # Softer edge (was 4.0)
	
	if dist < (road_width + falloff):
		var w = 1.0 - clamp((dist - road_width) / falloff, 0.0, 1.0)
		return { "is_road": true, "weight": w, "height": 2.1 } # 2.1 matches settlement height approx
	
	return { "is_road": false, "weight": 0.0, "height": 0.0 }

func _has_vertical_road(sc_x, sc_z):
	# Deterministic check: 40% chance of vertical road starting from this chunk southwards
	var hash_val = (int(sc_x) * 3344921) ^ (int(sc_z) * 8192371) ^ settlement_seed
	return (hash_val % 100) < 40

func _dist_to_road_segment(gx, gz, t_start, t_end, is_horizontal):
	# t_start, t_end are TILE coordinates
	
	var start_pos = Vector3.ZERO
	var end_pos = Vector3.ZERO
	var cp1 = Vector3.ZERO
	var cp2 = Vector3.ZERO
	
	if is_horizontal:
		# East-West Connection: Gate offsets 33.0 (East/West gates)
		start_pos = Vector3(t_start.x * tile_size + 33.0, 0, t_start.y * tile_size)
		end_pos = Vector3(t_end.x * tile_size - 33.0, 0, t_end.y * tile_size)
		
		# Control points Horizontal - Add random curvature
		var dist = start_pos.distance_to(end_pos)
		var handle_len = dist * 0.4
		
		# Deterministic Random for Curvature based on segment coords
		var seed_x = int(t_start.x) + int(t_end.x)
		var seed_z = int(t_start.y) + int(t_end.y)
		var curv_rng = RandomNumberGenerator.new()
		curv_rng.seed = (seed_x * 49297) ^ (seed_z * 91823) ^ settlement_seed
		var curve_z = curv_rng.randf_range(-40.0, 40.0) # Wiggle Z
		
		cp1 = start_pos + Vector3(handle_len, 0, curve_z)
		cp2 = end_pos - Vector3(handle_len, 0, -curve_z)
	else:
		# North-South Connection: Starts from MIDPOINT of Horizontal Road
		# We need to approximate the midpoint of the horizontal road passing through t_start
		# Horizontal segment is (t_start - 33m) to (t_next + 33m) roughly.
		# Simplified: Start from t_start (which represents the settlement node logic) 
		# actually represents the "Horizontal Road Body".
		# Let's anchor it to the middle of the t_start -> t_start+1 segment.
		
		# NOTE: t_start here is passed as 's_up' or 's_curr' from get_road_influence.
		# It refers to a settlement tile. 
		# We want the midpoint between t_start and t_start+1(next settlement east).
		# BUT wait, the loop passes s_up, s_curr. 
		# Correct logic: Vertical road at column SC_X should connect:
		# Point A: Midpoint of Road(Settlement[SC_X, SC_Z-1] -> Settlement[SC_X+1, SC_Z-1])
		# Point B: North Gate of Settlement[SC_X, SC_Z] OR Midpoint of current road?
		# User requested: "vertical intersections start in the middle of horizontal roads"
		
		# Let's implement: Midpoint(Horizontal Top) -> Midpoint(Horizontal Bottom)? 
		# Or Midpoint(Horizontal Top) -> Settlement(Bottom).
		# "intersecciones verticales... inicien en la mitad... entre los asentamientos" implies T-junction.
		# So: Midpoint of Horizontal Road -> Connects to Settlement South.
		
		# Logic:
		# Start = Midpoint of Road between t_start and (t_start + 1_Settlement)
		var sc_x = floor(t_start.x / SUPER_CHUNK_SIZE)
		var sc_z = floor(t_start.y / SUPER_CHUNK_SIZE)
		
		var s_east = get_settlement_coords(sc_x + 1, sc_z)
		
		# Re-calculate Horizontal Curve for Top Segment to find true midpoint
		var h_start = Vector3(t_start.x * tile_size + 33.0, 0, t_start.y * tile_size)
		var h_end = Vector3(s_east.x * tile_size - 33.0, 0, s_east.y * tile_size)
		var h_mid = (h_start + h_end) * 0.5 # Linear midpoint approx is fine for anchor
		
		# Determine Start/End
		start_pos = h_mid
		end_pos = Vector3(t_end.x * tile_size, 0, t_end.y * tile_size - 33.0) # North Gate of destination
		
		# Control points Vertical
		var dist = start_pos.distance_to(end_pos)
		var handle_len = dist * 0.4
		
		# Curvature X
		var seed_x_v = int(t_start.x)
		var seed_z_v = int(t_start.y)
		var curv_rng_v = RandomNumberGenerator.new()
		curv_rng_v.seed = (seed_x_v * 73821) ^ (seed_z_v * 19283) ^ settlement_seed
		var curve_x = curv_rng_v.randf_range(-40.0, 40.0)
		
		cp1 = start_pos + Vector3(curve_x, 0, handle_len)
		cp2 = end_pos - Vector3(-curve_x, 0, handle_len)
	
	# Sample distance (Approximate)
	
	# Sample distance (Approximate)
	# We sample 10 points along curve
	var min_d = 9999.0
	var pos = Vector3(gx, 0, gz)
	
	# Simple adaptive check or fixed steps
	var steps = 15
	var prev_p = start_pos
	
	for i in range(1, steps + 1):
		var t = float(i) / steps
		var curr_p = _cubic_bezier(start_pos, cp1, cp2, end_pos, t)
		
		# Dist to segment prev_p -> curr_p
		var d = _dist_to_segment_2d(pos, prev_p, curr_p)
		if d < min_d: min_d = d
		prev_p = curr_p
		
	return min_d

func _cubic_bezier(p0, p1, p2, p3, t):
	var t2 = t * t
	var t3 = t2 * t
	var mt = 1.0 - t
	var mt2 = mt * mt
	var mt3 = mt2 * mt
	return p0 * mt3 + p1 * (3.0 * mt2 * t) + p2 * (3.0 * mt * t2) + p3 * t3

func _dist_to_segment_2d(p, a, b):
	var pa = Vector2(p.x - a.x, p.z - a.z)
	var ba = Vector2(b.x - a.x, b.z - a.z)
	var h = clamp(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	return pa.distance_to(ba * h)

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
	
	# SPAWN QUEUE: Spawn 1 LOW LOD tile per frame (Super Fast)
	if spawn_queue.size() > 0:
		var coords = spawn_queue.pop_front()
		spawn_tile(int(coords.x), int(coords.y))
	
	# UPGRADE QUEUE: Check for LOW LOD tiles close to player and upgrade 1 per frame
	for key in active_tiles.keys():
		var tile = active_tiles[key]
		if tile.has_method("upgrade_to_high_lod") and tile.current_lod == tile.TileLOD.LOW:
			var dist = p_pos.distance_to(tile.global_transform.origin)
			if dist < 350.0: # Upgrade slightly before physics is needed
				tile.upgrade_to_high_lod()
				break # Only upgrade 1 per frame to avoid stutter
	
	var water = get_node_or_null("WaterPlane")
	if water:
		water.translation.x = p_pos.x
		water.translation.z = p_pos.z

func spawn_tile(x, z):
	var key = str(x) + "," + str(z)
	if active_tiles.has(key): return
	
	var tile = null
	# Intentar reciclar del pool
	if tile_pool.size() > 0:
		tile = tile_pool.pop_back()
	else:
		tile = tile_scene.instance()
	
	tile.translation = Vector3(x * tile_size, 0, z * tile_size)
	tile.visible = true
	add_child(tile)
	
	var is_spawn = (x == 0 and z == 0) or is_settlement_tile(x, z)
	
	# Always spawn as LOW LOD for speed. Will upgrade later.
	# Enum: LOD.LOW = 1
	if tile.has_method("setup_biome"):
		tile.setup_biome(0, shared_res, 0, is_spawn, 1) # 1 = LOD.LOW
	active_tiles[key] = tile

func get_tile_coords(pos):
	# POSICIÓN GLOBAL: Usamos global_transform para ignorar el parentesco
	return Vector2(floor((pos.x + tile_size*0.5) / tile_size), floor((pos.z + tile_size*0.5) / tile_size))

