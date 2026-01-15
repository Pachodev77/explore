extends Node

# =============================================================================
# ServiceLocator.gd - LOCALIZADOR DE SERVICIOS
# =============================================================================
# Proporciona acceso instantáneo a sistemas centrales sin usar find_node().
# =============================================================================

var world_manager = null
var player = null
var hud = null
var day_cycle = null
var save_manager = null
var inventory = null

func register_service(name: String, node: Node):
	match name:
		"world": world_manager = node
		"player": player = node
		"hud": hud = node
		"day_cycle": day_cycle = node
		"save_manager": save_manager = node
		"inventory": inventory = node

func has_service(name: String) -> bool:
	match name:
		"world": return world_manager != null
		"player": return player != null
		"hud": return hud != null
		"day_cycle": return day_cycle != null
		"save_manager": return save_manager != null
		"inventory": return inventory != null
	return false

func get_world_manager(): return world_manager
func get_player(): return player
func get_hud(): return hud
func get_day_cycle(): return day_cycle
func get_save_manager(): return save_manager
func get_inventory_manager(): return inventory
