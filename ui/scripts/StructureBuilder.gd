# =============================================================================
# StructureBuilder.gd - FACHADA PRINCIPAL DE CONSTRUCCIÓN
# =============================================================================
# Este script actúa como punto de entrada único para la construcción de 
# estructuras. Delega el trabajo a los módulos especializados en la carpeta
# 'structures/'.
#
# ARQUITECTURA MODULAR:
# - BuilderUtils.gd      → Utilidades comunes (materiales, colisiones, meshes)
# - FenceBuilder.gd      → Cercas perimetrales y puertas
# - FarmhouseBuilder.gd  → Casa principal de la granja
# - StableBuilder.gd     → Establo para caballos/ganado
# - ChickenCoopBuilder.gd → Gallinero con corral
# - MarketBuilder.gd     → Mercado y edificios comerciales
# - LivestockFairBuilder.gd → Feria ganadera
# - MineBuilder.gd       → Mina con rieles y andamios
# =============================================================================

extends Node
class_name StructureBuilder

# =============================================================================
# API PÚBLICA - COMPATIBILIDAD HACIA ATRÁS
# =============================================================================
# Estas funciones estáticas mantienen la compatibilidad con el código existente
# que usa StructureBuilder.add_X()

# --- UTILIDADES ---

static func add_col_box(parent: Node, pos: Vector3, size: Vector3) -> void:
	BuilderUtils.add_collision_box(parent, pos, size)

# --- CERCAS ---

static func add_fence(container: Node, shared_res: Dictionary, perimeter_y: float = 2.0) -> void:
	FenceBuilder.build_perimeter_fence(container, shared_res, perimeter_y)

static func add_gate(container: Node, pos: Vector3, rot_deg: float, shared_res: Dictionary) -> void:
	FenceBuilder.build_gate(container, pos, rot_deg, shared_res)

static func add_fence_collisions(container: Node, perimeter_y: float = 2.0) -> void:
	# Ahora integrado en build_perimeter_fence, pero mantenemos por compatibilidad
	pass

# --- EDIFICIOS DEL SPAWN ---

static func add_farmhouse(container: Node, shared_res: Dictionary) -> void:
	FarmhouseBuilder.build(container, shared_res)

static func add_stable(container: Node, shared_res: Dictionary) -> void:
	StableBuilder.build(container, shared_res)

static func add_chicken_coop(container: Node, shared_res: Dictionary) -> void:
	ChickenCoopBuilder.build(container, shared_res)

# --- ANTORCHAS (helper usado internamente) ---

static func add_torch(parent: Node, pos: Vector3, shared_res: Dictionary, side: float) -> void:
	# Delegado a FarmhouseBuilder que lo usa internamente
	# Si necesitas antorchas en otros lugares, usa esta función
	var torch_node = Spatial.new()
	torch_node.translation = pos + Vector3(0, 0, 0.15)
	torch_node.rotation_degrees.x = 45.0
	parent.add_child(torch_node)
	
	var wood_mat = BuilderUtils.get_wood_mat(shared_res)
	var stick = BuilderUtils.create_cube_mesh(Vector3(0.08, 0.4, 0.08), wood_mat)
	torch_node.add_child(stick)
	
	var ember = MeshInstance.new()
	var ember_mesh = SphereMesh.new()
	ember_mesh.radius = 0.08
	ember_mesh.height = 0.16
	ember.mesh = ember_mesh
	ember.material_override = BuilderUtils.create_emissive_material(
		Color(1.0, 0.4, 0.1), Color(1.0, 0.4, 0.0), 2.0
	)
	ember.translation.y = 0.25
	torch_node.add_child(ember)
	
	var light = OmniLight.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 0.0
	light.omni_range = 10.0
	light.omni_attenuation = 2.0
	light.add_to_group("house_lights")
	light.translation.y = 0.3
	torch_node.add_child(light)

static func add_house_collision(house_node: Node) -> void:
	# Ahora integrado en FarmhouseBuilder.build()
	pass

static func add_stable_collision(stable_node: Node) -> void:
	# Ahora integrado en StableBuilder.build()
	pass

# --- ASENTAMIENTOS REMOTOS ---

static func add_market_base(container: Node, shared_res: Dictionary) -> void:
	MarketBuilder.build(container, shared_res)

static func add_market_stall(container: Node, pos: Vector3, rot_deg: float, tent_color: Color, shared_res: Dictionary) -> void:
	# Delegado internamente por MarketBuilder
	MarketBuilder._build_stall(container, pos, rot_deg, tent_color, shared_res)

static func add_western_market_building(container: Node, pos: Vector3, rot_y: float, title: String, body_color: Color, shared_res: Dictionary) -> void:
	MarketBuilder._build_western_building(container, pos, rot_y, title, body_color, shared_res)

static func add_livestock_fair(container: Node, shared_res: Dictionary) -> void:
	LivestockFairBuilder.build(container, shared_res)

static func add_bleachers(container: Node, pos: Vector3, face_north: bool, mat: Material) -> void:
	LivestockFairBuilder._build_single_bleacher(container, pos, face_north, mat)

static func add_covered_corral(container: Node, pos: Vector3, mat: Material) -> void:
	LivestockFairBuilder._build_covered_corral(container, pos, mat)

static func add_mine_base(container: Node, shared_res: Dictionary) -> void:
	MineBuilder.build(container, shared_res)

static func add_mine_cart(container: Node, pos: Vector3, shared_res: Dictionary) -> void:
	MineBuilder._build_single_cart(container, pos, shared_res)

static func add_miner_cabin(container: Node, pos: Vector3, shared_res: Dictionary) -> void:
	MineBuilder._build_cabin(container, BuilderUtils.get_wood_mat(shared_res))
