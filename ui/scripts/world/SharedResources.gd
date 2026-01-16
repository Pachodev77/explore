# =============================================================================
# SharedResources.gd - RECURSOS COMPARTIDOS DEL MUNDO
# =============================================================================
# Gestiona la carga y cache de materiales, texturas y escenas compartidas.
# =============================================================================

extends Reference
class_name SharedResources

# Diccionario principal de recursos
var _resources: Dictionary = {}

# =============================================================================
# INICIALIZACIÓN
# =============================================================================

func _init():
	_resources = {
		"ground_mat": ShaderMaterial.new(),
		"tree_parts": [],
		"cactus_parts": [],
		"rock_mesh": SphereMesh.new(),
		"rock_mat": SpatialMaterial.new(),
		"bush_mesh": CubeMesh.new(),
		"bush_mat": SpatialMaterial.new(),
		"height_noise": null,
		"biome_noise": null,
		"H_SNOW": GameConfig.H_SNOW,
		"H_JUNGLE": GameConfig.H_JUNGLE,
		"H_DESERT": GameConfig.H_DESERT,
		"H_PRAIRIE": GameConfig.H_PRAIRIE,
		"wood_mat": null,
		"sign_mat": null,
		"cow_scene": null,
		"goat_scene": null,
		"chicken_scene": null
	}

func setup(height_noise: OpenSimplexNoise, biome_noise: OpenSimplexNoise) -> void:
	"""Configura todos los recursos compartidos."""
	_resources["height_noise"] = height_noise
	_resources["biome_noise"] = biome_noise
	
	_setup_ground_material()
	_setup_tree_meshes()
	_setup_cactus_meshes()
	_setup_wood_materials()
	_setup_animal_scenes()

# =============================================================================
# CONFIGURACIÓN DE RECURSOS
# =============================================================================

func _setup_ground_material() -> void:
	var shader = preload("res://ui/shaders/biome_blending.shader")
	_resources["ground_mat"].shader = shader
	
	var t_grass = preload("res://ui/textures/grass.jpg")
	var t_sand = preload("res://ui/textures/sand.jpg")
	var t_snow = preload("res://ui/textures/snow.jpg")
	var t_jungle = preload("res://ui/textures/jungle.jpg")
	var t_gravel = preload("res://ui/textures/gravel.jpg")
	
	_resources["ground_mat"].set_shader_param("grass_tex", t_grass)
	_resources["ground_mat"].set_shader_param("sand_tex", t_sand)
	_resources["ground_mat"].set_shader_param("snow_tex", t_snow)
	_resources["ground_mat"].set_shader_param("jungle_tex", t_jungle)
	_resources["ground_mat"].set_shader_param("gravel_tex", t_gravel)
	_resources["ground_mat"].set_shader_param("uv_scale", 0.04)
	_resources["ground_mat"].set_shader_param("triplanar_sharpness", 6.0)

func _setup_tree_meshes() -> void:
	var tree_scene = preload("res://ui/tree.glb")
	if tree_scene:
		var tree_inst = tree_scene.instance()
		_resources["tree_parts"] = _find_meshes_recursive(tree_inst)
		tree_inst.queue_free()

func _setup_cactus_meshes() -> void:
	var cactus_scene = preload("res://ui/cactus.glb")
	if cactus_scene:
		var cactus_inst = cactus_scene.instance()
		_resources["cactus_parts"] = _find_meshes_recursive(cactus_inst)
		cactus_inst.queue_free()
		
		# Desactivar emisión en materiales importados
		for part in _resources["cactus_parts"]:
			if part and part.has("mat") and part.mat and part.mat is SpatialMaterial:
				part.mat.emission_enabled = false
				part.mat.flags_unshaded = false

func _setup_wood_materials() -> void:
	var wood_mat = SpatialMaterial.new()
	wood_mat.albedo_color = Color(0.4, 0.25, 0.1)
	wood_mat.roughness = 0.9
	_resources["wood_mat"] = wood_mat
	
	var sign_mat = SpatialMaterial.new()
	sign_mat.albedo_color = Color(0.8, 0.7, 0.5)
	_resources["sign_mat"] = sign_mat

func _setup_animal_scenes() -> void:
	_resources["cow_scene"] = load("res://ui/scenes/Cow.tscn")
	_resources["goat_scene"] = load("res://ui/scenes/Goat.tscn")
	_resources["chicken_scene"] = load("res://ui/scenes/Chicken.tscn")

# =============================================================================
# UTILIDADES
# =============================================================================

func _find_meshes_recursive(node: Node, results: Array = []) -> Array:
	if node is MeshInstance:
		var mat = node.material_override
		if not mat:
			mat = node.get_surface_material(0)
		if not mat and node.mesh:
			mat = node.mesh.surface_get_material(0)
		results.append({"mesh": node.mesh, "mat": mat})
	
	for child in node.get_children():
		_find_meshes_recursive(child, results)
	return results

# =============================================================================
# ACCESO A RECURSOS
# =============================================================================

func get(key: String):
	return _resources.get(key)

func set_value(key: String, value) -> void:
	_resources[key] = value

func has(key: String) -> bool:
	return _resources.has(key)

func get_all() -> Dictionary:
	"""Retorna el diccionario completo para compatibilidad."""
	return _resources
