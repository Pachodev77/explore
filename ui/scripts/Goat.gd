# =============================================================================
# Goat.gd - CLASE CABRA (Refactorizada con Comportamiento de Rebaño PRO V2)
# =============================================================================
# Comportamiento: Saltitos ocasionales, movimientos rápidos y fuerte tendencia 
# a mantenerse en grupo de forma fluida (sin círculos infinitos).
# =============================================================================

extends AnimalBase

# --- CONFIGURACIÓN ESPECÍFICA ---
export var jump_force = 8.5
export var flock_radius = 60.0
export var flock_weight = 0.7  # Influencia social aumentada
export var separation_radius = 3.5 # Permitir que estén más juntas

# --- ESTADO INTERNO ---
var is_jumping = false
var biome_type = 2 

# =============================================================================
# OVERRIDES DE ANIMALBASE
# =============================================================================

func _get_animal_group() -> String:
	return "goat"

func _on_animal_ready():
	# Ajustes de velocidad y rotación más suaves para evitar círculos
	speed = 4.2
	rotation_speed = 4.0 # Rotación más natural
	if mesh_gen:
		mesh_gen.translation.y = 0.1
	
	is_eating = false
	move_timer = rand_range(1.0, 3.0)

func setup_animal(type):
	biome_type = type

func _get_eating_threshold() -> float:
	return 0.4

func _update_behavior(delta):
	# 1. Calcular fuerzas de rebaño (Solo si no estamos comiendo)
	var flock_info = {"cohesion": Vector3.ZERO, "separation": Vector3.ZERO}
	if not is_eating:
		flock_info = _calculate_flock_forces()
	
	# 2. Transiciones de estado (IA)
	if move_timer <= 0:
		if is_eating:
			# CAMBIO: Empezar a caminar (Ahora caminan menos)
			is_eating = false
			move_timer = rand_range(2.0, 5.0)
			
			# Lógica de dirección más estable
			var rand_angle = rand_range(0.0, TAU)
			var rand_dir = Vector3(sin(rand_angle), 0, cos(rand_angle))
			
			# Mezclar con el grupo solo al inicio del movimiento para evitar círculos
			if flock_info.cohesion.length() > 0.1:
				target_dir = rand_dir.linear_interpolate(flock_info.cohesion, flock_weight).normalized()
			else:
				target_dir = rand_dir
			
			if randf() < 0.3: _do_jump()
		else:
			# CAMBIO: Empezar a comer (Ahora comen más tiempo)
			is_eating = true
			target_dir = Vector3.ZERO
			velocity.x = 0
			velocity.z = 0
			move_timer = rand_range(15.0, 30.0)

	# 3. Micro-correcciones suaves (Evitar que se "atasquen" o giren en círculos)
	if not is_eating and target_dir.length() > 0.1:
		# Separación prioritaria: Evita atascos entre cabras
		if flock_info.separation.length() > 0.1:
			target_dir = target_dir.linear_interpolate(flock_info.separation, 4.0 * delta).normalized()
		
		# Cohesión suave: Solo si se aleja mucho del centro del grupo
		if flock_info.cohesion.length() > 0.1:
			# Solo aplicamos cohesión extra si el ángulo es muy cerrado (para no girar en círculos)
			var dot = target_dir.dot(flock_info.cohesion)
			if dot < 0.5: # Si el grupo está a un lado o atrás, girar gradualmente
				target_dir = target_dir.linear_interpolate(flock_info.cohesion, 0.8 * delta).normalized()

	# 4. Control de salto
	if is_on_floor() and velocity.y <= 0:
		is_jumping = false

# =============================================================================
# LÓGICA DE REBAÑO MEJORADA
# =============================================================================

func _calculate_flock_forces() -> Dictionary:
	var goats = get_tree().get_nodes_in_group("goat")
	var cohesion = Vector3.ZERO
	var separation = Vector3.ZERO
	var neighbors = 0
	var my_pos = global_transform.origin
	
	for goat in goats:
		if goat == self or not is_instance_valid(goat): continue
		
		var other_pos = goat.global_transform.origin
		var dist = my_pos.distance_to(other_pos)
		
		if dist < flock_radius:
			# Priorizar cabras que no están muy lejos para la cohesión
			cohesion += other_pos
			neighbors += 1
			
			# Separación fuerte para evitar que se pisen/atasquen
			if dist < separation_radius:
				separation += (my_pos - other_pos).normalized() * (separation_radius - dist)
	
	if neighbors > 0:
		cohesion = (cohesion / neighbors - my_pos).normalized()
	
	if separation.length() > 0.01:
		separation = separation.normalized()
		
	return {"cohesion": cohesion, "separation": separation}

func _do_jump():
	if is_on_floor():
		velocity.y = jump_force
		is_jumping = true

# =============================================================================
# ANIMACIÓN (Mismos parámetros visuales)
# =============================================================================

func _animate_animal(delta, is_moving):
	if not mesh_gen or not "parts" in mesh_gen: return
	var p = mesh_gen.parts
	
	var h_speed = Vector3(velocity.x, 0, velocity.z).length()
	var s_ratio = clamp(h_speed / speed, 0.0, 1.0)
	
	# Damping agresivo para evitar que las patas queden en el aire al empezar a comer
	var move_damping = 1.0 - eating_weight
	s_ratio *= move_damping
	
	# Solo permitir ratio de salto si no estamos comiendo y realmente estamos en el aire
	if not is_on_floor() and not is_eating:
		s_ratio = lerp(s_ratio, 1.0, move_damping)
	
	var bounce = abs(sin(anim_phase)) * 0.12 * s_ratio
	if "body" in p:
		p.body.translation.y = (mesh_gen.hu * 1.6) + bounce
		p.body.rotation.x = sin(anim_phase) * 0.08 * s_ratio
	
	var offsets = {"fl": 0.0, "br": PI*0.5, "fr": PI, "bl": PI*1.5}
	for leg in ["fl", "fr", "bl", "br"]:
		if not ("leg_"+leg in p): continue
		var lp = anim_phase + offsets[leg]
		p["leg_"+leg].rotation.x = sin(lp) * 0.45 * s_ratio
		if "joint_"+leg in p:
			p["joint_"+leg].rotation.x = -max(0, -cos(lp)) * 1.0 * s_ratio

	if "head" in p:
		p.head.rotation.y = sin(OS.get_ticks_msec() * 0.004) * 0.15 * (1.0 - eating_weight)
		if "neck_base" in p:
			p.neck_base.rotation.x = -eating_weight * deg2rad(120.0)
			p.head.rotation.x = eating_weight * deg2rad(75.0)
