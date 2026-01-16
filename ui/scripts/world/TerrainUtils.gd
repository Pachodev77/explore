# =============================================================================
# TerrainUtils.gd - UTILIDADES DE TERRENO
# =============================================================================
# Funciones para cálculo de altura y biomas del terreno.
# =============================================================================

extends Reference
class_name TerrainUtils

var _height_noise: OpenSimplexNoise
var _biome_noise: OpenSimplexNoise
var _road_system: RoadSystem
var _height_multipliers: Dictionary

# =============================================================================
# INICIALIZACIÓN
# =============================================================================

func init(height_noise: OpenSimplexNoise, biome_noise: OpenSimplexNoise, road_system: RoadSystem) -> void:
	_height_noise = height_noise
	_biome_noise = biome_noise
	_road_system = road_system
	
	_height_multipliers = {
		"snow": GameConfig.H_SNOW,
		"jungle": GameConfig.H_JUNGLE,
		"desert": GameConfig.H_DESERT,
		"prairie": GameConfig.H_PRAIRIE
	}

# =============================================================================
# ALTURA DEL TERRENO
# =============================================================================

func get_terrain_height_at(x: float, z: float) -> float:
	"""Calcula la altura del terreno en una posición mundial."""
	if not _height_noise or not _biome_noise:
		return 0.0
	
	var noise_val = _biome_noise.get_noise_2d(x, z)
	var deg = rad2deg(atan2(z, x)) + (noise_val * 120.0)
	
	# Normalizar ángulo
	while deg > 180:
		deg -= 360
	while deg <= -180:
		deg += 360
	
	var h_mult = _calculate_height_multiplier(deg)
	var y = _height_noise.get_noise_2d(x, z) * h_mult
	
	# Aplanado del área de spawn
	y = _apply_spawn_flattening(x, z, y)
	
	# Influencia de carreteras
	y = _apply_road_influence(x, z, y)
	
	return y

func _calculate_height_multiplier(deg: float) -> float:
	"""Calcula el multiplicador de altura basado en el bioma."""
	var hn = _height_multipliers.snow
	var hs = _height_multipliers.jungle
	var he = _height_multipliers.desert
	var hw = _height_multipliers.prairie
	
	if deg >= -90 and deg <= 0:
		var t = (deg + 90) / 90.0
		return lerp(hn, he, t)
	elif deg > 0 and deg <= 90:
		var t = deg / 90.0
		return lerp(he, hs, t)
	elif deg > 90 and deg <= 180:
		var t = (deg - 90) / 90.0
		return lerp(hs, hw, t)
	else:
		var t = (deg + 180) / 90.0
		return lerp(hw, hn, t)

func _apply_spawn_flattening(x: float, z: float, y: float) -> float:
	"""Aplana el terreno en el área de spawn."""
	if abs(x) < 50 and abs(z) < 50:
		var dist = max(abs(x), abs(z))
		var blend = clamp(1.0 - (dist - 33.0) / 20.0, 0.0, 1.0)
		return lerp(y, 2.0, blend)
	return y

func _apply_road_influence(x: float, z: float, y: float) -> float:
	"""Aplica la influencia de las carreteras en la altura."""
	if _road_system:
		var road_info = _road_system.get_road_influence(x, z)
		if road_info.is_road:
			return lerp(y, road_info.height, road_info.weight)
	return y

# =============================================================================
# CÁLCULO DE SPAWN INICIAL
# =============================================================================

func calculate_spawn_height() -> float:
	"""Calcula la altura de spawn inicial en (0,0)."""
	var h_val = _height_noise.get_noise_2d(0, 0)
	var b_noise_val = _biome_noise.get_noise_2d(0, 0)
	var deg = rad2deg(atan2(0, 0)) + (b_noise_val * 120.0)
	
	var h_mult = GameConfig.H_PRAIRIE
	if deg > 45 and deg <= 135:
		h_mult = GameConfig.H_JUNGLE
	elif deg > -45 and deg <= 45:
		h_mult = GameConfig.H_DESERT
	elif deg > -135 and deg <= -45:
		h_mult = GameConfig.H_SNOW
	
	return h_val * h_mult + 5.0
