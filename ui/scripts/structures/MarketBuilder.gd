# =============================================================================
# MarketBuilder.gd - CONSTRUCTOR DEL MERCADO
# =============================================================================

extends Reference
class_name MarketBuilder

static func build(container: Node, shared_res: Dictionary) -> void:
	_build_western_building(container, Vector3(-18.0, 2.0, -30), 0, "GENERAL STORE", Color(0.4, 0.3, 0.2), shared_res)
	_build_western_building(container, Vector3(18.0, 2.0, -30), 0, "MEAT MARKET", Color(0.5, 0.2, 0.2), shared_res)
	_build_western_building(container, Vector3(0, 2.0, -30), 0, "MARKET HALL", Color(0.2, 0.3, 0.4), shared_res)
	
	var stall_configs = [
		{"pos": Vector3(-12, 2.0, -5), "rot": 45, "color": Color(0.9, 0.1, 0.1)},
		{"pos": Vector3(12, 2.0, -5), "rot": -45, "color": Color(0.1, 0.4, 0.9)},
		{"pos": Vector3(-15, 2.0, 12), "rot": 150, "color": Color(0.9, 0.8, 0.1)},
		{"pos": Vector3(15, 2.0, 12), "rot": 210, "color": Color(0.1, 0.8, 0.2)},
		{"pos": Vector3(0, 2.0, 28), "rot": 0, "color": Color(0.8, 0.5, 0.2)}
	]
	for cfg in stall_configs:
		_build_stall(container, cfg.pos, cfg.rot, cfg.color, shared_res)

static func _build_stall(container: Node, pos: Vector3, rot_deg: float, tent_color: Color, shared_res: Dictionary) -> void:
	var node = Spatial.new()
	node.translation = pos
	node.rotation_degrees.y = rot_deg
	container.add_child(node)
	
	var wood_mat = BuilderUtils.get_wood_mat(shared_res)
	var table = BuilderUtils.create_cube_mesh(Vector3(4.5, 0.2, 2.0), wood_mat)
	table.translation = Vector3(0, 1.0, 0)
	node.add_child(table)
	
	var tent = BuilderUtils.create_prism_mesh(Vector3(5.0, 1.5, 2.5))
	tent.translation = Vector3(0, 3.8, 0)
	tent.material_override = BuilderUtils.create_material(tent_color, 0.0, 0.9)
	node.add_child(tent)
	
	for ox in [-2.2, 2.2]:
		for oz in [-1.1, 1.1]:
			var post = BuilderUtils.create_cube_mesh(Vector3(0.15, 3.1, 0.15), wood_mat)
			post.translation = Vector3(ox, 1.55, oz)
			node.add_child(post)

static func _build_western_building(container: Node, pos: Vector3, rot_y: float, title: String, body_color: Color, shared_res: Dictionary) -> void:
	var building = Spatial.new()
	building.translation = pos
	building.rotation_degrees.y = rot_y
	container.add_child(building)
	
	var wood_mat = BuilderUtils.get_wood_mat(shared_res)
	var mat_body = BuilderUtils.create_material(body_color)
	var sign_mat = BuilderUtils.get_sign_mat(shared_res)
	
	var body = BuilderUtils.create_cube_mesh(Vector3(12, 12, 10), mat_body)
	body.translation = Vector3(0, 6, -5)
	building.add_child(body)
	
	var facade = BuilderUtils.create_cube_mesh(Vector3(14, 16, 0.5), mat_body)
	facade.translation = Vector3(0, 8, 0)
	building.add_child(facade)
	
	var sign_bg = BuilderUtils.create_cube_mesh(Vector3(10, 3, 0.2), sign_mat)
	sign_bg.translation = Vector3(0, 14, 0.4)
	building.add_child(sign_bg)
	
	var p_floor = BuilderUtils.create_cube_mesh(Vector3(14, 0.3, 5), wood_mat)
	p_floor.translation = Vector3(0, 0.15, 2.5)
	building.add_child(p_floor)
	
	var p_roof = BuilderUtils.create_cube_mesh(Vector3(14, 0.2, 5.2), wood_mat)
	p_roof.translation = Vector3(0, 5, 2.6)
	p_roof.rotation_degrees.x = 8
	building.add_child(p_roof)
	
	for x in [-6.5, 0, 6.5]:
		var col = BuilderUtils.create_cube_mesh(Vector3(0.4, 5, 0.4), wood_mat)
		col.translation = Vector3(x, 2.5, 4.8)
		building.add_child(col)
	
	var door = BuilderUtils.create_cube_mesh(Vector3(2.5, 4, 0.2), wood_mat)
	door.translation = Vector3(0, 2.1, 0.1)
	building.add_child(door)
	
	var sb = StaticBody.new()
	var cs = CollisionShape.new()
	var shape = BoxShape.new()
	shape.extents = Vector3(7, 8, 8)
	cs.shape = shape
	cs.translation = Vector3(0, 8, -4)
	sb.add_child(cs)
	building.add_child(sb)
