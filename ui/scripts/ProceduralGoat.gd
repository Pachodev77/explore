extends Spatial

# --- PROCEDURAL GOAT ULTRA V4 (SISTEMA DE ALTA CALIDAD) ---
# Anatomía de montaña con mallas fusionadas y perfiles anatómicos reales.

export var hu = 0.52 
export var color = Color(0.98, 0.97, 0.92)
export var horn_color = Color(0.28, 0.24, 0.2)
export var skin_color = Color(0.9, 0.75, 0.75)

var parts = {} 
var master_material: SpatialMaterial

func _ready():
	master_material = SpatialMaterial.new()
	master_material.albedo_color = Color(1, 1, 1)
	master_material.roughness = 0.75
	master_material.params_diffuse_mode = SpatialMaterial.DIFFUSE_BURLEY
	_generate_structure()

func _generate_structure():
	for c in get_children(): c.queue_free()
	parts.clear()
	
	var leg_h = hu * 1.75
	var body_root = Spatial.new()
	body_root.name = "BodyRoot"
	body_root.translation = Vector3(0, leg_h, 0)
	add_child(body_root)
	parts["body"] = body_root

	# 1. TORSO CAPRINO (Estructura en Cuña)
	# Tórax profundo
	var chest_p = Vector3(0, hu*0.12, -hu*0.5)
	_create_part_mesh(body_root, "Chest", chest_p, Vector3(hu*0.65, hu*0.82, hu*0.75), "ellipsoid")
	
	# Pelvis elevada y ósea
	var hip_p = Vector3(0, hu*0.2, hu*0.65)
	_create_part_mesh(body_root, "Pelvis", hip_p, Vector3(hu*0.6, hu*0.78, hu*0.8), "ellipsoid")
	
	# Abdomen recogido (Tucked)
	var belly_p = Vector3(0, -hu*0.05, 0)
	_create_part_mesh(body_root, "Belly", belly_p, Vector3(hu*0.58, hu*0.68, hu*0.85), "ellipsoid")

	# 2. CUELLO Y CABEZA
	var neck_base = Spatial.new()
	neck_base.name = "NeckBase"
	neck_base.translation = chest_p + Vector3(0, hu*0.35, -hu*0.5)
	body_root.add_child(neck_base)
	parts["neck_base"] = neck_base
	
	var n1_v = Vector3(0, hu*0.48, -hu*0.32)
	_create_part_mesh(neck_base, "Neck1", n1_v*0.5, Vector3(hu*0.34, hu*0.26, 0), "tapered", n1_v, 0.85)

	var head_n = Spatial.new()
	head_n.name = "Head"
	head_n.translation = n1_v
	neck_base.add_child(head_n); parts["head"] = head_n
	
	# Cráneo y Hocico Fino
	var skull_v = Vector3(0, 0, -hu*0.15)
	_create_part_mesh(head_n, "Skull", skull_v*0.5, Vector3(hu*0.24, hu*0.28, hu*0.32), "ellipsoid")
	
	var muz_v = Vector3(0, -hu*0.18, -hu*0.45)
	_create_part_mesh(head_n, "Muzzle", skull_v + muz_v*0.5, Vector3(hu*0.2, hu*0.14, 0), "tapered", muz_v, 0.9, skin_color)

	# Cuernos Cimitarra (Doble Segmento)
	for s in [-1, 1]:
		var h_base = skull_v + Vector3(hu*0.12*s, hu*0.2, 0)
		var h1_v = Vector3(hu*0.08*s, hu*0.35, hu*0.15)
		_create_part_mesh(head_n, "H1_"+str(s), h_base + h1_v*0.5, Vector3(hu*0.07, hu*0.07, 0), "tapered", h1_v, 0.9, horn_color)
		var h2_v = Vector3(0, hu*0.2, hu*0.35) # Curva hacia atrás
		_create_part_mesh(head_n, "H2_"+str(s), h_base + h1_v + h2_v*0.5, Vector3(hu*0.05, hu*0.03, 0), "tapered", h2_v, 0.9, horn_color)

	# Barba y Orejas laterales
	_create_part_mesh(head_n, "Goatee", skull_v + muz_v + Vector3(0, -hu*0.15, 0.1), Vector3(hu*0.03, hu*0.15, hu*0.03), "ellipsoid")
	for s in [-1, 1]:
		_create_part_mesh(head_n, "Ear"+str(s), skull_v + Vector3(hu*0.25*s, hu*0.05, 0), Vector3(hu*0.08, hu*0.18, hu*0.03), "ellipsoid", Vector3(s, 0.3, 0))

	# 3. EXTREMIDADES (Articulación Técnica de Montaña)
	var lx = hu * 0.4; var fz = -hu * 0.8; var bz = hu * 0.65
	var legs = ["fl", "fr", "bl", "br"]
	for i in range(4):
		var s = -1 if i % 2 == 0 else 1; var is_f = i < 2; var z = fz if is_f else bz
		var l_root = Spatial.new(); l_root.translation = Vector3(lx*s, 0, z)
		body_root.add_child(l_root); parts["leg_"+legs[i]] = l_root
		
		var u_v = Vector3(0, -hu*0.85, 0)
		if not is_f: u_v = Vector3(0, -hu*0.85, hu*0.15) # Inclinación fémur
		_create_part_mesh(l_root, "U", u_v*0.5, Vector3(hu*0.2, hu*0.16, 0), "tapered", u_v, 0.6)
		var joint = Spatial.new(); joint.translation = u_v
		l_root.add_child(joint); parts["joint_"+legs[i]] = joint
		var lo_v = Vector3(0, -hu*0.75, 0)
		if not is_f: lo_v = Vector3(0, -hu*0.8, -hu*0.2) # Corvejón
		_create_part_mesh(joint, "L", lo_v*0.5, Vector3(hu*0.12, hu*0.09, 0), "tapered", lo_v, 0.65)
		_create_part_mesh(joint, "Hoof", lo_v, Vector3(hu*0.14, hu*0.08, hu*0.16), "ellipsoid", Vector3.ZERO, 1.0, Color(0.1, 0.1, 0.1))

	# 4. COLA (Upturned)
	var t_root = Spatial.new(); t_root.translation = hip_p + Vector3(0, hu*0.1, hu*0.7); body_root.add_child(t_root)
	parts["tail"] = t_root
	var t_v = Vector3(0, hu*0.32, hu*0.25)
	_create_part_mesh(t_root, "T", t_v*0.5, Vector3(hu*0.06, hu*0.06, 0), "tapered", t_v, 0.9)

func _create_part_mesh(parent, p_name, pos, p_scale, type, dir = Vector3.ZERO, overlap = 0.7, p_color = null):
	var mi = MeshInstance.new(); mi.name = p_name; parent.add_child(mi); mi.translation = pos
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat = master_material if not p_color else master_material.duplicate()
	if p_color: mat.albedo_color = p_color
	st.set_material(mat)
	if type == "ellipsoid": _add_ellipsoid(st, Vector3.ZERO, p_scale, dir)
	elif type == "tapered": _add_tapered(st, -dir*overlap, dir*overlap, p_scale.x, p_scale.y)
	mi.mesh = st.commit()
	# Sombras activadas para la cabra
	mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON
	return mi

func _add_ellipsoid(st, center, scale, dir = Vector3.ZERO):
	var steps = 12
	for i in range(steps):
		var lat = PI * i / steps; var lat_n = PI * (i + 1) / steps
		for j in range(steps * 2):
			var lon = 2 * PI * j / (steps * 2); var lon_n = 2 * PI * (j + 1) / (steps * 2)
			var p1 = _get_p(lat, lon, scale); var p2 = _get_p(lat_n, lon, scale)
			var p3 = _get_p(lat, lon_n, scale); var p4 = _get_p(lat_n, lon_n, scale)
			st.add_normal(p1.normalized()); st.add_vertex(p1); st.add_normal(p2.normalized()); st.add_vertex(p2)
			st.add_normal(p3.normalized()); st.add_vertex(p3); st.add_normal(p2.normalized()); st.add_vertex(p2)
			st.add_normal(p4.normalized()); st.add_vertex(p4); st.add_normal(p3.normalized()); st.add_vertex(p3)

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
		st.add_normal(n1); st.add_vertex(v1); st.add_normal(n1); st.add_vertex(v3); st.add_normal(n2); st.add_vertex(v2)
		st.add_normal(n2); st.add_vertex(v2); st.add_normal(n1); st.add_vertex(v3); st.add_normal(n2); st.add_vertex(v4)
