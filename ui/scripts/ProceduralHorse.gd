extends Spatial

# --- CABALLO PROCEDURAL V3 (ANIMADO) ---
# Genera partes separadas como nodos para animación eficiente

export var hu = 0.65 
export var color = Color(0.45, 0.3, 0.15)
export var hair_color = Color(0.15, 0.1, 0.05)

var parts = {} # Diccionario de nodos para animación
var master_material: SpatialMaterial

func _ready():
	master_material = SpatialMaterial.new()
	master_material.albedo_color = color
	master_material.roughness = 0.8 # Un poco más mate para suavizar brillos
	master_material.metallic = 0.0
	master_material.params_diffuse_mode = SpatialMaterial.DIFFUSE_BURLEY # Mejor respuesta a la luz
	_generate_structure()

func _generate_structure():
	for c in get_children(): c.queue_free()
	parts.clear()
	
	# --- ANATOMÍA ---
	var leg_height = hu * 2.2 # ~1.43m
	var body_z_start = -hu * 1.5 
	var body_z_end = hu * 1.0
	
	# 1. CUERPO (Nodo raíz de torso)
	var body_root = Spatial.new()
	body_root.name = "BodyRoot"
	body_root.translation = Vector3(0, leg_height, 0) # El cuerpo empieza sobre las patas
	add_child(body_root)
	parts["body"] = body_root

	# Sub-partes del cuerpo (visuales fijas al root)
	# Ribcage: Ligeramente más pequeño (hu*0.71, hu*0.81)
	var rib_pos = Vector3(0, hu*0.05, body_z_start + hu*0.5)
	_create_part_mesh(body_root, "Ribcage", rib_pos, Vector3(hu*0.71, hu*0.81, hu*1.05), "ellipsoid")
	
	# Hindquarters: Ligeramente más pequeño (hu*0.77)
	var rear_pos = Vector3(0, 0, body_z_end - hu*0.6)
	var hind = _create_part_mesh(body_root, "Hindquarters", rear_pos, Vector3(hu*0.77, hu*0.77, hu*1.0), "ellipsoid")
	parts["hindquarters"] = hind

	# Belly: Ligeramente más pequeño (hu*0.68, hu*0.76)
	var mid_pos = (rib_pos + rear_pos) * 0.5 + Vector3(0, -hu*0.05, 0)
	_create_part_mesh(body_root, "Belly", mid_pos, Vector3(hu*0.5, hu*0.76, hu*0.9), "ellipsoid")

	# 2. CUELLO Y CABEZA
	var neck_base_node = Spatial.new()
	neck_base_node.name = "NeckBase"
	# Hundir más el cuello en el pecho (hu*0.7 en vez de 0.8)
	neck_base_node.translation = rib_pos + Vector3(0, hu*0.3, -hu*0.7)
	body_root.add_child(neck_base_node)
	parts["neck_base"] = neck_base_node
	
	var neck_v = Vector3(0, hu * 0.7, -hu * 0.3)
	# Cuello 1: de hu*0.45 (pecho) a hu*0.35 (mitad) - Sobrelape alto (0.8)
	_create_part_mesh(neck_base_node, "NeckSegment1", neck_v*0.5, Vector3(hu*0.42, hu*0.32, 0), "tapered", neck_v, 0.8)

	var neck_mid_node = Spatial.new()
	neck_mid_node.name = "NeckMid"
	neck_mid_node.translation = neck_v
	neck_base_node.add_child(neck_mid_node)
	parts["neck_mid"] = neck_mid_node
	
	var head_v = Vector3(0, hu * 0.4, -hu * 0.4)
	# Cuello 2: de hu*0.32 (mitad) a hu*0.3 (cabeza) - Sobrelape alto (0.8)
	_create_part_mesh(neck_mid_node, "NeckSegment2", head_v*0.5, Vector3(hu*0.32, hu*0.3, 0), "tapered", head_v, 0.8)

	var head_node = Spatial.new()
	head_node.name = "Head"
	head_node.translation = head_v
	neck_mid_node.add_child(head_node)
	parts["head"] = head_node
	
	var head_dir = Vector3(0, -0.2, -0.6).normalized()
	
	# Parte 1: Cráneo/Mejillas (Ganache) - Sobrelape alto (0.8)
	var upper_head_v = head_dir * hu * 0.4
	_create_part_mesh(head_node, "UpperHead", upper_head_v*0.5, Vector3(hu*0.3, hu*0.22, 0), "tapered", upper_head_v, 0.8)

	# Parte 2: Hocico (Muzzle) - Sobrelape alto (0.8)
	var muzzle_v = head_dir * hu * 0.4
	_create_part_mesh(head_node, "Muzzle", upper_head_v + muzzle_v*0.5, Vector3(hu*0.22, hu*0.14, 0), "tapered", muzzle_v, 0.8)

	# --- ANCLAJE PARA RIENDAS ---
	var rein_anchor = Position3D.new()
	rein_anchor.name = "ReinAnchor"
	# Posición exacta al final del hocico: UpperHead + Muzzle
	rein_anchor.translation = upper_head_v + muzzle_v
	head_node.add_child(rein_anchor)

	# 3. PATAS
	var leg_x = hu * 0.4
	var f_leg_z = body_z_start + hu * 0.1
	var b_leg_z = body_z_end - hu * 0.3
	
	var leg_names = ["FL", "FR", "BL", "BR"]
	for i in range(4):
		var name = leg_names[i]
		var is_front = i < 2
		var side = -1 if i % 2 == 0 else 1
		var z = f_leg_z if is_front else b_leg_z
		
		# Root de la pata (Hombro/Cadera)
		var leg_root = Spatial.new()
		leg_root.name = "Leg_" + name
		leg_root.translation = Vector3(leg_x * side, 0, z) # Se une al body_root en Y=0 (relativo)
		body_root.add_child(leg_root)
		parts["leg_" + name.to_lower()] = leg_root
		
		# Segmento Superior
		var upper_v = Vector3(0, -hu*1.1, 0) 
		if not is_front: upper_v = Vector3(0, -hu*1.1, hu*0.3)
		
		# Pata superior: Sobrelape bajo (0.55) para evitar protrusion
		_create_part_mesh(leg_root, "Upper", upper_v*0.5, Vector3(hu*0.28, hu*0.18, 0), "tapered", upper_v, 0.55)
		
		# Articulación Media (Nodo pivote, sin geometría propia)
		var mid_joint = Spatial.new()
		mid_joint.name = "Joint_" + name
		mid_joint.translation = upper_v
		leg_root.add_child(mid_joint)
		parts["joint_" + name.to_lower()] = mid_joint
		
		# Segmento Inferior
		var lower_v = Vector3(0, -hu*1.1, 0)
		if not is_front: lower_v = Vector3(0, -hu*1.1, -hu*0.3)
		
		# Pata inferior: Sobrelape bajo (0.55) 
		_create_part_mesh(mid_joint, "Lower", lower_v*0.5, Vector3(hu*0.18, hu*0.12, 0), "tapered", lower_v, 0.55)
		
		# Casco (Sigue siendo un elipsoide pero bien encajado)
		var hoof_pos = lower_v + Vector3(0, hu*0.08, 0)
		var hoof = _create_part_mesh(mid_joint, "Hoof", hoof_pos, Vector3(hu*0.15, hu*0.1, hu*0.15), "ellipsoid")
		parts["hoof_" + name.to_lower()] = hoof

	# 4. COLA
	var tail_root = Spatial.new()
	tail_root.name = "TailRoot"
	# Mover a un punto intermedio y aún más abajo (hu*0.15)
	tail_root.translation = rear_pos + Vector3(0, hu*0.15, hu*0.95)
	body_root.add_child(tail_root)
	parts["tail"] = tail_root
	
	# Un poco más corta
	var tail_dir = Vector3(0, -hu*0.6, hu*0.8) 
	var tail_center = tail_dir * 0.5
	# Cola cónica: Sobrelape alto (0.8)
	_create_part_mesh(tail_root, "TailMesh", tail_center, Vector3(hu*0.15, hu*0.06, 0), "tapered", tail_dir, 0.8)

# --- FUNCION MAESTRA DE CREACIÓN DE PARTES ---
func _create_part_mesh(parent: Node, p_name: String, pos: Vector3, p_scale: Vector3, type: String, dir: Vector3 = Vector3.ZERO, overlap: float = 0.7):
	var mi = MeshInstance.new()
	mi.name = p_name
	parent.add_child(mi)
	mi.translation = pos
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(master_material)
	
	if type == "ellipsoid":
		_add_ellipsoid(st, Vector3.ZERO, p_scale)
	elif type == "tapered":
		# Usamos el parámetro de sobrelape específico para esta pieza
		_add_tapered_cylinder_oriented(st, -dir*overlap, dir*overlap, p_scale.x, p_scale.y)
	elif type == "capsule":
		_add_tapered_cylinder_oriented(st, -dir*overlap, dir*overlap, p_scale.x, p_scale.x)

	# st.generate_normals() # YA NO ES NECESARIO, LAS CALCULAMOS A MANO PARA FUSIONAR
	mi.mesh = st.commit()
	
	# Sombras activadas para el caballo
	mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON
	return mi

func _get_stable_basis(up_dir: Vector3):
	var up = up_dir.normalized()
	# Usar una referencia más estable para evitar giros bruscos en el eje vertical
	var ref = Vector3.UP if abs(up.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var right = up.cross(ref).normalized()
	var forward = right.cross(up).normalized()
	return [right, up, forward]

# --- HELPERS MEJORADOS (LOCALES) ---

func _add_ellipsoid(st, center, scale, dir = Vector3.UP):
	var basis = _get_stable_basis(dir)
	var right = basis[0]; var up = basis[1]; var forward = basis[2]
	
	var steps = 16 
	for i in range(steps):
		var lat = PI * i / steps
		var lat_n = PI * (i + 1) / steps
		for j in range(steps * 2):
			var lon = 2 * PI * j / (steps * 2)
			var lon_n = 2 * PI * (j + 1) / (steps * 2)
			
			var p1_raw = _spherical_oriented(lat, lon, right, up, forward)
			var p2_raw = _spherical_oriented(lat_n, lon, right, up, forward)
			var p3_raw = _spherical_oriented(lat, lon_n, right, up, forward)
			var p4_raw = _spherical_oriented(lat_n, lon_n, right, up, forward)
			
			var p1 = center + p1_raw * scale
			var p2 = center + p2_raw * scale
			var p3 = center + p3_raw * scale
			var p4 = center + p4_raw * scale
			
			# Normales: Para un elipsoide, la normal NO es solo la posición.
			# Es proporcional a (x/a^2, y/b^2, z/c^2). O equivalentemente:
			# p_raw / scale (normalizado).
			var n1 = (p1_raw / scale).normalized()
			var n2 = (p2_raw / scale).normalized()
			var n3 = (p3_raw / scale).normalized()
			var n4 = (p4_raw / scale).normalized()
			
			# FIX: Evitar triángulos degenerados en los polos
			if p1.distance_squared_to(p3) > 0.00001:
				st.add_normal(n1); st.add_vertex(p1)
				st.add_normal(n2); st.add_vertex(p2)
				st.add_normal(n3); st.add_vertex(p3)
			if p2.distance_squared_to(p4) > 0.00001:
				st.add_normal(n2); st.add_vertex(p2)
				st.add_normal(n4); st.add_vertex(p4)
				st.add_normal(n3); st.add_vertex(p3)

func _spherical_oriented(lat, lon, right, up, forward):
	# Coordenadas esféricas estándar
	var x = sin(lat) * cos(lon)
	var y = cos(lat)
	var z = sin(lat) * sin(lon)
	# Transformar a la base orientada
	return right * x + up * y + forward * z

func _add_cylinder_between(st, p1, p2, r):
	var dir = (p2 - p1).normalized()
	var basis = _get_stable_basis(dir)
	var right = basis[0]; var _up = basis[1]; var forward = basis[2]
	
	# IMPORTANTE: Invertimos el orden para que los vértices coincidan con la orientación de la esfera
	# La esfera genera lon de 0 a 2PI. El cilindro debe usar el mismo 'lon' para sus anillos.
	
	var steps = 16 # Coincidir con la resolución del elipsoide
	for i in range(steps * 2):
		var angle = 2 * PI * i / (steps * 2)
		var angle_next = 2 * PI * (i + 1) / (steps * 2)
		
		# Calcular desplazamiento radial
		var offset = (right * cos(angle) + forward * sin(angle)) * r
		var offset_next = (right * cos(angle_next) + forward * sin(angle_next)) * r
		
		var v1 = p1 + offset
		var v2 = p1 + offset_next
		var v3 = p2 + offset
		var v4 = p2 + offset_next
		
		# Normales radiales (perpendiculares al eje 'up')
		var n_r = (offset / r).normalized()
		var n_rn = (offset_next / r).normalized()
		
		# FIX: Evitar triángulos degenerados si r=0 o p1=p2
		if v1.distance_squared_to(v2) > 0.00001 and v1.distance_squared_to(v3) > 0.00001:
			st.add_normal(n_r); st.add_vertex(v1)
			st.add_normal(n_r); st.add_vertex(v3)
			st.add_normal(n_rn); st.add_vertex(v2)
		if v2.distance_squared_to(v4) > 0.00001 and v2.distance_squared_to(v3) > 0.00001:
			st.add_normal(n_rn); st.add_vertex(v2)
			st.add_normal(n_rn); st.add_vertex(v3)
			st.add_normal(n_rn); st.add_vertex(v4)

func _add_tapered_cylinder_oriented(st, p1, p2, r1, r2):
	# Safety: Validate radius parameters
	if r1 == null or r2 == null:
		push_error("ProceduralHorse: null radius in _add_tapered_cylinder_oriented")
		return
	
	var dir = (p2 - p1).normalized()
	var basis = _get_stable_basis(dir)
	var right = basis[0]; var up = basis[1]; var forward = basis[2]
	
	var steps = 16 
	for i in range(steps * 2):
		var angle = 2 * PI * i / (steps * 2)
		var angle_next = 2 * PI * (i + 1) / (steps * 2)
		
		var offset1 = (right * cos(angle) + forward * sin(angle)) * r1
		var offset1_next = (right * cos(angle_next) + forward * sin(angle_next)) * r1
		
		var offset2 = (right * cos(angle) + forward * sin(angle)) * r2
		var offset2_next = (right * cos(angle_next) + forward * sin(angle_next)) * r2
		
		var v1 = p1 + offset1
		var v2 = p1 + offset1_next
		var v3 = p2 + offset2
		var v4 = p2 + offset2_next
		
		# Normales radiales (perpendiculares al eje 'up')
		var n_r = (offset1 / r1).normalized() if r1 > 0 else up
		var n_rn = (offset1_next / r1).normalized() if r1 > 0 else up
		
		# FIX: Seguridad ante radios cero o puntos idénticos
		if v1.distance_squared_to(v2) > 0.00001 and v1.distance_squared_to(v3) > 0.00001:
			st.add_normal(n_r); st.add_vertex(v1)
			st.add_normal(n_r); st.add_vertex(v3)
			st.add_normal(n_rn); st.add_vertex(v2)
		if v2.distance_squared_to(v4) > 0.00001 and v2.distance_squared_to(v3) > 0.00001:
			st.add_normal(n_rn); st.add_vertex(v2)
			st.add_normal(n_rn); st.add_vertex(v3)
			st.add_normal(n_rn); st.add_vertex(v4)

