# =============================================================================
# MineBuilder.gd - CONSTRUCTOR DE LA MINA
# =============================================================================

extends Reference
class_name MineBuilder

static func build(container: Node, shared_res: Dictionary) -> void:
	var wood_mat = BuilderUtils.get_wood_mat(shared_res)
	
	_build_portal(container, wood_mat)
	_build_rails(container, wood_mat)
	_build_carts(container, shared_res)
	_build_scaffold(container, wood_mat)
	_build_cabin(container, wood_mat)

static func _build_portal(container: Node, wood_mat: Material) -> void:
	var portal = Spatial.new()
	portal.translation = Vector3(0, 2.0, -25)
	container.add_child(portal)
	
	for x in [-4, 4]:
		var post = BuilderUtils.create_cube_mesh(Vector3(1.2, 8.0, 1.2), wood_mat)
		post.translation = Vector3(x, 4.0, 0)
		portal.add_child(post)
	
	var beam = BuilderUtils.create_cube_mesh(Vector3(10.0, 1.2, 1.5), wood_mat)
	beam.translation = Vector3(0, 8.0, 0)
	portal.add_child(beam)
	
	var dark = MeshInstance.new()
	var q = QuadMesh.new()
	q.size = Vector2(8, 8)
	dark.mesh = q
	dark.translation = Vector3(0, 4, -0.1)
	dark.material_override = BuilderUtils.create_material(Color(0, 0, 0))
	portal.add_child(dark)

static func _build_rails(container: Node, wood_mat: Material) -> void:
	var rails = Spatial.new()
	rails.translation = Vector3(0, 2.1, -25)
	container.add_child(rails)
	
	var iron = BuilderUtils.create_material(Color(0.3, 0.3, 0.3), 0.8, 0.3)
	
	for i in range(15):
		var z_pos = i * 3.0
		
		var plank = BuilderUtils.create_cube_mesh(Vector3(2.5, 0.1, 0.4), wood_mat)
		plank.translation = Vector3(0, 0, z_pos)
		rails.add_child(plank)
		
		for side in [-0.8, 0.8]:
			var rail = BuilderUtils.create_cube_mesh(Vector3(0.1, 0.2, 3.1), iron)
			rail.translation = Vector3(side, 0.1, z_pos)
			rails.add_child(rail)

static func _build_carts(container: Node, shared_res: Dictionary) -> void:
	_build_single_cart(container, Vector3(0, 2.65, -5), shared_res)
	_build_single_cart(container, Vector3(0, 2.65, 12), shared_res)

static func _build_single_cart(container: Node, pos: Vector3, shared_res: Dictionary) -> void:
	var cart = Spatial.new()
	cart.translation = pos
	container.add_child(cart)
	
	var wood_mat = BuilderUtils.get_wood_mat(shared_res)
	var box = BuilderUtils.create_cube_mesh(Vector3(2.0, 1.2, 2.5), wood_mat)
	cart.add_child(box)
	
	var w_mat = BuilderUtils.create_material(Color(0.1, 0.1, 0.1))
	for ox in [-0.9, 0.9]:
		for oz in [-0.8, 0.8]:
			var wheel = MeshInstance.new()
			var c = CylinderMesh.new()
			c.top_radius = 0.3
			c.bottom_radius = 0.3
			c.height = 0.2
			wheel.mesh = c
			wheel.translation = Vector3(ox, -0.6, oz)
			wheel.rotation_degrees.z = 90
			wheel.material_override = w_mat
			cart.add_child(wheel)

static func _build_scaffold(container: Node, wood_mat: Material) -> void:
	var scaffold = Spatial.new()
	scaffold.translation = Vector3(15, 2.0, -15)
	container.add_child(scaffold)
	
	for h in range(3):
		var level = BuilderUtils.create_cube_mesh(Vector3(6, 0.3, 6), wood_mat)
		level.translation = Vector3(0, h * 4.0, 0)
		scaffold.add_child(level)
		
		for ox in [-2.5, 2.5]:
			for oz in [-2.5, 2.5]:
				var col = BuilderUtils.create_cube_mesh(Vector3(0.3, 4.0, 0.3), wood_mat)
				col.translation = Vector3(ox, h * 4.0 + 2.0, oz)
				scaffold.add_child(col)

static func _build_cabin(container: Node, wood_mat: Material) -> void:
	var cabin = Spatial.new()
	cabin.translation = Vector3(-18, 2.0, -10)
	container.add_child(cabin)
	
	var body = BuilderUtils.create_cube_mesh(Vector3(8, 5, 8), wood_mat)
	body.translation = Vector3(0, 2.5, 0)
	cabin.add_child(body)
	
	var roof = BuilderUtils.create_prism_mesh(Vector3(9, 3, 9), wood_mat)
	roof.translation = Vector3(0, 6.0, 0)
	cabin.add_child(roof)
