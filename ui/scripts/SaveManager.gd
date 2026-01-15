extends Node

# =============================================================================
# SaveManager.gd - GESTOR DE PERSISTENCIA (Mejorado)
# =============================================================================
# Maneja el guardado y carga de partidas en disco mediante JSON.
# Uso: SaveManager.save_game(), SaveManager.load_game_data()
# =============================================================================

const SAVE_PATH: String = "user://savegame.json"

var has_pending_load: bool = false
var save_data: Dictionary = {}

func _ready() -> void:
	ServiceLocator.register_service("save_manager", self)

# =============================================================================
# GUARDADO
# =============================================================================

func save_game() -> bool:
	"""Guarda el estado actual del juego. Retorna true si tuvo éxito."""
	var data: Dictionary = {}
	
	# 1. Mundo (Seed)
	var wm = ServiceLocator.get_world_manager()
	if wm and "current_seed" in wm:
		data["world_seed"] = wm.current_seed
	
	# 2. Jugador (Posición, Rotación)
	var player = ServiceLocator.get_player()
	if player:
		data["player_pos"] = _vector3_to_dict(player.global_transform.origin)
		data["player_rot_y"] = player.rotation.y
		
		# Cámara
		if player.has_node("CameraPivot"):
			data["player_cam_rot_x"] = player.get_node("CameraPivot").rotation.x
		
		# Dirección de mirada
		if "look_dir" in player:
			data["player_look_dir"] = {"x": player.look_dir.x, "y": player.look_dir.y}
		
		# Estado de montura
		data["is_riding"] = player.get("is_riding") == true
		if data["is_riding"] and is_instance_valid(player.get("current_horse")):
			var h = player.current_horse
			data["horse_pos"] = _vector3_to_dict(h.global_transform.origin)
			data["horse_rot_y"] = h.rotation.y
	
	# 3. Inventario
	var inv = ServiceLocator.get_inventory_manager()
	if inv and inv.has_method("get_save_data"):
		data["inventory"] = inv.get_save_data()
	
	# 4. Ciclo Día/Noche
	var dnc = ServiceLocator.get_day_cycle()
	if dnc and "time_of_day" in dnc:
		data["day_time"] = dnc.time_of_day
	
	# 5. Timestamp
	data["save_timestamp"] = OS.get_unix_time()
	
	# Escribir a disco
	var file = File.new()
	var err = file.open(SAVE_PATH, File.WRITE)
	if err != OK:
		push_error("SaveManager: No se pudo abrir archivo para escritura. Error: " + str(err))
		return false
	
	file.store_string(to_json(data))
	file.close()
	
	GameEvents.emit_signal("save_requested")
	return true

# =============================================================================
# CARGA
# =============================================================================

func load_game_data() -> bool:
	"""Carga los datos del archivo de guardado. Retorna true si tuvo éxito."""
	var file = File.new()
	
	if not file.file_exists(SAVE_PATH):
		push_warning("SaveManager: No existe archivo de guardado.")
		return false
	
	var err = file.open(SAVE_PATH, File.READ)
	if err != OK:
		push_error("SaveManager: No se pudo abrir archivo para lectura. Error: " + str(err))
		return false
	
	var content = file.get_as_text()
	file.close()
	
	if content.strip_edges() == "":
		push_warning("SaveManager: Archivo vacío.")
		return false
	
	var data = parse_json(content)
	
	if data == null or typeof(data) != TYPE_DICTIONARY:
		push_error("SaveManager: Error de parseo JSON.")
		return false
	
	save_data = data
	has_pending_load = true
	
	GameEvents.emit_signal("load_requested")
	return true

func get_pending_data() -> Dictionary:
	"""Obtiene los datos cargados pendientes de aplicar."""
	return save_data

func clear_pending_load() -> void:
	"""Limpia los datos pendientes después de aplicarlos."""
	has_pending_load = false
	save_data = {}

func has_save_file() -> bool:
	"""Verifica si existe un archivo de guardado."""
	var file = File.new()
	return file.file_exists(SAVE_PATH)

func delete_save_file() -> bool:
	"""Elimina el archivo de guardado. Retorna true si tuvo éxito."""
	var dir = Directory.new()
	if dir.file_exists(SAVE_PATH):
		var err = dir.remove(SAVE_PATH)
		return err == OK
	return true

# =============================================================================
# UTILIDADES
# =============================================================================

func _vector3_to_dict(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}

func _dict_to_vector3(d: Dictionary) -> Vector3:
	return Vector3(d.get("x", 0), d.get("y", 0), d.get("z", 0))

func get_save_info() -> Dictionary:
	"""Obtiene información sobre el guardado sin cargarlo completamente."""
	if not has_save_file():
		return {}
	
	var file = File.new()
	if file.open(SAVE_PATH, File.READ) != OK:
		return {}
	
	var content = file.get_as_text()
	file.close()
	
	var data = parse_json(content)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		return {}
	
	return {
		"timestamp": data.get("save_timestamp", 0),
		"has_horse": data.get("is_riding", false)
	}
