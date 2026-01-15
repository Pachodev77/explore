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

func register_service(name: String, node: Node):
	match name:
		"world": world_manager = node
		"player": player = node
		"hud": hud = node
		"day_cycle": day_cycle = node

func get_world_manager(): return world_manager
func get_player(): return player
func get_hud(): return hud
func get_day_cycle(): return day_cycle
