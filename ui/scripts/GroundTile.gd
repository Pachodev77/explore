extends StaticBody

enum Biome { PRAIRIE, DESERT, SNOW, JUNGLE }

# Configuración del plano (coincide con el MeshInstance base)
const GRID_RES = 16 # 16x16 tramos = 17x17 vértices
const TILE_SIZE = 150.0

func setup_biome(_dummy_type, shared_resources, _dummy_height = 0, is_spawn = false):
	var mesh_instance = get_node_or_null("MeshInstance")
	var deco_container = get_node_or_null("Decos")
	if not mesh_instance or not deco_container: return
	
	# 1. Aplicar Material de Bioma
	mesh_instance.set_surface_material(0, shared_resources["ground_mat"])
	
	# 2. Re-generar Malla y Colisiones con SurfaceTool (Máxima fiabilidad)
	_rebuild_mesh_and_physics(mesh_instance, shared_resources, is_spawn)
	
	# 3. Decoraciones (Grid Optimizado)
	_add_decos_final(deco_container, shared_resources, is_spawn)

	if is_spawn:
		_add_fence(deco_container)

func _add_fence(container):
	# Material de madera procedural (simple color marrón)
	var wood_mat = SpatialMaterial.new()
	wood_mat.albedo_color = Color(0.4, 0.25, 0.1)
	wood_mat.roughness = 0.9
	
	# Mallas
	var post_mesh = CubeMesh.new()
	post_mesh.size = Vector3(0.4, 2.5, 0.4) # Más altos para enterrarlos mejor
	
	var rail_mesh = CubeMesh.new()
	rail_mesh.size = Vector3(3.0, 0.3, 0.15) # Tablas horizontales
	
	# Generar transformaciones
	var posts = []
	var rails = []
	
	var size = TILE_SIZE # 150.0
	var half = 33.0 # 33.0 * 2 = 66m. (Cercano a 65, divisible por 3)
	var perimeter_y = 2.0 # Altura base del spawn
	
	# 4 Lados: Norte, Sur, Este, Oeste
	# Lado Norte (Z = -half) y Sur (Z = half)
	for x in range(-half, half + 1, 3): # Cada 3 metros
		# Norte
		var t_n = Transform()
		t_n.origin = Vector3(x, perimeter_y + 0.5, -half) # Bajamos centro a Y=2.5 (Fondo en 1.25)
		posts.append(t_n)
		
		# Sur
		var t_s = Transform()
		t_s.origin = Vector3(x, perimeter_y + 0.5, half)
		posts.append(t_s)
		
		# Tablas (entre este poste y el siguiente)
		if x < half:
			# Norte
			var tr_n = Transform()
			tr_n.origin = Vector3(x + 1.5, perimeter_y + 1.5, -half)
			rails.append(tr_n)
			var tr_n2 = Transform()
			tr_n2.origin = Vector3(x + 1.5, perimeter_y + 1.0, -half)
			rails.append(tr_n2)
			
			# Sur
			var tr_s = Transform()
			tr_s.origin = Vector3(x + 1.5, perimeter_y + 1.5, half)
			rails.append(tr_s)
			var tr_s2 = Transform()
			tr_s2.origin = Vector3(x + 1.5, perimeter_y + 1.0, half)
			rails.append(tr_s2)

	# Lado Este (X = half) y Oeste (X = -half)
	# Nota: Saltamos las esquinas para no duplicar demasiado, o superponemos simple
	for z in range(-half, half + 1, 3):
		# LOGICA DE HUECO PARA PORTICOS (Z entre -6 y 6)
		# Rango de hueco agrandado para encajar con grid (12m ancho: -6 a 6)
		
		# 1. Postes (Solo si están fuera del hueco estricto)
		# Los postes de -6 y 6 son reemplazados por el marco del pórtico
		if abs(z) > 6.0:
			# Oeste
			var t_w = Transform()
			t_w.origin = Vector3(-half, perimeter_y + 0.5, z)
			posts.append(t_w)
			
			# Este
			var t_e = Transform()
			t_e.origin = Vector3(half, perimeter_y + 0.5, z)
			posts.append(t_e)
		
		# 2. Tablas (rotadas 90 grados)
		if z < half:
			# Evitar generar tablas DENTRO del hueco
			# -6: saltar (iría a -3)
			# -3, 0, 3: saltar
			# 6: generar (va a 9)
			# -9: generar (va a -6)
			if z >= -6 and z < 6: continue
			
			var rot = Basis(Vector3.UP, deg2rad(90))
			
			# Oeste
			var tr_w = Transform(rot, Vector3(-half, perimeter_y + 1.5, z + 1.5))
			rails.append(tr_w)
			var tr_w2 = Transform(rot, Vector3(-half, perimeter_y + 1.0, z + 1.5))
			rails.append(tr_w2)
			
			# Este
			var tr_e = Transform(rot, Vector3(half, perimeter_y + 1.5, z + 1.5))
			rails.append(tr_e)
			var tr_e2 = Transform(rot, Vector3(half, perimeter_y + 1.0, z + 1.5))
			rails.append(tr_e2)
			
	# Crear MultiMeshes
	var mmi_posts = MultiMeshInstance.new()
	var mm_posts = MultiMesh.new()
	mm_posts.transform_format = MultiMesh.TRANSFORM_3D
	mm_posts.mesh = post_mesh
	mm_posts.instance_count = posts.size()
	for i in range(posts.size()):
		mm_posts.set_instance_transform(i, posts[i])
	mmi_posts.multimesh = mm_posts
	mmi_posts.material_override = wood_mat
	mmi_posts.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	container.add_child(mmi_posts)
	
	var mmi_rails = MultiMeshInstance.new()
	var mm_rails = MultiMesh.new()
	mm_rails.transform_format = MultiMesh.TRANSFORM_3D
	mm_rails.mesh = rail_mesh
	mm_rails.instance_count = rails.size()
	for i in range(rails.size()):
		mm_rails.set_instance_transform(i, rails[i])
	mmi_rails.multimesh = mm_rails
	mmi_rails.material_override = wood_mat
	mmi_rails.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	container.add_child(mmi_rails)
	
	# Añadir Pórticos en las Salidas (Oeste y Este)
	# Oeste
	_add_gate(container, Vector3(-half, perimeter_y, 0), 0.0)
	# Este
	_add_gate(container, Vector3(half, perimeter_y, 0), 0.0)

func _add_gate(container, pos, rot_deg):
	var mat = SpatialMaterial.new()
	mat.albedo_color = Color(0.35, 0.2, 0.1) # Madera más oscura
	
	var sign_mat = SpatialMaterial.new()
	sign_mat.albedo_color = Color(0.8, 0.7, 0.5) # Madera clara para letrero
	
	var rot = Basis(Vector3.UP, deg2rad(rot_deg))
	
	# 1. Postes Altos (Izquierda y Derecha del hueco de 12m -> +/- 6m)
	var post_mesh = CubeMesh.new()
	post_mesh.size = Vector3(0.6, 7.0, 0.6) # 7m de alto (antes 5m)
	
	for offset_z in [-6.0, 6.0]: # Ajustado a 6m para coincidir con fence grid
		var p = MeshInstance.new()
		p.mesh = post_mesh
		p.material_override = mat
		p.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		# Posición relativa rotada (Centro en 3.5m)
		var local_pos = rot.xform(Vector3(0, 3.5, offset_z)) 
		p.translation = pos + local_pos
		container.add_child(p)
		
	# 2. Viga Superior (Marco)
	var beam = MeshInstance.new()
	beam.mesh = CubeMesh.new()
	beam.mesh.size = Vector3(0.5, 0.6, 13.0) # Cubre los 12m + margen
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	# Rotar la viga según la orientación del pórtico
	beam.transform.basis = rot
	beam.translation = pos + Vector3(0, 6.5, 0) # Subimos a 6.5m
	container.add_child(beam)
	
	# 3. Letrero Colgante
	var sign_board = MeshInstance.new()
	sign_board.mesh = CubeMesh.new()
	sign_board.mesh.size = Vector3(0.3, 1.5, 4.0)
	sign_board.material_override = sign_mat
	sign_board.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	sign_board.transform.basis = rot
	sign_board.translation = pos + Vector3(0, 5.5, 0) # Colgando en 5.5m
	container.add_child(sign_board)


func _rebuild_mesh_and_physics(mesh_instance, shared_res, is_spawn):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var h_noise = shared_res["height_noise"]
	var b_noise = shared_res["biome_noise"]
	var hn = shared_res["H_SNOW"]; var hs = shared_res["H_JUNGLE"]
	var he = shared_res["H_DESERT"]; var hw = shared_res["H_PRAIRIE"]
	
	# Generar vértices en un grid
	var step = TILE_SIZE / GRID_RES
	var offset = TILE_SIZE / 2.0
	
	# Initialize fixed noise for spawn consistency
	var fixed_noise = null
	if is_spawn:
		fixed_noise = OpenSimplexNoise.new()
		fixed_noise.seed = 1337
		fixed_noise.period = 60.0 # Más suave (olas más largas)
		fixed_noise.persistence = 0.5
		fixed_noise.octaves = 2
	
	# Almacenamos vértices para la triangulación
	var verts = []
	for z in range(GRID_RES + 1):
		for x in range(GRID_RES + 1):
			var lx = (x * step) - offset
			var lz = (z * step) - offset
			var gx = translation.x + lx
			var gz = translation.z + lz
			
			var noise_val = b_noise.get_noise_2d(gx, gz)
			var deg = rad2deg(atan2(gz, gx)) + (noise_val * 45.0)
			
			var blend = 0.0
			if is_spawn:
				# Distance from center (Square shape to match fence)
				var dist = max(abs(lx), abs(lz))
				# Blend: 1.0 at <33m (inside fence), transitions to 0.0 at >53m
				blend = clamp(1.0 - (dist - 33.0) / 20.0, 0.0, 1.0)
				
				# Target biome angle: 180 (Prairie)
				# We use lerp_angle to smoothly blend the rotation
				deg = lerp_angle(deg2rad(deg), deg2rad(180.0), blend)
				deg = rad2deg(deg)
			
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
			
			if is_spawn:
				# Mezcla basada en ruido para parches definidos
				# Usamos el mismo fixed_noise pero con diferente escala/offset si quisiéramos, 
				# o simplemente el valor directo.
				var tex_n = fixed_noise.get_noise_2d(gx * 8.0, gz * 8.0) # Frecuencia ALTA para muchos parches pequeños
				
				# Convertir ruido (-1 a 1) en factor de mezcla (0 a 1) con contraste
				var patch_mix = clamp((tex_n + 0.2) * 3.0, 0.0, 1.0) 
				
				# Definir colores target para el centro (Patch Mix: 0=Desierto, 1=Pradera)
				var target_wr = patch_mix
				var target_wg = 1.0 - patch_mix
				var target_wb = 0.0
				var target_wa = 0.0
				
				# Mezclar con el bioma global en los bordes
				wr = lerp(wr, target_wr, blend)
				wg = lerp(wg, target_wg, blend)
				wb = lerp(wb, target_wb, blend)
				wa = lerp(wa, target_wa, blend)
			
			var y = h_noise.get_noise_2d(gx, gz) * h_mult
			if is_spawn: 
				var spawn_y = 2.0 # Totalmente plano
				y = lerp(y, spawn_y, blend)
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

func _add_decos_final(deco_container, shared_res, is_spawn):
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
			
			if is_spawn:
				var dist = max(abs(lx), abs(lz))
				var blend = clamp(1.0 - (dist - 33.0) / 20.0, 0.0, 1.0)
				deg = lerp_angle(deg2rad(deg), deg2rad(180.0), blend)
				deg = rad2deg(deg)
			
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
			# Approximation for height check: 
			# We don't have the exact blended height here easily without recalculating logic
			# But trees/bushes should check their Y against valid ground separately if needed.
			# For now, let's just let them spawn based on the biome check above.
			# The y calculation for object placement usually follows the terrain height.
			# In this loop (old code), y_h is just used for filtering "underwater" (<-7.0)
			# and then `tf.origin.y` is usually set to `y_h`? 
			# Wait, the original code sets `y_h + offset`. 
			# We need the CORRECT height for the object.
			
			if is_spawn:
				# Re-calculate correct blended height
				var dist = max(abs(lx), abs(lz))
				var blend = clamp(1.0 - (dist - 33.0) / 20.0, 0.0, 1.0)
				
				# We need the fixed_noise instance here too...
				# To avoid duplicate code complexity, let's just make a simple reproducible noise
				var local_noise_val = 0.0
				# Simple pseudo-noise or just re-instance if performance allows (it's 36 iterations)
				var fn = OpenSimplexNoise.new(); fn.seed=1337; fn.period=60.0; fn.octaves=2;
				var sy = fn.get_noise_2d(gx, gz) * 0.1 + 2.0
				y_h = lerp(y_h, sy, blend)
			
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
