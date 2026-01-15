extends Node

# =============================================================================
# GameEvents.gd - SISTEMA DE EVENTOS GLOBAL (SIGNAL BUS)
# =============================================================================
# Desacopla los sistemas permitiendo comunicación sin referencias directas.
# =============================================================================

# Eventos de UI / Jugador
signal joystick_moved(vector)
signal camera_moved(vector)
signal action_pressed(action_id)
signal interaction_available(text)

# Eventos de Mundo
signal biome_changed(new_biome)
signal time_changed(is_night)
signal settlement_discovered(name)

# Eventos de Inventario
signal item_collected(item_id, amount)
signal inventory_updated()

# Eventos de Sistema
signal save_requested()
signal settings_updated()
signal world_ready()
