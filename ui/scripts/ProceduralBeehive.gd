extends Spatial

# Colmena de Apicultura Premium (Tipo Langstroth)
var attack_cooldown = 0.0
var is_active_swarm = false

func _ready():
	add_to_group("beehive")
	
	# Limpieza para permitir re-llamadas (Cooldown Update)
	for child in get_children():
		child.queue_free()
	
	_generate_hive()
	
	# Verificar Cooldown de 3 días
	var is_available = true
	var wm = ServiceLocator.get_world_manager()
	var dnc = ServiceLocator.get_day_cycle()
	if wm and dnc:
		var pos_key = "%d,%d,%d" % [round(global_transform.origin.x), round(global_transform.origin.y), round(global_transform.origin.z)]
		if wm.beehive_harvests.has(pos_key):
			var last_day = wm.beehive_harvests[pos_key]
			if dnc.get_current_day() < last_day + 3:
				is_available = false
	
	is_active_swarm = is_available
	if is_active_swarm:
		_setup_bees()
		_setup_ambient_audio()
	set_process(is_active_swarm)

func _setup_ambient_audio():
	var asp = AudioStreamPlayer3D.new()
	asp.name = "BeeAudio"
	if AudioManager.sounds.has("bee_loop"):
		var stream = load(AudioManager.sounds["bee_loop"])
		if stream:
			asp.stream = stream
			asp.unit_db = linear2db(0.4)
			asp.max_db = 0.0
			asp.unit_size = 3.0
			asp.max_distance = 15.0
			asp.autoplay = true
			asp.stream_paused = false
			asp.bus = "SFX"
			add_child(asp)

func _process(delta):
	attack_cooldown -= delta
	if attack_cooldown <= 0:
		var player = ServiceLocator.get_player()
		if player:
			var dist = global_transform.origin.distance_to(player.global_transform.origin)
			if dist < 5.0:
				if player.stats:
					player.stats.take_damage(0.04)
					AudioManager.play_sfx("bee_sting", 0.6)
					attack_cooldown = 2.5 # Picaduras más lentas (cada 2.5 segundos)

func is_harvestable():
	var wm = ServiceLocator.get_world_manager()
	var dnc = ServiceLocator.get_day_cycle()
	if wm and dnc:
		var pos_key = "%d,%d,%d" % [round(global_transform.origin.x), round(global_transform.origin.y), round(global_transform.origin.z)]
		if wm.beehive_harvests.has(pos_key):
			var last_day = wm.beehive_harvests[pos_key]
			return dnc.get_current_day() >= last_day + 3
	return true

func _generate_hive():
	var mat_wood = SpatialMaterial.new()
	mat_wood.albedo_color = Color(0.6, 0.45, 0.3)
	mat_wood.roughness = 0.8
	
	var mat_roof = SpatialMaterial.new()
	mat_roof.albedo_color = Color(0.9, 0.9, 0.85) # Blanco para el techo
	mat_roof.roughness = 0.5
	
	# 1. Soporte de madera
	_add_box(Vector3(1.2, 0.15, 0.8), Vector3(0, 0.07, 0), mat_wood)
	for x in [-0.5, 0.5]:
		for z in [-0.3, 0.3]:
			_add_box(Vector3(0.1, 0.4, 0.1), Vector3(x, 0.2, z), mat_wood)
	
	# 2. Base de la colmena (Piquera)
	_add_box(Vector3(1.0, 0.1, 0.7), Vector3(0, 0.45, 0), mat_wood)
	
	# 3. Cajones (Cuerpos de la colmena)
	var box_height = 0.6
	for i in range(2):
		var y_pos = 0.55 + (i * (box_height + 0.02)) + box_height/2.0
		_add_box(Vector3(0.9, box_height, 0.6), Vector3(0, y_pos, 0), mat_wood)
		
		# Detalle de hendidura (agarradera)
		var handle = _add_box(Vector3(0.4, 0.1, 0.05), Vector3(0, y_pos + 0.1, 0.3), mat_wood)
	
	# 4. Techo Telescópico
	var roof_y = 0.55 + (2 * (box_height + 0.02)) + 0.1
	_add_box(Vector3(1.0, 0.2, 0.7), Vector3(0, roof_y, 0), mat_roof)
	
	# Piquera (Entrada) - Una caja negra pequeña
	var black_mat = SpatialMaterial.new()
	black_mat.albedo_color = Color(0, 0, 0)
	_add_box(Vector3(0.3, 0.05, 0.05), Vector3(0, 0.5, 0.33), black_mat)

func _add_box(size, pos, mat):
	var mi = MeshInstance.new()
	var mesh = CubeMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.translation = pos
	# Optimización: Desactivar sombras para las piezas del cajón
	mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _setup_bees():
	# 1. Enjambre mínimo (Piquera)
	var entrance_bees = _create_bee_cloud(6, 0.3, Vector3(0, 0.6, 0.4), 0.4)
	add_child(entrance_bees)
	
	# 2. Muy pocas exploradoras alrededor
	var scout_bees = _create_bee_cloud(4, 2.0, Vector3(0, 1.5, 0), 1.0)
	add_child(scout_bees)
	
	# ELIMINADO: OmniLight (Consumen mucho rendimiento en masa)

func _create_bee_cloud(amount, radius, pos, velocity):
	var particles = CPUParticles.new()
	
	# Malla alargada para que parezca una abeja
	var p_mesh = CubeMesh.new()
	p_mesh.size = Vector3(0.06, 0.06, 0.12) 
	
	# Shader para las franjas (Rayas amarillas y negras)
	var mat = ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = """
		shader_type canvas_item; // Error corregido: debe ser spatial
	"""
	# Corregir a spatial shader
	var s_code = """
		shader_type spatial;
		render_mode unshaded;
		void fragment() {
			// Crear franjas basadas en la coordenada Z local (longitud de la abeja)
			float stripe = sin(UV.y * 20.0); 
			if (stripe > 0.0) {
				ALBEDO = vec3(1.0, 0.8, 0.0); // Amarillo
			} else {
				ALBEDO = vec3(0.05, 0.05, 0.05); // Negro
			}
		}
	"""
	var bee_shader = Shader.new()
	bee_shader.code = s_code
	var bee_mat = ShaderMaterial.new()
	bee_mat.shader = bee_shader
	p_mesh.material = bee_mat
	
	particles.mesh = p_mesh
	particles.amount = amount
	particles.lifetime = 2.5
	particles.preprocess = 2.0
	
	particles.emission_shape = CPUParticles.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius
	particles.gravity = Vector3(0, 0.02, 0)
	particles.initial_velocity = velocity
	particles.initial_velocity_random = 0.5
	particles.orbit_velocity = 0.4
	particles.orbit_velocity_random = 0.5
	
	# Las abejas suelen mirar hacia donde vuelan (aproximadamente)
	particles.flag_align_y = true 
	
	particles.translation = pos
	# Optimización: No proyectar sombras desde las abejas
	particles.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	return particles
