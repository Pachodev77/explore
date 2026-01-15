extends Spatial

# --- GALLINA PROCEDURAL PRO ---
# Diseño realista con jerarquía de nodos para animación fluida.

export var size_unit = 0.25 
export var body_color = Color(1.0, 0.95, 0.9) 
export var pattern_color = Color(0.7, 0.3, 0.1) 

var parts = {}
var master_material
var _gen_id = 0

func _ready():
	_setup_materials()
	var state = _generate_structure()
	if state is GDScriptFunctionState:
		yield(state, "completed")

func _setup_materials():
	var shader = load("res://ui/shaders/chicken.shader")
	if shader:
		master_material = ShaderMaterial.new()
		master_material.shader = shader
		master_material.set_shader_param("base_color", body_color)
		master_material.set_shader_param("pattern_color", pattern_color)
		master_material.set_shader_param("pattern_scale", 15.0)
	else:
		master_material = SpatialMaterial.new()
		master_material.albedo_color = body_color
		master_material.roughness = 0.8

func _generate_structure():
	_gen_id += 1
	var gid = _gen_id
	
	for c in get_children(): c.queue_free()
	parts.clear()
	
	yield(get_tree(), "idle_frame")
	if not is_instance_valid(self) or gid != _gen_id: return
	
	var su = size_unit
	var root = Spatial.new()
	root.name = "BodyRoot"
	root.translation = Vector3(0, su * 2.0, 0) 
	add_child(root); parts["body"] = root
	
	# 1. CUERPO
	_create_part_mesh(root, "Torso", Vector3.ZERO, Vector3(su*1.2, su, su*1.5), "ellipsoid")
	
	yield(get_tree(), "idle_frame")
	if not is_instance_valid(self) or gid != _gen_id: return
	if not is_instance_valid(root): return
	
	# 2. CUELLO Y CABEZA
	var neck_base = Spatial.new()
	neck_base.name = "NeckBase"
	neck_base.translation = Vector3(0, su * 0.5, -su * 1.0)
	root.add_child(neck_base); parts["neck_base"] = neck_base
	
	var neck_v = Vector3(0, su * 1.2, -su * 0.4)
	_create_part_mesh(neck_base, "Neck", neck_v * 0.5, Vector3(su*0.4, su*0.3, 0), "tapered", neck_v, 0.8)
	
	var head = Spatial.new()
	head.name = "Head"
	head.translation = neck_v
	neck_base.add_child(head); parts["head"] = head
	
	# Cabeza redonda
	_create_part_mesh(head, "Skull", Vector3.ZERO, Vector3(su*0.5, su*0.55, su*0.6), "ellipsoid")
	
	# Pico
	var beak_v = Vector3(0, -su*0.1, -su*0.6)
	_create_part_mesh(head, "Beak", Vector3(0, -su*0.1, -su*0.4), Vector3(su*0.15, su*0.15, 0), "tapered", beak_v, 1.0, Color(1.0, 0.7, 0.1))
	
	# Cresta
	_create_part_mesh(head, "Comb", Vector3(0, su*0.5, 0), Vector3(su*0.1, su*0.4, su*0.6), "ellipsoid", Vector3.ZERO, 0.7, Color(0.9, 0.1, 0.1))
	
	# Barbilla
	_create_part_mesh(head, "Wattle", Vector3(0, -su*0.3, -su*0.2), Vector3(su*0.15, su*0.3, su*0.2), "ellipsoid", Vector3.ZERO, 0.7, Color(0.9, 0.1, 0.1))
	
	# Ojos
	for s in [-1, 1]:
		_create_part_mesh(head, "Eye"+str(s), Vector3(su*0.4*s, su*0.1, -su*0.2), Vector3(su*0.1, su*0.1, su*0.1), "ellipsoid", Vector3.ZERO, 1.0, Color(0.1, 0.1, 0.1))

	yield(get_tree(), "idle_frame")
	if not is_instance_valid(self) or gid != _gen_id: return
	if not is_instance_valid(root): return

	# 3. ALAS
	for s in [-1, 1]:
		var wing = Spatial.new()
		wing.name = "Wing" + ("L" if s == -1 else "R")
		wing.translation = Vector3(su * 1.1 * s, 0, 0)
		root.add_child(wing); parts["wing_"+("l" if s == -1 else "r")] = wing
		_create_part_mesh(wing, "WingMesh", Vector3(0, 0, su*0.2), Vector3(su*0.1, su*0.7, su*1.1), "ellipsoid")

	# 4. COLA
	var tail_root = Spatial.new()
	tail_root.name = "TailRoot"
	tail_root.translation = Vector3(0, su*0.5, su*1.3)
	root.add_child(tail_root); parts["tail"] = tail_root
	for i in range(3):
		var rot = (i - 1) * 0.3
		var t_v = Vector3(0, su*1.2, su*0.5).rotated(Vector3.UP, rot)
		_create_part_mesh(tail_root, "Feather"+str(i), t_v*0.5, Vector3(su*0.3, su*0.2, 0), "tapered", t_v, 0.8)

	yield(get_tree(), "idle_frame")
	if not is_instance_valid(self) or gid != _gen_id: return
	if not is_instance_valid(root): return

	# 5. PATAS
	for s in [-1, 1]:
		var leg_root = Spatial.new()
		leg_root.name = "Leg" + ("L" if s == -1 else "R")
		leg_root.translation = Vector3(su*0.4*s, -su*0.2, -su*0.1)
		root.add_child(leg_root); parts["leg_"+("l" if s == -1 else "r")] = leg_root
		
		# Muslo
		var thigh_v = Vector3(0, -su*0.5, 0)
		_create_part_mesh(leg_root, "Thigh", thigh_v*0.5, Vector3(su*0.35, su*0.25, 0), "tapered", thigh_v, 0.8, body_color)
		
		# Articulación
		var joint = Spatial.new()
		joint.translation = thigh_v
		leg_root.add_child(joint)
		
		# Zanca
		var tarsus_v = Vector3(0, -su*0.6, su*0.1) 
		_create_part_mesh(joint, "Tarsus", tarsus_v*0.5, Vector3(su*0.08, su*0.06, 0), "tapered", tarsus_v, 1.0, Color(1.0, 0.8, 0.2))
		
		# Pies
		var foot_node = Spatial.new()
		foot_node.translation = tarsus_v
		joint.add_child(foot_node)
		
		# Dedos
		for rot in [-0.6, 0, 0.6]:
			var toe_v = Vector3(0, -su*0.1, -su*0.5).rotated(Vector3.UP, rot)
			_create_part_mesh(foot_node, "Toe", toe_v*0.5, Vector3(su*0.04, su*0.04, 0), "tapered", toe_v, 1.0, Color(1.0, 0.8, 0.2))
		var back_toe_v = Vector3(0, -su*0.05, su*0.2)
		_create_part_mesh(foot_node, "BackToe", back_toe_v*0.5, Vector3(su*0.04, su*0.04, 0), "tapered", back_toe_v, 1.0, Color(1.0, 0.8, 0.2))

func _create_part_mesh(parent, p_name, pos, p_scale, type, dir = Vector3.ZERO, overlap = 0.7, p_color = null):
	if not is_instance_valid(parent) or not parent.is_inside_tree(): return null
	var mi = MeshInstance.new()
	mi.name = p_name
	parent.add_child(mi)
	mi.translation = pos
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var mat = master_material.duplicate()
	if p_color:
		if mat is ShaderMaterial:
			mat.set_shader_param("base_color", p_color)
			mat.set_shader_param("pattern_intensity", 0.0)
		elif mat is SpatialMaterial:
			mat.albedo_color = p_color
	st.set_material(mat)
	
	if type == "ellipsoid":
		_add_ellipsoid(st, p_scale)
	elif type == "tapered":
		_add_tapered(st, -dir*overlap, dir*overlap, p_scale.x, p_scale.y)
	
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON
	return mi

func _add_ellipsoid(st, scale):
	var steps = 10
	for i in range(steps):
		var lat = PI * i / steps
		var lat_n = PI * (i + 1) / steps
		for j in range(steps * 2):
			var lon = 2 * PI * j / (steps * 2)
			var lon_n = 2 * PI * (j + 1) / (steps * 2)
			var p1 = _get_p(lat, lon, scale)
			var p2 = _get_p(lat_n, lon, scale)
			var p3 = _get_p(lat, lon_n, scale)
			var p4 = _get_p(lat_n, lon_n, scale)
			st.add_normal(p1.normalized()); st.add_vertex(p1)
			st.add_normal(p2.normalized()); st.add_vertex(p2)
			st.add_normal(p4.normalized()); st.add_vertex(p4)
			st.add_normal(p1.normalized()); st.add_vertex(p1)
			st.add_normal(p4.normalized()); st.add_vertex(p4)
			st.add_normal(p3.normalized()); st.add_vertex(p3)

func _get_p(lat, lon, s):
	return Vector3(sin(lat)*cos(lon)*s.x, cos(lat)*s.y, sin(lat)*sin(lon)*s.z)

func _add_tapered(st, p1, p2, r1, r2):
	var dir = (p2 - p1).normalized()
	var ref = Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var right = dir.cross(ref).normalized()
	var fwd = right.cross(dir).normalized()
	var steps = 8
	for i in range(steps):
		var a = 2 * PI * i / steps; var an = 2 * PI * (i + 1) / steps
		var c = cos(a); var s = sin(a); var cn = cos(an); var sn = sin(an)
		var v1 = p1 + (right*c + fwd*s)*r1; var v2 = p1 + (right*cn + fwd*sn)*r1
		var v3 = p2 + (right*c + fwd*s)*r2; var v4 = p2 + (right*cn + fwd*sn)*r2
		var n1 = (v1-p1).normalized(); var n2 = (v2-p1).normalized()
		st.add_normal(n1); st.add_vertex(v1)
		st.add_normal(n2); st.add_vertex(v2)
		st.add_normal(n2); st.add_vertex(v4)
		st.add_normal(n1); st.add_vertex(v1)
		st.add_normal(n2); st.add_vertex(v4)
		st.add_normal(n1); st.add_vertex(v3)
