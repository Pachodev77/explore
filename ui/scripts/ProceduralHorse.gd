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
	tail_root.translation = rear_pos + Vector3(0, hu*0.3, hu*0.6)
	body_root.add_child(tail_root)
	parts["tail"] = tail_root
	_create_part_mesh(tail_root, "TailMesh", Vector3(0, -hu*0.6, hu*0.1), Vector3(hu*0.08, hu*0.6, hu*0.08), "capsule", Vector3(0, -hu*1.2, hu*0.2))

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
		_add_tapered_box_oriented(st, -dir*hu*0.4, dir*hu*0.4, p_scale.x, p_scale.y)

	st.generate_normals()
	mi.mesh = st.commit()
	return mi

# --- HELPERS MEJORADOS (LOCALES) ---

func _add_ellipsoid(st, center, scale):
	var steps = 12 # Bajamos un poco para performance de muchas partes
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
	_add_ellipsoid(st, p1, Vector3(r,r,r))
	_add_ellipsoid(st, p2, Vector3(r,r,r))
	_add_box_between(st, p1, p2, r)

func _add_box_between(st, p1, p2, w):
	var dir = (p2 - p1).normalized()
	var right = dir.cross(Vector3.UP).normalized()
	if right.length() < 0.01: right = Vector3.RIGHT
	var up = dir.cross(right).normalized()
	var corners = [right+up, right-up, -right-up, -right+up]
	for i in range(4):
		var n1 = corners[i] * w; var n2 = corners[(i+1)%4] * w
		st.add_vertex(p1+n1); st.add_vertex(p1+n2); st.add_vertex(p2+n1)
		st.add_vertex(p2+n1); st.add_vertex(p1+n2); st.add_vertex(p2+n2)

func _add_tapered_box_oriented(st, p1, p2, w1, w2):
	var dir = (p2 - p1).normalized()
	var right = dir.cross(Vector3.UP).normalized()
	if right.length() < 0.01: right = Vector3.RIGHT
	var up = dir.cross(right).normalized()
	var corners = [right+up, right-up, -right-up, -right+up]
	for i in range(4):
		var n1 = corners[i] * w1; var n2 = corners[(i+1)%4] * w1
		var m1 = corners[i] * w2; var m2 = corners[(i+1)%4] * w2
		st.add_vertex(p1+n1); st.add_vertex(p1+n2); st.add_vertex(p2+m1)
		st.add_vertex(p2+m1); st.add_vertex(p1+n2); st.add_vertex(p2+m2)

