extends Node

# =============================================================================
# ServiceLocator.gd - LOCALIZADOR DE SERVICIOS (Mejorado)
# =============================================================================
# Proporciona acceso instantáneo a sistemas centrales sin usar find_node().
# Uso: ServiceLocator.get_player(), ServiceLocator.register_service("player", self)
# =============================================================================

# --- REFERENCIAS A SERVICIOS ---
var world_manager: Node = null
var player: Node = null
var hud: Control = null
var day_cycle: Node = null
var save_manager: Node = null
var inventory: Node = null

# --- CONSTANTES DE NOMBRES ---
const SERVICE_WORLD = "world"
const SERVICE_PLAYER = "player"
const SERVICE_HUD = "hud"
const SERVICE_DAY_CYCLE = "day_cycle"
const SERVICE_SAVE_MANAGER = "save_manager"
const SERVICE_INVENTORY = "inventory"

# =============================================================================
# API PÚBLICA
# =============================================================================

func register_service(service_name: String, node: Node) -> void:
	"""Registra un servicio para acceso global."""
	match service_name:
		SERVICE_WORLD: world_manager = node
		SERVICE_PLAYER: player = node
		SERVICE_HUD: hud = node
		SERVICE_DAY_CYCLE: day_cycle = node
		SERVICE_SAVE_MANAGER: save_manager = node
		SERVICE_INVENTORY: inventory = node
		_: push_warning("ServiceLocator: Servicio desconocido: " + service_name)

func unregister_service(service_name: String) -> void:
	"""Desregistra un servicio (útil al cambiar de escena)."""
	register_service(service_name, null)

func has_service(service_name: String) -> bool:
	"""Verifica si un servicio está registrado."""
	match service_name:
		SERVICE_WORLD: return world_manager != null
		SERVICE_PLAYER: return player != null
		SERVICE_HUD: return hud != null
		SERVICE_DAY_CYCLE: return day_cycle != null
		SERVICE_SAVE_MANAGER: return save_manager != null
		SERVICE_INVENTORY: return inventory != null
	return false

func clear_all() -> void:
	"""Limpia todos los servicios (útil al volver al menú principal)."""
	world_manager = null
	player = null
	hud = null
	day_cycle = null
	# save_manager e inventory se mantienen ya que son Autoloads persistentes

# =============================================================================
# GETTERS TIPADOS
# =============================================================================

func get_world_manager() -> Node:
	return world_manager

func get_player() -> Node:
	return player

func get_hud() -> Control:
	return hud

func get_day_cycle() -> Node:
	return day_cycle

func get_save_manager() -> Node:
	return save_manager

func get_inventory_manager() -> Node:
	return inventory
