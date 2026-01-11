# =============================================================================
# RoadSystem.gd - LOGICA DE CARRETERAS Y ASENTAMIENTOS
# =============================================================================
# Clase especializada en el cálculo de trazado de caminos mediante curvas Bézier,
# gestión de semillas de asentamientos e influencia vial en el terreno.
# =============================================================================

extends Node
class_name RoadSystem

const SUPER_CHUNK_SIZE = 5

var settlement_seed: int = 0
var tile_size: float = 150.0
var road_cache = {} # { "sc_x,sc_z": [ {a, b}, ... ] }
var _cached_rng : RandomNumberGenerator = RandomNumberGenerator.new()

func init(seed_val: int, t_size: float):
	settlement_seed = seed_val + 999
	tile_size = t_size

func get_settlement_coords(sc_x: int, sc_z: int) -> Vector2:
	if sc_x == 0 and sc_z == 0: return Vector2(4, 0)      # Mercado al Este
	if sc_x == -1 and sc_z == 0: return Vector2(-4, 0)   # Feria Ganadera al Oeste
	if sc_x == 0 and sc_z == -1: return Vector2(0, -4)   # Mina al Norte
		
	var hash_val = (sc_x * 73856093) ^ (sc_z * 19349663) ^ settlement_seed
	_cached_rng.seed = hash_val
	var rel_x = _cached_rng.randi_range(0, SUPER_CHUNK_SIZE - 1)
	var rel_z = _cached_rng.randi_range(0, SUPER_CHUNK_SIZE - 1)
	return Vector2(sc_x * SUPER_CHUNK_SIZE + rel_x, sc_z * SUPER_CHUNK_SIZE + rel_z)

func get_road_influence(gx: float, gz: float) -> Dictionary:
	var tile_x = floor(gx / tile_size)
	var tile_z = floor(gz / tile_size)
	var sc_x = floor(tile_x / SUPER_CHUNK_SIZE)
	var sc_z = floor(tile_z / SUPER_CHUNK_SIZE)
	
	var segments = _get_road_segments_cached(sc_x, sc_z)
	var min_d = 9999.0
	var pos_2d = Vector2(gx, gz)
	
	for seg in segments:
		# FAST BOUNDING BOX per segment
		if abs(gx - seg.a.x) > 40.0 and abs(gx - seg.b.x) > 40.0: continue
		if abs(gz - seg.a.y) > 40.0 and abs(gz - seg.b.y) > 40.0: continue
		
		var d = _dist_to_segment_2d_optimized(pos_2d, seg.a, seg.b)
		if d < min_d: 
			min_d = d
			if min_d < 1.0: break # Early exit
	
	var road_width = 12.0
	var falloff = 6.0
	var is_on_edge = false
	var tree_edge_dist = 14.5 
	
	if abs(min_d - tree_edge_dist) < 1.5:
		is_on_edge = true
	
	if min_d < (road_width + falloff):
		var w = 1.0 - clamp((min_d - road_width) / falloff, 0.0, 1.0)
		return { "is_road": true, "weight": w, "height": 2.1, "is_edge": is_on_edge, "dist": min_d }
	
	return { "is_road": false, "weight": 0.0, "height": 0.0, "is_edge": is_on_edge, "dist": min_d }

func is_settlement_tile(x: int, z: int) -> bool:
	var sc_x = floor(float(x) / SUPER_CHUNK_SIZE)
	var sc_z = floor(float(z) / SUPER_CHUNK_SIZE)
	var sett_coords = get_settlement_coords(int(sc_x), int(sc_z))
	return int(sett_coords.x) == x and int(sett_coords.y) == z

func _get_road_segments_cached(sc_x: int, sc_z: int) -> Array:
	var key = str(sc_x) + "," + str(sc_z)
	if road_cache.has(key): return road_cache[key]
	
	var segments = []
	var s_prev = get_settlement_coords(sc_x - 1, sc_z)
	var s_curr = get_settlement_coords(sc_x, sc_z)
	segments.append_array(_generate_road_points(s_prev, s_curr, true))
	
	var s_next = get_settlement_coords(sc_x + 1, sc_z)
	segments.append_array(_generate_road_points(s_curr, s_next, true))
	
	if _has_vertical_road(sc_x, sc_z - 1):
		var s_up = get_settlement_coords(sc_x, sc_z - 1)
		segments.append_array(_generate_road_points(s_up, s_curr, false))
		
	if _has_vertical_road(sc_x, sc_z):
		var s_down = get_settlement_coords(sc_x, sc_z + 1)
		segments.append_array(_generate_road_points(s_curr, s_down, false))
	
	road_cache[key] = segments
	if road_cache.size() > 50:
		road_cache.erase(road_cache.keys()[0])
		
	return segments

func _generate_road_points(t_start: Vector2, t_end: Vector2, is_horizontal: bool) -> Array:
	var points = []
	var start_pos = Vector3.ZERO
	var end_pos = Vector3.ZERO
	var cp1 = Vector3.ZERO
	var cp2 = Vector3.ZERO
	
	if is_horizontal:
		start_pos = Vector3(t_start.x * tile_size + 33.0, 0, t_start.y * tile_size)
		end_pos = Vector3(t_end.x * tile_size - 33.0, 0, t_end.y * tile_size)
		var dist = start_pos.distance_to(end_pos)
		var handle_len = dist * 0.4
		var curv_rng = RandomNumberGenerator.new()
		curv_rng.seed = (int(t_start.x + t_end.x) * 49297) ^ (int(t_start.y + t_end.y) * 91823) ^ settlement_seed
		var curve_z = curv_rng.randf_range(-40.0, 40.0)
		cp1 = start_pos + Vector3(handle_len, 0, curve_z)
		cp2 = end_pos - Vector3(handle_len, 0, -curve_z)
	else:
		var sc_x = floor(t_start.x / SUPER_CHUNK_SIZE)
		var sc_z = floor(t_start.y / SUPER_CHUNK_SIZE)
		var s_east = get_settlement_coords(sc_x + 1, sc_z)
		var h_start = Vector3(t_start.x * tile_size + 33.0, 0, t_start.y * tile_size)
		var h_end = Vector3(s_east.x * tile_size - 33.0, 0, s_east.y * tile_size)
		var h_mid = (h_start + h_end) * 0.5
		start_pos = h_mid
		end_pos = Vector3(t_end.x * tile_size, 0, t_end.y * tile_size - 33.0)
		var dist = start_pos.distance_to(end_pos)
		var handle_len = dist * 0.4
		var curv_rng_v = RandomNumberGenerator.new()
		curv_rng_v.seed = (int(t_start.x) * 73821) ^ (int(t_start.y) * 19283) ^ settlement_seed
		var curve_x = curv_rng_v.randf_range(-40.0, 40.0)
		cp1 = start_pos + Vector3(curve_x, 0, handle_len)
		cp2 = end_pos - Vector3(-curve_x, 0, handle_len)
	
	var steps = 12
	var prev_p = Vector2(start_pos.x, start_pos.z)
	for i in range(1, steps + 1):
		var t = float(i) / steps
		var p3 = _cubic_bezier(start_pos, cp1, cp2, end_pos, t)
		var curr_p = Vector2(p3.x, p3.z)
		points.append({"a": prev_p, "b": curr_p})
		prev_p = curr_p
	return points

func _has_vertical_road(sc_x: int, sc_z: int) -> bool:
	var hash_val = (int(sc_x) * 3344921) ^ (int(sc_z) * 8192371) ^ settlement_seed
	return (hash_val % 100) < 40

func _dist_to_segment_2d_optimized(p: Vector2, a: Vector2, b: Vector2) -> float:
	var pa = p - a
	var ba = b - a
	var h = clamp(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	return (pa - ba * h).length()

func _cubic_bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 = t * t
	var t3 = t2 * t
	var mt = 1.0 - t
	var mt2 = mt * mt
	var mt3 = mt2 * mt
	return p0 * mt3 + p1 * (3.0 * mt2 * t) + p2 * (3.0 * mt * t2) + p3 * t3
