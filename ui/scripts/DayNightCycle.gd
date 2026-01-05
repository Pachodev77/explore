extends Spatial

# OPTIMIZACIÓN EXTREMA: Ciclo día/noche ultra-eficiente
# Actualiza solo cuando es necesario, sin operaciones costosas

export var cycle_duration_minutes : float = 1.0
export var start_time : float = 0.22

# Referencias cacheadas
onready var sun = get_parent().get_node("DirectionalLight")
onready var environment = get_parent().get_node("WorldEnvironment").environment
onready var stars_sphere = get_node_or_null("StarsSphere")

var time_of_day : float = 0.5
var last_update_time : float = 0.0
const UPDATE_INTERVAL = 0.5  # Actualizar cada 0.5 segundos (2 veces por segundo - suficiente para movimiento suave)

# Colores precalculados
const SKY_DAY_TOP = Color(0.2, 0.4, 0.8)
const SKY_DAY_HORIZON = Color(0.5, 0.7, 0.9)
const SKY_NIGHT_TOP = Color(0.01, 0.01, 0.05)
const SKY_NIGHT_HORIZON = Color(0.02, 0.02, 0.08)
const SKY_SUNSET_HORIZON = Color(0.8, 0.4, 0.2)
const AMBIENT_DAY = Color(0.65, 0.65, 0.65)
const AMBIENT_NIGHT = Color(0.15, 0.15, 0.25)

func _ready():
	time_of_day = start_time
	
	# Shadows restored by user request - configured for low-end in Scene
	# sun.shadow_enabled = true # Managed by Scene Settings now
	
	update_cycle()

func _process(delta):
	# OPTIMIZACIÓN 1: Actualizar tiempo cada frame
	var cycle_speed = 1.0 / (cycle_duration_minutes * 60.0)
	time_of_day += delta * cycle_speed
	if time_of_day >= 1.0:
		time_of_day -= 1.0
	
	# Actualizar ciclo (Ambiente, Energía luz) - IMPORTANTE para que no sea oscuro
	update_cycle()
	
	# SEGUIR A LA CÁMARA: La bóveda celeste siempre centrada en la vista (standard skybox)
	var cam = get_viewport().get_camera()
	if cam:
		global_transform.origin = cam.global_transform.origin
	
	# Actualizar rotación del sol (luz)
	# Esto es barato (transform update)
	var angle = (time_of_day - 0.25) * 360.0
	sun.rotation_degrees = Vector3(-angle, 90, 0)
	
	# Actualizar shader del cielo (GPU es rápida, sin lag)
	if stars_sphere:
		var mat = stars_sphere.get_surface_material(0)
		if mat:
			mat.set_shader_param("time_of_day", time_of_day)

func update_cycle():
	# Ya no necesitamos lógica compleja aquí, _process maneja lo esencial suavemente
	
	var day_phase = get_day_phase() # 0.0 (noche) a 1.0 (día)
	
	# 2. Energía del Sol (Suave)
	# Usar day_phase para que la luz aparezca progresivamente al amanecer
	sun.light_energy = ease(day_phase, 0.5) * 0.7
	sun.light_color = lerp(Color(0.8, 0.4, 0.2), Color(1.0, 0.95, 0.8), day_phase)
	
	# 3. Luz Ambiental y Niebla
	environment.ambient_light_color = lerp(AMBIENT_NIGHT, AMBIENT_DAY, day_phase)
	environment.fog_color = environment.ambient_light_color
	
	# ProceduralSky logic REMOVED entirely - causes lag on GLES2/Old GPU
	
	# OPTIMIZACIÓN: Cactus brightness ELIMINADO
	# Esto causaba 18,000 operaciones/segundo
	# Los cactus ahora usan la luz ambiental automáticamente

func get_day_phase():
	# 0.0 noche, 1.0 día pleno
	if time_of_day < 0.2 or time_of_day > 0.8:
		return 0.0
	elif time_of_day > 0.3 and time_of_day < 0.7:
		return 1.0
	elif time_of_day >= 0.2 and time_of_day <= 0.3:
		return (time_of_day - 0.2) / 0.1
	else: # 0.7 a 0.8
		return (0.8 - time_of_day) / 0.1
