extends Spatial

# --- VACA PROCEDURAL PRO V3 (GEOMETRÍA ORGÁNICA) ---
# Sistema de alto nivel con SurfaceTool y fusión de normales.

export var hu = 0.6 
export var color = Color(0.9, 0.9, 0.9) # Blanco base
export var spot_color = Color(0.1, 0.1, 0.1)
export var skin_color = Color(0.9, 0.7, 0.7)

var parts = {} 
var master_material: SpatialMaterial

func _ready():
	master_material = SpatialMaterial.new()
	master_material.albedo_color = Color(1, 1, 1) # Usar blanco base
	master_material.roughness = 0.8
	master_material.params_diffuse_mode = SpatialMaterial.DIFFUSE_BURLEY
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
	_create_part_mesh(body_root, "Chest", rib_p, Vector3(hu*0.9, hu*0.95, hu*1.1), "ellipsoid")
	
	var rear_p = Vector3(0, hu*0.05, hu*0.6)
	_create_part_mesh(body_root, "Hind", rear_p, Vector3(hu*0.95, hu*0.95, hu*1.0), "ellipsoid")
	
	var belly_p = (rib_p + rear_p) * 0.5 + Vector3(0, -hu*0.15, 0)
	_create_part_mesh(body_root, "Belly", belly_p, Vector3(hu*0.85, hu*0.88, hu*0.95), "ellipsoid")

	# 2. CUELLO Y CABEZA
	var neck_base = Spatial.new()
	neck_base.name = "NeckBase"
	neck_base.translation = rib_p + Vector3(0, hu*0.3, -hu*0.7)
	body_root.add_child(neck_base)
	parts["neck_base"] = neck_base
	
	var neck_v = Vector3(0, hu * 0.45, -hu * 0.3)
	_create_part_mesh(neck_base, "Neck", neck_v*0.5, Vector3(hu*0.55, hu*0.48, 0), "tapered", neck_v, 0.8)

	var head_n = Spatial.new()
	head_n.name = "Head"
	head_n.translation = neck_v
	neck_base.add_child(head_n)
	parts["head"] = head_n
	
	# Cabeza: Gran frente y hocico
	var skull_v = Vector3(0, 0, -hu*0.35)
	_create_part_mesh(head_n, "Skull", skull_v*0.5, Vector3(hu*0.38, hu*0.32, 0), "tapered", skull_v, 0.8)
	
	var muzzle_v = Vector3(0, -hu*0.2, -hu*0.4)
	_create_part_mesh(head_n, "Muzzle", skull_v + muzzle_v*0.5, Vector3(hu*0.3, hu*0.25, 0), "tapered", muzzle_v, 0.85, skin_color)

	# Cuernos (Cortos) y Orejas
	for s in [-1, 1]:
		var h_dir = Vector3(hu*0.3*s, hu*0.1, -hu*0.1)
		_create_part_mesh(head_n, "Horn"+str(s), skull_v + Vector3(hu*0.2*s, hu*0.2, 0), Vector3(hu*0.08, hu*0.05, 0), "tapered", h_dir, 0.9, Color(0.8, 0.8, 0.7))
		_create_part_mesh(head_n, "Ear"+str(s), skull_v + Vector3(hu*0.3*s, 0.1, 0), Vector3(hu*0.15, hu*0.08, hu*0.05), "ellipsoid")

	# UBRE (Detalle Clave)
	_create_part_mesh(body_root, "Udder", belly_p + Vector3(0, -hu*0.4, hu*0.3), Vector3(hu*0.38, hu*0.28, hu*0.38), "ellipsoid", Vector3.ZERO, 1.0, skin_color)

	# 3. PATAS (Robustas)
	var lx = hu * 0.45; var fz = -hu * 1.0; var bz = hu * 0.8
	var legs = ["FL", "FR", "BL", "BR"]
	for i in range(4):
		var s = -1 if i % 2 == 0 else 1
		var is_f = i < 2
		var z = fz if is_f else bz
		var l_root = Spatial.new()
		l_root.translation = Vector3(lx*s, 0, z)
		body_root.add_child(l_root)
		parts["leg_"+legs[i].to_lower()] = l_root
		
		var u_v = Vector3(0, -hu*0.8, 0)
		_create_part_mesh(l_root, "U", u_v*0.5, Vector3(hu*0.28, hu*0.22, 0), "tapered", u_v, 0.6)
		var joint = Spatial.new(); joint.translation = u_v
		l_root.add_child(joint); parts["joint_"+legs[i].to_lower()] = joint
		var lo_v = Vector3(0, -hu*0.7, 0)
		_create_part_mesh(joint, "L", lo_v*0.5, Vector3(hu*0.2, hu*0.15, 0), "tapered", lo_v, 0.65)
		_create_part_mesh(joint, "Hoof", lo_v, Vector3(hu*0.18, hu*0.1, hu*0.2), "ellipsoid", Vector3.ZERO, 1.0, Color(0.15, 0.15, 0.15))

	# 4. COLA
	var t_root = Spatial.new(); t_root.translation = rear_p + Vector3(0, hu*0.1, hu*0.95); body_root.add_child(t_root)
	parts["tail"] = t_root
	var t_v = Vector3(0, -hu*1.1, hu*0.1)
	_create_part_mesh(t_root, "T", t_v*0.5, Vector3(hu*0.05, hu*0.05, 0), "tapered", t_v, 0.9)

func _create_part_mesh(parent, p_name, pos, p_scale, type, dir = Vector3.ZERO, overlap = 0.7, p_color = null):
	var mi = MeshInstance.new(); mi.name = p_name; parent.add_child(mi); mi.translation = pos
	var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat = master_material if not p_color else master_material.duplicate()
	if p_color: mat.albedo_color = p_color
	st.set_material(mat)
	if type == "ellipsoid": _add_ellipsoid(st, Vector3.ZERO, p_scale)
	elif type == "tapered": _add_tapered(st, -dir*overlap, dir*overlap, p_scale.x, p_scale.y)
	mi.mesh = st.commit(); return mi

func _add_ellipsoid(st, center, scale):
	var steps = 12
	for i in range(steps):
		var lat = PI * i / steps; var lat_n = PI * (i + 1) / steps
		for j in range(steps * 2):
			var lon = 2 * PI * j / (steps * 2); var lon_n = 2 * PI * (j + 1) / (steps * 2)
			var p1 = _get_p(lat, lon, scale); var p2 = _get_p(lat_n, lon, scale)
			var p3 = _get_p(lat, lon_n, scale); var p4 = _get_p(lat_n, lon_n, scale)
			st.add_normal(p1.normalized()); st.add_vertex(p1)
			st.add_normal(p2.normalized()); st.add_vertex(p2)
			st.add_normal(p3.normalized()); st.add_vertex(p3)
			st.add_normal(p2.normalized()); st.add_vertex(p2)
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
		st.add_normal(n1); st.add_vertex(v1); st.add_normal(n1); st.add_vertex(v3)
		st.add_normal(n2); st.add_vertex(v2); st.add_normal(n2); st.add_vertex(v2)
		st.add_normal(n1); st.add_vertex(v3); st.add_normal(n2); st.add_vertex(v4)
