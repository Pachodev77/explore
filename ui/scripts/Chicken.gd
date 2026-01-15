# =============================================================================
# Chicken.gd - CLASE GALLINA (Refactorizada - Extiende AnimalBase)
# =============================================================================
# Comportamiento: Movimientos espasmódicos, picoteo y regreso al gallinero.
# Ahora hereda de AnimalBase para evitar duplicación de código.
# =============================================================================

extends AnimalBase

# --- CONFIGURACIÓN ESPECÍFICA ---
export var size_unit = 0.28

# --- ESTADO DE COMPORTAMIENTO ---
var is_pecking = false
var is_sleeping = false
var sleeping_weight = 0.0
var head_bob = 0.0

# --- NAVEGACIÓN NOCTURNA (Usa sistema de AnimalBase) ---
var is_night_chicken = false  # Alias para compatibilidad

# =============================================================================
# OVERRIDES DE ANIMALBASE
# =============================================================================

func _get_animal_group() -> String:
	return "chicken"

func _on_animal_ready():
	# Configuración específica de gallinas
	speed = 2.0
	rotation_speed = 8.0
	gravity = 20.0
	active_dist = 40.0
	
	if mesh_gen:
		if mesh_gen.has_method("_generate_structure"):
			if "size_unit" in mesh_gen:
				mesh_gen.size_unit = size_unit
			mesh_gen._generate_structure()
		mesh_gen.translation.y = 0.05
	
	move_timer = rand_range(2.0, 4.0)
	is_pecking = true
	is_eating = true  # Sincronizar con AnimalBase

func _get_eating_threshold() -> float:
	return 0.5

# =============================================================================
# COMPORTAMIENTO (Override de AnimalBase)
# =============================================================================

func _update_behavior(delta):
	# Sincronizar estado de navegación nocturna con AnimalBase
	if is_night_chicken:
		is_night_animal = true
		night_target_pos = night_target_pos if night_target_pos else Vector3.ZERO
		night_waypoint_pos = night_waypoint_pos if night_waypoint_pos else Vector3.ZERO
	
	var _is_night = is_night()
	
	# Navegación nocturna (Usando sistema de AnimalBase)
	if is_night_chicken and (_is_night or is_exiting):
		if _is_night:
			# Navegar al refugio
			var arrived = navigate_to_night_target(delta)
			is_pecking = false
			if arrived:
				is_sleeping = true
				is_pecking = false
			else:
				is_sleeping = false
		elif is_exiting:
			# Salir del refugio
			var exited = exit_night_shelter(delta)
			is_sleeping = false
			is_pecking = false
			if exited:
				is_pecking = true
	elif move_timer <= 0:
		_random_behavior()

func _random_behavior():
	is_sleeping = false
	
	# Detectar si debe salir del refugio
	if not is_night() and is_night_chicken and has_reached_waypoint and not is_exiting:
		is_exiting = true
	elif not is_pecking and randf() < 0.75:
		# Empezar a picotear
		is_pecking = true
		is_eating = true  # Sincronizar con AnimalBase
		target_dir = Vector3.ZERO
		move_timer = rand_range(8.0, 18.0)
	else:
		# Empezar a moverse
		is_pecking = false
		is_eating = false
		var rand_angle = rand_range(0.0, TAU)
		target_dir = Vector3(sin(rand_angle), 0, cos(rand_angle))
		move_timer = rand_range(2.0, 4.0)

# =============================================================================
# ANIMACIÓN (Override de AnimalBase)
# =============================================================================

func _animate_animal(delta, is_moving):
	if not mesh_gen or not "parts" in mesh_gen:
		return
	var p: Dictionary = mesh_gen.parts
	
	# Actualizar pesos de animación
	_update_animation_weights(delta)
	
	# 1. Cuerpo y cabeceo
	if is_moving:
		head_bob = sin(anim_phase * 2.0) * 0.2
		if "body" in p:
			p.body.translation.y = (mesh_gen.size_unit * 2.0) + abs(sin(anim_phase)) * 0.04
		if "neck_base" in p:
			p.neck_base.translation.z = -mesh_gen.size_unit * 1.0 + head_bob
	else:
		head_bob = lerp(head_bob, 0.0, 5.0 * delta)
		if "body" in p:
			var base_h = mesh_gen.size_unit * (2.0 - (sleeping_weight * 0.3))
			p.body.translation.y = lerp(p.body.translation.y, base_h, 5.0 * delta)
	
	# 2. Picoteo (Usando eating_weight de AnimalBase)
	if "neck_base" in p:
		var bow_neck = -eating_weight * deg2rad(50.0)
		p.neck_base.translation.y = (mesh_gen.size_unit * 0.5) - (eating_weight * mesh_gen.size_unit * 0.15)
		
		var jitter = 0.0
		if eating_weight > 0.5:
			jitter = -abs(sin(OS.get_ticks_msec() * 0.015)) * deg2rad(30.0)
		
		p.neck_base.rotation.x = bow_neck + jitter
		
		if "head" in p:
			p.head.rotation.x = -eating_weight * deg2rad(15.0) + jitter * 0.3
	
	# 3. Patas
	if is_moving:
		for s in [-1, 1]:
			var leg = "leg_l" if s == -1 else "leg_r"
			if leg in p:
				var l_phase = anim_phase if s == -1 else anim_phase + PI
				p[leg].rotation.x = sin(l_phase) * 0.6
	else:
		for leg in ["leg_l", "leg_r"]:
			if leg in p:
				p[leg].rotation.x = lerp(p[leg].rotation.x, 0.0, 5.0 * delta)
	
	# 4. Alas
	if is_moving:
		var wing_flap = sin(anim_phase * 4.0) * 0.1
		if "wing_l" in p:
			p.wing_l.rotation.z = wing_flap
		if "wing_r" in p:
			p.wing_r.rotation.z = -wing_flap
	else:
		if "wing_l" in p:
			p.wing_l.rotation.z = lerp(p.wing_l.rotation.z, 0.0, 5.0 * delta)
		if "wing_r" in p:
			p.wing_r.rotation.z = lerp(p.wing_r.rotation.z, 0.0, 5.0 * delta)

func _update_animation_weights(delta):
	# Picoteo: Solo si está comiendo y casi quieta
	var target_peck = 1.0 if is_pecking and velocity.length() < 0.5 and not is_sleeping else 0.0
	eating_weight = lerp(eating_weight, target_peck, 4.0 * delta)
	
	# Dormir
	var target_sleep = 1.0 if is_sleeping else 0.0
	sleeping_weight = lerp(sleeping_weight, target_sleep, 2.0 * delta)
