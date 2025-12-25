extends StaticBody

onready var mesh_instance = $MeshInstance
onready var deco_container = $Decos

enum Biome { PRAIRIE, DESERT, SNOW, JUNGLE }

func setup_biome(_dummy_type, shared_resources, _dummy_height = 0):
	# 1. Asignar el material de SHADER
	mesh_instance.set_surface_material(0, shared_resources["ground_mat"])
	
	# 2. Deformar y Pesar vértices para el shader
	deform_and_weight_terrain(shared_resources)
	
	# 3. Limpiar y añadir decos
	for child in deco_container.get_children():
		child.queue_free()
		
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
		
		# 2. Calcular PESOS SUAVES para cada bioma (Vertex Color RGB)
		var weights = calculate_soft_weights(deg)
		var weight_color = Color(weights[0], weights[1], weights[2], 1.0) # R=Grass, G=Sand, B=Snow
		
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
	
	# Puntos cardinales principales (grados)
	# Norte: -90 (Snow -> B)
	# Sur: 90 (Jungle -> None/R+G+B=0)
	# Este: 0 (Sand -> G)
	# Oeste: 180/-180 (Grass -> R)
	
	var w_r = 0.0 # Grass/Prairie
	var w_g = 0.0 # Sand/Desert
	var w_b = 0.0 # Snow
	
	# Transición suave entre biomas cardinales
	if deg >= -90 and deg <= 0: # Norte a Este (Snow a Sand)
		var t = (deg + 90) / 90.0 # 0 en Norte, 1 en Este
		w_b = 1.0 - t
		w_g = t
	elif deg > 0 and deg <= 90: # Este a Sur (Sand a Jungle)
		var t = deg / 90.0 # 0 en Este, 1 en Sur
		w_g = 1.0 - t
		# Jungle no tiene canal propio, se define por la ausencia de los otros
	elif deg > 90 and deg <= 180: # Sur a Oeste (Jungle a Grass)
		var t = (deg - 90) / 90.0 # 0 en Sur, 1 en Oeste
		w_r = t
	else: # Oeste a Norte (Grass a Snow) - deg entre -180 y -90
		var t = (deg + 180) / 90.0 # 0 en Oeste, 1 en Norte
		w_r = 1.0 - t
		w_b = t
		
	return [w_r, w_g, w_b]

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
	
	for i in range(5):
		var deco = MeshInstance.new()
		var rand_x = rand_range(-65, 65)
		var rand_z = rand_range(-65, 65)
		var gx = translation.x + rand_x
		var gz = translation.z + rand_z
		
		var noise_val = b_noise.get_noise_2d(gx, gz)
		var deg = rad2deg(atan2(gz, gx)) + (noise_val * 45.0)
		
		# Para decos seguimos usando un bioma dominante para decidir qué objeto poner
		var type = get_biome_from_deg(deg)
		
		var h_mult = calculate_blended_height(deg, shared_resources)
		var y_height = h_noise.get_noise_2d(gx, gz) * h_mult
		
		var pos = Vector3(rand_x, y_height, rand_z)
		match type:
			Biome.DESERT:
				deco.mesh = shared_resources["cactus_mesh"]
				deco.material_override = shared_resources["cactus_mat"]
				deco.scale.y = rand_range(1, 3)
			Biome.JUNGLE:
				deco.mesh = shared_resources["tree_mesh"]
				deco.material_override = shared_resources["tree_mat"]
				deco.scale = Vector3.ONE * rand_range(0.8, 1.8)
			Biome.SNOW:
				deco.mesh = shared_resources["rock_mesh"]
				deco.material_override = shared_resources["rock_mat"]
				deco.rotation_degrees.y = rand_range(0, 360)
				pos.y -= 0.5
			Biome.PRAIRIE:
				deco.mesh = shared_resources["bush_mesh"]
				deco.material_override = shared_resources["bush_mat"]
				deco.scale = Vector3.ONE * rand_range(1, 2)
				pos.y -= 0.5
		
		deco.translation = pos
		deco_container.add_child(deco)

func get_biome_from_deg(deg):
	while deg > 180: deg -= 360
	while deg <= -180: deg += 360
	if deg > -135 and deg <= -45: return Biome.SNOW
	elif deg > 45 and deg <= 135: return Biome.JUNGLE
	elif deg > -45 and deg <= 45: return Biome.DESERT
	else: return Biome.PRAIRIE
