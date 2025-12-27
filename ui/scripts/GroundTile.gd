extends StaticBody

onready var mesh_instance = $MeshInstance
onready var deco_container = $Decos

enum Biome { PRAIRIE, DESERT, SNOW, JUNGLE }

func setup_biome(_dummy_type, shared_resources, _dummy_height = 0):
	# 1. Asignar el material de SHADER
	mesh_instance.set_surface_material(0, shared_resources["ground_mat"])
	
	# 2. Deformar y Pesar vértices para el shader
	deform_and_weight_terrain(shared_resources)
	
	# 3. Limpiar
	for child in deco_container.get_children():
		child.queue_free()
	
	# 4. Generar Decoraciones Optimizadas
	add_decos(shared_resources)

func deform_and_weight_terrain(shared_res):
	var h_noise = shared_res["height_noise"]
	var b_noise = shared_res["biome_noise"]
	
	var mdt = MeshDataTool.new()
	var plane_mesh = mesh_instance.mesh
	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane_mesh.get_mesh_arrays())
	
	mdt.create_from_surface(array_mesh, 0)
	
	for i in range(mdt.get_vertex_count()):
		var v = mdt.get_vertex(i)
		var global_v = translation + v
		
		# 1. Calcular ángulo con distorsión por ruido
		var noise_val = b_noise.get_noise_2d(global_v.x, global_v.z)
		var distortion = noise_val * 45.0
		var angle = atan2(global_v.z, global_v.x)
		var deg = rad2deg(angle) + distortion
		
		# 2. Calcular PESOS SUAVES para cada bioma (Vertex Color RGBA)
		var weights = calculate_soft_weights(deg)
		var weight_color = Color(weights[0], weights[1], weights[2], weights[3]) # R=Grass, G=Sand, B=Snow, A=Jungle
		
		# 3. Calcular Altura con mezcla (usamos el mismo deg para consistencia)
		var h_mult = calculate_blended_height(deg, shared_res)
		var h = h_noise.get_noise_2d(global_v.x, global_v.z) * h_mult
		
		v.y = h
		mdt.set_vertex(i, v)
		mdt.set_vertex_color(i, weight_color)
		
	array_mesh.surface_remove(0)
	mdt.commit_to_surface(array_mesh)
	mesh_instance.mesh = array_mesh
	
	var collision_shape = get_node_or_null("CollisionShape")
	if not collision_shape:
		collision_shape = CollisionShape.new()
		collision_shape.name = "CollisionShape"
		add_child(collision_shape)
	collision_shape.shape = array_mesh.create_trimesh_shape()

func calculate_soft_weights(deg):
	# Normalizamos deg al rango -180 a 180
	while deg > 180: deg -= 360
	while deg <= -180: deg += 360
	
	var w_r = 0.0 # Grass/Prairie
	var w_g = 0.0 # Sand/Desert
	var w_b = 0.0 # Snow
	var w_a = 0.0 # Jungle (Sur)
	
	# Transición suave entre biomas cardinales
	if deg >= -90 and deg <= 0: # Norte a Este (Snow a Sand)
		var t = (deg + 90) / 90.0
		w_b = 1.0 - t
		w_g = t
	elif deg > 0 and deg <= 90: # Este a Sur (Sand a Jungle)
		var t = deg / 90.0
		w_g = 1.0 - t
		w_a = t
	elif deg > 90 and deg <= 180: # Sur a Oeste (Jungle a Grass)
		var t = (deg - 90) / 90.0
		w_a = 1.0 - t
		w_r = t
	else: # Oeste a Norte (Grass a Snow)
		var t = (deg + 180) / 90.0
		w_r = 1.0 - t
		w_b = t
		
	return [w_r, w_g, w_b, w_a]

func calculate_blended_height(deg, shared_res):
	while deg > 180: deg -= 360
	while deg <= -180: deg += 360
	var h_n = shared_res["H_SNOW"]
	var h_s = shared_res["H_JUNGLE"]
	var h_e = shared_res["H_DESERT"]
	var h_w = shared_res["H_PRAIRIE"]
	
	var h = 0.0
	if deg >= -90 and deg <= 0:
		h = lerp(h_n, h_e, (deg + 90) / 90.0)
	elif deg > 0 and deg <= 90:
		h = lerp(h_e, h_s, deg / 90.0)
	elif deg > 90 and deg <= 180:
		h = lerp(h_s, h_w, (deg - 90) / 90.0)
	else:
		h = lerp(h_w, h_n, (deg + 180) / 90.0)
	return h

func add_decos(shared_resources):
	seed(int(translation.x) + int(translation.z) + 123)
	var h_noise = shared_resources["height_noise"]
	var b_noise = shared_resources["biome_noise"]
	
	# Configurar MultiMeshes
	var tree_mms = []
	for part in shared_resources["tree_parts"]:
		var mmi = MultiMeshInstance.new()
		setup_multimesh(mmi, part.mesh, part.mat)
		tree_mms.append(mmi)
		
	var cactus_mms = []
	for part in shared_resources["cactus_parts"]:
		var mmi = MultiMeshInstance.new()
		setup_multimesh(mmi, part.mesh, part.mat)
		cactus_mms.append(mmi)
	
	var tree_instances = []
	var cactus_instances = []
	
	# Intentar colocar objetos en una rejilla aleatoria
	var grid_size = 10
	var spacing = 150.0 / grid_size
	
	for x in range(grid_size):
		for z in range(grid_size):
			var rand_off_x = rand_range(-spacing*0.4, spacing*0.4)
			var rand_off_z = rand_range(-spacing*0.4, spacing*0.4)
			
			var lx = (x * spacing) - 75.0 + rand_off_x
			var lz = (z * spacing) - 75.0 + rand_off_z
			
			var gx = translation.x + lx
			var gz = translation.z + lz
			
			var noise_val = b_noise.get_noise_2d(gx, gz)
			var deg = rad2deg(atan2(gz, gx)) + (noise_val * 45.0)
			var type = get_biome_from_deg(deg)
			
			var h_mult = calculate_blended_height(deg, shared_resources)
			var y_height = h_noise.get_noise_2d(gx, gz) * h_mult
			
			# No spawnear bajo el agua (nivel agua es -8)
			if y_height < -7.0:
				continue
				
			if type == Biome.JUNGLE and shared_resources["tree_parts"].size() > 0:
				if randf() < 0.75: # Probabilidad aumentada de árboles para una jungla densa
					var tf = Transform()
					tf = tf.rotated(Vector3.RIGHT, deg2rad(-90)) # Corregir orientación "acostado"
					tf = tf.rotated(Vector3.UP, rand_range(0, TAU))
					var s = rand_range(0.8, 1.8)
					tf = tf.scaled(Vector3(s, s, s))
					tf.origin = Vector3(lx, y_height - 0.2, lz) # Ajuste final a -0.2
					tree_instances.append(tf)
			
			elif type == Biome.DESERT and shared_resources["cactus_parts"].size() > 0:
				if randf() < 0.04: # Probabilidad muy reducida de cactus
					var tf = Transform()
					tf = tf.rotated(Vector3.RIGHT, deg2rad(-90)) # Corregir orientación "acostado"
					tf = tf.rotated(Vector3.UP, rand_range(0, TAU))
					var s = rand_range(1.0, 2.5)
					tf = tf.scaled(Vector3(s, s, s))
					tf.origin = Vector3(lx, y_height + 2.1, lz) # Offset específico solicitado
					cactus_instances.append(tf)

	# Aplicar instancias a todos los MMIs de cada objeto
	for mmi in tree_mms:
		apply_instances(mmi, tree_instances)
		if tree_instances.size() > 0:
			deco_container.add_child(mmi)
			
	for mmi in cactus_mms:
		apply_instances(mmi, cactus_instances)
		if cactus_instances.size() > 0:
			deco_container.add_child(mmi)

func setup_multimesh(mmi, mesh, mat):
	if not mesh: return
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mmi.multimesh = mm
	if mat:
		mmi.material_override = mat

func apply_instances(mmi, instances):
	if instances.size() == 0 or not mmi.multimesh: return
	mmi.multimesh.instance_count = instances.size()
	for i in range(instances.size()):
		mmi.multimesh.set_instance_transform(i, instances[i])

func get_biome_from_deg(deg):
	while deg > 180: deg -= 360
	while deg <= -180: deg += 360
	if deg > -135 and deg <= -45: return Biome.SNOW
	elif deg > 45 and deg <= 135: return Biome.JUNGLE
	elif deg > -45 and deg <= 45: return Biome.DESERT
	else: return Biome.PRAIRIE
