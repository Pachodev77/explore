extends Spatial

# Configuración del ciclo
export var cycle_duration_minutes : float = 1.0 # Duración de un día completo para pruebas
export var start_time : float = 0.22 # Amanecer

# Referencias
onready var sun = get_parent().get_node("DirectionalLight")
onready var environment = get_parent().get_node("WorldEnvironment").environment
onready var stars_sphere = get_node_or_null("StarsSphere")

# Variables internas
var time_of_day : float = 0.5
var player : Spatial

# Colores de atmósfera (ProceduralSky)
const SKY_DAY_TOP = Color(0.2, 0.4, 0.8)
const SKY_DAY_HORIZON = Color(0.5, 0.7, 0.9)
const SKY_NIGHT_TOP = Color(0.01, 0.01, 0.05)
const SKY_NIGHT_HORIZON = Color(0.02, 0.02, 0.08)
const SKY_SUNSET_HORIZON = Color(0.8, 0.4, 0.2)

const AMBIENT_DAY = Color(0.85, 0.85, 0.85)
const AMBIENT_NIGHT = Color(0.15, 0.15, 0.25)

func _ready():
	time_of_day = start_time
	player = get_parent().get_node_or_null("Player")
	update_cycle()

	# Configuración de sombras robusta
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.1
	sun.directional_shadow_normal_bias = 0.8

func _process(delta):
	var cycle_speed = 1.0 / (cycle_duration_minutes * 60.0)
	time_of_day += delta * cycle_speed
	if time_of_day >= 1.0:
		time_of_day -= 1.0
	
	# Hacer que la esfera de estrellas siga al jugador
	if player and stars_sphere:
		stars_sphere.global_transform.origin = player.global_transform.origin
	
	update_cycle()

func update_cycle():
	var day_phase = get_day_phase()
	
	# 1. Rotación del Sol (Ciclo simple de 0 a 360 grados)
	# 0.25 = Amanecer (Sol saliendo), 0.5 = Mediodía (Arriba), 0.75 = Atardecer (Bajando)
	var angle = (time_of_day - 0.25) * 360.0
	sun.rotation_degrees.x = -angle # Invertimos para que suba y baje
	sun.rotation_degrees.y = 180 # Orientación Este-Oeste
	
	# 2. Energía del Sol
	# El sol solo ilumina de día
	var sun_visible = time_of_day > 0.22 and time_of_day < 0.78
	sun.light_energy = 1.0 if sun_visible else 0.0
	
	# 3. Colores del Cielo (ProceduralSky)
	if environment.background_sky is ProceduralSky:
		var sky = environment.background_sky
		
		# Interpolar colores
		sky.sky_top_color = lerp(SKY_NIGHT_TOP, SKY_DAY_TOP, day_phase)
		
		# El horizonte tiene un toque naranja al atardecer/amanecer
		var horizon_color = lerp(SKY_NIGHT_HORIZON, SKY_DAY_HORIZON, day_phase)
		if day_phase > 0.0 and day_phase < 1.0:
			var sunset_mix = sin(day_phase * PI) # Máximo en 0.5 de la transición
			horizon_color = lerp(horizon_color, SKY_SUNSET_HORIZON, sunset_mix * 0.7)
		
		sky.sky_horizon_color = horizon_color
		sky.ground_horizon_color = horizon_color
		
		# Sincronizar sol del sky con la luz direccional
		sky.sun_latitude = -sun.rotation_degrees.x
		sky.sun_longitude = sun.rotation_degrees.y
	
	# 4. Luz Ambiental
	environment.ambient_light_color = lerp(AMBIENT_NIGHT, AMBIENT_DAY, day_phase)
	
	# 5. Niebla
	environment.fog_color = environment.ambient_light_color
	
	# 6. Estrellas
	if stars_sphere:
		var mat = stars_sphere.get_surface_material(0)
		if mat:
			mat.set_shader_param("time_of_day", time_of_day)
			# Rotar las estrellas con el tiempo
			stars_sphere.rotation_degrees.y = time_of_day * 360.0

	# 7. Oscurecer Cactus específicamente (para evitar que brillen de noche)
	var world_manager = get_parent().get_node_or_null("WorldManager")
	if world_manager and "shared_res" in world_manager:
		var cactus_parts = world_manager.shared_res.get("cactus_parts", [])
		# Factor de brillo: 1.0 de día, 0.2 de noche
		var brightness_factor = lerp(0.2, 1.0, day_phase)
		for part in cactus_parts:
			var mat = part.get("mat")
			if mat is SpatialMaterial:
				# Aplicamos el factor al color albedo
				mat.albedo_color = Color(brightness_factor, brightness_factor, brightness_factor)
				# Si tiene emisión, también la bajamos
				if mat.emission_enabled:
					mat.emission_energy = brightness_factor

func get_day_phase():
	# 0.0 noche, 1.0 día pleno
	if time_of_day < 0.2 or time_of_day > 0.8:
		return 0.0
	elif time_of_day > 0.3 and time_of_day < 0.7:
		return 1.0
	elif time_of_day >= 0.2 and time_of_day <= 0.3:
		return (time_of_day - 0.2) / 0.1 # Suave 0 a 1
	else: # 0.7 a 0.8
		return (0.8 - time_of_day) / 0.1 # Suave 1 a 0
