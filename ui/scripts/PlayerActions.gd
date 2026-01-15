# =============================================================================
# PlayerActions.gd - SISTEMA DE ACCIONES E INTERACCIONES
# =============================================================================
# Gestiona la deteccion de objetos interactuables (vacas, arboles) y las
# secuencias de animacion para obtener recursos.
# =============================================================================

extends Node
class_name PlayerActions

var player = null
var hud_ref = null

var is_performing_action = false
var _near_cow = false
var _near_tree = false
var _near_beehive = false
var _near_coop = false

var current_target_tree_mmi = null
var current_target_tree_idx = -1
var milking_target_cow = null
var target_beehive = null
var coop_pos = Vector3(-18.0, 1.0, 18.0)

var _check_tick = 0

func init(p_node, h_ref):
	player = p_node
	hud_ref = h_ref

func update_interaction_check():
	if not hud_ref: return
	
	_check_tick += 1
	if _check_tick < 10: return
	_check_tick = 0
	
	# 1. Deteccion de Vacas
	var can_milk = false
	var cows = player.get_tree().get_nodes_in_group("cow")
	for c in cows:
		var is_in_stable = false
		if c.get("is_night_cow") and c.get("has_reached_waypoint"):
			var target = c.get("night_target_pos")
			if target and c.global_transform.origin.distance_to(target) < 2.5:
				is_in_stable = true
		
		if is_in_stable and c.global_transform.origin.distance_to(player.global_transform.origin) < 3.0:
			can_milk = true
			milking_target_cow = c
			break
	
	# 2. Deteccion de Arboles (solo si no hay vacas cerca)
	var can_wood = false
	if not can_milk:
		current_target_tree_mmi = null
		current_target_tree_idx = -1
		var tree_mmis = player.get_tree().get_nodes_in_group("tree_mmi")
		var closest_dist = 7.0
		var my_pos = player.global_transform.origin
		
		for mmi in tree_mmis:
			if my_pos.distance_to(mmi.global_transform.origin) > 100.0: continue
			if mmi is MultiMeshInstance and mmi.multimesh:
				var mm = mmi.multimesh
				var max_check = min(mm.instance_count, 30)
				for i in range(max_check):
					var itf = mmi.global_transform * mm.get_instance_transform(i)
					
					# NO INTERACTUAR SI EL ARBOL TIENE ESCALA 0 (Ya talado)
					if mm.get_instance_transform(i).basis.get_scale().length() < 0.1:
						continue
						
					var dist = my_pos.distance_to(itf.origin)
					if dist < closest_dist:
						closest_dist = dist
						can_wood = true
						current_target_tree_mmi = mmi
						current_target_tree_idx = i
						if dist < 2.2: break
			if can_wood and closest_dist < 2.2: break
	
	# 3. Deteccion de Colmenas (solo si no hay vacas ni arboles cerca)
	var can_honey = false
	if not can_milk and not can_wood:
		target_beehive = null
		var beehives = player.get_tree().get_nodes_in_group("beehive")
		for b in beehives:
			if b.global_transform.origin.distance_to(player.global_transform.origin) < 3.0:
				if b.has_method("is_harvestable") and not b.is_harvestable():
					continue
				can_honey = true
				target_beehive = b
				break

	# 4. Deteccion de Gallinero (solo si no hay otros cerca)
	var can_eggs = false
	if not can_milk and not can_wood and not can_honey:
		var wm = ServiceLocator.get_world_manager()
		var dnc = ServiceLocator.get_day_cycle()
		if wm and dnc and wm.last_egg_harvest_day < dnc.get_current_day():
			# Solo en el tile central (0,0)
			if abs(player.global_transform.origin.x) < 75.0 and abs(player.global_transform.origin.z) < 75.0:
				if player.global_transform.origin.distance_to(coop_pos) < 5.0:
					can_eggs = true

	_near_cow = can_milk
	_near_tree = can_wood
	_near_beehive = can_honey
	_near_coop = can_eggs
	
	if _near_cow: hud_ref.set_action_label("MILK")
	elif _near_tree: hud_ref.set_action_label("WOOD")
	elif _near_beehive: hud_ref.set_action_label("HONEY")
	elif _near_coop: hud_ref.set_action_label("EGGS")
	else: hud_ref.set_action_label("ACTION")

func execute_action():
	if is_performing_action or player.is_riding: return
	
	if _near_cow:
		_start_milking_sequence()
	elif _near_tree:
		_start_woodcutting_sequence()
	elif _near_beehive:
		_start_honey_sequence()
	elif _near_coop:
		_start_egg_sequence()

func _start_egg_sequence():
	is_performing_action = true
	player.is_performing_action = true
	
	var dir_to_coop = (coop_pos - player.global_transform.origin).normalized()
	var target_rot = atan2(dir_to_coop.x, dir_to_coop.z)
	player.get_node("MeshInstance").rotation.y = target_rot
	
	if player.has_node("WalkAnimator"):
		player.get_node("WalkAnimator").set_milking(true) # Reusar animación
	
	AudioManager.play_sfx("milking", 0.6)
	yield(player.get_tree().create_timer(2.0), "timeout")
	_finish_egg()

func _finish_egg():
	is_performing_action = false
	player.is_performing_action = false
	if player.has_node("WalkAnimator"):
		player.get_node("WalkAnimator").set_milking(false)
	
	var chicken_count = player.get_tree().get_nodes_in_group("chicken").size()
	if chicken_count > 0:
		if player.has_node("/root/InventoryManager"):
			player.get_node("/root/InventoryManager").add_item("egg", chicken_count)
		
		var wm = ServiceLocator.get_world_manager()
		var dnc = ServiceLocator.get_day_cycle()
		if wm and dnc:
			wm.last_egg_harvest_day = dnc.get_current_day()

func _start_honey_sequence():
	if not target_beehive: return
	is_performing_action = true
	player.is_performing_action = true
	
	var dir_to_hive = (target_beehive.global_transform.origin - player.global_transform.origin).normalized()
	var target_rot = atan2(dir_to_hive.x, dir_to_hive.z)
	player.get_node("MeshInstance").rotation.y = target_rot
	
	if player.has_node("WalkAnimator"):
		player.get_node("WalkAnimator").set_milking(true) # Reusar animación de manos
	
	AudioManager.play_sfx("milking", 0.7) # Sonido similar para recolectar
	yield(player.get_tree().create_timer(4.0), "timeout")
	_finish_honey()

func _finish_honey():
	is_performing_action = false
	player.is_performing_action = false
	if player.has_node("WalkAnimator"):
		player.get_node("WalkAnimator").set_milking(false)
		
	if player.has_node("/root/InventoryManager"):
		player.get_node("/root/InventoryManager").add_item("honey", 1)
	
	# Registrar Cosecha para Cooldown de 3 dias
	var wm = ServiceLocator.get_world_manager()
	var dnc = ServiceLocator.get_day_cycle()
	if wm and dnc and target_beehive:
		var pos_key = "%d,%d,%d" % [round(target_beehive.global_transform.origin.x), round(target_beehive.global_transform.origin.y), round(target_beehive.global_transform.origin.z)]
		wm.beehive_harvests[pos_key] = dnc.get_current_day()
		# Forzar que el nodo oculte las abejas inmediatamente
		if target_beehive.has_method("_ready"):
			target_beehive._ready()
	
	target_beehive = null

func _start_woodcutting_sequence():
	if not current_target_tree_mmi: return
	is_performing_action = true
	player.is_performing_action = true # Sync with main player state
	
	var mm = current_target_tree_mmi.multimesh
	var itf = current_target_tree_mmi.global_transform * mm.get_instance_transform(current_target_tree_idx)
	var dir_to_tree = (itf.origin - player.global_transform.origin).normalized()
	var ideal_dist = 1.3
	var target_pos = itf.origin - dir_to_tree * ideal_dist
	target_pos.y = player.global_transform.origin.y
	
	var tween = player.get_tree().create_tween()
	tween.tween_property(player, "translation", target_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	yield(tween, "finished")
	
	dir_to_tree = (itf.origin - player.global_transform.origin).normalized()
	var target_rot = atan2(dir_to_tree.x, dir_to_tree.z)
	player.get_node("MeshInstance").rotation.y = target_rot - deg2rad(45.0)
	
	if player.has_node("WalkAnimator"):
		player.get_node("WalkAnimator").set_chopping(true)
	
	AudioManager.play_sfx("chopping", 1.0)
	yield(player.get_tree().create_timer(1.2), "timeout") # Duración síncrona con animación
	_finish_woodcutting()

func _finish_woodcutting():
	is_performing_action = false
	player.is_performing_action = false
	if player.has_node("WalkAnimator"):
		player.get_node("WalkAnimator").set_chopping(false)
		
	if is_instance_valid(current_target_tree_mmi) and current_target_tree_mmi.multimesh:
		var tile = current_target_tree_mmi.get_parent().get_parent()
		var container = current_target_tree_mmi.get_parent()
		var target_idx = current_target_tree_idx
		var target_group = "tree_mmi" if current_target_tree_mmi.is_in_group("tree_mmi") else "cactus_mmi"
		
		if tile.has_method("mark_instance_as_harvested"):
			tile.mark_instance_as_harvested(target_group, target_idx)
		
		for child in container.get_children():
			if child is MultiMeshInstance and child.multimesh and child.is_in_group(target_group):
				var mm = child.multimesh
				if target_idx >= 0 and target_idx < mm.instance_count:
					var tf = mm.get_instance_transform(target_idx)
					tf = tf.scaled(Vector3.ZERO)
					mm.set_instance_transform(target_idx, tf)

	if player.has_node("/root/InventoryManager"):
		player.get_node("/root/InventoryManager").add_item("wood", 3)
	
	current_target_tree_mmi = null
	current_target_tree_idx = -1

func _start_milking_sequence():
	if not milking_target_cow: return
	is_performing_action = true
	player.is_performing_action = true
	
	var dir_to_cow = (milking_target_cow.global_transform.origin - player.global_transform.origin).normalized()
	var target_rot = atan2(dir_to_cow.x, dir_to_cow.z)
	player.get_node("MeshInstance").rotation.y = target_rot
	
	if player.has_node("WalkAnimator"):
		player.get_node("WalkAnimator").set_milking(true)
	
	AudioManager.play_sfx("milking", 0.8)
	yield(player.get_tree().create_timer(3.0), "timeout")
	_finish_milking()

func _finish_milking():
	is_performing_action = false
	player.is_performing_action = false
	if player.has_node("WalkAnimator"):
		player.get_node("WalkAnimator").set_milking(false)
		
	if player.has_node("/root/InventoryManager"):
		player.get_node("/root/InventoryManager").add_item("milk", 1)
	
	milking_target_cow = null
