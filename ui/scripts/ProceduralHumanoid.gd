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
	# FORZAR REGENERACIÓN: Borrar cachés viejos para asegurar que el cambio se vea
	var dir = Directory.new()
	if dir.open("user://") == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.begins_with("humanoid_cache_"):
				dir.remove(file_name)
			file_name = dir.get_next()
	
	var cache_path = "user://humanoid_cache_final_v7.tres"
	var cached_mesh = null
	
	_setup_materials()
	_generate_rig()
	
	if cached_mesh and cached_mesh is ArrayMesh:
		mesh = cached_mesh
	else:
		_generate_skinned_mesh()
		_apply_visual_test()
		
		if mesh:
			ResourceSaver.save(cache_path, mesh)
	
	# CRÍTICO: Asignar skeleton path SIEMPRE (no solo al generar mesh)
	# Esto permite que la animación funcione incluso con mesh cacheado
	if skel_node:
		self.skeleton = get_path_to(skel_node)
	
	# CORRECCIÓN DE VISIBILIDAD: El modo anterior lo hacía invisible.
	# Ahora es visible y, gracias al shader 'unshaded', no tiene manchas.
	self.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_ON

func _setup_materials():
	# Lista de partes que comparten material
	var part_groups = {
		"Head": ["Head"],
		"Neck": ["Neck"],
		"Hips": ["Hips"],
		"Abdomen": ["Spine", "Spine2"],
		"Hair": ["Head"],
		"Nose": ["Head"],
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
		var tex_path = "res://assets/textures/player/" + group_name.to_lower() + ".png"
		var tex = null
		
		if ResourceLoader.exists(tex_path):
			tex = load(tex_path)
		
		# FALLBACKS PARA TEXTURAS FALTANTES (Nose, Hands, etc)
		if not tex:
			if group_name == "Nose" or group_name == "Hands":
				# Usar la de la cabeza o abdomen si no hay específica
				var fallback_paths = [
					"res://assets/textures/player/head.png",
					"res://assets/textures/player/abdomen.png"
				]
				for p in fallback_paths:
					if ResourceLoader.exists(p):
						tex = load(p)
						break
		
		# Si falla todo, placeholder blanco
		if not tex: 
			tex = _create_white_placeholder()

		# Forzar el uso del ShaderMaterial en todas las plataformas para un look sólido y limpio
		var mat = ShaderMaterial.new()
		mat.shader = load("res://ui/shaders/realistic_skin.shader")
		mat.set_shader_param("skin_color", Color(1, 1, 1))
		mat.set_shader_param("albedo_texture", tex)
		body_materials[group_name] = mat

var _dnc_ref = null
var _update_timer = 0.0

func _process(delta):
	# OPTIMIZACIÓN: Solo actualizar color cada 0.2 segundos para ahorrar batería
	_update_timer += delta
	if _update_timer < 0.2: return
	_update_timer = 0.0
	
	if not _dnc_ref:
		_dnc_ref = get_tree().root.find_node("DayNightCycle", true, false)
	
	if _dnc_ref:
		# Obtener el color de la luz del sol/ambiente actual
		var sun_node = _dnc_ref.sun
		if sun_node:
			# Calculamos un factor de brillo basado en la energía del sol
			# day_phase es 0 en noche, 1 en día
			var energy = sun_node.light_energy
			var base_brightness = clamp(energy * 1.5, 0.2, 1.0)
			
			# Sincronizar con el color del sol pero permitir visibilidad nocturna
			var final_color = sun_node.light_color * base_brightness
			
			# Aplicar a TODOS los materiales del cuerpo
			for mat in body_materials.values():
				if mat is ShaderMaterial:
					mat.set_shader_param("sun_color", final_color)

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
	
	_add_bone("Hips", -1, Vector3(0, 0.95, 0))
	_add_bone("Spine", bone_ids["Hips"], Vector3(0, 0.15, 0))
	_add_bone("Spine2", bone_ids["Spine"], Vector3(0, 0.2, 0))
	_add_bone("Neck", bone_ids["Spine2"], Vector3(0, 0.2, 0))
	_add_bone("Head", bone_ids["Neck"], Vector3(0, 0.2, 0))
	
	for side in ["L", "R"]:
		var sm = 1.0 if side == "R" else -1.0
		var s = "Shoulder"+side; _add_bone(s, bone_ids["Spine2"], Vector3(0.18*sm, 0.1, 0))
		var ua = "UpperArm"+side; _add_bone(ua, bone_ids[s], Vector3(0.03*sm, -0.02, 0))
		var la = "LowerArm"+side; _add_bone(la, bone_ids[ua], Vector3(0, -0.2, 0))
		var ul = "UpperLeg"+side; _add_bone(ul, bone_ids["Hips"], Vector3(0.11*sm, -0.05, 0))
		var ll = "LowerLeg"+side; _add_bone(ll, bone_ids[ul], Vector3(0, -0.35, 0))
		var ft = "Foot"+side; _add_bone(ft, bone_ids[ll], Vector3(0, -0.5, 0)) # Pivote en el tobillo
		var hnd = "Hand"+side; _add_bone(hnd, bone_ids[la], Vector3(0, -0.22, 0)) # Pivote en la muñeca
	
	# CREAR ATTACHMENT PARA ACCESORIOS (Como la antorcha)
	hand_r_attachment = BoneAttachment.new()
	hand_r_attachment.bone_name = "HandR"
	hand_r_attachment.name = "HandRAttachment"
	skel_node.add_child(hand_r_attachment)

var hand_r_attachment = null

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
			["Spine", Vector3(0, 1.1, 0), Vector3(0.18, 0.18, 0.12)],
			["Spine2", Vector3(0, 1.3, 0), Vector3(0.22, 0.23, 0.18)]
		],
		"Head": [
			["Head", Vector3(0, 1.73, 0.02), Vector3(0.13, 0.19, 0.14)] # Reducido Z de 0.15 a 0.14
		],
		"Eyes": [
			["Head", Vector3(0.038, 1.73, 0.158), Vector3(0.016, 0.016, 0.012)], # Un poco más adentro
			["Head", Vector3(-0.038, 1.73, 0.158), Vector3(0.016, 0.016, 0.012)]
		],
		"Mouth": [
			["Head", Vector3(0, 1.66, 0.148), Vector3(0.045, 0.01, 0.012)] # Un poco más arriba (de 1.63 a 1.66)
		],
		"Hair": [
			["Head", Vector3(0, 1.81, -0.01), Vector3(0.135, 0.16, 0.155)]
		],
		"Nose": [
			["Head", Vector3(0, 1.7, 0.16), Vector3(0.015, 0.025, 0.02)] # Un poco más adentro
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
		groups["Shoulders"].append(["Shoulder"+side, Vector3(0.18*sm, 1.4, 0), Vector3(0.09, 0.09, 0.09)])
		groups["UpperArms"].append(["UpperArm"+side, Vector3(0.21*sm, 1.23, 0), Vector3(0.08, 0.2, 0.08)])
		groups["LowerArms"].append(["LowerArm"+side, Vector3(0.23*sm, 1.05, 0), Vector3(0.07, 0.2, 0.07)])
		groups["Hands"].append(["Hand"+side, Vector3(0.25*sm, 0.85, 0), Vector3(0.06, 0.09, 0.05)])
		
		groups["UpperLegs"].append(["UpperLeg"+side, Vector3(0.11*sm, 0.75, 0), Vector3(0.11, 0.2, 0.11)])
		groups["LowerLegs"].append(["LowerLeg"+side, Vector3(0.11*sm, 0.31, 0), Vector3(0.09, 0.3, 0.09)])
		
		# PIE (Base en tobillo z=0, extensión hacia adelante +Z)
		# Centro Y ajustado para que la base plana esté en Y=0 (size.y * 0.3)
		groups["Feet"].append(["Foot"+side, Vector3(0.11*sm, 0.036, 0.1), Vector3(0.09, 0.12, 0.18)])

	var sphere = SphereMesh.new()
	sphere.radial_segments = 32 # Suavizado para evitar faceteado
	sphere.rings = 24
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
			var p_uvs = sphere_arrays[Mesh.ARRAY_TEX_UV]
			var p_indices = sphere_arrays[Mesh.ARRAY_INDEX]
			
			var is_foot = b_name.begins_with("Foot")
			var is_head = b_name.begins_with("Head")
			var is_lower_leg = b_name.begins_with("LowerLeg")
			
			for i in range(p_verts.size()):
				var v_orig = p_verts[i]
				var v = v_orig
				
				# 1. DEFORMACIONES ANATÓMICAS
				if is_head:
					var taper = 1.0
					if v_orig.y < 0:
						taper = lerp(0.52, 1.0, (v_orig.y + 1.0) / 1.0)
					else:
						if v_orig.y > 0.6: v.y *= 0.7
						taper = lerp(1.0, 0.82, pow(v_orig.y, 2))
					v.x *= taper
					v.x *= (1.0 - abs(v_orig.x) * 0.05)
					if v_orig.z < 0:
						v.z *= 0.7
						v.x *= 1.02 
					else:
						v.z *= 1.02
				
				if b_name == "Spine" or b_name == "Spine2":
					if v_orig.z < 0: v.z *= 0.65
					elif b_name == "Spine2" and v_orig.z > 0: v.z *= 0.82
				elif b_name == "Hips":
					v.z *= 0.72
					v.x *= 0.85
				
				if is_lower_leg:
					var taper = 1.0
					if v_orig.y < 0:
						taper = lerp(0.3, 1.0, (v_orig.y + 1.0) / 1.0)
					else:
						taper = lerp(1.0, 1.15, v_orig.y)
					v.x *= taper
					v.x *= taper
				
				# 2. ESCALADO
				v.x *= size.x; v.y *= size.y; v.z *= size.z
				
				# 3. NORMAL DE ELIPSOIDE
				var n = Vector3(v_orig.x / (size.x*size.x), v_orig.y / (size.y*size.y), v_orig.z / (size.z*size.z)).normalized()
				
				# 4. NORMAL BENDING (MÁS FUERTE)
				# Esto hace que las piezas parezcan una sola pieza de goma al iluminarse
				var pole_factor = abs(v_orig.y)
				if pole_factor > 0.6:
					var blend = (pole_factor - 0.6) / 0.4
					var target_n = Vector3(0, 1.0 if v_orig.y > 0 else -1.0, 0)
					n = n.linear_interpolate(target_n, blend * 0.95).normalized()
				
				# 5. APLANAR LA SUELA
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
	pass
