# =============================================================================
# TileManager.gd - GESTIÓN DE TILES DEL MUNDO
# =============================================================================
# Maneja el spawning, pooling, LOD y cola de tiles del terreno.
# =============================================================================

extends Reference
class_name TileManager

# Configuración
var tile_scene: PackedScene
var tile_size: float = 150.0
var render_distance: int = 4

# OPTIMIZACIÓN: Limitar el pool para no acumular memoria
const MAX_POOL_SIZE: int = 9  # Máximo tiles en pool (3x3)

# Estado
var active_tiles: Dictionary = {}
var spawn_queue: Array = []
var tile_pool: Array = []
var last_player_tile: Vector2 = Vector2.INF

# Referencias
var _world_node: Node = null
var _road_system: RoadSystem = null
var _shared_res: Dictionary = {}

# Timers
var _lod_upgrade_timer: float = 0.0

# Para ordenamiento
var _sort_target: Vector2 = Vector2.ZERO

# Debug
var _tiles_recycled_count: int = 0
var _tiles_destroyed_count: int = 0

# =============================================================================
# INICIALIZACIÓN
# =============================================================================

func init(world_node: Node, road_system: RoadSystem, shared_res: Dictionary, ts: float, rd: int) -> void:
	_world_node = world_node
	_road_system = road_system
	_shared_res = shared_res
	tile_size = ts
	render_distance = rd
	tile_scene = preload("res://ui/scenes/GroundTile.tscn")

# =============================================================================
# SPAWNING INICIAL
# =============================================================================

func spawn_initial_area(player_pos: Vector3) -> void:
	"""Genera el área inicial 3x3 con LOD alto en el centro."""
	var p_coords = get_tile_coords(player_pos)
	
	for x in range(int(p_coords.x) - 1, int(p_coords.x) + 2):
		for z in range(int(p_coords.y) - 1, int(p_coords.y) + 2):
			var is_player_tile = (x == int(p_coords.x) and z == int(p_coords.y))
			spawn_tile(x, z, 0 if is_player_tile else 1)
	
	last_player_tile = p_coords

# =============================================================================
# ACTUALIZACIÓN DE TILES
# =============================================================================

func update_tiles(player_pos: Vector3) -> void:
	"""Actualiza los tiles activos basándose en la posición del jugador."""
	var player_coords = get_tile_coords(player_pos)
	var new_active_coords = []
	var x_int = int(player_coords.x)
	var z_int = int(player_coords.y)
	
	# Determinar tiles necesarios
	for x in range(x_int - render_distance, x_int + render_distance + 1):
		for z in range(z_int - render_distance, z_int + render_distance + 1):
			var coords = Vector2(x, z)
			new_active_coords.append(coords)
			
			if not active_tiles.has(coords):
				if not spawn_queue.has(coords):
					spawn_queue.push_back(coords)
	
	# Limpiar cola de tiles fuera de rango
	var filtered_queue = []
	for c in spawn_queue:
		if abs(c.x - x_int) <= render_distance and abs(c.y - z_int) <= render_distance:
			filtered_queue.append(c)
	spawn_queue = filtered_queue
	
	# Ordenar por distancia si la cola es grande
	if spawn_queue.size() > 5:
		_sort_target = player_coords
		spawn_queue.sort_custom(self, "_sort_by_dist")
	
	# Reciclar tiles fuera de rango
	_recycle_tiles(new_active_coords)

func _recycle_tiles(new_active_coords: Array) -> void:
	"""Recicla tiles que ya no son necesarios."""
	var coords_to_remove = []
	for coords in active_tiles.keys():
		if not coords in new_active_coords:
			coords_to_remove.append(coords)
	
	for coords in coords_to_remove:
		var tile = active_tiles[coords]
		if is_instance_valid(tile):
			# SIEMPRE limpiar el contenido del tile ANTES de cualquier otra cosa
			_deep_cleanup_tile(tile)
			
			# Remover del árbol
			if tile.get_parent():
				tile.get_parent().remove_child(tile)
			
			# Decidir si guardar en pool o destruir
			if tile_pool.size() < MAX_POOL_SIZE:
				tile_pool.append(tile)
				_tiles_recycled_count += 1
			else:
				# Pool lleno: DESTRUIR el tile completamente
				tile.queue_free()
				_tiles_destroyed_count += 1
		
		active_tiles.erase(coords)

func _deep_cleanup_tile(tile: Node) -> void:
	"""Limpieza PROFUNDA y COMPLETA de todo el contenido del tile."""
	# 1. Limpiar contenedor de decoraciones
	var deco_container = tile.get_node_or_null("Decos")
	if deco_container:
		_destroy_all_children(deco_container)
	
	# 2. Limpiar cualquier hijo directo del tile que no sea estructural
	for child in tile.get_children():
		# Mantener solo MeshInstance y CollisionShape (estructura del tile)
		if child.name == "MeshInstance" or child.name == "CollisionShape" or child.name == "Decos":
			continue
		# Destruir todo lo demás
		child.queue_free()
	
	# 3. Resetear estado del tile
	if tile.has_method("_reset_state"):
		tile._reset_state()

func _destroy_all_children(parent: Node) -> void:
	"""Destruye TODOS los hijos de un nodo, recursivamente."""
	# Crear lista de hijos primero para evitar modificar mientras iteramos
	var children = []
	for child in parent.get_children():
		children.append(child)
	
	# Destruir cada hijo
	for child in children:
		if is_instance_valid(child):
			# Recursivamente limpiar nietos primero
			_destroy_all_children(child)
			child.queue_free()

func _sort_by_dist(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(_sort_target) < b.distance_to(_sort_target)

# =============================================================================
# PROCESO POR FRAME
# =============================================================================

func process_spawn_queue(player_pos: Vector3) -> void:
	"""Procesa la cola de spawn (1 tile por frame)."""
	if spawn_queue.size() == 0:
		return
	
	var best_idx = 0
	var min_d = 99999.0
	
	for i in range(min(spawn_queue.size(), 4)):
		var d = player_pos.distance_to(Vector3(spawn_queue[i].x * tile_size, 0, spawn_queue[i].y * tile_size))
		if d < min_d:
			min_d = d
			best_idx = i
	
	var coords = spawn_queue[best_idx]
	spawn_queue.remove(best_idx)
	spawn_tile(int(coords.x), int(coords.y))

func process_lod_upgrades(delta: float, player_pos: Vector3) -> void:
	"""Procesa upgrades de LOD (1 por ciclo)."""
	_lod_upgrade_timer -= delta
	if _lod_upgrade_timer > 0:
		return
	
	_lod_upgrade_timer = 2.0  # Solo cada 2 segundos
	
	for coords in active_tiles.keys():
		var tile = active_tiles[coords]
		if tile.has_method("upgrade_to_high_lod") and tile.current_lod == tile.TileLOD.LOW:
			var dist = player_pos.distance_to(tile.global_transform.origin)
			if dist < 200.0:
				tile.upgrade_to_high_lod()
				break  # Solo 1 por ciclo

# =============================================================================
# SPAWNING
# =============================================================================

func spawn_tile(x: int, z: int, forced_lod: int = -1) -> void:
	"""Spawnea o recicla un tile en las coordenadas dadas."""
	var coords = Vector2(x, z)
	if active_tiles.has(coords):
		return
	
	var tile = null
	if tile_pool.size() > 0:
		tile = tile_pool.pop_back()
		# Asegurarse de que el tile reciclado esté limpio
		if is_instance_valid(tile):
			_deep_cleanup_tile(tile)
	else:
		tile = tile_scene.instance()
	
	tile.translation = Vector3(x * tile_size, 0, z * tile_size)
	tile.visible = true
	_world_node.add_child(tile)
	
	var is_spawn = (x == 0 and z == 0) or _road_system.is_settlement_tile(x, z)
	var lod = forced_lod if forced_lod != -1 else 1
	
	if tile.has_method("setup_biome"):
		tile.setup_biome(0, _shared_res, 0, is_spawn, lod)
	
	active_tiles[coords] = tile

# =============================================================================
# UTILIDADES
# =============================================================================

func get_tile_coords(pos: Vector3) -> Vector2:
	"""Convierte posición global a coordenadas de tile."""
	return Vector2(
		floor((pos.x + tile_size * 0.5) / tile_size),
		floor((pos.z + tile_size * 0.5) / tile_size)
	)

func should_update(player_pos: Vector3) -> bool:
	"""Determina si es necesario actualizar los tiles."""
	var current_tile = get_tile_coords(player_pos)
	return current_tile.distance_to(last_player_tile) > 0.5

func mark_updated(player_pos: Vector3) -> void:
	"""Marca la posición actual como última actualizada."""
	last_player_tile = get_tile_coords(player_pos)

# =============================================================================
# DEBUG / STATS
# =============================================================================

func get_stats() -> Dictionary:
	"""Retorna estadísticas para debug."""
	return {
		"active_tiles": active_tiles.size(),
		"pool_size": tile_pool.size(),
		"queue_size": spawn_queue.size(),
		"tiles_recycled": _tiles_recycled_count,
		"tiles_destroyed": _tiles_destroyed_count
	}

func force_cleanup_all() -> void:
	"""Fuerza la limpieza de todos los tiles (para cambio de escena)."""
	for coords in active_tiles.keys():
		var tile = active_tiles[coords]
		if is_instance_valid(tile):
			_deep_cleanup_tile(tile)
			tile.queue_free()
	active_tiles.clear()
	
	for tile in tile_pool:
		if is_instance_valid(tile):
			tile.queue_free()
	tile_pool.clear()
	
	spawn_queue.clear()
