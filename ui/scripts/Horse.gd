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
var anim_phase = 0.0
var anim_bounce = 0.0
var anim_pitch = 0.0

func _ready():
	add_to_group("horses")
	# Inicializar mesh si no está hecho
	if mesh_gen and mesh_gen.has_method("_generate_structure"):
		mesh_gen._generate_structure()

func _physics_process(delta):
	# Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if is_ridden and rider:
		_process_ridden_movement(delta)
	else:
		_process_idle_movement(delta)
	
	# Movimiento con Snap balanceado: 70 grados de tope y snap más suave (0.4)
	var snap = -get_floor_normal() * 0.4 if is_on_floor() else Vector3.DOWN * 0.2
	velocity = move_and_slide_with_snap(velocity, snap, Vector3.UP, true, 4, deg2rad(70))
	
	# Gestionar Animación
	_update_animation(delta)

func _update_animation(delta):
	var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
	if horizontal_speed > 0.5:
		# Animación más pausada: Reducimos la frecuencia base y el multiplicador
		var freq = 1.2 + (horizontal_speed / speed) * 1.0 
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
	var forward_lean = -0.06 * speed_ratio 
	anim_bounce = abs(sin(p * TAU)) * 0.12 * speed_ratio
	anim_pitch = cos(p * TAU) * 0.1 * speed_ratio + forward_lean
	
	if "body" in p_nodes:
		p_nodes.body.translation.y = (mesh_gen.hu * 2.2) + anim_bounce
		p_nodes.body.rotation.x = anim_pitch
		
	# 2. Patas (Articulación Avanzada con Sesgo Frontal)
	# Tiempos: BL (0.0), BR (0.2), FL (0.5), FR (0.7)
	var offsets = {"bl": 0.0, "br": 0.2, "fl": 0.5, "fr": 0.7}
	
	for leg in ["fl", "fr", "bl", "br"]:
		if not ("leg_"+leg in p_nodes) or not ("joint_"+leg in p_nodes): continue
		
		var leg_p = wrapf(p + offsets[leg], 0.0, 1.0)
		var swing = sin(leg_p * TAU)
		
		# --- ROTACIÓN SUPERIOR (Hombro/Cadera) ---
		# Sesgo frontal: Sumamos 0.2 para que la pata llegue más lejos adelante
		var upper_rot = (swing * 0.7 + 0.2) * speed_ratio
		if leg.begins_with("b"): upper_rot *= 0.9 # Traseras potentes
		p_nodes["leg_"+leg].rotation.x = upper_rot
		
		# --- ARTICULACIÓN MEDIA (Rodilla/Corvejón) ---
		# Doblez agresivo en la fase de vuelo (swing > 0)
		var knee_fold = 0.0
		if swing > 0:
			knee_fold = (swing * 1.5) * speed_ratio # Se dobla más para no chocar con el suelo
		else:
			knee_fold = (sin(leg_p * TAU) * 0.3) * speed_ratio # Estiramiento ligero al plantar
		p_nodes["joint_"+leg].rotation.x = -knee_fold
		
		# --- CASCOS (Menudillo/Fetlock) ---
		# Flicking: El casco se dobla hacia arriba al levantar la pata y baja al plantar
		if "hoof_"+leg in p_nodes:
			var hoof_rot = 0.0
			if swing > 0.3: # Levantando/Vuelo
				hoof_rot = (swing - 0.3) * 1.5
			elif swing < -0.5: # Impacto
				hoof_rot = -0.3
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
	
	# Movimiento con aceleración suave
	var target_vel = move_dir.normalized() * speed * (0.5 if rider_input.length() < 0.5 else 1.0)
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
