extends KinematicBody

class_name Horse

export var speed = 10.0
export var rotation_speed = 3.0
export var jump_force = 12.0
export var gravity = 25.0

var velocity = Vector3.ZERO
var is_ridden = false
var rider = null

# --- SISTEMA DE AGUA ---
export var water_level = -8.0
var in_water = false

# Puntos clave
onready var mount_point = $MountPoint
onready var interaction_area = $InteractionArea
onready var mesh_gen = $ProceduralMesh

var rider_input = Vector2.ZERO
var rider_sprinting = false
var anim_phase = 0.0
var anim_bounce = 0.0
var anim_pitch = 0.0

# --- SISTEMA DE SALTO PRO ---
enum JumpState { IDLE, ANTICIPATION, IN_AIR, IMPACT }
var current_jump_state = JumpState.IDLE
var jump_timer = 0.0

# Parámetros suavizados
var curr_h_crouch = 0.0
var curr_h_pitch = 0.0
var curr_h_leg_f = 0.0 # Front legs lift
var curr_h_leg_b = 0.0 # Back legs lift
var horse_smoothing = 12.0
var gait_lerp = 0.0 # 0 = Trot/Standard, 1 = Full Gallop

func _ready():
	add_to_group("horses")
	# Inicializar mesh si no está hecho
	if mesh_gen and mesh_gen.has_method("_generate_structure"):
		mesh_gen._generate_structure()
		# AJUSTE VISUAL: Subir el mesh para que no parezca hundido en el suelo
		mesh_gen.translation.y = 0.3

func _physics_process(delta):
	# Detección de agua (Hasta el cuello, más profundo)
	# Si el origen está por debajo de water_level + 2.1, ya estamos en el agua
	in_water = global_transform.origin.y < water_level + 2.1
	
	if in_water:
		# 1. Resistencia viscosa
		velocity.y = lerp(velocity.y, 0, 8.0 * delta)
		
		# 2. Objetivo de flotación profunda: -2.05m (V4: Sumergir más el cuello)
		var target_y = water_level - 2.05 
		var diff = target_y - global_transform.origin.y
		
		# Solo aplicar flotación si no estamos tocando el suelo DE FORMA FIRME 
		# o si el suelo está muy profundo.
		var b_force = 45.0
		if is_on_floor() and global_transform.origin.y > target_y:
			# Si estamos en la orilla, reducir flotación para ganar tracción
			b_force = 5.0
		
		velocity.y += diff * b_force * delta
	else:
		# Gravedad normal fuera del agua
		if not is_on_floor():
			velocity.y -= gravity * delta
	
	# --- MOVIMIENTO Y SALTO ---
	match current_jump_state:
		JumpState.ANTICIPATION:
			jump_timer += delta
			if jump_timer > 0.12:
				velocity.y = jump_force
				current_jump_state = JumpState.IN_AIR
				jump_timer = 0.0
		JumpState.IN_AIR:
			jump_timer += delta
			if is_on_floor() and velocity.y <= 0:
				current_jump_state = JumpState.IMPACT
				jump_timer = 0.0
		JumpState.IMPACT:
			jump_timer += delta
			if jump_timer > 0.3:
				current_jump_state = JumpState.IDLE
				jump_timer = 0.0
	
	if is_ridden and rider:
		_process_ridden_movement(delta)
	else:
		_process_idle_movement(delta)
	
	# SNAP: Solo activarlo si estamos en la orilla o tierra firme
	# Si el origen está muy profundo (y < water_level - 1.0), NO snappeamos para poder flotar
	var snap = Vector3.ZERO
	if is_on_floor() and current_jump_state == JumpState.IDLE:
		if not in_water or global_transform.origin.y > water_level - 1.0:
			snap = -get_floor_normal() * 0.4
	
	velocity = move_and_slide_with_snap(velocity, snap, Vector3.UP, true, 4, deg2rad(70))
	
	# --- ACTUALIZAR SUAVIZADO DE ANIMACIÓN ---
	_update_smoothed_parameters(delta)
	
	# Transición de marcha (Gait)
	var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
	var target_gait = 1.0 if (rider_sprinting and horizontal_speed > speed * 0.8) else 0.0
	gait_lerp = lerp(gait_lerp, target_gait, delta * 3.0)
	
	# Gestionar Animación
	_update_animation(delta)

func _update_animation(delta):
	var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
	if horizontal_speed > 0.5:
		# Animación más pausada: Reducimos la frecuencia base y el multiplicador
		# Antes: 1.2 + ... * 1.0. Ahora es más lento.
		var freq = 0.8 + (horizontal_speed / speed) * 0.6 
		anim_phase = wrapf(anim_phase + freq * delta, 0.0, 1.0)
		_animate_gallop(anim_phase)
	else:
		anim_phase = lerp(anim_phase, 0.0, 5 * delta)
		_animate_gallop(0.0) # Reset a pose base

func _animate_gallop(p):
	if not mesh_gen or not "parts" in mesh_gen: return
	var p_nodes = mesh_gen.parts
	
	var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
	var speed_ratio = clamp(horizontal_speed / speed, 0.0, 1.0)
	
	# 1. Cuerpo (Dinámica de Carrera)
	# Intensificar movimiento si está al galope tendido
	var bounce_mult = lerp(1.0, 1.4, gait_lerp)
	var pitch_mult = lerp(1.0, 1.8, gait_lerp)
	
	anim_bounce = abs(sin(p * TAU)) * 0.12 * speed_ratio * bounce_mult
	anim_pitch = cos(p * TAU) * 0.1 * speed_ratio * pitch_mult
	
	if "body" in p_nodes:
		p_nodes.body.translation.y = (mesh_gen.hu * 2.2) + anim_bounce + curr_h_crouch
		p_nodes.body.rotation.x = anim_pitch + deg2rad(curr_h_pitch)
		
	# 2. Patas (Articulación Avanzada)
	# Ritmo normal (Trote/Canter): Diagonales
	var off_normal = {"bl": 0.0, "fr": 0.1, "br": 0.5, "fl": 0.6}
	# Ritmo Gallop Tendido: Asimétrico (1-2-1 o similar)
	var off_sprint = {"bl": 0.0, "br": 0.15, "fl": 0.5, "fr": 0.65}
	
	# Nueva variable para detener el ciclo de las patas durante el salto
	var cycle_weight = 1.0 if current_jump_state == JumpState.IDLE else 0.0
	
	for leg in ["fl", "fr", "bl", "br"]:
		if not ("leg_"+leg in p_nodes) or not ("joint_"+leg in p_nodes): continue
		
		# Mezclar offsets según la intensidad de la marcha
		var leg_off = lerp(off_normal[leg], off_sprint[leg], gait_lerp)
		var leg_p = wrapf(p + leg_off, 0.0, 1.0)
		var swing = sin(leg_p * TAU) * cycle_weight # Detener vaivén si salta
		
		# --- ROTACIÓN SUPERIOR (Hombro/Cadera) ---
		var upper_rot = 0.0
		if leg.begins_with("f"):
			# Delanteras: Sesgo frontal para alcanzar terreno
			# El sesgo base (+0.45) también se multiplica por cycle_weight para dejar paso limpio a la pose de salto
			upper_rot = (swing * 0.8 + 0.45 * cycle_weight) * speed_ratio
		else:
			# Traseras: Sesgo trasero para empujar (-0.2)
			upper_rot = (swing * 0.7 - 0.2 * cycle_weight) * speed_ratio
		
		# Modificar rotación base por el salto (FRONT: Forward, BACK: Tuck)
		var jump_offset = curr_h_leg_f if leg.begins_with("f") else -curr_h_leg_b
		p_nodes["leg_"+leg].rotation.x = upper_rot + deg2rad(jump_offset)
		
		# --- ARTICULACIÓN MEDIA (Rodilla/Corvejón) ---
		var knee_fold = 0.0
		if swing > 0:
			# Fase de vuelo del galope (Doblar)
			knee_fold = (swing * 1.5) * speed_ratio 
		
		if leg.begins_with("f"):
			# Rodilla delantera
			p_nodes["joint_"+leg].rotation.x = -knee_fold
		else:
			# Corvejón trasero: En salto usamos jump_knee, en galope knee_fold
			var jump_knee = (curr_h_leg_b * 1.5) if current_jump_state != JumpState.IDLE else 0.0
			p_nodes["joint_"+leg].rotation.x = -knee_fold * 0.7 - deg2rad(jump_knee)
			
		
		# --- CASCOS (Menudillo/Fetlock) ---
		if "hoof_"+leg in p_nodes:
			var hoof_rot = 0.0
			if swing > 0.3: # Levantando (solo en galope por cycle_weight)
				hoof_rot = (swing - 0.3) * 1.2
			elif swing < -0.5: # Impacto
				hoof_rot = -0.2
			p_nodes["hoof_"+leg].rotation.x = hoof_rot * speed_ratio

	# 3. Cuello y Cola (Contrapeso y Fluidez)
	if "neck_base" in p_nodes:
		var neck_bounce = sin(p * TAU - 0.5) * 0.1 * speed_ratio
		# Bajar la cabeza al correr (postura de esfuerzo)
		var neck_lowering = gait_lerp * 0.4
		p_nodes.neck_base.rotation.x = -anim_pitch * 0.6 + neck_bounce + neck_lowering
		
	if "tail" in p_nodes:
		# La cola ahora se mueve menos y está más baja
		var tail_lift = lerp(0.3, 0.8, gait_lerp)
		var tail_swing_speed = lerp(1.5, 3.0, gait_lerp)
		p_nodes.tail.rotation.x = tail_lift + (sin(p * TAU * tail_swing_speed) * 0.2 * speed_ratio)
		p_nodes.tail.rotation.z = (sin(p * TAU * 1.5) * 0.15 * speed_ratio * (1.0 + gait_lerp))

func _process_ridden_movement(delta):
	var move_dir = Vector3.ZERO
	
	if rider and rider.has_node("CameraPivot"):
		var cam_pivot = rider.get_node("CameraPivot")
		var cam_basis = cam_pivot.global_transform.basis
		
		# 1. Calcular dirección deseada en el mundo (Relativa a la cámara)
		var forward = -cam_basis.z
		var right = cam_basis.x
		forward.y = 0
		right.y = 0
		forward = forward.normalized()
		right = right.normalized()
		
		var target_world_dir = (forward * -rider_input.y + right * rider_input.x).normalized()
		
		# 2. Si hay input, rotar el caballo hacia esa dirección
		if rider_input.length() > 0.1 and target_world_dir.length() > 0.1:
			var old_cam_basis = cam_pivot.global_transform.basis
			
			# Crear una base que mire hacia la dirección objetivo
			var target_basis = Transform.IDENTITY.looking_at(target_world_dir, Vector3.UP).basis
			var target_quat = Quat(target_basis).normalized()
			var current_quat = Quat(global_transform.basis).normalized()
			
			var new_quat = current_quat.slerp(target_quat, 4.0 * delta)
			global_transform.basis = Basis(new_quat)
			
			# Mantener estabilidad
			rotation.x = 0
			rotation.z = 0
			
			# Evitar que la cámara gire solidaria al caballo
			cam_pivot.global_transform.basis = old_cam_basis
			
			# Al estar rotando hacia la dirección, el movimiento siempre es "adelante" del caballo
			move_dir = -transform.basis.z * rider_input.length()
	
	# SPRINT: Apply 1.5x speed multiplier when rider is sprinting
	var current_speed = speed * (1.5 if rider_sprinting else 1.0)
	
	# REDUCIR VELOCIDAD EN AGUA
	if in_water:
		# Si toca tierra (is_on_floor), tiene más tracción (0.75), si no, nada más lento (0.45)
		var swim_factor = 0.75 if is_on_floor() else 0.45
		current_speed *= swim_factor
	
	# Movimiento con aceleración suave
	var target_vel = move_dir.normalized() * current_speed * (0.5 if rider_input.length() < 0.5 else 1.0)
	velocity.x = lerp(velocity.x, target_vel.x, 3 * delta)
	velocity.z = lerp(velocity.z, target_vel.z, 3 * delta)

func _process_idle_movement(delta):
	# Fricción fuerte cuando nadie monta
	velocity.x = lerp(velocity.x, 0, 5 * delta)
	velocity.z = lerp(velocity.z, 0, 5 * delta)

func interact(player_node):
	if is_ridden:
		return # Ya montado
	
	print("Caballo: Jugador montando")
	is_ridden = true
	rider = player_node
	
	# El jugador se encargará de posicionarse, o lo hacemos aquí
	# Aquí solo marcamos estado

func dismount():
	is_ridden = false
	rider = null


func jump():
	if current_jump_state == JumpState.IDLE and is_on_floor():
		current_jump_state = JumpState.ANTICIPATION
		jump_timer = 0.0

func _update_smoothed_parameters(delta):
	var targets = {"crouch": 0.0, "pitch": 0.0, "leg_f": 0.0, "leg_b": 0.0}
	
	match current_jump_state:
		JumpState.ANTICIPATION:
			var t = clamp(jump_timer / 0.12, 0.0, 1.0)
			targets.crouch = -0.3 * sin(t * PI)
			targets.pitch = 2.0 * t # Pitch muy leve hacia abajo
			targets.leg_f = 20.0 * t
		JumpState.IN_AIR:
			# SALTO BALANCEADO: Menos vertical, más horizontal
			if jump_timer < 0.22:
				var t = clamp(jump_timer / 0.22, 0.0, 1.0)
				targets.pitch = 18.0 * t  
				targets.leg_f = 75.0 * t  # Más elevación delantera (antes 60)
				targets.leg_b = 35.0 * t
			else:
				if velocity.y > 0:
					var v_f = clamp(velocity.y / jump_force, 0, 1)
					targets.pitch = lerp(5.0, 18.0, v_f) 
					targets.leg_f = 70.0
					targets.leg_b = 35.0 
				else:
					# Descenso (Ápice y bajada)
					# Para que las patas delanteras toquen primero:
					# 1. Mayor cabeceo hacia adelante (-22 grados)
					# 2. Las patas delanteras se estiran rápido, las traseras se quedan encogidas más tiempo
					var v_f = clamp(abs(velocity.y) / gravity, 0.0, 1.0)
					targets.pitch = -22.0 * v_f 
					targets.leg_f = lerp(70.0, -10.0, clamp(v_f * 1.5, 0, 1)) # Estirar un poco más allá del 0
					targets.leg_b = lerp(35.0, 10.0, v_f) # Mantener cierto encogimiento
		JumpState.IMPACT:
			var t = clamp(jump_timer / 0.3, 0.0, 1.0)
			var s = sin(t * PI)
			targets.crouch = -0.4 * s
			# El cabeceo se recupera: primero cae el frente, luego la parte trasera (baja el pitch)
			targets.pitch = lerp(-22.0, 5.0, t) * s 
			targets.leg_f = 0.0
			targets.leg_b = 0.0
			
	curr_h_crouch = lerp(curr_h_crouch, targets.crouch, delta * horse_smoothing)
	curr_h_pitch = lerp(curr_h_pitch, targets.pitch, delta * horse_smoothing)
	curr_h_leg_f = lerp(curr_h_leg_f, targets.leg_f, delta * horse_smoothing)
	curr_h_leg_b = lerp(curr_h_leg_b, targets.leg_b, delta * horse_smoothing)
