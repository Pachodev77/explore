extends Spatial

# --- CABRA PROCEDURAL (ESTILO LOW-POLY ORGÁNICO) ---
# Anatomía más ágil y cuernos curvados

export var hu = 0.45 
export var color = Color(0.95, 0.95, 0.9) # Crema/Blanco
export var horn_color = Color(0.3, 0.25, 0.2)

var parts = {} 
var master_material: SpatialMaterial

# OPTIMIZACIÓN: Mallas primitivas compartidas
var sphere_mesh = SphereMesh.new()
var cylinder_mesh = CylinderMesh.new()

func _ready():
	sphere_mesh.radial_segments = 8
	sphere_mesh.rings = 6
	cylinder_mesh.radial_segments = 8
	cylinder_mesh.rings = 1
	
	master_material = SpatialMaterial.new()
	master_material.albedo_color = color
	master_material.roughness = 0.8
	master_material.params_diffuse_mode = SpatialMaterial.DIFFUSE_BURLEY
	_generate_structure()

func _generate_structure():
	for c in get_children(): c.queue_free()
	parts.clear()
	
	# --- ANATOMÍA ---
	var leg_height = hu * 1.6
	var body_z_start = -hu * 1.2
	var body_z_end = hu * 1.0
	
	# 1. CUERPO
	var body_root = Spatial.new()
	body_root.name = "BodyRoot"
	body_root.translation = Vector3(0, leg_height, 0)
	add_child(body_root)
	parts["body"] = body_root

	# Torso
	_create_part_mesh(body_root, "Torso", Vector3(0, hu*0.1, 0), Vector3(hu*0.65, hu*0.75, hu*1.1), "ellipsoid")
	
	# 2. CUELLO Y CABEZA
	var neck_base = Spatial.new()
	neck_base.translation = Vector3(0, hu*0.3, body_z_start + hu*0.2)
	body_root.add_child(neck_base)
	
	var neck_v = Vector3(0, hu * 0.6, -hu * 0.4)
	_create_part_mesh(neck_base, "Neck", neck_v*0.5, Vector3(hu*0.35, hu*0.3, 0), "tapered", neck_v, 0.8)

	var head_node = Spatial.new()
	head_node.translation = neck_v
	neck_base.add_child(head_node)
	parts["head"] = head_node
	
	# Cabeza
	_create_part_mesh(head_node, "HeadMain", Vector3(0, 0, -hu*0.25), Vector3(hu*0.22, hu*0.25, hu*0.45), "ellipsoid")
	
	# Cuernos (Curvados hacia atrás)
	for side in [-1, 1]:
		var horn_start = Vector3(hu * 0.12 * side, hu * 0.2, 0)
		var horn_v = Vector3(hu * 0.1 * side, hu * 0.4, hu * 0.3)
		_create_part_mesh(head_node, "Horn" + str(side), horn_start + horn_v*0.5, Vector3(hu*0.06, hu*0.06, 0), "tapered", horn_v, 0.9, horn_color)

	# Barbilla (Gotee)
	_create_part_mesh(head_node, "Beard", Vector3(0, -hu*0.3, -hu*0.4), Vector3(hu*0.05, hu*0.15, hu*0.05), "ellipsoid")

	# 3. PATAS
	var leg_x = hu * 0.35
	var f_leg_z = body_z_start + hu * 0.2
	var b_leg_z = body_z_end - hu * 0.3
	
	var leg_names = ["FL", "FR", "BL", "BR"]
	for i in range(4):
		var name = leg_names[i]
		var is_front = i < 2
		var side = -1 if i % 2 == 0 else 1
		var z = f_leg_z if is_front else b_leg_z
		
		var leg_root = Spatial.new()
		leg_root.name = "Leg_" + name
		leg_root.translation = Vector3(leg_x * side, 0, z)
		body_root.add_child(leg_root)
		parts["leg_" + name.to_lower()] = leg_root
		
		var upper_v = Vector3(0, -hu*0.9, 0)
		_create_part_mesh(leg_root, "Upper", upper_v*0.5, Vector3(hu*0.18, hu*0.18, 0), "tapered", upper_v, 0.7)
		
		var mid_joint = Spatial.new()
		mid_joint.translation = upper_v
		leg_root.add_child(mid_joint)
		parts["joint_" + name.to_lower()] = mid_joint
		
		var lower_v = Vector3(0, -hu*0.8, 0)
		_create_part_mesh(mid_joint, "Lower", lower_v*0.5, Vector3(hu*0.12, hu*0.12, 0), "tapered", lower_v, 0.7)
		
		# Pezuña
		_create_part_mesh(mid_joint, "Hoof", lower_v, Vector3(hu*0.12, hu*0.08, hu*0.14), "ellipsoid", Vector3.ZERO, 0.7, Color(0.2, 0.2, 0.2))

	# 4. COLA
	var tail_root = Spatial.new()
	tail_root.translation = Vector3(0, hu*0.4, body_z_end)
	body_root.add_child(tail_root)
	parts["tail"] = tail_root
	
	var tail_v = Vector3(0, hu*0.2, hu*0.2)
	_create_part_mesh(tail_root, "Tail", tail_v*0.5, Vector3(hu*0.08, hu*0.08, 0), "tapered", tail_v, 0.8)

func _create_part_mesh(parent, p_name, pos, p_scale, type, dir = Vector3.ZERO, overlap = 0.7, p_color = null):
	var mi = MeshInstance.new()
	mi.name = p_name
	parent.add_child(mi)
	mi.translation = pos
	
	if type == "ellipsoid":
		mi.mesh = sphere_mesh
		mi.scale = p_scale
	elif type == "tapered":
		mi.mesh = cylinder_mesh
		var length = dir.length() * overlap * 2.0
		mi.scale = Vector3(p_scale.x, length, p_scale.y)
		
		if dir.length() > 0.001:
			var up = dir.normalized()
			var look_pos = mi.global_transform.origin + up
			if up.distance_to(Vector3.UP) < 0.01:
				mi.look_at(mi.global_transform.origin + Vector3.RIGHT, up)
			else:
				mi.look_at(look_pos, Vector3.UP)
			mi.rotate_object_local(Vector3.RIGHT, deg2rad(90))

	var mat = master_material
	if p_color:
		mat = master_material.duplicate()
		mat.albedo_color = p_color
	mi.material_override = mat
	return mi
