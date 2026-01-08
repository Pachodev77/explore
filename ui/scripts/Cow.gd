extends KinematicBody

# --- CLASE VACA V1 ---
# Comportamiento básico: Caminar errático y pose relajada

export var speed = 1.5
export var rotation_speed = 2.0
export var gravity = 25.0

var velocity = Vector3.ZERO
var anim_phase = 0.0
var move_timer = 0.0
var target_dir = Vector3.ZERO
var is_eating = true
var eating_weight = 0.0 # Suavizado para bajar la cabeza
var biome_type = 0 # 0: Prairie

var player_node = null
var active_dist = 60.0 # Reducido de 80 para móviles
var check_timer = 0.0
var anim_throttle = 0

onready var mesh_gen = $ProceduralMesh

func _ready():
	add_to_group("animals")
	player_node = get_tree().get_nodes_in_group("player")[0] if get_tree().get_nodes_in_group("player").size() > 0 else null
	
	if mesh_gen and mesh_gen.has_method("_generate_structure"):
		mesh_gen._generate_structure()
		mesh_gen.translation.y = 0.2
	
	move_timer = rand_range(2, 5)
	is_eating = true

func setup_animal(type):
	biome_type = type

var physics_tick = 0

func _process(delta):
	check_timer -= delta
	if check_timer <= 0:
		check_timer = 1.5 + rand_range(0.0, 0.5) # Chequeo menos frecuente
		if player_node:
			var d = global_transform.origin.distance_to(player_node.global_transform.origin)
			var is_active = d < active_dist
			set_physics_process(is_active)
			if mesh_gen: mesh_gen.visible = d < 80.0 # Reducido de 120
			
	if not is_physics_processing():
		return

func _physics_process(delta):
	physics_tick += 1
	if physics_tick % 2 != 0: return
	
	var ed = delta * 2.0 # Effective Delta
	
	# Gravedad
	if not is_on_floor():
		velocity.y -= gravity * ed
	
	# SEGURIDAD: Evitar caída al vacío
	if global_transform.origin.y < -30.0:
		# Intentar reposicionar en el suelo (aproximado por ruido)
		var hn = 0.0
		if player_node and player_node.get_parent().has_method("get_road_influence"):
			# El world manager está en el padre del jugador normalmente
			pass 
		# Snapping simple a nivel de mar + margen
		global_transform.origin.y = 10.0
		velocity.y = 0
	
	# IA de vaca
	move_timer -= ed
	if move_timer <= 0:
		if not is_eating:
			is_eating = true
			target_dir = Vector3.ZERO
			move_timer = rand_range(10, 25)
		else:
			is_eating = false
			var rand_angle = rand_range(0, TAU)
			target_dir = Vector3(sin(rand_angle), 0, cos(rand_angle))
			move_timer = rand_range(3, 6)
	
	# Rotación hacia el objetivo
	if target_dir.length() > 0.1:
		var target_basis = Transform.IDENTITY.looking_at(target_dir, Vector3.UP).basis
		global_transform.basis = global_transform.basis.slerp(target_basis, rotation_speed * ed)
		
		velocity.x = target_dir.x * speed
		velocity.z = target_dir.z * speed
	else:
		velocity.x = lerp(velocity.x, 0, 2 * ed)
		velocity.z = lerp(velocity.z, 0, 2 * ed)

	velocity = move_and_slide(velocity, Vector3.UP)
	
	# Mezclar peso de animación de comer
	var target_eat_w = 1.0 if (is_eating and Vector3(velocity.x,0,velocity.z).length() < 0.1) else 0.0
	eating_weight = lerp(eating_weight, target_eat_w, 2.0 * delta)
	
	_update_animation(ed)

func _update_animation(delta):
	var h_speed = Vector3(velocity.x, 0, velocity.z).length()
	if h_speed > 0.1:
		anim_phase = wrapf(anim_phase + h_speed * delta * 0.8, 0.0, 1.0)
		_animate_cow(anim_phase)
	else:
		anim_phase = lerp(anim_phase, 0.0, 3 * delta)
		_animate_cow(0.0)

func _animate_cow(p):
	if not mesh_gen or not "parts" in mesh_gen: return
	var p_nodes = mesh_gen.parts
	
	var h_speed = Vector3(velocity.x, 0, velocity.z).length()
	var s_ratio = clamp(h_speed / speed, 0.0, 1.0)
	
	# Rebote de cuerpo (Lento y pesado)
	var bounce = abs(sin(p * TAU)) * 0.06 * s_ratio
	if "body" in p_nodes:
		p_nodes.body.translation.y = (mesh_gen.hu * 1.5) + bounce
		p_nodes.body.rotation.z = sin(p * TAU) * 0.02 * s_ratio
	
	# Patas (Caminata alternada)
	var offsets = {"fl": 0.0, "br": 0.25, "fr": 0.5, "bl": 0.75}
	for leg in ["fl", "fr", "bl", "br"]:
		if not ("leg_"+leg in p_nodes): continue
		
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
		
	# Cuello y Cabeza (Comer)
	if "neck_base" in p_nodes:
		# Bajar el cuello pesadamente
		var eat_pose = -eating_weight * deg2rad(80.0)
		p_nodes.neck_base.rotation.x = eat_pose
		
		if "head" in p_nodes:
			# Extender la cabeza un poco al comer
			p_nodes.head.rotation.x = eating_weight * deg2rad(20.0)
