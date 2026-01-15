extends Node

# =============================================================================
# GameEvents.gd - SISTEMA DE EVENTOS GLOBAL (SIGNAL BUS) - EXTENDIDO
# =============================================================================
# Desacopla los sistemas permitiendo comunicación sin referencias directas.
# Todos los componentes deben usar estas señales en lugar de conexiones directas.
# =============================================================================

# --- EVENTOS DE INPUT / UI ---
signal joystick_moved(vector)       # Vector2: Dirección del joystick de movimiento
signal camera_moved(vector)          # Vector2: Dirección del joystick de cámara
signal action_pressed(action_id)     # String: ID de la acción ("interact", "attack", etc.)
signal interaction_available(text)   # String: Texto del botón de acción

# --- EVENTOS DE JUGADOR ---
signal player_spawned(player_node)   # Node: Referencia al jugador recién creado
signal player_mounted(horse_node)    # Node: Caballo en el que se montó
signal player_dismounted()           # El jugador desmontó
signal player_damaged(amount)        # Float: Cantidad de daño recibido
signal player_died()                 # El jugador murió
signal player_respawned()            # El jugador reapareció

# --- EVENTOS DE ANIMALES ---
signal animal_spawned(animal_node, animal_type)  # Node, String: Animal creado
signal animal_entered_shelter(animal_node)       # Node: Animal entró a refugio nocturno
signal animal_exited_shelter(animal_node)        # Node: Animal salió de refugio

# --- EVENTOS DE MUNDO ---
signal biome_changed(new_biome)          # Int: Nuevo bioma (enum)
signal day_passed(day_number)            # Int: Número de día actual
signal time_changed(is_night)            # Bool: true si es de noche
signal settlement_discovered(name)       # String: Nombre del asentamiento
signal tile_spawned(tile_coords)         # Vector2: Coordenadas del tile creado
signal tile_recycled(tile_coords)        # Vector2: Coordenadas del tile reciclado
signal structure_built(type, position)   # String, Vector3: Estructura construida
signal world_ready()                     # El mundo terminó de cargar

# --- EVENTOS DE INVENTARIO ---
signal item_collected(item_id, amount)   # String, Int: Item recolectado
signal item_used(item_id)                # String: Item usado
signal inventory_updated()               # El inventario cambió

# --- EVENTOS DE UI ---
signal panel_opened(panel_name)          # String: Nombre del panel abierto
signal panel_closed(panel_name)          # String: Nombre del panel cerrado
signal notification_shown(message)       # String: Notificación mostrada

# --- EVENTOS DE SISTEMA ---
signal save_requested()           # Se solicitó guardar
signal load_requested()           # Se solicitó cargar
signal settings_updated()         # La configuración cambió
signal game_paused()              # El juego se pausó
signal game_resumed()             # El juego se reanudó
