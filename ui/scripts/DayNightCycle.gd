extends Node

# Configuración del ciclo
export var cycle_duration_minutes : float = 5.0 # Duración de un día completo en minutos
export var start_time : float = 0.5 # Hora de inicio (0.0 = medianoche, 0.25 = amanecer, 0.5 = mediodía)

# Referencias
onready var sun = get_parent().get_node("DirectionalLight")
onready var environment = get_parent().get_node("WorldEnvironment").environment

# Variables internas
var time_of_day : float = 0.5 # 0.0 a 1.0 (0.0 = medianoche, 0.5 = mediodía)

# Colores y configuraciones
const SUN_COLOR_DAY = Color(1.0, 0.95, 0.8) # Amarillo cálido
const SUN_COLOR_SUNSET = Color(1.0, 0.6, 0.3) # Naranja
const SUN_COLOR_NIGHT = Color(0.4, 0.5, 0.7) # Azul luna

const AMBIENT_DAY = Color(0.85, 0.85, 0.85)
const AMBIENT_NIGHT = Color(0.45, 0.48, 0.55)

const SUN_ENERGY_DAY = 1.0
const SUN_ENERGY_NIGHT = 0.8

func _ready():
	time_of_day = start_time
	update_cycle()

	# Ajustes de sombra para evitar Z-fighting
	# Cambiar a PSSM 4 Splits para mejor calidad de sombras a distancia
	sun.directional_shadow_mode = DirectionalLight.SHADOW_PARALLEL_4_SPLITS

	# Distribuir las divisiones de PSSM para dar más detalle cerca
	sun.directional_shadow_split_1 = 0.1
	sun.directional_shadow_split_2 = 0.25
	sun.directional_shadow_split_3 = 0.5

	sun.shadow_bias = 0.15
	# El normal bias es clave para terrenos irregulares
	sun.directional_shadow_normal_bias = 1.2
	sun.shadow_contact = 0.0

func _process(delta):
	# Avanzar el tiempo
	var cycle_speed = 1.0 / (cycle_duration_minutes * 60.0)
	time_of_day += delta * cycle_speed
	
	# Mantener en el rango 0-1
	if time_of_day >= 1.0:
		time_of_day -= 1.0
	
	update_cycle()

func update_cycle():
	# Calcular fase del día
	var day_phase = get_day_phase()
	
	# Rotar el sol/luna de este a oeste
	# time_of_day: 0.0 = medianoche, 0.25 = amanecer, 0.5 = mediodía, 0.75 = atardecer
	
	# Calcular el ángulo de rotación (0-360 grados)
	# A mediodía (0.5) el sol debe estar arriba (270 grados en X)
	# A medianoche (0.0) la luna debe estar arriba
	var angle_deg = time_of_day * 360.0
	
	# Convertir a radianes para la rotación
	var angle_rad = deg2rad(angle_deg)
	
	# Para simular un ciclo de este a oeste, el sol debe orbitar.
	# Lo rotaremos en el eje Y para la hora del día y en el eje X para la altura.
	var rotation_y = angle_rad
	# Inclinamos la órbita para que el sol no pase directamente por encima.
	var rotation_x = deg2rad(-30) # Inclinación de la órbita

	var new_transform = Transform.IDENTITY
	# Rotar para la hora del día (este-oeste)
	new_transform = new_transform.rotated(Vector3(0, 1, 0), rotation_y)
	# Rotar para la inclinación de la órbita
	new_transform = new_transform.rotated(new_transform.basis.x.normalized(), rotation_x)

	sun.transform = new_transform
	
	# Actualizar color de la luz
	sun.light_color = get_sun_color(day_phase)
	
	# Actualizar energía de la luz
	sun.light_energy = lerp(SUN_ENERGY_NIGHT, SUN_ENERGY_DAY, day_phase)
	
	# Actualizar luz ambiental
	environment.ambient_light_color = lerp(AMBIENT_NIGHT, AMBIENT_DAY, day_phase)

func get_day_phase() -> float:
	# Retorna 0.0 en la noche, 1.0 en el día
	# Transición suave usando una curva
	var t = time_of_day
	
	# Noche: 0.0-0.2 y 0.8-1.0
	# Día: 0.3-0.7
	# Transiciones: 0.2-0.3 (amanecer) y 0.7-0.8 (atardecer)
	
	if t < 0.2 or t > 0.8:
		return 0.0 # Noche
	elif t > 0.3 and t < 0.7:
		return 1.0 # Día
	elif t >= 0.2 and t <= 0.3:
		return smoothstep(0.2, 0.3, t) # Amanecer
	else: # t >= 0.7 and t <= 0.8
		return smoothstep(0.8, 0.7, t) # Atardecer

func get_sun_color(day_phase: float) -> Color:
	# Interpolar entre colores según la fase
	if day_phase > 0.8:
		return SUN_COLOR_DAY
	elif day_phase < 0.2:
		return SUN_COLOR_NIGHT
	elif day_phase > 0.5:
		return lerp(SUN_COLOR_SUNSET, SUN_COLOR_DAY, (day_phase - 0.5) / 0.3)
	else:
		return lerp(SUN_COLOR_NIGHT, SUN_COLOR_SUNSET, day_phase / 0.5)

func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
