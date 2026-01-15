extends Node

# SaveManager.gd - GESTOR DE PERSISTENCIA (Corregido y Robusto)
# Maneja el guardado y carga de partidas en disco mediante JSON.

const SAVE_PATH = "user://savegame.json"

var has_pending_load = false
var save_data = {}

func _ready():
	ServiceLocator.register_service("save_manager", self)

func save_game():
	var data = {}
	
	# 1. Mundo (Seed)
	var wm = ServiceLocator.get_world_manager()
	if wm:
		data["world_seed"] = wm.current_seed
	
	# 2. Jugador (Posición, Rotación)
	var player = ServiceLocator.get_player()
	if player:
		data["player_pos"] = {
			"x": player.global_transform.origin.x,
			"y": player.global_transform.origin.y,
			"z": player.global_transform.origin.z
		}
		data["player_rot_y"] = player.rotation.y
		if player.has_node("CameraPivot"):
			data["player_cam_rot_x"] = player.get_node("CameraPivot").rotation.x
		if "look_dir" in player:
			data["player_look_dir"] = {"x": player.look_dir.x, "y": player.look_dir.y}
			
		# 2.5 Caballos (Si está montado)
		data["is_riding"] = player.get("is_riding")
		if data["is_riding"] and is_instance_valid(player.get("current_horse")):
			var h = player.current_horse
			data["horse_pos"] = {
				"x": h.global_transform.origin.x,
				"y": h.global_transform.origin.y,
				"z": h.global_transform.origin.z
			}
			data["horse_rot_y"] = h.rotation.y
	
	# 3. Inventario
	var inv = ServiceLocator.get_inventory_manager()
	if inv:
		data["inventory"] = inv.get_save_data()
	
	# 4. Ciclo Día/Noche
	var dnc = ServiceLocator.get_day_cycle()
	if dnc:
		data["day_time"] = dnc.time_of_day
	
	# Guardar a disco
	var file = File.new()
	if file.open(SAVE_PATH, File.WRITE) == OK:
		file.store_string(to_json(data))
		file.close()
		print("SaveManager: Juego guardado exitosamente.")
		return true
	return false

func load_game_data():
	var file = File.new()
	if not file.file_exists(SAVE_PATH):
		print("SaveManager: No existe archivo de guardado.")
		return false
		
	if file.open(SAVE_PATH, File.READ) == OK:
		var content = file.get_as_text()
		if content.strip_edges() == "":
			print("SaveManager: Archivo vacío.")
			return false
			
		var data = parse_json(content)
		file.close()
		
		if data == null or typeof(data) != TYPE_DICTIONARY:
			print("SaveManager: Error de parseo JSON.")
			return false
			
		save_data = data
		has_pending_load = true
		print("SaveManager: Datos de carga listos.")
		return true
	return false

func get_pending_data():
	return save_data

func clear_pending_load():
	has_pending_load = false
	save_data = {}

func has_save_file():
	var file = File.new()
	return file.file_exists(SAVE_PATH)
