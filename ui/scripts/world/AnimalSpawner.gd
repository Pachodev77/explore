# =============================================================================
# AnimalSpawner.gd - SPAWNING DE ANIMALES
# =============================================================================
# Maneja la creación y posicionamiento inicial de animales en el mundo.
# =============================================================================

extends Reference
class_name AnimalSpawner

var _world_node: Node = null
var _shared_res: Dictionary = {}

# =============================================================================
# INICIALIZACIÓN
# =============================================================================

func init(world_node: Node, shared_res: Dictionary) -> void:
	_world_node = world_node
	_shared_res = shared_res

# =============================================================================
# SPAWNING DE ANIMALES
# =============================================================================

func spawn_initial_animals(get_height_func: FuncRef, saved_data = null) -> void:
	"""Spawnea todos los animales iniciales de forma escalonada."""
	# Caballo
	yield(_spawn_horse(get_height_func, saved_data), "completed")
	
	# Vacas
	yield(_spawn_cows(get_height_func), "completed")
	
	# Cabras
	yield(_spawn_goats(get_height_func), "completed")
	
	# Gallinas
	yield(_spawn_chickens(get_height_func), "completed")

func _spawn_horse(get_height_func: FuncRef, saved_data) -> void:
	var horse_scene = load("res://ui/scenes/Horse.tscn")
	if not horse_scene:
		return
	
	yield(_world_node.get_tree(), "idle_frame")
	if not is_instance_valid(_world_node):
		return
	
	var horse = horse_scene.instance()
	_world_node.add_child(horse)
	
	var h_pos = Vector3(10, 0, -10)
	var h_rot = 0.0
	var should_mount = false
	
	if saved_data and saved_data.has("is_riding") and saved_data["is_riding"]:
		if saved_data.has("horse_pos"):
			var hp = saved_data["horse_pos"]
			h_pos = Vector3(hp.x, hp.y, hp.z)
			should_mount = true
		if saved_data.has("horse_rot_y"):
			h_rot = saved_data["horse_rot_y"]
	
	var h_y = get_height_func.call_func(h_pos.x, h_pos.z)
	horse.global_transform.origin = Vector3(h_pos.x, h_y + 0.8, h_pos.z)
	horse.rotation.y = h_rot
	
	if should_mount:
		yield(_world_node.get_tree(), "idle_frame")
		var player = ServiceLocator.get_player()
		if is_instance_valid(player) and player.has_method("mount"):
			player.mount(horse)

func _spawn_cows(get_height_func: FuncRef) -> void:
	if not _shared_res.has("cow_scene") or not _shared_res["cow_scene"]:
		return
	
	for i in range(2):
		var cow = _shared_res["cow_scene"].instance()
		_world_node.add_child(cow)
		cow.speed = 4.0
		
		var offset = 15 if i == 0 else -15
		var h = get_height_func.call_func(offset, -offset)
		cow.global_transform.origin = Vector3(offset, h + 0.8, -offset)
		
		cow.is_night_cow = true
		cow.night_target_pos = Vector3(18.0, 2.0, 18.0)  # Establo
		cow.night_waypoint_pos = Vector3(18.0, 2.0, 10.0)
	
	yield(_world_node.get_tree(), "idle_frame")

func _spawn_goats(get_height_func: FuncRef) -> void:
	if not _shared_res.has("goat_scene") or not _shared_res["goat_scene"]:
		return
	
	for i in range(3):
		var goat = _shared_res["goat_scene"].instance()
		_world_node.add_child(goat)
		
		var angle = i * (TAU / 3.0)
		var cluster_offset = Vector3(cos(angle), 0, sin(angle)) * 3.0
		var spawn_pos = Vector3(10, 0, 0) + cluster_offset
		var hg = get_height_func.call_func(spawn_pos.x, spawn_pos.z)
		goat.global_transform.origin = Vector3(spawn_pos.x, hg + 0.8, spawn_pos.z)
	
	yield(_world_node.get_tree(), "idle_frame")

func _spawn_chickens(get_height_func: FuncRef) -> void:
	if not _shared_res.has("chicken_scene") or not _shared_res["chicken_scene"]:
		return
	
	for i in range(4):
		var chicken = _shared_res["chicken_scene"].instance()
		_world_node.add_child(chicken)
		chicken.size_unit = 0.28
		
		var angle = i * (TAU / 4.0)
		var offset = Vector3(cos(angle), 0, sin(angle)) * 4.0
		var spawn_pos = Vector3(-18, 0, 18) + offset
		var hc = get_height_func.call_func(spawn_pos.x, spawn_pos.z)
		chicken.global_transform.origin = Vector3(spawn_pos.x, hc + 0.5, spawn_pos.z)
		
		chicken.is_night_chicken = true
		chicken.night_target_pos = Vector3(-18.0, 2.0, 18.0)  # Gallinero
		chicken.night_waypoint_pos = Vector3(-18.0, 2.0, 14.0)
	
	yield(_world_node.get_tree(), "idle_frame")
