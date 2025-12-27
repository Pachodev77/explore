extends MeshInstance

# --- SISTEMA DE HUMANOIDE PROCEDURAL "PRO" V9 (MULTI-MATERIAL) ---
# Cada parte del cuerpo tiene su propia superficie y material editable.

var skel_node = null
var bone_ids = {}

# Definición de materiales por parte
var body_materials = {
	"Head": null,
	"Neck": null,
	"Hips": null,
	"Abdomen": null,
	"Shoulders": null,
	"UpperArms": null,
	"LowerArms": null,
	"UpperLegs": null,
	"LowerLegs": null,
	"Feet": null
}

func _ready():
	_setup_materials()
	_generate_everything()

func _setup_materials():
	# Lista de partes que comparten material
	var part_groups = {
		"Head": ["Head"],
		"Neck": ["Neck"],
		"Hips": ["Hips"],
		"Abdomen": ["Spine", "Spine2"],
		"Shoulders": ["ShoulderL", "ShoulderR"],
		"UpperArms": ["UpperArmL", "UpperArmR"],
		"LowerArms": ["LowerArmL", "LowerArmR"],
		"UpperLegs": ["UpperLegL", "UpperLegR"],
		"LowerLegs": ["LowerLegL", "LowerLegR"],
		"Feet": ["FootL", "FootR"]
	}
	
	for group_name in part_groups.keys():
		var mat = ShaderMaterial.new()
		mat.shader = load("res://ui/shaders/realistic_skin.shader")
		
		# Intentar cargar textura, si no crear una blanca por defecto
		var tex_path = "res://assets/textures/player/" + group_name.to_lower() + ".png"
		var tex = load(tex_path)
		if not tex:
			tex = _create_white_placeholder()
			
		mat.set_shader_param("skin_color", Color(1, 1, 1)) # Usar blanco para que mande la textura
		mat.set_shader_param("albedo_texture", tex)
		mat.set_shader_param("roughness", 0.4)
		mat.set_shader_param("sss_strength", 0.3)
		mat.set_shader_param("detail_scale", 50.0)
		
		body_materials[group_name] = mat

func _create_white_placeholder():
	var img = Image.new()
	img.create(16, 16, false, Image.FORMAT_RGB8)
	img.fill(Color.white)
	var tex = ImageTexture.new()
	tex.create_from_image(img)
	return tex

func _generate_everything():
	_generate_rig()
	_generate_skinned_mesh()
	_apply_visual_test()

func _generate_rig():
	skel_node = Skeleton.new()
	skel_node.name = "HumanoidSkeleton"
	add_child(skel_node)
	
	_add_bone("Hips", -1, Vector3(0, 0.95, 0))
	_add_bone("Spine", bone_ids["Hips"], Vector3(0, 0.15, 0))
	_add_bone("Spine2", bone_ids["Spine"], Vector3(0, 0.2, 0))
	_add_bone("Neck", bone_ids["Spine2"], Vector3(0, 0.2, 0))
	_add_bone("Head", bone_ids["Neck"], Vector3(0, 0.2, 0))
	
	for side in ["L", "R"]:
		var sm = 1.0 if side == "R" else -1.0
		var s = "Shoulder"+side; _add_bone(s, bone_ids["Spine2"], Vector3(0.21*sm, 0.1, 0))
		var ua = "UpperArm"+side; _add_bone(ua, bone_ids[s], Vector3(0.03*sm, -0.02, 0))
		var la = "LowerArm"+side; _add_bone(la, bone_ids[ua], Vector3(0, -0.2, 0))
		var ul = "UpperLeg"+side; _add_bone(ul, bone_ids["Hips"], Vector3(0.11*sm, -0.05, 0))
		var ll = "LowerLeg"+side; _add_bone(ll, bone_ids[ul], Vector3(0, -0.35, 0))
		var ft = "Foot"+side; _add_bone(ft, bone_ids[ll], Vector3(0, -0.5, 0)) # Pivote en el tobillo

func _add_bone(name, parent, rest):
	skel_node.add_bone(name)
	var id = skel_node.find_bone(name)
	bone_ids[name] = id
	if parent != -1: skel_node.set_bone_parent(id, parent)
	skel_node.set_bone_rest(id, Transform(Basis(), rest))

func _generate_skinned_mesh():
	var am = ArrayMesh.new()
	
	# Grupos de partes por material
	var groups = {
		"Hips": [
			["Hips", Vector3(0, 0.95, 0), Vector3(0.22, 0.16, 0.16)]
		],
		"Abdomen": [
			["Spine", Vector3(0, 1.1, 0), Vector3(0.2, 0.2, 0.14)],
			["Spine2", Vector3(0, 1.3, 0), Vector3(0.24, 0.25, 0.2)]
		],
		"Head": [
			["Head", Vector3(0, 1.75, 0), Vector3(0.16, 0.18, 0.16)]
		],
		"Neck": [
			["Neck", Vector3(0, 1.55, 0), Vector3(0.06, 0.25, 0.06)]
		],
		"Shoulders": [],
		"UpperArms": [],
		"LowerArms": [],
		"UpperLegs": [],
		"LowerLegs": [],
		"Feet": []
	}
	
	for side in ["L", "R"]:
		var sm = 1.0 if side == "R" else -1.0
		groups["Shoulders"].append(["Shoulder"+side, Vector3(0.21*sm, 1.4, 0), Vector3(0.09, 0.09, 0.09)])
		groups["UpperArms"].append(["UpperArm"+side, Vector3(0.24*sm, 1.23, 0), Vector3(0.08, 0.2, 0.08)])
		groups["LowerArms"].append(["LowerArm"+side, Vector3(0.26*sm, 1.05, 0), Vector3(0.07, 0.2, 0.07)])
		
		groups["UpperLegs"].append(["UpperLeg"+side, Vector3(0.11*sm, 0.75, 0), Vector3(0.11, 0.2, 0.11)])
		groups["LowerLegs"].append(["LowerLeg"+side, Vector3(0.11*sm, 0.35, 0), Vector3(0.09, 0.3, 0.09)])
		
		# PIE (Base en tobillo z=0, extensión hacia adelante +Z)
		# Centro Y ajustado para que la base plana esté en Y=0 (size.y * 0.3)
		groups["Feet"].append(["Foot"+side, Vector3(0.11*sm, 0.036, 0.1), Vector3(0.09, 0.12, 0.18)])

	var sphere = SphereMesh.new()
	sphere.radial_segments = 12
	sphere.rings = 8
	var sphere_arrays = sphere.get_mesh_arrays()
	
	for group_name in groups.keys():
		var group_parts = groups[group_name]
		if group_parts.empty(): continue
		
		var verts = PoolVector3Array()
		var norms = PoolVector3Array()
		var uvs = PoolVector2Array()
		var bones = PoolIntArray()
		var weights = PoolRealArray()
		var indices = PoolIntArray()
		
		for part in group_parts:
			var b_name = part[0]
			var center = part[1]
			var size = part[2]
			var b_id = bone_ids.get(b_name, 0)
			
			var offset = verts.size()
			var p_verts = sphere_arrays[Mesh.ARRAY_VERTEX]
			var p_norms = sphere_arrays[Mesh.ARRAY_NORMAL]
			var p_uvs = sphere_arrays[Mesh.ARRAY_TEX_UV]
			var p_indices = sphere_arrays[Mesh.ARRAY_INDEX]
			
			var is_foot = b_name.begins_with("Foot")
			
			for i in range(p_verts.size()):
				var v = p_verts[i]
				var n = p_norms[i]
				
				# Aplicar escalado
				v.x *= size.x; v.y *= size.y; v.z *= size.z
				
				# Aplanar la suela si es un pie (Corte más agresivo al 30% inferior)
				if is_foot and v.y < -size.y * 0.3:
					v.y = -size.y * 0.3
					n = Vector3(0, -1, 0) # Normal hacia abajo para la suela
				
				v += center
				verts.append(v)
				norms.append(n)
				uvs.append(p_uvs[i])
				bones.append(b_id); bones.append(0); bones.append(0); bones.append(0)
				weights.append(1.0); weights.append(0.0); weights.append(0.0); weights.append(0.0)
			
			for i in range(p_indices.size()):
				indices.append(p_indices[i] + offset)
		
		var surface_arrays = []
		surface_arrays.resize(Mesh.ARRAY_MAX)
		surface_arrays[Mesh.ARRAY_VERTEX] = verts
		surface_arrays[Mesh.ARRAY_NORMAL] = norms
		surface_arrays[Mesh.ARRAY_TEX_UV] = uvs
		surface_arrays[Mesh.ARRAY_BONES] = bones
		surface_arrays[Mesh.ARRAY_WEIGHTS] = weights
		surface_arrays[Mesh.ARRAY_INDEX] = indices
		
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
		var surface_idx = am.get_surface_count() - 1
		am.surface_set_material(surface_idx, body_materials[group_name])

	mesh = am
	self.skeleton = get_path_to(skel_node)

func _apply_visual_test():
	print("ProceduralHumanoid V9: Multi-material listo.")
