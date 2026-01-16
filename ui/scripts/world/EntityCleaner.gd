# =============================================================================
# EntityCleaner.gd - SISTEMA DE LIMPIEZA AGRESIVA DE ENTIDADES
# =============================================================================
# Limpia animales, colmenas y otras entidades que están lejos del jugador.
# =============================================================================

extends Reference
class_name EntityCleaner

# Configuración
const CLEANUP_INTERVAL: float = 2.0  # Segundos entre limpiezas (más frecuente)
const DESPAWN_DISTANCE: float = 250.0  # Distancia para despawnear (reducida)

# Estado
var _cleanup_timer: float = 0.0
var _player: Node = null
var _world_node: Node = null

# Animales del spawn inicial que NO deben limpiarse
var _protected_entities: Array = []

# Estadísticas
var _total_cleaned: int = 0

# =============================================================================
# API PÚBLICA
# =============================================================================

func init(world_node: Node) -> void:
	_world_node = world_node
	_player = ServiceLocator.get_player()

func protect_animal(animal: Node) -> void:
	"""Marca un animal como protegido (no se limpiará)."""
	if animal and not animal in _protected_entities:
		_protected_entities.append(animal)

func unprotect_animal(animal: Node) -> void:
	"""Quita la protección de un animal."""
	var idx = _protected_entities.find(animal)
	if idx >= 0:
		_protected_entities.remove(idx)

func process(delta: float) -> void:
	"""Llamar desde _process del WorldManager."""
	_cleanup_timer -= delta
	if _cleanup_timer > 0:
		return
	
	_cleanup_timer = CLEANUP_INTERVAL
	
	if not _player or not is_instance_valid(_player):
		_player = ServiceLocator.get_player()
		if not _player:
			return
	
	var player_pos = _player.global_transform.origin
	
	# Limpiar diferentes tipos de entidades
	_cleanup_distant_entities(player_pos, "animals")
	_cleanup_distant_entities(player_pos, "beehive")
	_cleanup_distant_entities(player_pos, "horses")
	
	# Limpiar lista de protegidos de referencias inválidas
	_cleanup_protected_list()

# =============================================================================
# LIMPIEZA DE ENTIDADES
# =============================================================================

func _cleanup_distant_entities(player_pos: Vector3, group_name: String) -> void:
	"""Limpia entidades de un grupo que están muy lejos del jugador."""
	if not _world_node:
		return
	
	var tree = _world_node.get_tree()
	if not tree:
		return
	
	var entities = tree.get_nodes_in_group(group_name)
	
	for entity in entities:
		if not is_instance_valid(entity):
			continue
		
		# Saltar entidades protegidas
		if entity in _protected_entities:
			continue
		
		# Calcular distancia
		var distance = entity.global_transform.origin.distance_to(player_pos)
		
		if distance > DESPAWN_DISTANCE:
			# Limpiar hijos primero si los tiene
			_destroy_children_recursive(entity)
			entity.queue_free()
			_total_cleaned += 1

func _destroy_children_recursive(node: Node) -> void:
	"""Destruye todos los hijos de un nodo recursivamente."""
	var children = []
	for child in node.get_children():
		children.append(child)
	
	for child in children:
		if is_instance_valid(child):
			_destroy_children_recursive(child)
			child.queue_free()

func _cleanup_protected_list() -> void:
	"""Limpia referencias inválidas de la lista de protegidos."""
	var valid_entities = []
	for entity in _protected_entities:
		if is_instance_valid(entity):
			valid_entities.append(entity)
	_protected_entities = valid_entities

# =============================================================================
# LIMPIEZA FORZADA
# =============================================================================

func force_cleanup_all_unprotected() -> void:
	"""Fuerza la limpieza de TODAS las entidades no protegidas."""
	if not _world_node:
		return
	
	var tree = _world_node.get_tree()
	if not tree:
		return
	
	var groups = ["animals", "beehive", "horses"]
	
	for group_name in groups:
		var entities = tree.get_nodes_in_group(group_name)
		for entity in entities:
			if is_instance_valid(entity) and not entity in _protected_entities:
				_destroy_children_recursive(entity)
				entity.queue_free()
				_total_cleaned += 1

# =============================================================================
# ESTADÍSTICAS
# =============================================================================

func get_stats() -> Dictionary:
	"""Retorna estadísticas de limpieza."""
	var tree = _world_node.get_tree() if _world_node else null
	var total_animals = tree.get_nodes_in_group("animals").size() if tree else 0
	var total_beehives = tree.get_nodes_in_group("beehive").size() if tree else 0
	
	return {
		"total_animals": total_animals,
		"total_beehives": total_beehives,
		"protected_count": _protected_entities.size(),
		"total_cleaned": _total_cleaned
	}
