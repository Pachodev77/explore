# =============================================================================
# LivestockFairBuilder.gd - CONSTRUCTOR DE LA FERIA GANADERA
# =============================================================================

extends Reference
class_name LivestockFairBuilder

static func build(container: Node, shared_res: Dictionary) -> void:
	var wood_mat = BuilderUtils.get_wood_mat(shared_res)
	
	_build_arena(container)
	_build_arena_fence(container, wood_mat)
	_build_bleachers(container, wood_mat)
	_build_corrals(container, wood_mat)

static func _build_arena(container: Node) -> void:
	var arena = MeshInstance.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 16.0
	cyl.bottom_radius = 16.0
	cyl.height = 0.15
	arena.mesh = cyl
	arena.translation = Vector3(0, 2.05, 0)
	arena.material_override = BuilderUtils.create_material(Color(0.65, 0.55, 0.4))
	container.add_child(arena)

static func _build_arena_fence(container: Node, wood_mat: Material) -> void:
	for i in range(24):
		var angle = i * (TAU / 24.0)
		var pos = Vector3(cos(angle), 0, sin(angle)) * 16.5
		
		var post = BuilderUtils.create_cube_mesh(Vector3(0.4, 2.4, 0.4), wood_mat)
		post.translation = pos + Vector3(0, 3.2, 0)
		container.add_child(post)
		
		var next_angle = (i + 1) * (TAU / 24.0)
		var next_pos = Vector3(cos(next_angle), 0, sin(next_angle)) * 16.5
		var mid = (pos + next_pos) * 0.5
		
		for h in [3.0, 3.8]:
			var board = BuilderUtils.create_cube_mesh(Vector3(0.1, 0.25, 4.5), wood_mat)
			board.translation = mid + Vector3(0, h, 0)
			var diff = next_pos - pos
			board.rotation.y = atan2(diff.x, diff.z)
			container.add_child(board)

static func _build_bleachers(container: Node, wood_mat: Material) -> void:
	for side in [-1, 1]:
		_build_single_bleacher(container, Vector3(0, 2.0, side * 26.0), side == 1, wood_mat)

static func _build_single_bleacher(container: Node, pos: Vector3, face_north: bool, mat: Material) -> void:
	var node = Spatial.new()
	node.translation = pos
	if not face_north:
		node.rotation_degrees.y = 180
	container.add_child(node)
	
	for row in range(4):
		var row_h = row * 1.2 + 0.6
		var row_z = row * 1.8
		
		var floor_mesh = BuilderUtils.create_cube_mesh(Vector3(25, 0.25, 1.8), mat)
		floor_mesh.translation = Vector3(0, row_h, row_z)
		node.add_child(floor_mesh)
		
		var bench = BuilderUtils.create_cube_mesh(Vector3(25, 0.15, 0.5), mat)
		bench.translation = Vector3(0, row_h + 0.45, row_z - 0.4)
		node.add_child(bench)
	
	var roof = BuilderUtils.create_cube_mesh(Vector3(28, 0.3, 10.0), mat)
	roof.translation = Vector3(0, 8.5, 3.0)
	roof.rotation_degrees.x = -12
	node.add_child(roof)
	
	for x in [-12.5, 12.5]:
		for z in [-1, 8]:
			var col = BuilderUtils.create_cube_mesh(Vector3(0.4, 8.5, 0.4), mat)
			col.translation = Vector3(x, 4.25, z)
			node.add_child(col)

static func _build_corrals(container: Node, wood_mat: Material) -> void:
	for x_side in [-1, 1]:
		for z_side in [-1, 1]:
			_build_covered_corral(container, Vector3(x_side * 28, 2.0, z_side * 18), wood_mat)

static func _build_covered_corral(container: Node, pos: Vector3, mat: Material) -> void:
	var corral = Spatial.new()
	corral.translation = pos
	container.add_child(corral)
	
	var size = 8.0
	for i in range(4):
		var angle = i * PI / 2.0
		var side_pos = Vector3(cos(angle), 0, sin(angle)) * (size / 2.0)
		var wall = MeshInstance.new()
		wall.mesh = CubeMesh.new()
		if i % 2 == 0:
			wall.mesh.size = Vector3(0.15, 1.6, size)
		else:
			wall.mesh.size = Vector3(size, 1.6, 0.15)
		wall.translation = side_pos + Vector3(0, 0.8, 0)
		wall.material_override = mat
		corral.add_child(wall)
	
	var roof = BuilderUtils.create_cube_mesh(Vector3(size + 1, 0.2, size + 1), mat)
	roof.translation = Vector3(0, 4.5, 0)
	roof.rotation_degrees.x = 5
	corral.add_child(roof)
	
	for ox in [-1, 1]:
		for oz in [-1, 1]:
			var c = BuilderUtils.create_cube_mesh(Vector3(0.2, 4.5, 0.2), mat)
			c.translation = Vector3(ox * 3.5, 2.25, oz * 3.5)
			corral.add_child(c)
