extends Spatial

# --- CABALLO PROCEDURAL V3 (ANIMADO) ---
# Genera partes separadas como nodos para animación eficiente

export var hu = 0.65 
export var color = Color(0.45, 0.3, 0.15)
export var hair_color = Color(0.15, 0.1, 0.05)

var parts = {} # Diccionario de nodos para animación

func _ready():
	_generate_structure()

func _generate_structure():
	for c in get_children(): c.queue_free()
	parts.clear()
	
	# --- ANATOMÍA ---
	var ground_y = 0.0
	var withers_y = hu * 2.8 # ~1.82m
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
	var rib_pos = Vector3(0, 0, body_z_start + hu*0.6)
	_create_part_mesh(body_root, "Ribcage", rib_pos, Vector3(hu*0.7, hu*0.8, hu*1.0), "ellipsoid")
	
	var rear_pos = Vector3(0, -hu*0.05, body_z_end - hu*0.4)
	var hind = _create_part_mesh(body_root, "Hindquarters", rear_pos, Vector3(hu*0.75, hu*0.75, hu*0.8), "ellipsoid")
	parts["hindquarters"] = hind

	var mid_pos = (rib_pos + rear_pos) * 0.5
	_create_part_mesh(body_root, "Belly", mid_pos, Vector3(hu*0.65, hu*0.75, hu*0.7), "ellipsoid")

	# 2. CUELLO Y CABEZA
	var neck_base_node = Spatial.new()
	neck_base_node.name = "NeckBase"
	neck_base_node.translation = rib_pos + Vector3(0, hu*0.4, -hu*0.8)
	body_root.add_child(neck_base_node)
	parts["neck_base"] = neck_base_node
	
	var neck_v = Vector3(0, hu * 0.7, -hu * 0.3)
	_create_part_mesh(neck_base_node, "NeckSegment1", neck_v*0.5, Vector3(hu*0.35, neck_v.length()*0.6, hu*0.35), "capsule", neck_v)

	var neck_mid_node = Spatial.new()
	neck_mid_node.name = "NeckMid"
	neck_mid_node.translation = neck_v
	neck_base_node.add_child(neck_mid_node)
	parts["neck_mid"] = neck_mid_node
	
	var head_v = Vector3(0, hu * 0.4, -hu * 0.4)
	_create_part_mesh(neck_mid_node, "NeckSegment2", head_v*0.5, Vector3(hu*0.25, head_v.length()*0.6, hu*0.25), "capsule", head_v)

	var head_node = Spatial.new()
	head_node.name = "Head"
	head_node.translation = head_v
	neck_mid_node.add_child(head_node)
	parts["head"] = head_node
	
	var head_dir = Vector3(0, -0.2, -0.6).normalized()
	_create_part_mesh(head_node, "Skull", head_dir*hu*0.4, Vector3(hu*0.25, hu*0.15, hu*0.4), "tapered", head_dir)

	# --- ANCLAJE PARA RIENDAS ---
	var rein_anchor = Position3D.new()
	rein_anchor.name = "ReinAnchor"
	# Posición aproximada de la boca/bocado: Adelante y abajo relativo a la cabeza
	rein_anchor.translation = head_dir * hu * 0.7 + Vector3(0, -hu*0.1, 0)
	head_node.add_child(rein_anchor)

	# 3. PATAS
	var leg_x = hu * 0.4
	var f_leg_z = body_z_start + hu * 0.4
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
		_create_part_mesh(leg_root, "Upper", upper_v*0.5, Vector3(hu*0.2, upper_v.length()*0.55, hu*0.2), "capsule", upper_v)
		
		# Articulación Media
		var mid_joint = Spatial.new()
		mid_joint.name = "Joint_" + name
		mid_joint.translation = upper_v
		leg_root.add_child(mid_joint)
		parts["joint_" + name.to_lower()] = mid_joint
		
		# Segmento Inferior
		var lower_v = Vector3(0, -hu*1.1, 0)
		if not is_front: lower_v = Vector3(0, -hu*1.1, -hu*0.3)
		_create_part_mesh(mid_joint, "Lower", lower_v*0.5, Vector3(hu*0.12, lower_v.length()*0.55, hu*0.12), "capsule", lower_v)
		
		# Casco (Elipsoide centrado en Y=0.08 relativo al final de la pata)
		var hoof_pos = lower_v + Vector3(0, hu*0.08, 0)
		var hoof = _create_part_mesh(mid_joint, "Hoof", hoof_pos, Vector3(hu*0.15, hu*0.1, hu*0.15), "ellipsoid")
		parts["hoof_" + name.to_lower()] = hoof

	# 4. COLA
	var tail_root = Spatial.new()
	tail_root.name = "TailRoot"
	# Mover más atrás (hu*0.8) y un poco más arriba (hu*0.4)
	tail_root.translation = rear_pos + Vector3(0, hu*0.4, hu*0.8)
	body_root.add_child(tail_root)
	parts["tail"] = tail_root
	
	# Hacerla más visible y orientada hacia AFUERA (Backwards +Z)
	# Dir: Apuntando 45 grados hacia atrás y abajo
	var tail_dir = Vector3(0, -hu*1.0, hu*1.5) 
	var tail_center = tail_dir * 0.5
	_create_part_mesh(tail_root, "TailMesh", tail_center, Vector3(hu*0.15, tail_dir.length()*0.9, hu*0.15), "capsule", tail_dir)

# --- FUNCION MAESTRA DE CREACIÓN DE PARTES ---
func _create_part_mesh(parent: Node, p_name: String, pos: Vector3, p_scale: Vector3, type: String, dir: Vector3 = Vector3.ZERO):
	var mi = MeshInstance.new()
	mi.name = p_name
	parent.add_child(mi)
	mi.translation = pos
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat = SpatialMaterial.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	st.set_material(mat)
	
	if type == "ellipsoid":
		_add_ellipsoid(st, Vector3.ZERO, p_scale)
	elif type == "capsule":
		# La escala p_scale ya trae el radio en X/Z y el largo en Y (aprox)
		# Orientamos hacia 'dir'
		var d = dir.normalized()
		_add_capsule_oriented(st, -dir*0.5, dir*0.5, p_scale.x)
	elif type == "tapered":
		_add_tapered_cylinder_oriented(st, -dir*hu*0.4, dir*hu*0.4, p_scale.x, p_scale.y)

	st.generate_normals()
	mi.mesh = st.commit()
	return mi

# --- HELPERS MEJORADOS (LOCALES) ---

func _add_ellipsoid(st, center, scale):
	var steps = 16 # Aumentado para mayor suavidad (de 12)
	for i in range(steps):
		var lat = PI * i / steps
		for j in range(steps * 2):
			var lon = 2 * PI * j / (steps * 2)
			var p1 = center + _spherical(lat, lon) * scale
			var p2 = center + _spherical(lat + PI/steps, lon) * scale
			var p3 = center + _spherical(lat, lon + PI/steps) * scale
			var p4 = center + _spherical(lat + PI/steps, lon + PI/steps) * scale
			st.add_vertex(p1); st.add_vertex(p2); st.add_vertex(p3)
			st.add_vertex(p2); st.add_vertex(p4); st.add_vertex(p3)

func _spherical(lat, lon):
	return Vector3(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon))

func _add_capsule_oriented(st, p1, p2, r):
	# Aumentar radio de uniones 5% para ocultar costuras
	var r_joint = r * 1.05
	_add_ellipsoid(st, p1, Vector3(r_joint, r_joint, r_joint))
	_add_ellipsoid(st, p2, Vector3(r_joint, r_joint, r_joint))
	
	# Usar cilindro en vez de caja para que sea redondo
	_add_cylinder_between(st, p1, p2, r)

func _add_cylinder_between(st, p1, p2, r):
	var dir = (p2 - p1).normalized()
	# Crear base ortonormal
	var up = dir
	var right = up.cross(Vector3.UP).normalized()
	if right.length() < 0.01: right = Vector3.RIGHT
	var forward = right.cross(up).normalized()
	
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
		
		st.add_vertex(v1); st.add_vertex(v3); st.add_vertex(v2)
		st.add_vertex(v2); st.add_vertex(v3); st.add_vertex(v4)

func _add_tapered_cylinder_oriented(st, p1, p2, r1, r2):
	# Safety: Validate radius parameters
	if r1 == null or r2 == null:
		push_error("ProceduralHorse: null radius in _add_tapered_cylinder_oriented")
		return
	
	var dir = (p2 - p1).normalized()
	var up = dir
	var right = up.cross(Vector3.UP).normalized()
	if right.length() < 0.01: right = Vector3.RIGHT
	var forward = right.cross(up).normalized()
	
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
		
		st.add_vertex(v1); st.add_vertex(v3); st.add_vertex(v2)
		st.add_vertex(v2); st.add_vertex(v3); st.add_vertex(v4)

