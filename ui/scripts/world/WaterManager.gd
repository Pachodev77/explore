# =============================================================================
# WaterManager.gd - GESTIÓN DEL AGUA
# =============================================================================
# Maneja el plano de agua infinito que sigue al jugador.
# =============================================================================

extends Reference
class_name WaterManager

var _water_mesh: MeshInstance = null
var _world_node: Node = null

# =============================================================================
# INICIALIZACIÓN
# =============================================================================

func init(world_node: Node, tile_size: float) -> void:
	_world_node = world_node
	_create_water_plane(tile_size)

func _create_water_plane(tile_size: float) -> void:
	"""Crea el plano de agua infinito."""
	_water_mesh = MeshInstance.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(tile_size * 8, tile_size * 8)
	plane.subdivide_depth = 15
	plane.subdivide_width = 15
	
	_water_mesh.mesh = plane
	_water_mesh.name = "WaterPlane"
	_world_node.add_child(_water_mesh)
	
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://ui/shaders/water.shader")
	_water_mesh.set_surface_material(0, mat)
	_water_mesh.translation.y = GameConfig.WATER_LEVEL

# =============================================================================
# ACTUALIZACIÓN
# =============================================================================

func update_position(player_pos: Vector3) -> void:
	"""Actualiza la posición del agua para seguir al jugador."""
	if _water_mesh:
		_water_mesh.translation.x = player_pos.x
		_water_mesh.translation.z = player_pos.z
