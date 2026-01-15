# =============================================================================
# Chicken.gd - CLASE GALLINA
# =============================================================================
# Comportamiento: Movimientos espasmódicos, picoteo y regreso al gallinero.
# =============================================================================

extends KinematicBody

# --- CONFIGURACIÓN ---
export var speed = 2.0
export var rotation_speed = 8.0
export var gravity = 20.0
export var size_unit = 0.28
export var active_dist = 40.0

# --- ESTADO DE MOVIMIENTO ---
var velocity = Vector3.ZERO
var target_dir = Vector3.ZERO
var move_timer = 0.0
var anim_phase = 0.0
var head_bob = 0.0

# --- ESTADO DE COMPORTAMIENTO ---
var is_pecking = false
var is_sleeping = false
var eating_weight = 0.0
var sleeping_weight = 0.0

# --- NAVEGACIÓN NOCTURNA ---
var is_night_chicken = false
var night_waypoint_pos: Vector3
var night_target_pos: Vector3
var has_reached_waypoint = false
var is_exiting = false

# --- REFERENCIAS CACHEADAS ---
var _day_cycle_node: Node = null
onready var mesh_gen = $ProceduralMesh

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready():
	add_to_group("animals")
	add_to_group("chicken")
	_day_cycle_node = get_tree().root.find_node("DayNightCycle", true, false)
	
	if mesh_gen and mesh_gen.has_method("_generate_structure"):
		mesh_gen.size_unit = size_unit
		mesh_gen._generate_structure()
		mesh_gen.translation.y = 0.05 # Offset ajustado a la baja
	
	move_timer = rand_range(2.0, 4.0)
	is_pecking = true

func _physics_process(delta: float):
	# Seguridad anti-void
	if global_transform.origin.y < -30.0:
		global_transform.origin.y = 5.0
		velocity.y = 0
	
	# Optimización: Check de distancia al jugador
	if not _is_player_nearby():
		return
	
	# Comportamiento
	move_timer -= delta
	_update_behavior(delta)
	
	# Movimiento
	_apply_movement(delta)
	
	# Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0:
		velocity.y = 0
	
	velocity = move_and_slide(velocity, Vector3.UP)
	
	# Animación
	_update_animation_weights(delta)
	_update_animation(delta)

# =============================================================================
# SISTEMAS
# =============================================================================

func _is_player_nearby() -> bool:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var d = global_transform.origin.distance_to(players[0].global_transform.origin)
		return d < active_dist
	return true  # Si no hay jugador, procesar igual

func _is_night() -> bool:
	if _day_cycle_node and _day_cycle_node.has_method("get_day_phase"):
		return _day_cycle_node.get_day_phase() < 0.7
	return false

func _update_behavior(delta: float):
	var is_night = _is_night()
	
	# Navegación nocturna
	if is_night_chicken and (is_night or is_exiting):
		if is_night:
			_navigate_to_roost()
		elif is_exiting:
			_exit_roost()
	elif move_timer <= 0:
		_random_behavior()

func _navigate_to_roost():
	if night_target_pos == null: return
	
	is_pecking = false
	is_exiting = false
	
	var final_target = night_target_pos
	
	# Ir primero al waypoint
	if not has_reached_waypoint and night_waypoint_pos != null:
		final_target = night_waypoint_pos
		var dist_2d = _distance_2d(global_transform.origin, final_target)
		if dist_2d < 0.6:
			has_reached_waypoint = true
	
	# Calcular dirección 2D
	if final_target != null:
		target_dir = _direction_2d_to(final_target)
	
	# Comprobar llegada al objetivo final
	if has_reached_waypoint:
		var dist_final = _distance_2d(global_transform.origin, night_target_pos)
		if dist_final < 0.2:
			target_dir = Vector3.ZERO
			velocity = Vector3.ZERO
			is_sleeping = true
			is_pecking = false
	else:
		is_sleeping = false

func _exit_roost():
	is_sleeping = false
	is_pecking = false
	
	if night_waypoint_pos == null:
		is_exiting = false
		has_reached_waypoint = false
		return
		
	target_dir = _direction_2d_to(night_waypoint_pos)
	
	if _distance_2d(global_transform.origin, night_waypoint_pos) < 1.0:
		is_exiting = false
		has_reached_waypoint = false
		move_timer = rand_range(2.0, 4.0)

func _random_behavior():
	is_sleeping = false
	
	if not _is_night() and is_night_chicken and has_reached_waypoint and not is_exiting:
		is_exiting = true
	elif not is_pecking and randf() < 0.75:
		is_pecking = true
		target_dir = Vector3.ZERO
		move_timer = rand_range(8.0, 18.0)
	else:
		is_pecking = false
		var rand_angle = rand_range(0.0, TAU)
		target_dir = Vector3(sin(rand_angle), 0, cos(rand_angle))
		move_timer = rand_range(2.0, 4.0)

func _apply_movement(delta: float):
	if not is_sleeping and target_dir.length() > 0.1:
		var target_basis = Transform.IDENTITY.looking_at(target_dir, Vector3.UP).basis
		global_transform.basis = global_transform.basis.slerp(target_basis, rotation_speed * delta)
		velocity.x = target_dir.x * speed
		velocity.z = target_dir.z * speed
	else:
		velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 10.0 * delta)

# =============================================================================
# UTILIDADES
# =============================================================================

func _distance_2d(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))

func _direction_2d_to(target: Vector3) -> Vector3:
	var pos_2d = Vector2(global_transform.origin.x, global_transform.origin.z)
	var target_2d = Vector2(target.x, target.z)
	var dir_2d = (target_2d - pos_2d).normalized()
	return Vector3(dir_2d.x, 0, dir_2d.y)

# =============================================================================
# ANIMACIÓN
# =============================================================================

func _update_animation_weights(delta: float):
	var target_peck = 1.0 if is_pecking and velocity.length() < 0.5 and not is_sleeping else 0.0
	eating_weight = lerp(eating_weight, target_peck, 4.0 * delta)
	
	var target_sleep = 1.0 if is_sleeping else 0.0
	sleeping_weight = lerp(sleeping_weight, target_sleep, 2.0 * delta)

func _update_animation(delta: float):
	var h_speed = Vector3(velocity.x, 0, velocity.z).length()
	var is_moving = h_speed > 0.1 and not is_sleeping
	
	if is_moving:
		anim_phase = wrapf(anim_phase + h_speed * delta * 5.0, 0.0, TAU)
	else:
		anim_phase = lerp(anim_phase, 0.0, 5.0 * delta)
	
	_animate_chicken(delta, is_moving)

func _animate_chicken(delta: float, is_moving: bool):
	if not mesh_gen or not "parts" in mesh_gen:
		return
	var p: Dictionary = mesh_gen.parts
	
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
	
	# 2. Picoteo
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
