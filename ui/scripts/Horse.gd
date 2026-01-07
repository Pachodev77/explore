extends KinematicBody

class_name Horse

export var speed = 10.0
export var rotation_speed = 3.0
export var jump_force = 12.0
export var gravity = 25.0

var velocity = Vector3.ZERO
var is_ridden = false
var rider = null

# Puntos clave
onready var mount_point = $MountPoint
onready var interaction_area = $InteractionArea
onready var mesh_gen = $ProceduralMesh

var rider_input = Vector2.ZERO
var rider_sprinting = false
var anim_phase = 0.0
var anim_bounce = 0.0
var anim_pitch = 0.0

func _ready():
	add_to_group("horses")
	# Inicializar mesh si no está hecho
	if mesh_gen and mesh_gen.has_method("_generate_structure"):
		mesh_gen._generate_structure()
		# AJUSTE VISUAL: Subir el mesh para que no parezca hundido en el suelo
		mesh_gen.translation.y = 0.3

func _physics_process(delta):
	# Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Update jump state
	if is_jumping:
		jump_timer += delta
		if jump_timer > 0.5 or (is_on_floor() and jump_timer > 0.1):  # Reset after 0.5s or when landing (with small delay)
			is_jumping = false
			jump_timer = 0.0
	
	if is_ridden and rider:
		_process_ridden_movement(delta)
	else:
		_process_idle_movement(delta)
	
	# CRITICAL FIX: Disable snap when jumping to allow upward velocity
	# Snap forces the body to stick to ground, which cancels jump velocity
	var snap = Vector3.ZERO
	if is_on_floor() and not is_jumping:
		snap = -get_floor_normal() * 0.4
	elif is_on_floor():
		snap = Vector3.DOWN * 0.2
	
	velocity = move_and_slide_with_snap(velocity, snap, Vector3.UP, true, 4, deg2rad(70))
	
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
	# Reducimos la inclinación frontal (forward_lean) para sea más natural
	var forward_lean = 0.0 # Eliminado: no inclinarse hacia adelante
	anim_bounce = abs(sin(p * TAU)) * 0.12 * speed_ratio
	anim_pitch = cos(p * TAU) * 0.1 * speed_ratio + forward_lean
	
	if "body" in p_nodes:
		p_nodes.body.translation.y = (mesh_gen.hu * 2.2) + anim_bounce
		p_nodes.body.rotation.x = anim_pitch
		
	# 2. Patas (Articulación Avanzada)
	# Tiempos: Cambiamos a un ritmo de "Trote" o "Walk" más estable visualmente
	# Diagonal pairs: (BL, FR) y (BR, FL)
	var offsets = {"bl": 0.0, "fr": 0.1, "br": 0.5, "fl": 0.6}
	
	for leg in ["fl", "fr", "bl", "br"]:
		if not ("leg_"+leg in p_nodes) or not ("joint_"+leg in p_nodes): continue
		
		var leg_p = wrapf(p + offsets[leg], 0.0, 1.0)
		var swing = sin(leg_p * TAU)
		
		# --- ROTACIÓN SUPERIOR (Hombro/Cadera) ---
		var upper_rot = 0.0
		if leg.begins_with("f"):
			# Delanteras: Sesgo frontal para alcanzar terreno (+0.3)
			upper_rot = (swing * 0.6 + 0.3) * speed_ratio
		else:
			# Traseras: Sesgo trasero para empujar (-0.2)
			# Movimiento más de "pistón"
			upper_rot = (swing * 0.7 - 0.2) * speed_ratio
		
		p_nodes["leg_"+leg].rotation.x = upper_rot
		
		# --- ARTICULACIÓN MEDIA (Rodilla/Corvejón) ---
		var knee_fold = 0.0
		if swing > 0:
			# Fase de vuelo (Doblar)
			knee_fold = (swing * 1.5) * speed_ratio
		else:
			# Fase de apoyo (Estirar suavemente o mantener recto)
			knee_fold = 0.0 
			
		if leg.begins_with("f"):
			# Rodilla delantera se dobla hacia atrás (rotación negativa habitual)
			p_nodes["joint_"+leg].rotation.x = -knee_fold
		else:
			# Corvejón trasero: Visualmente la "rodilla" trasera (stifle) está arriba oculta,
			# pero la articulación media visible (hock) se dobla "hacia atrás" igual que la delantera
			# en la mayoría de rigs simples, PERO con menos intensidad para no parecer agachado.
			p_nodes["joint_"+leg].rotation.x = -knee_fold * 0.7
			
		
		# --- CASCOS (Menudillo/Fetlock) ---
		if "hoof_"+leg in p_nodes:
			var hoof_rot = 0.0
			if swing > 0.3: # Levantando
				hoof_rot = (swing - 0.3) * 1.2
			elif swing < -0.5: # Impacto
				hoof_rot = -0.2
			p_nodes["hoof_"+leg].rotation.x = hoof_rot * speed_ratio

	# 3. Cuello y Cola (Contrapeso y Fluidez)
	if "neck_base" in p_nodes:
		var neck_bounce = sin(p * TAU - 0.5) * 0.1 * speed_ratio
		p_nodes.neck_base.rotation.x = -anim_pitch * 0.6 + neck_bounce
	if "tail" in p_nodes:
		# La cola ondea más rápido y alto según la velocidad
		p_nodes.tail.rotation.x = 0.6 + (sin(p * TAU * 2) * 0.4 * speed_ratio)
		p_nodes.tail.rotation.z = (sin(p * TAU) * 0.2 * speed_ratio) # Coletazos laterales sumados

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

var is_jumping = false
var jump_timer = 0.0

func jump():
	# Always apply jump force when called
	velocity.y = jump_force
	is_jumping = true
	jump_timer = 0.0
