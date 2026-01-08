extends KinematicBody

# --- CLASE CABRA V1 ---
# Comportamiento: Saltitos ocasionales y movimientos rápidos

export var speed = 5.0
export var rotation_speed = 4.0
export var gravity = 25.0

var velocity = Vector3.ZERO
var anim_phase = 0.0
var move_timer = 0.0
var target_dir = Vector3.ZERO
var is_jumping = false
var biome_type = 2 # 2: Snow

var player_node = null
var active_dist = 80.0
var check_timer = 0.0

onready var mesh_gen = $ProceduralMesh

func _ready():
	add_to_group("animals")
	player_node = get_tree().get_nodes_in_group("player")[0] if get_tree().get_nodes_in_group("player").size() > 0 else null
	
	if mesh_gen and mesh_gen.has_method("_generate_structure"):
		mesh_gen._generate_structure()
		mesh_gen.translation.y = 0.1
	
	move_timer = rand_range(1, 3)

func setup_animal(type):
	biome_type = type

func _process(delta):
	# OPTIMIZACIÓN: El chequeo de distancia debe estar en _process
	check_timer -= delta
	if check_timer <= 0:
		check_timer = 1.0 + rand_range(0.0, 0.4)
		if player_node:
			var d = global_transform.origin.distance_to(player_node.global_transform.origin)
			var is_active = d < active_dist
			set_physics_process(is_active)
			if mesh_gen: mesh_gen.visible = d < 180.0
			
	if not is_physics_processing():
		return

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	move_timer -= delta
	if move_timer <= 0:
		if target_dir.length() > 0:
			target_dir = Vector3.ZERO
			move_timer = rand_range(2, 5)
		else:
			var rand_angle = rand_range(0, TAU)
			target_dir = Vector3(sin(rand_angle), 0, cos(rand_angle))
			move_timer = rand_range(2, 4)
			
			# Probabilidad ALTA de saltito al empezar a caminar (0.6)
			if randf() < 0.6:
				velocity.y = 8.5
				is_jumping = true
	
	if is_on_floor() and velocity.y <= 0:
		is_jumping = false

	if target_dir.length() > 0.1:
		var target_basis = Transform.IDENTITY.looking_at(target_dir, Vector3.UP).basis
		global_transform.basis = global_transform.basis.slerp(target_basis, rotation_speed * delta)
		
		var current_speed = speed if not is_jumping else speed * 1.5
		velocity.x = target_dir.x * current_speed
		velocity.z = target_dir.z * current_speed
	else:
		velocity.x = lerp(velocity.x, 0, 5 * delta)
		velocity.z = lerp(velocity.z, 0, 5 * delta)

	velocity = move_and_slide(velocity, Vector3.UP)
	_update_animation(delta)

func _update_animation(delta):
	var h_speed = Vector3(velocity.x, 0, velocity.z).length()
	if h_speed > 0.1 or not is_on_floor():
		var freq = 1.2 if is_jumping else 1.0
		anim_phase = wrapf(anim_phase + (h_speed + 2.0) * delta * freq, 0.0, TAU)
		_animate_goat(anim_phase)
	else:
		anim_phase = lerp(anim_phase, 0.0, 5 * delta)
		_animate_goat(0.0)

func _animate_goat(p):
	if not mesh_gen or not "parts" in mesh_gen: return
	var p_nodes = mesh_gen.parts
	
	var h_speed = Vector3(velocity.x, 0, velocity.z).length()
	var s_ratio = clamp(h_speed / speed, 0.0, 1.0)
	if not is_on_floor(): s_ratio = 1.0
	
	# Cuerpo saltarín
	var bounce = abs(sin(p)) * 0.1 * s_ratio
	if "body" in p_nodes:
		p_nodes.body.translation.y = (mesh_gen.hu * 1.6) + bounce
		p_nodes.body.rotation.x = sin(p) * 0.1 * s_ratio
	
	# Patas
	var offsets = {"fl": 0.0, "br": PI*0.5, "fr": PI, "bl": PI*1.5}
	for leg in ["fl", "fr", "bl", "br"]:
		if not ("leg_"+leg in p_nodes): continue
		
		var lp = p + offsets[leg]
		var swing = sin(lp)
		
		p_nodes["leg_"+leg].rotation.x = swing * 0.5 * s_ratio
		
		if "joint_"+leg in p_nodes:
			var knee = max(0, -cos(lp)) * 1.2 * s_ratio
			p_nodes["joint_"+leg].rotation.x = -knee

	# Cabeza (Moviéndose curiosamente)
	if "head" in p_nodes:
		p_nodes.head.rotation.y = sin(OS.get_ticks_msec() * 0.005) * 0.2
