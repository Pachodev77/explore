# =============================================================================
# AnimalBase.gd - CLASE BASE PARA TODOS LOS ANIMALES
# =============================================================================
# Proporciona funcionalidad común: activación por distancia, física robusta,
# seguridad anti-void, y sistema de animación unificado.
# =============================================================================

extends KinematicBody
class_name AnimalBase

# --- CONFIGURACIÓN EXPORTADA (Overrideable por cada animal) ---
export var speed = 2.0
export var rotation_speed = 3.0
export var gravity = GameConfig.PLAYER_GRAVITY
export var active_dist = 60.0  # Distancia máxima para procesar física
export var animal_type = ""    # Identificador para sonidos (cow, goat, chicken)

# --- ESTADO DE MOVIMIENTO ---
var velocity = Vector3.ZERO
var target_dir = Vector3.ZERO
var move_timer = 0.0
var anim_phase = 0.0
var is_landing = true  # Nuevo: Empiezan en modo aterrizaje (congelados)
var landing_timer = 0.0 # Tiempo de espera para que la física se sincronice

# --- ESTADO DE COMPORTAMIENTO ---
var is_eating = false
var eating_weight = 0.0  # Suavizado para animación de comer
var is_active = true     # Controlado por distancia al jugador

# --- NAVEGACIÓN NOCTURNA (Opcional) ---
var is_night_animal = false
var night_waypoint_pos: Vector3
var night_target_pos: Vector3
var has_reached_waypoint = false
var is_exiting = false

var sound_timer = 0.0

# --- REFERENCIAS CACHEADAS ---
var _player_node: Node = null
var _day_cycle_node: Node = null
var _check_timer = 0.0
var _physics_tick = 0

# --- REFERENCIAS INTERNAS ---
onready var mesh_gen = get_node_or_null("ProceduralMesh")

# =============================================================================
# FUNCIONES VIRTUALES (Para override en clases hijas)
# =============================================================================

func _get_animal_group() -> String:
	return "animals"

func _on_animal_ready():
	# Override en clase hija para setup específico
	pass

func _update_behavior(_delta: float):
	# Override: Lógica de IA específica del animal
	pass

func _animate_animal(_delta: float, _is_moving: bool):
	# Override: Animación específica del animal
	pass

func _get_eating_threshold() -> float:
	return 0.3  # Velocidad bajo la cual se considera "comiendo"

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready():
	add_to_group("animals")
	add_to_group(_get_animal_group())
	
	# Cachear referencias vía ServiceLocator
	_player_node = ServiceLocator.get_player()
	_day_cycle_node = ServiceLocator.get_day_cycle()
	
	# Generar mesh si existe
	if mesh_gen and mesh_gen.has_method("_generate_structure"):
		mesh_gen._generate_structure()
	
	# Inicializar con comportamiento de comer
	move_timer = rand_range(2.0, 5.0)
	is_eating = true
	
	# Hook para clases hijas
	_on_animal_ready()
	
	sound_timer = rand_range(2.0, 15.0)

func _process(delta):
	_check_timer -= delta
	if _check_timer <= 0:
		_check_timer = 1.5 + randf() * 0.5  # Intervalo aleatorizado
		_update_activation_state()

func _physics_process(delta):
	if not is_active:
		return
	
	# Throttle: Procesar cada N frames para rendimiento (según Config)
	_physics_tick += 1
	if _physics_tick % GameConfig.PHYSICS_REDUCTION_FACTOR != 0:
		return
	
	var ed = delta * GameConfig.PHYSICS_REDUCTION_FACTOR  # Effective Delta compensado
	
	# 1. Seguridad anti-void y Aterrizaje
	if is_landing:
		landing_timer += ed
		velocity = Vector3.ZERO # No acumular fuerza de caída mientras esperamos el suelo
		
		# Intentar "pegar" al suelo si estamos cerca o si ha pasado suficiente tiempo para que la colisión cargue
		if is_on_floor() or landing_timer > 0.5:
			is_landing = false
		else:
			# Si no ha aterrizado, forzar snap hacia abajo suavemente para buscar el suelo
			velocity.y = -2.0 
			velocity = move_and_slide(velocity, Vector3.UP)
			return
	
	_handle_void_safety()
	
	# 2. Gravedad Normal (Solo si ya aterrizó)
	if not is_on_floor():
		velocity.y -= gravity * ed
	elif velocity.y < 0:
		velocity.y = 0 # Detener caída al tocar suelo real
	
	# 3. Comportamiento específico del animal
	move_timer -= ed
	_update_behavior(ed)
	
	# 4. Movimiento y rotación
	_apply_movement(ed)
	
	# 5. Física
	velocity = move_and_slide(velocity, Vector3.UP)
	
	# 6. Animación
	_update_eating_weight(ed)
	_update_animation_phase(ed)
	
	# Sonidos aleatorios 3D (Desactivado)
	sound_timer -= ed
	if sound_timer <= 0:
		sound_timer = rand_range(8.0, 20.0)



# =============================================================================
# SISTEMAS COMUNES
# =============================================================================

func _update_activation_state():
	if not _player_node or not is_instance_valid(_player_node):
		_player_node = ServiceLocator.get_player()
		if not _player_node: return
	
	var d = global_transform.origin.distance_to(_player_node.global_transform.origin)
	is_active = d < active_dist
	set_physics_process(is_active)
	
	if mesh_gen:
		mesh_gen.visible = d < (active_dist * 1.3)

func _handle_void_safety():
	if global_transform.origin.y < -30.0:
		velocity = Vector3.ZERO
		is_landing = true # Volver a congelar para aterrizar seguro
		landing_timer = 0.0
		
		var wm = ServiceLocator.get_world_manager()
		if wm and wm.has_method("get_terrain_height_at"):
			var gx = global_transform.origin.x
			var gz = global_transform.origin.z
			global_transform.origin.y = wm.get_terrain_height_at(gx, gz) + 1.5
		else:
			global_transform.origin.y = 15.0

func _apply_movement(delta: float):
	if target_dir.length() > 0.1:
		var target_basis = Transform.IDENTITY.looking_at(target_dir, Vector3.UP).basis
		global_transform.basis = global_transform.basis.slerp(target_basis, rotation_speed * delta)
		velocity.x = target_dir.x * speed
		velocity.z = target_dir.z * speed
	else:
		velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 5.0 * delta)

func _update_eating_weight(delta: float):
	var h_speed = Vector3(velocity.x, 0, velocity.z).length()
	var target_w = 1.0 if (is_eating and h_speed < _get_eating_threshold()) else 0.0
	eating_weight = lerp(eating_weight, target_w, 3.0 * delta)

func _update_animation_phase(delta: float):
	var h_speed = Vector3(velocity.x, 0, velocity.z).length()
	var is_moving = h_speed > 0.1
	
	if is_moving:
		anim_phase = wrapf(anim_phase + h_speed * delta * 0.6, 0.0, TAU)
	else:
		anim_phase = lerp(anim_phase, 0.0, 5.0 * delta)
	
	_animate_animal(delta, is_moving)

# =============================================================================
# NAVEGACIÓN NOCTURNA (Sistema unificado)
# =============================================================================

func is_night() -> bool:
	if _day_cycle_node and _day_cycle_node.has_method("get_day_phase"):
		return _day_cycle_node.get_day_phase() < 0.7
	return false

func navigate_to_night_target(delta: float) -> bool:
	"""Navega hacia el objetivo nocturno. Retorna true si llegó."""
	if not is_night_animal:
		return false
	
	is_eating = false
	is_exiting = false
	
	var final_target: Vector3 = night_target_pos
	
	# Fase 1: Ir al waypoint
	if not has_reached_waypoint and night_waypoint_pos:
		final_target = night_waypoint_pos
		if global_transform.origin.distance_to(night_waypoint_pos) < 2.0:
			has_reached_waypoint = true
	
	# Calcular dirección (Solo XZ para evitar vuelo)
	var pos_2d = Vector2(global_transform.origin.x, global_transform.origin.z)
	var target_2d = Vector2(final_target.x, final_target.z)
	var dir_2d = (target_2d - pos_2d).normalized()
	target_dir = Vector3(dir_2d.x, 0, dir_2d.y)
	
	# Comprobar llegada
	if has_reached_waypoint and pos_2d.distance_to(Vector2(night_target_pos.x, night_target_pos.z)) < 1.5:
		target_dir = Vector3.ZERO
		velocity.x = 0
		velocity.z = 0
		is_eating = true
		return true
	
	return false

func exit_night_shelter(delta: float) -> bool:
	"""Sale del refugio nocturno. Retorna true si terminó de salir."""
	is_eating = false
	
	var pos_2d = Vector2(global_transform.origin.x, global_transform.origin.z)
	var target_2d = Vector2(night_waypoint_pos.x, night_waypoint_pos.z)
	var dir_2d = (target_2d - pos_2d).normalized()
	target_dir = Vector3(dir_2d.x, 0, dir_2d.y)
	
	if pos_2d.distance_to(target_2d) < 2.0:
		is_exiting = false
		has_reached_waypoint = false
		is_eating = true
		move_timer = rand_range(2.0, 4.0)
		return true
	
	return false
