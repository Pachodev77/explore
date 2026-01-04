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
	"Hair": null,
	"Eyes": null,
	"Mouth": null,
	"Shoulders": null,
	"UpperArms": null,
	"LowerArms": null,
	"UpperLegs": null,
	"LowerLegs": null,
	"Feet": null,
	"Hands": null
}

func _ready():
	# OPTIMIZACIÓN + FIX: Siempre crear skeleton, solo cachear el mesh
	# Esto arregla la animación que estaba rota
	var cache_path = "user://humanoid_cache.tres"
	var cached_mesh = null
	
	# Intentar cargar mesh cacheado
	var file = File.new()
	if file.file_exists(cache_path):
		cached_mesh = load(cache_path)
	
	# SIEMPRE crear el skeleton (necesario para animación)
	_setup_materials()
	_generate_rig()  # Crea el skeleton
	
	# DEBUG: Verificar que el skeleton se creó
	if skel_node:
		print("✅ Skeleton creado con", skel_node.get_bone_count(), "huesos")
	else:
		print("❌ ERROR: Skeleton NO se creó")
	
	if cached_mesh and cached_mesh is ArrayMesh:
		# Usar mesh cacheado (INSTANTÁNEO - ~5ms)
		mesh = cached_mesh
		print("ProceduralHumanoid: Mesh cargado desde caché")
	else:
		# Primera vez: Generar mesh completo
		print("ProceduralHumanoid: Generando mesh...")
		_generate_skinned_mesh()
		_apply_visual_test()
		
		# Guardar solo el mesh en caché
		if mesh:
			var result = ResourceSaver.save(cache_path, mesh)
			if result == OK:
				print("ProceduralHumanoid: Mesh guardado en caché")
	
	# CRÍTICO: Asignar skeleton path SIEMPRE (no solo al generar mesh)
	# Esto permite que la animación funcione incluso con mesh cacheado
	if skel_node:
		self.skeleton = get_path_to(skel_node)
		print("✅ Skeleton path asignado:", self.skeleton)

func _setup_materials():
	# Lista de partes que comparten material
	var part_groups = {
		"Head": ["Head"],
		"Neck": ["Neck"],
		"Hips": ["Hips"],
		"Abdomen": ["Spine", "Spine2"],
		"Hair": ["Head"],
		"Eyes": ["Head"],
		"Mouth": ["Head"],
		"Shoulders": ["ShoulderL", "ShoulderR"],
		"UpperArms": ["UpperArmL", "UpperArmR"],
		"LowerArms": ["LowerArmL", "LowerArmR"],
		"UpperLegs": ["UpperLegL", "UpperLegR"],
		"LowerLegs": ["LowerLegL", "LowerLegR"],
		"Feet": ["FootL", "FootR"],
		"Hands": ["HandL", "HandR"]
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
	skel_node.name = "HumanoidRig"
	add_child(skel_node)
	
	print("DEBUG: Skeleton creado y añadido como hijo de:", get_name())
	print("DEBUG: Ruta del skeleton:", skel_node.get_path())
	
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
		var hnd = "Hand"+side; _add_bone(hnd, bone_ids[la], Vector3(0, -0.22, 0)) # Pivote en la muñeca
	
	print("DEBUG: Total de huesos creados:", skel_node.get_bone_count())

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
			["Head", Vector3(0, 1.75, 0.02), Vector3(0.13, 0.19, 0.15)]
		],
		"Eyes": [
			["Head", Vector3(0.04, 1.8, 0.16), Vector3(0.015, 0.015, 0.01)], # Ojo R
			["Head", Vector3(-0.04, 1.8, 0.16), Vector3(0.015, 0.015, 0.01)] # Ojo L
		],
		"Mouth": [
			["Head", Vector3(0, 1.7, 0.16), Vector3(0.03, 0.01, 0.01)]
		],
		"Hair": [
			["Head", Vector3(0, 1.82, -0.02), Vector3(0.15, 0.18, 0.16)]
		],
		"Neck": [
			["Neck", Vector3(0, 1.55, 0), Vector3(0.06, 0.25, 0.06)]
		],
		"Shoulders": [],
		"UpperArms": [],
		"LowerArms": [],
		"UpperLegs": [],
		"LowerLegs": [],
		"Feet": [],
		"Hands": []
	}
	
	for side in ["L", "R"]:
		var sm = 1.0 if side == "R" else -1.0
		groups["Shoulders"].append(["Shoulder"+side, Vector3(0.21*sm, 1.4, 0), Vector3(0.09, 0.09, 0.09)])
		groups["UpperArms"].append(["UpperArm"+side, Vector3(0.24*sm, 1.23, 0), Vector3(0.08, 0.2, 0.08)])
		groups["LowerArms"].append(["LowerArm"+side, Vector3(0.26*sm, 1.05, 0), Vector3(0.07, 0.2, 0.07)])
		groups["Hands"].append(["Hand"+side, Vector3(0.28*sm, 0.85, 0), Vector3(0.04, 0.07, 0.035)])
		
		groups["UpperLegs"].append(["UpperLeg"+side, Vector3(0.11*sm, 0.75, 0), Vector3(0.11, 0.2, 0.11)])
		groups["LowerLegs"].append(["LowerLeg"+side, Vector3(0.11*sm, 0.35, 0), Vector3(0.09, 0.3, 0.09)])
		
		# PIE (Base en tobillo z=0, extensión hacia adelante +Z)
		# Centro Y ajustado para que la base plana esté en Y=0 (size.y * 0.3)
		groups["Feet"].append(["Foot"+side, Vector3(0.11*sm, 0.036, 0.1), Vector3(0.09, 0.12, 0.18)])

	var sphere = SphereMesh.new()
	sphere.radial_segments = 24 # Reducido de 64 para performance
	sphere.rings = 16 # Reducido de 48 para performance
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
			var is_head = b_name.begins_with("Head")
			
			for i in range(p_verts.size()):
				var v_orig = p_verts[i] # La esfera unitaria (-1 a 1)
				var v = v_orig
				
				# 1. DEFORMACIÓN ANATÓMICA (CABEZA HUMANA)
				if is_head:
					# Estrechar la mandíbula (Y bajo) y ensanchar sutilmente la parte superior
					var taper = 1.0
					if v_orig.y < 0:
						taper = lerp(0.65, 1.0, (v_orig.y + 1.0) / 1.0)
					else:
						taper = lerp(1.0, 0.9, v_orig.y) # Ensanchar/estabilizar cráneo
					
					v.x *= taper
					v.z *= (taper * 1.1) if v_orig.z > 0 else taper # Un poco más de volumen facial
				
				# 2. ESCALADO
				v.x *= size.x; v.y *= size.y; v.z *= size.z
				
				# 3. CÁLCULO DE NORMAL DE ELIPSOIDE CORRECTA
				# La normal de un elipsoide (x/a)^2 + (y/b)^2 + (z/c)^2 = 1 es (x/a^2, y/b^2, z/c^2)
				var n = Vector3(v_orig.x / size.x, v_orig.y / size.y, v_orig.z / size.z).normalized()
				
				# 4. NORMAL BENDING (DOBLADO DE NORMALES EN LOS POLOS)
				# Esto suaviza la iluminación en las juntas donde las piezas se cortan o intersecan
				var pole_factor = abs(v_orig.y) # 0 en ecuador, 1 en polos
				if pole_factor > 0.7:
					var blend = (pole_factor - 0.7) / 0.3
					var target_n = Vector3(0, 1.0 if v_orig.y > 0 else -1.0, 0)
					n = n.linear_interpolate(target_n, blend * 0.8).normalized()
				
				# 5. APLANAR LA SUELA (SOLO PIES)
				if is_foot and v.y < -size.y * 0.3:
					v.y = -size.y * 0.3
					n = Vector3(0, -1, 0)
				
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

func _apply_visual_test():
	print("ProceduralHumanoid V9: Multi-material listo.")
