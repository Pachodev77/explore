extends Spatial

# --- VACA PROCEDURAL PRO V3 (GEOMETRÍA ORGÁNICA) ---
# Sistema de alto nivel con SurfaceTool y fusión de normales.

export var hu = 0.75 
export var color = Color(0.9, 0.9, 0.9) # Blanco base
export var spot_color = Color(0.1, 0.1, 0.1)
export var skin_color = Color(0.9, 0.7, 0.7)

var parts = {} 
var master_material: ShaderMaterial
func _ready():
	master_material = ShaderMaterial.new()
	master_material.shader = load("res://ui/shaders/cow_spots.shader")
	master_material.set_shader_param("base_color", color)
	master_material.set_shader_param("spot_color", spot_color)
	master_material.set_shader_param("spot_scale", 4.5)
	master_material.set_shader_param("spot_threshold", 0.42)
	
	_generate_structure()

func _generate_structure():
	for c in get_children(): c.queue_free()
	parts.clear()
	
	var leg_h = hu * 1.5
	var body_root = Spatial.new()
	body_root.name = "BodyRoot"
	body_root.translation = Vector3(0, leg_h, 0)
	add_child(body_root)
	parts["body"] = body_root

	# 1. TORSO (Estructura Pesada)
	var rib_p = Vector3(0, hu*0.1, -hu*0.6)
	_create_part_mesh(body_root, "Chest", rib_p, Vector3(hu*0.8, hu*0.85, hu*1.0), "ellipsoid", Vector3.ZERO, 0.7, null, rib_p)
	
	var rear_p = Vector3(0, hu*0.05, hu*0.6)
	_create_part_mesh(body_root, "Hind", rear_p, Vector3(hu*0.85, hu*0.85, hu*0.9), "ellipsoid", Vector3.ZERO, 0.7, null, rear_p)
	
	var belly_p = (rib_p + rear_p) * 0.5 + Vector3(0, -hu*0.15, 0)
	_create_part_mesh(body_root, "Belly", belly_p, Vector3(hu*0.75, hu*0.8, hu*0.85), "ellipsoid", Vector3.ZERO, 0.7, null, belly_p)

	# 2. CUELLO Y CABEZA
	var neck_base = Spatial.new()
	neck_base.name = "NeckBase"
	var neck_base_p = rib_p + Vector3(0, hu*0.1, -hu*0.7) # Pivote más bajo
	neck_base.translation = neck_base_p
	body_root.add_child(neck_base); parts["neck_base"] = neck_base
	
	var neck_v = Vector3(0, hu * 0.65, -hu * 0.45) # Cuello más largo
	var neck_offset = neck_base_p + neck_v * 0.5
	_create_part_mesh(neck_base, "Neck", neck_v*0.5, Vector3(hu*0.55, hu*0.48, 0), "tapered", neck_v, 0.8, null, neck_offset)

	var head_n = Spatial.new()
	head_n.name = "Head"
	head_n.translation = neck_v
	neck_base.add_child(head_n); parts["head"] = head_n
	var head_global_p = neck_base_p + neck_v
	
	# Cabeza: Gran frente y hocico
	var skull_v = Vector3(0, 0, -hu*0.35)
	var skull_offset = head_global_p + skull_v * 0.5
	_create_part_mesh(head_n, "Skull", skull_v*0.5, Vector3(hu*0.38, hu*0.32, 0), "tapered", skull_v, 0.8, null, skull_offset)
	
	var muzzle_v = Vector3(0, -hu*0.2, -hu*0.4)
	var muzzle_offset = head_global_p + skull_v + muzzle_v * 0.5
	_create_part_mesh(head_n, "Muzzle", skull_v + muzzle_v*0.5, Vector3(hu*0.3, hu*0.25, 0), "tapered", muzzle_v, 0.85, skin_color, muzzle_offset)

	# Cuernos y Orejas
	for s in [-1, 1]:
		var h_pos = skull_v + Vector3(hu*0.2*s, hu*0.2, 0)
		_create_part_mesh(head_n, "Horn"+str(s), h_pos, Vector3(hu*0.08, hu*0.05, 0), "tapered", Vector3(hu*0.3*s, hu*0.1, -hu*0.1), 0.9, Color(0.8, 0.8, 0.7), head_global_p + h_pos)
		var e_pos = skull_v + Vector3(hu*0.3*s, 0.1, 0)
		_create_part_mesh(head_n, "Ear"+str(s), e_pos, Vector3(hu*0.15, hu*0.08, hu*0.05), "ellipsoid", Vector3.ZERO, 0.7, null, head_global_p + e_pos)

	# UBRE
	var udder_p = belly_p + Vector3(0, -hu*0.4, hu*0.3)
	_create_part_mesh(body_root, "Udder", udder_p, Vector3(hu*0.38, hu*0.28, hu*0.38), "ellipsoid", Vector3.ZERO, 1.0, skin_color, udder_p)

	# 3. PATAS (Robustas)
	var lx = hu * 0.45; var fz = -hu * 1.0; var bz = hu * 0.8
	var legs = ["FL", "FR", "BL", "BR"]
	for i in range(4):
		var s = -1 if i % 2 == 0 else 1
		var is_f = i < 2
		var z = fz if is_f else bz
		var l_rest_p = Vector3(lx*s, 0, z)
		var l_root = Spatial.new(); l_root.translation = l_rest_p
		body_root.add_child(l_root); parts["leg_"+legs[i].to_lower()] = l_root
		
		var u_v = Vector3(0, -hu*0.8, 0)
		_create_part_mesh(l_root, "U", u_v*0.5, Vector3(hu*0.28, hu*0.22, 0), "tapered", u_v, 0.6, null, l_rest_p + u_v*0.5)
		var joint = Spatial.new(); joint.translation = u_v
		l_root.add_child(joint); parts["joint_"+legs[i].to_lower()] = joint
		var lo_v = Vector3(0, -hu*0.7, 0)
		_create_part_mesh(joint, "L", lo_v*0.5, Vector3(hu*0.2, hu*0.15, 0), "tapered", lo_v, 0.65, null, l_rest_p + u_v + lo_v*0.5)
		_create_part_mesh(joint, "Hoof", lo_v, Vector3(hu*0.18, hu*0.1, hu*0.2), "ellipsoid", Vector3.ZERO, 1.0, Color(0.15, 0.15, 0.15), l_rest_p + u_v + lo_v)

	# 4. COLA
	var tail_p = rear_p + Vector3(0, hu*0.1, hu*0.75)
	var t_root = Spatial.new(); t_root.translation = tail_p; body_root.add_child(t_root); parts["tail"] = t_root
	var t_v = Vector3(0, -hu*1.1, hu*0.1)
	_create_part_mesh(t_root, "T", t_v*0.5, Vector3(hu*0.05, hu*0.05, 0), "tapered", t_v, 0.9, null, tail_p + t_v*0.5)

func _create_part_mesh(parent, p_name, pos, p_scale, type, dir = Vector3.ZERO, overlap = 0.7, p_color = null, noise_offset = Vector3.ZERO):
	var mi = MeshInstance.new(); mi.name = p_name; parent.add_child(mi); mi.translation = pos
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# SIEMPRE DUPLICAR para que cada pieza tenga su propio part_offset
	var mat = master_material.duplicate()
	mat.set_shader_param("part_offset", noise_offset)
	
	if p_color:
		mat.set_shader_param("base_color", p_color)
		mat.set_shader_param("spot_threshold", 2.0)
	
	st.set_material(mat)
	if type == "ellipsoid": _add_ellipsoid(st, Vector3.ZERO, p_scale)
	elif type == "tapered": _add_tapered(st, -dir*overlap, dir*overlap, p_scale.x, p_scale.y)
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON
	return mi

func _add_ellipsoid(st, _center, scale):
	var steps = 12
	for i in range(steps):
		var lat = PI * i / steps; var lat_n = PI * (i + 1) / steps
		for j in range(steps * 2):
			var lon = 2 * PI * j / (steps * 2); var lon_n = 2 * PI * (j + 1) / (steps * 2)
			var p1 = _get_p(lat, lon, scale); var p2 = _get_p(lat_n, lon, scale)
			var p3 = _get_p(lat, lon_n, scale); var p4 = _get_p(lat_n, lon_n, scale)
			# Triangulo 1 (CCW)
			st.add_normal(p1.normalized()); st.add_vertex(p1)
			st.add_normal(p2.normalized()); st.add_vertex(p2)
			st.add_normal(p4.normalized()); st.add_vertex(p4)
			# Triangulo 2 (CCW)
			st.add_normal(p1.normalized()); st.add_vertex(p1)
			st.add_normal(p4.normalized()); st.add_vertex(p4)
			st.add_normal(p3.normalized()); st.add_vertex(p3)

func _get_p(lat, lon, s): return Vector3(sin(lat)*cos(lon)*s.x, cos(lat)*s.y, sin(lat)*sin(lon)*s.z)

func _add_tapered(st, p1, p2, r1, r2):
	var dir = (p2 - p1).normalized(); var ref = Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var right = dir.cross(ref).normalized(); var fwd = right.cross(dir).normalized()
	var steps = 12
	for i in range(steps):
		var a = 2 * PI * i / steps; var an = 2 * PI * (i + 1) / steps
		var c = cos(a); var s = sin(a); var cn = cos(an); var sn = sin(an)
		var v1 = p1 + (right*c + fwd*s)*r1; var v2 = p1 + (right*cn + fwd*sn)*r1
		var v3 = p2 + (right*c + fwd*s)*r2; var v4 = p2 + (right*cn + fwd*sn)*r2
		var n1 = (v1-p1).normalized(); var n2 = (v2-p1).normalized()
		# Triangulo 1: v1, v2, v4 (CCW)
		st.add_normal(n1); st.add_vertex(v1)
		st.add_normal(n2); st.add_vertex(v2)
		st.add_normal(n2); st.add_vertex(v4)
		# Triangulo 2: v1, v4, v3 (CCW)
		st.add_normal(n1); st.add_vertex(v1)
		st.add_normal(n2); st.add_vertex(v4)
		st.add_normal(n1); st.add_vertex(v3)
