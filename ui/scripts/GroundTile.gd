extends StaticBody

enum Biome { PRAIRIE, DESERT, SNOW, JUNGLE }

# Configuración del plano (coincide con el MeshInstance base)
const GRID_RES = 16 # 16x16 tramos = 17x17 vértices
const TILE_SIZE = 150.0

func setup_biome(_dummy_type, shared_resources, _dummy_height = 0):
	var mesh_instance = get_node_or_null("MeshInstance")
	var deco_container = get_node_or_null("Decos")
	if not mesh_instance or not deco_container: return
	
	# 1. Aplicar Material de Bioma
	mesh_instance.set_surface_material(0, shared_resources["ground_mat"])
	
	# 2. Re-generar Malla y Colisiones con SurfaceTool (Máxima fiabilidad)
	_rebuild_mesh_and_physics(mesh_instance, shared_resources)
	
	# 3. Decoraciones (Grid Optimizado)
	_add_decos_final(deco_container, shared_resources)

func _rebuild_mesh_and_physics(mesh_instance, shared_res):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var h_noise = shared_res["height_noise"]
	var b_noise = shared_res["biome_noise"]
	var hn = shared_res["H_SNOW"]; var hs = shared_res["H_JUNGLE"]
	var he = shared_res["H_DESERT"]; var hw = shared_res["H_PRAIRIE"]
	
	# Generar vértices en un grid
	var step = TILE_SIZE / GRID_RES
	var offset = TILE_SIZE / 2.0
	
	# Almacenamos vértices para la triangulación
	var verts = []
	for z in range(GRID_RES + 1):
		for x in range(GRID_RES + 1):
			var lx = (x * step) - offset
			var lz = (z * step) - offset
			var gx = translation.x + lx
			var gz = translation.z + lz
			
			var noise_val = b_noise.get_noise_2d(gx, gz)
			# RESTAURADO: Biomas definidos por dirección (radial)
			var deg = rad2deg(atan2(gz, gx)) + (noise_val * 45.0)
			
			while deg > 180: deg -= 360
			while deg <= -180: deg += 360
			
			var wr = 0.0; var wg = 0.0; var wb = 0.0; var wa = 0.0
			var h_mult = 0.0
			
			if deg >= -90 and deg <= 0:
				var t = (deg + 90) / 90.0
				wb = 1.0 - t; wg = t; h_mult = lerp(hn, he, t) # Snow -> Desert
			elif deg > 0 and deg <= 90:
				var t = deg / 90.0
				wg = 1.0 - t; wa = t; h_mult = lerp(he, hs, t) # Desert -> Jungle
			elif deg > 90 and deg <= 180:
				var t = (deg - 90) / 90.0
				wa = 1.0 - t; wr = t; h_mult = lerp(hs, hw, t) # Jungle -> Prairie
			else:
				var t = (deg + 180) / 90.0
				wr = 1.0 - t; wb = t; h_mult = lerp(hw, hn, t) # Prairie -> Snow
			
			var y = h_noise.get_noise_2d(gx, gz) * h_mult
			var v = Vector3(lx, y, lz)
			
			st.add_color(Color(wr, wg, wb, wa))
			st.add_uv(Vector2(x / float(GRID_RES), z / float(GRID_RES)))
			st.add_vertex(v)
			verts.append(v)
			
	# Triangulación (Índices)
	for z in range(GRID_RES):
		for x in range(GRID_RES):
			var i = x + z * (GRID_RES + 1)
			# Primer Triángulo
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + GRID_RES + 1)
			# Segundo Triángulo
			st.add_index(i + 1)
			st.add_index(i + GRID_RES + 2)
			st.add_index(i + GRID_RES + 1)
			
	st.generate_normals()
	var new_mesh = st.commit()
	mesh_instance.mesh = new_mesh
	
	# Colisión (Trimesh es infalible para grids pequeños)
	var collision_shape = get_node_or_null("CollisionShape")
	if not collision_shape:
		collision_shape = CollisionShape.new()
		collision_shape.name = "CollisionShape"
		add_child(collision_shape)
	collision_shape.shape = new_mesh.create_trimesh_shape()

func _add_decos_final(deco_container, shared_res):
	# Limpieza previa
	for child in deco_container.get_children():
		child.free()
		
	seed(int(translation.x) + int(translation.z) + 123)
	var tree_instances = []
	var cactus_instances = []
	
	# OPTIMIZACIÓN: Grid reducido 6x6 con 40% spawn = ~14 objetos/tile
	# Antes: 8x8 con 60% = ~38 objetos/tile
	# Resultado: 63% menos decoraciones (950 -> 350 objetos totales)
	var grid_size = 6
	var spacing = TILE_SIZE / grid_size
	
	for x in range(grid_size):
		for z in range(grid_size):
			
			var lx = (x * spacing) - 75.0 + rand_range(-2, 2)
			var lz = (z * spacing) - 75.0 + rand_range(-2, 2)
			var gx = translation.x + lx
			var gz = translation.z + lz
			
			var noise_val = shared_res["biome_noise"].get_noise_2d(gx, gz)
			# RESTAURADO: Biomas definidos por dirección (radial)
			var deg = rad2deg(atan2(gz, gx)) + (noise_val * 45.0)
			while deg > 180: deg -= 360
			while deg <= -180: deg += 360
			
			var type = Biome.PRAIRIE
			if deg > -135 and deg <= -45: type = Biome.SNOW
			elif deg > 45 and deg <= 135: type = Biome.JUNGLE
			elif deg > -45 and deg <= 45: type = Biome.DESERT
			
			# DENSIDAD POR BIOMA: Jungla espesa (90%), Desierto despejado (15%), Resto (35%)
			var spawn_chance = 0.35
			if type == Biome.JUNGLE: spawn_chance = 0.9
			elif type == Biome.DESERT: spawn_chance = 0.15
			
			if randf() > spawn_chance: continue
			
			var h_mult = 0.0
			if deg >= -90 and deg <= 0: h_mult = lerp(shared_res["H_SNOW"], shared_res["H_DESERT"], (deg + 90) / 90.0)
			elif deg > 0 and deg <= 90: h_mult = lerp(shared_res["H_DESERT"], shared_res["H_JUNGLE"], deg / 90.0)
			elif deg > 90 and deg <= 180: h_mult = lerp(shared_res["H_JUNGLE"], shared_res["H_PRAIRIE"], (deg - 90) / 90.0)
			else: h_mult = lerp(shared_res["H_PRAIRIE"], shared_res["H_SNOW"], (deg + 180) / 90.0)
			
			var y_h = shared_res["height_noise"].get_noise_2d(gx, gz) * h_mult
			if y_h < -7.0: continue
			
			var tf = Transform().rotated(Vector3.RIGHT, deg2rad(-90))
			tf = tf.rotated(Vector3.UP, rand_range(0, TAU))
			
			if type == Biome.JUNGLE and shared_res["tree_parts"].size() > 0:
				var s = rand_range(1.0, 2.0)
				tf = tf.scaled(Vector3(s, s, s))
				tf.origin = Vector3(lx, y_h - 0.2, lz)
				tree_instances.append(tf)
			elif type == Biome.DESERT and shared_res["cactus_parts"].size() > 0:
				# TAMAÑO MENOR: Reducido de 1.2-3.0 a 0.7-1.4
				var s = rand_range(0.7, 1.4)
				tf = tf.scaled(Vector3(s, s, s))
				tf.origin = Vector3(lx, y_h + 2.1, lz)
				cactus_instances.append(tf)

	_apply_mmi_final(deco_container, shared_res["tree_parts"], tree_instances)
	_apply_mmi_final(deco_container, shared_res["cactus_parts"], cactus_instances)

func _apply_mmi_final(container, parts, instances):
	if instances.size() == 0: return
	for part in parts:
		var mmi = MultiMeshInstance.new()
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part.mesh
		mm.instance_count = instances.size()
		for i in range(instances.size()):
			mm.set_instance_transform(i, instances[i])
		mmi.multimesh = mm
		if part.mat: mmi.material_override = part.mat
		container.add_child(mmi)
