# =============================================================================
# Cow.gd - CLASE VACA (Refactorizada - Extiende AnimalBase)
# =============================================================================
# Comportamiento: Caminar errático y pose relajada de pastoreo.
# Ahora hereda de AnimalBase para evitar duplicación de código.
# =============================================================================

extends AnimalBase

# --- CONFIGURACIÓN ESPECÍFICA ---
var biome_type = 0  # 0: Prairie

# --- NAVEGACIÓN NOCTURNA (Alias para compatibilidad) ---
var is_night_cow = false

# =============================================================================
# OVERRIDES DE ANIMALBASE
# =============================================================================

func _get_animal_group() -> String:
	return "cow"

func _on_animal_ready():
	# Configuración específica de vacas
	speed = 1.5
	rotation_speed = 2.0
	gravity = 25.0
	active_dist = 60.0
	
	if mesh_gen:
		if mesh_gen.has_method("_generate_structure"):
			mesh_gen._generate_structure()
		mesh_gen.translation.y = 0.2
	
	move_timer = rand_range(2.0, 5.0)
	is_eating = true

func setup_animal(type):
	biome_type = type

func _get_eating_threshold() -> float:
	return 0.4

# =============================================================================
# COMPORTAMIENTO (Override de AnimalBase)
# =============================================================================

func _update_behavior(delta):
	# Sincronizar estado de navegación nocturna con AnimalBase
	if is_night_cow:
		is_night_animal = true
	
	var _is_night = is_night()
	
	# Navegación nocturna (Usando sistema de AnimalBase)
	if is_night_cow and (_is_night or is_exiting):
		if _is_night:
			# Navegar al establo
			var arrived = navigate_to_night_target(delta)
			if arrived:
				is_eating = true  # Descansar en el establo
		elif is_exiting:
			# Salir del establo
			exit_night_shelter(delta)
	elif move_timer <= 0:
		_random_behavior()

func _random_behavior():
	# Detectar si debe salir del establo
	if not is_night() and is_night_cow and has_reached_waypoint and not is_exiting:
		is_exiting = true
	elif not is_eating:
		# Empezar a comer
		is_eating = true
		target_dir = Vector3.ZERO
		move_timer = rand_range(10.0, 25.0)
	else:
		# Empezar a caminar
		is_eating = false
		var rand_angle = rand_range(0.0, TAU)
		target_dir = Vector3(sin(rand_angle), 0, cos(rand_angle))
		move_timer = rand_range(3.0, 6.0)

# =============================================================================
# ANIMACIÓN (Override de AnimalBase)
# =============================================================================

func _animate_animal(delta, is_moving):
	if not mesh_gen or not "parts" in mesh_gen:
		return
	var p_nodes = mesh_gen.parts
	
	var h_speed = Vector3(velocity.x, 0, velocity.z).length()
	var s_ratio = clamp(h_speed / speed, 0.0, 1.0) if speed > 0 else 0.0
	
	# Usar anim_phase de AnimalBase (ya actualizado)
	var p = anim_phase / TAU  # Convertir a 0-1 para compatibilidad
	
	# Rebote de cuerpo (Lento y pesado)
	var bounce = abs(sin(p * TAU)) * 0.06 * s_ratio
	if "body" in p_nodes:
		p_nodes.body.translation.y = (mesh_gen.hu * 1.5) + bounce
		p_nodes.body.rotation.z = sin(p * TAU) * 0.02 * s_ratio
	
	# Patas (Caminata alternada)
	var offsets = {"fl": 0.0, "br": 0.25, "fr": 0.5, "bl": 0.75}
	for leg in ["fl", "fr", "bl", "br"]:
		if not ("leg_"+leg in p_nodes):
			continue
		
		var lp = wrapf(p + offsets[leg], 0.0, 1.0)
		var swing = sin(lp * TAU)
		
		# Rotación de pierna
		p_nodes["leg_"+leg].rotation.x = swing * 0.4 * s_ratio
		
		# Flexión de rodilla (Solo al levantar)
		if "joint_"+leg in p_nodes:
			var knee = max(0, -cos(lp * TAU)) * 0.8 * s_ratio
			p_nodes["joint_"+leg].rotation.x = -knee

	# Cola
	if "tail" in p_nodes:
		p_nodes.tail.rotation.z = sin(OS.get_ticks_msec() * 0.002) * 0.3
		
	# Cuello y Cabeza (Comer) - Usando eating_weight de AnimalBase
	if "neck_base" in p_nodes:
		# Bajar el cuello más profundo
		var eat_pose = -eating_weight * deg2rad(110.0)
		p_nodes.neck_base.rotation.x = eat_pose
		
		if "head" in p_nodes:
			# Extender la cabeza hacia arriba/adelante para compensar
			p_nodes.head.rotation.x = eating_weight * deg2rad(60.0)
