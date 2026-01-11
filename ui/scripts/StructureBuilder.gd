# =============================================================================
# StructureBuilder.gd - LIBRERIA DE CONSTRUCCION ARQUITECTONICA
# =============================================================================
# Este script contiene toda la logica de generacion de mallas para los edificios
# y estructuras del juego (Casa, Establo, Mercado, Mina, etc.).
# =============================================================================

extends Node
class_name StructureBuilder

# --- UTILES DE COLISION ---

static func add_col_box(parent: Node, pos: Vector3, size: Vector3):
	var sb = StaticBody.new()
	var cs = CollisionShape.new()
	var shape = BoxShape.new()
	shape.extents = size * 0.5
	cs.shape = shape
	sb.add_child(cs)
	sb.translation = pos
	parent.add_child(sb)

# --- FENCES & GATES ---

static func add_fence(container, shared_res, perimeter_y = 2.0):
	var wood_mat = shared_res.get("wood_mat")
	if not wood_mat:
		wood_mat = SpatialMaterial.new()
		wood_mat.albedo_color = Color(0.4, 0.25, 0.1)
	
	var post_mesh = CubeMesh.new()
	post_mesh.size = Vector3(0.4, 2.5, 0.4)
	
	var rail_mesh = CubeMesh.new()
	rail_mesh.size = Vector3(3.0, 0.3, 0.15)
	
	var posts = []
	var rails = []
	var half = 33.0 
	
	for x in range(-half, half + 1, 3):
		var t_n = Transform()
		t_n.origin = Vector3(x, perimeter_y + 0.5, -half)
		posts.append(t_n)
		var t_s = Transform()
		t_s.origin = Vector3(x, perimeter_y + 0.5, half)
		posts.append(t_s)
		
		if x < half:
			var tr_n = Transform()
			tr_n.origin = Vector3(x + 1.5, perimeter_y + 1.5, -half)
			rails.append(tr_n)
			var tr_n2 = Transform()
			tr_n2.origin = Vector3(x + 1.5, perimeter_y + 1.0, -half)
			rails.append(tr_n2)
			
			var tr_s = Transform()
			tr_s.origin = Vector3(x + 1.5, perimeter_y + 1.5, half)
			rails.append(tr_s)
			var tr_s2 = Transform()
			tr_s2.origin = Vector3(x + 1.5, perimeter_y + 1.0, half)
			rails.append(tr_s2)

	for z in range(-half, half + 1, 3):
		if abs(z) > 6.0:
			var t_w = Transform()
			t_w.origin = Vector3(-half, perimeter_y + 0.5, z)
			posts.append(t_w)
			var t_e = Transform()
			t_e.origin = Vector3(half, perimeter_y + 0.5, z)
			posts.append(t_e)
		
		if z < half:
			if z >= -6 and z < 6: continue
			var rot = Basis(Vector3.UP, deg2rad(90))
			var tr_w = Transform(rot, Vector3(-half, perimeter_y + 1.5, z + 1.5))
			rails.append(tr_w)
			var tr_w2 = Transform(rot, Vector3(-half, perimeter_y + 1.0, z + 1.5))
			rails.append(tr_w2)
			var tr_e = Transform(rot, Vector3(half, perimeter_y + 1.5, z + 1.5))
			rails.append(tr_e)
			var tr_e2 = Transform(rot, Vector3(half, perimeter_y + 1.0, z + 1.5))
			rails.append(tr_e2)
			
	var mmi_posts = MultiMeshInstance.new()
	var mm_posts = MultiMesh.new()
	mm_posts.transform_format = MultiMesh.TRANSFORM_3D
	mm_posts.mesh = post_mesh
	mm_posts.instance_count = posts.size()
	for i in range(posts.size()):
		mm_posts.set_instance_transform(i, posts[i])
	mmi_posts.multimesh = mm_posts
	mmi_posts.material_override = wood_mat
	mmi_posts.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	container.add_child(mmi_posts)
	
	var mmi_rails = MultiMeshInstance.new()
	var mm_rails = MultiMesh.new()
	mm_rails.transform_format = MultiMesh.TRANSFORM_3D
	mm_rails.mesh = rail_mesh
	mm_rails.instance_count = rails.size()
	for i in range(rails.size()):
		mm_rails.set_instance_transform(i, rails[i])
	mmi_rails.multimesh = mm_rails
	mmi_rails.material_override = wood_mat
	mmi_rails.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	container.add_child(mmi_rails)
	
	add_gate(container, Vector3(-half, perimeter_y, 0), 0.0, shared_res)
	add_gate(container, Vector3(half, perimeter_y, 0), 0.0, shared_res)
	add_fence_collisions(container, perimeter_y)

static func add_gate(container, pos, rot_deg, shared_res):
	var mat = shared_res.get("wood_mat")
	if not mat: mat = SpatialMaterial.new(); mat.albedo_color = Color(0.35, 0.2, 0.1)
	var sign_mat = shared_res.get("sign_mat")
	if not sign_mat: sign_mat = SpatialMaterial.new(); sign_mat.albedo_color = Color(0.8, 0.7, 0.5)
	
	var rot = Basis(Vector3.UP, deg2rad(rot_deg))
	var post_mesh = CubeMesh.new()
	post_mesh.size = Vector3(0.6, 7.0, 0.6)
	
	for offset_z in [-6.0, 6.0]:
		var p = MeshInstance.new()
		p.mesh = post_mesh
		p.material_override = mat
		p.translation = pos + rot.xform(Vector3(0, 3.5, offset_z))
		container.add_child(p)
		
	var beam = MeshInstance.new()
	beam.mesh = CubeMesh.new(); beam.mesh.size = Vector3(0.5, 0.6, 13.0)
	beam.material_override = mat
	beam.transform.basis = rot
	beam.translation = pos + Vector3(0, 6.5, 0)
	container.add_child(beam)
	
	var sign_board = MeshInstance.new()
	sign_board.mesh = CubeMesh.new(); sign_board.mesh.size = Vector3(0.3, 1.5, 4.0)
	sign_board.material_override = sign_mat
	sign_board.transform.basis = rot
	sign_board.translation = pos + Vector3(0, 5.5, 0)
	container.add_child(sign_board)

static func add_fence_collisions(container, perimeter_y = 2.0):
	var half = 33.0
	var height = 3.0
	var thickness = 1.0
	var y_center = perimeter_y + height/2.0
	
	add_col_box(container, Vector3(0, y_center, -half), Vector3(half*2, height, thickness))
	add_col_box(container, Vector3(0, y_center, half), Vector3(half*2, height, thickness))
	add_col_box(container, Vector3(-half, y_center, -19.5), Vector3(thickness, height, 27.0))
	add_col_box(container, Vector3(-half, y_center, 19.5), Vector3(thickness, height, 27.0))
	add_col_box(container, Vector3(half, y_center, -19.5), Vector3(thickness, height, 27.0))
	add_col_box(container, Vector3(half, y_center, 19.5), Vector3(thickness, height, 27.0))

# --- FARMHOUSE ---

static func add_farmhouse(container, shared_res):
	var house_node = Spatial.new()
	house_node.translation = Vector3(-18.0, 1.9, -18.0) 
	house_node.rotation_degrees.y = 45.0
	container.add_child(house_node)
	
	var mat_wall = SpatialMaterial.new(); mat_wall.albedo_color = Color(0.98, 0.98, 0.95); mat_wall.roughness = 0.85
	var mat_base = SpatialMaterial.new(); mat_base.albedo_color = Color(0.3, 0.3, 0.32); mat_base.roughness = 0.9
	var mat_roof = SpatialMaterial.new(); mat_roof.albedo_color = Color(0.45, 0.12, 0.12); mat_roof.roughness = 0.6
	var mat_wood_dark = shared_res.get("wood_mat")
	if not mat_wood_dark: mat_wood_dark = SpatialMaterial.new(); mat_wood_dark.albedo_color = Color(0.25, 0.15, 0.08)
	var mat_trim = SpatialMaterial.new(); mat_trim.albedo_color = Color(0.9, 0.9, 0.85)
	var mat_window = SpatialMaterial.new(); mat_window.albedo_color = Color(0.1, 0.15, 0.25); mat_window.metallic = 0.9; mat_window.roughness = 0.1
	var mat_shutter = SpatialMaterial.new(); mat_shutter.albedo_color = Color(0.15, 0.25, 0.15)
	
	var base = MeshInstance.new()
	base.mesh = CubeMesh.new(); base.mesh.size = Vector3(10.5, 0.8, 8.5); base.translation = Vector3(0, 0.4, 0)
	base.material_override = mat_base
	house_node.add_child(base)
	
	var body = MeshInstance.new()
	body.mesh = CubeMesh.new(); body.mesh.size = Vector3(10, 6.6, 8); body.translation = Vector3(0, 4.0, 0)
	body.material_override = mat_wall
	house_node.add_child(body)
	
	for x in [-5.05, 5.05]:
		for z in [-4.05, 4.05]:
			var trim = MeshInstance.new()
			trim.mesh = CubeMesh.new(); trim.mesh.size = Vector3(0.4, 6.5, 0.4); trim.translation = Vector3(x, 4.0, z)
			trim.material_override = mat_trim
			house_node.add_child(trim)
			
	var roof = MeshInstance.new()
	var prism = PrismMesh.new(); prism.size = Vector3(11.5, 3.5, 9)
	roof.mesh = prism; roof.translation = Vector3(0, 8.95, 0); roof.material_override = mat_roof
	house_node.add_child(roof)
	
	var fascia_f = MeshInstance.new()
	fascia_f.mesh = CubeMesh.new(); fascia_f.mesh.size = Vector3(11.6, 0.2, 0.2); fascia_f.translation = Vector3(0, 7.3, 4.4); fascia_f.material_override = mat_trim
	house_node.add_child(fascia_f)
	
	var porch_deck = MeshInstance.new()
	porch_deck.mesh = CubeMesh.new(); porch_deck.mesh.size = Vector3(10, 0.3, 3.5); porch_deck.translation = Vector3(0, 0.7, 5.75); porch_deck.material_override = mat_wood_dark
	house_node.add_child(porch_deck)
	
	for i in range(2):
		var step = MeshInstance.new()
		step.mesh = CubeMesh.new(); step.mesh.size = Vector3(3, 0.2, 0.4); step.translation = Vector3(0, 0.5 - (i*0.25), 7.7 + (i*0.4)); step.material_override = mat_wood_dark
		house_node.add_child(step)
		
	var p_roof = MeshInstance.new()
	p_roof.mesh = CubeMesh.new(); p_roof.mesh.size = Vector3(11, 0.2, 4); p_roof.translation = Vector3(0, 4.1, 5.8); p_roof.rotation_degrees.x = 12; p_roof.material_override = mat_roof
	house_node.add_child(p_roof)
	
	for x in [-4.5, 4.5]:
		var col = MeshInstance.new()
		col.mesh = CubeMesh.new(); col.mesh.size = Vector3(0.3, 3.2, 0.3); col.translation = Vector3(x, 2.15, 7.3); col.material_override = mat_trim
		house_node.add_child(col)
		
	for x_side in [-1, 1]:
		var rail = MeshInstance.new()
		rail.mesh = CubeMesh.new(); rail.mesh.size = Vector3(3.5, 0.1, 0.1); rail.translation = Vector3(x_side * 3.0, 1.8, 7.4); rail.material_override = mat_trim
		house_node.add_child(rail)
		for off in range(-15, 16, 5):
			var b = MeshInstance.new()
			b.mesh = CubeMesh.new(); b.mesh.size = Vector3(0.05, 1.0, 0.05); b.translation = Vector3(x_side * 3.0 + (off*0.1), 1.3, 7.4); b.material_override = mat_trim
			house_node.add_child(b)

	var door_frame = MeshInstance.new()
	door_frame.mesh = CubeMesh.new(); door_frame.mesh.size = Vector3(2.0, 3.5, 0.2); door_frame.translation = Vector3(0, 2.45, 4.01); door_frame.material_override = mat_trim
	house_node.add_child(door_frame)
	
	var door = MeshInstance.new()
	door.mesh = CubeMesh.new(); door.mesh.size = Vector3(1.6, 3.2, 0.1); door.translation = Vector3(0, 2.3, 4.05); door.material_override = mat_wood_dark
	house_node.add_child(door)
	
	var knob = MeshInstance.new()
	var sph = SphereMesh.new(); sph.radius = 0.08; sph.height = 0.16
	knob.mesh = sph; knob.translation = Vector3(0.5, 2.3, 4.15)
	var gold = SpatialMaterial.new(); gold.albedo_color = Color(0.8, 0.6, 0.2); gold.metallic = 1.0; gold.roughness = 0.2
	knob.material_override = gold
	house_node.add_child(knob)

	var win_configs = [
		{"pos": Vector3(-2.8, 5.8, 4.1), "rot": 0, "shutters": true, "w": 1.6, "h": 2.0},
		{"pos": Vector3(2.8, 5.8, 4.1), "rot": 0, "shutters": true, "w": 1.6, "h": 2.0},
		{"pos": Vector3(-5.1, 4.8, 0.0), "rot": 90, "shutters": true, "w": 1.6, "h": 2.0},
		{"pos": Vector3(5.1, 4.8, 0.0), "rot": -90, "shutters": true, "w": 1.6, "h": 2.0},
		{"pos": Vector3(0, 8.2, 4.6), "rot": 0, "shutters": false, "w": 1.1, "h": 1.1, "round": true}
	]
	
	for cfg in win_configs:
		var w_node = Spatial.new(); w_node.translation = cfg.pos; w_node.rotation_degrees.y = cfg.rot
		house_node.add_child(w_node)
		var is_round = cfg.get("round", false); var ww = cfg.w; var wh = cfg.h
		var glass = MeshInstance.new()
		if is_round:
			var cyl = CylinderMesh.new(); cyl.top_radius = ww * 0.5; cyl.bottom_radius = ww * 0.5; cyl.height = 0.05
			glass.mesh = cyl; glass.rotation_degrees.x = 90
		else:
			glass.mesh = CubeMesh.new(); glass.mesh.size = Vector3(ww, wh, 0.05)
		glass.material_override = mat_window
		w_node.add_child(glass)
		
		var frame = MeshInstance.new()
		if is_round:
			var f_cyl = CylinderMesh.new(); f_cyl.top_radius = ww * 0.55; f_cyl.bottom_radius = ww * 0.55; f_cyl.height = 0.1
			frame.mesh = f_cyl; frame.rotation_degrees.x = 90; frame.translation.z = -0.04
		else:
			frame.mesh = CubeMesh.new(); frame.mesh.size = Vector3(ww + 0.2, wh + 0.2, 0.1); frame.translation.z = -0.04
		frame.material_override = mat_trim
		w_node.add_child(frame)
		
		var cross_h = MeshInstance.new(); cross_h.mesh = CubeMesh.new(); cross_h.mesh.size = Vector3(ww, 0.08, 0.1); cross_h.material_override = mat_trim
		w_node.add_child(cross_h)
		var cross_v = MeshInstance.new(); cross_v.mesh = CubeMesh.new(); cross_v.mesh.size = Vector3(0.08, wh, 0.1); cross_v.material_override = mat_trim
		w_node.add_child(cross_v)
		if cfg.shutters:
			for side in [-1, 1]:
				var shutter = MeshInstance.new(); shutter.mesh = CubeMesh.new(); shutter.mesh.size = Vector3(0.8, wh, 0.05); shutter.translation = Vector3(side * (ww*0.5 + 0.5), 0, 0); shutter.material_override = mat_shutter
				w_node.add_child(shutter)

	var chimney = MeshInstance.new(); chimney.mesh = CubeMesh.new(); chimney.mesh.size = Vector3(1.4, 6, 1.4); chimney.translation = Vector3(3.5, 9, -2); chimney.material_override = mat_base
	house_node.add_child(chimney)
	var chim_top = MeshInstance.new(); chim_top.mesh = CubeMesh.new(); chim_top.mesh.size = Vector3(1.6, 0.3, 1.6); chim_top.translation = Vector3(3.5, 12, -2); chim_top.material_override = mat_trim
	house_node.add_child(chim_top)

	for tx in [-4.5, 4.5]:
		var side = 1.0 if tx > 0 else -1.0
		add_torch(house_node, Vector3(tx, 2.5, 7.45), shared_res, side)
	add_house_collision(house_node)

static func add_house_collision(house_node):
	var sb = StaticBody.new(); house_node.add_child(sb)
	var cs_body = CollisionShape.new(); var shape_body = BoxShape.new(); shape_body.extents = Vector3(5, 4, 4)
	cs_body.shape = shape_body; cs_body.translation = Vector3(0, 4, 0); sb.add_child(cs_body)
	var cs_porch = CollisionShape.new(); var shape_porch = BoxShape.new(); shape_porch.extents = Vector3(5, 0.4, 1.75)
	cs_porch.shape = shape_porch; cs_porch.translation = Vector3(0, 0.7, 5.75); sb.add_child(cs_porch)
	var cs_roof = CollisionShape.new(); var shape_roof = BoxShape.new(); shape_roof.extents = Vector3(5.5, 1.5, 4.5)
	cs_roof.shape = shape_roof; cs_roof.translation = Vector3(0, 8.5, 0); sb.add_child(cs_roof)

static func add_torch(parent, pos, shared_res, side):
	var torch_node = Spatial.new(); torch_node.translation = pos + Vector3(0, 0, 0.15); torch_node.rotation_degrees.x = 45.0; parent.add_child(torch_node)
	var stick = MeshInstance.new(); var stick_mesh = CubeMesh.new(); stick_mesh.size = Vector3(0.08, 0.4, 0.08); stick.mesh = stick_mesh
	var wood_mat = shared_res.get("wood_mat"); if wood_mat: stick.material_override = wood_mat
	torch_node.add_child(stick)
	var ember = MeshInstance.new(); var ember_mesh = SphereMesh.new(); ember_mesh.radius = 0.08; ember_mesh.height = 0.16; ember.mesh = ember_mesh
	var fire_mat = SpatialMaterial.new(); fire_mat.albedo_color = Color(1.0, 0.4, 0.1); fire_mat.emission_enabled = true; fire_mat.emission = Color(1.0, 0.4, 0.0); fire_mat.emission_energy = 2.0; ember.material_override = fire_mat; ember.translation.y = 0.25; torch_node.add_child(ember)
	var light = OmniLight.new(); light.light_color = Color(1.0, 0.6, 0.2); light.light_energy = 0.0; light.omni_range = 10.0; light.omni_attenuation = 2.0; light.add_to_group("house_lights"); light.translation.y = 0.3; torch_node.add_child(light)

# --- STABLE ---

static func add_stable(container, shared_res):
	var stable_node = Spatial.new(); stable_node.translation = Vector3(18.0, 2.0, 18.0); stable_node.rotation_degrees.y = 225.0; container.add_child(stable_node)
	var mat_wood = shared_res.get("wood_mat"); var mat_roof = SpatialMaterial.new(); mat_roof.albedo_color = Color(0.35, 0.2, 0.15); mat_roof.roughness = 0.8
	var post_mesh = CubeMesh.new(); post_mesh.size = Vector3(0.5, 5, 0.5)
	var posts_pos = [Vector3(-5, 2.5, -4), Vector3(5, 2.5, -4), Vector3(-5, 2.5, 4), Vector3(5, 2.5, 4), Vector3(0, 2.5, -4)]
	for p_pos in posts_pos:
		var p = MeshInstance.new(); p.mesh = post_mesh; p.translation = p_pos; p.material_override = mat_wood; stable_node.add_child(p)
	var roof = MeshInstance.new(); var prism = PrismMesh.new(); prism.size = Vector3(12, 3, 10); roof.mesh = prism; roof.translation = Vector3(0, 6.5, 0); roof.material_override = mat_roof; stable_node.add_child(roof)
	var rails_configs = [
		{"pos": Vector3(-5, 0.8, 0), "rot": 90, "size": Vector3(8, 0.2, 0.2)},
		{"pos": Vector3(-5, 1.8, 0), "rot": 90, "size": Vector3(8, 0.2, 0.2)},
		{"pos": Vector3(0, 0.8, -4), "rot": 0, "size": Vector3(10, 0.2, 0.2)},
		{"pos": Vector3(0, 1.8, -4), "rot": 0, "size": Vector3(10, 0.2, 0.2)},
		{"pos": Vector3(5, 0.8, 0), "rot": 90, "size": Vector3(8, 0.2, 0.2)},
		{"pos": Vector3(5, 1.8, 0), "rot": 90, "size": Vector3(8, 0.2, 0.2)}
	]
	for r_cfg in rails_configs:
		var r = MeshInstance.new(); r.mesh = CubeMesh.new(); r.mesh.size = r_cfg.size; r.translation = r_cfg.pos; r.rotation_degrees.y = r_cfg.rot; r.material_override = mat_wood; stable_node.add_child(r)
	var mat_trough = SpatialMaterial.new(); mat_trough.albedo_color = Color(0.2, 0.15, 0.1); var mat_hay = SpatialMaterial.new(); mat_hay.albedo_color = Color(0.8, 0.7, 0.2)
	for side in [-1, 1]:
		var trough = MeshInstance.new(); trough.mesh = CubeMesh.new(); trough.mesh.size = Vector3(3.5, 0.8, 1.2); trough.translation = Vector3(side * 2.2, 0.4, -3.2); trough.material_override = mat_trough; stable_node.add_child(trough)
		var hay = MeshInstance.new(); hay.mesh = CubeMesh.new(); hay.mesh.size = Vector3(3.3, 0.2, 1.0); hay.translation = Vector3(side * 2.2, 0.85, -3.2); hay.material_override = mat_hay; stable_node.add_child(hay)
	var divider = MeshInstance.new(); divider.mesh = CubeMesh.new(); divider.mesh.size = Vector3(0.5, 1.2, 1.4); divider.translation = Vector3(0, 0.6, -3.2); divider.material_override = mat_wood; stable_node.add_child(divider)
	add_stable_collision(stable_node)

static func add_stable_collision(stable_node):
	var sb = StaticBody.new(); stable_node.add_child(sb)
	var col_configs = [{"pos": Vector3(-5, 1.5, 0), "size": Vector3(0.5, 3.0, 8)}, {"pos": Vector3(5, 1.5, 0), "size": Vector3(0.5, 3.0, 8)}, {"pos": Vector3(0, 1.5, -4), "size": Vector3(10, 3.0, 0.5)}]
	for c in col_configs:
		var cs = CollisionShape.new(); var shape = BoxShape.new(); shape.extents = c.size * 0.5; cs.shape = shape; cs.translation = c.pos; sb.add_child(cs)
	for side in [-1, 1]:
		var cs_t = CollisionShape.new(); var shape_t = BoxShape.new(); shape_t.extents = Vector3(1.75, 0.4, 0.6); cs_t.shape = shape_t; cs_t.translation = Vector3(side * 2.2, 0.4, -3.2); sb.add_child(cs_t)
	var cs_div = CollisionShape.new(); var shape_div = BoxShape.new(); shape_div.extents = Vector3(0.25, 0.6, 0.7); cs_div.shape = shape_div; cs_div.translation = Vector3(0, 0.6, -3.2); sb.add_child(cs_div)

# --- CHICKEN COOP ---

static func add_chicken_coop(container, shared_res):
	var coop_node = Spatial.new(); coop_node.translation = Vector3(-18.0, 2.0, 18.0); coop_node.rotation_degrees.y = 135.0; container.add_child(coop_node)
	var mat_wood = shared_res.get("wood_mat"); var mat_wood_light = SpatialMaterial.new(); mat_wood_light.albedo_color = Color(0.6, 0.45, 0.3); var mat_roof = SpatialMaterial.new(); mat_roof.albedo_color = Color(0.5, 0.2, 0.1); var mat_wire = SpatialMaterial.new(); mat_wire.albedo_color = Color(0.4, 0.4, 0.45); mat_wire.metallic = 0.8; mat_wire.roughness = 0.2
	var post_mesh = CubeMesh.new(); post_mesh.size = Vector3(0.2, 1.5, 0.2)
	for px in [-1.4, 1.4]:
		for pz in [-1.2, 1.2]:
			var post = MeshInstance.new(); post.mesh = post_mesh; post.translation = Vector3(px, 0.75, pz); post.material_override = mat_wood; coop_node.add_child(post)
	var house_body = MeshInstance.new(); house_body.mesh = CubeMesh.new(); house_body.mesh.size = Vector3(3.0, 2.0, 2.5); house_body.translation = Vector3(0, 2.5, 0); house_body.material_override = mat_wood_light; coop_node.add_child(house_body)
	var roof = MeshInstance.new(); var prism = PrismMesh.new(); prism.size = Vector3(3.5, 1.2, 3.0); roof.mesh = prism; roof.translation = Vector3(0, 4.1, 0); roof.material_override = mat_roof; coop_node.add_child(roof)
	for side in [-1, 1]:
		var nest = MeshInstance.new(); nest.mesh = CubeMesh.new(); nest.mesh.size = Vector3(0.8, 0.8, 1.8); nest.translation = Vector3(side * 1.8, 2.2, 0); nest.material_override = mat_wood; coop_node.add_child(nest)
		var n_roof = MeshInstance.new(); n_roof.mesh = CubeMesh.new(); n_roof.mesh.size = Vector3(1.0, 0.1, 2.0); n_roof.translation = Vector3(side * 1.9, 2.6, 0); n_roof.rotation_degrees.z = side * 20; n_roof.material_override = mat_roof; coop_node.add_child(n_roof)
	var ramp = MeshInstance.new(); ramp.mesh = CubeMesh.new(); ramp.mesh.size = Vector3(1.2, 0.1, 2.5); ramp.translation = Vector3(0, 0.75, 2.0); ramp.rotation_degrees.x = 35; ramp.material_override = mat_wood; coop_node.add_child(ramp)
	var run_structure = Spatial.new(); var run_size = 6.0; run_structure.translation = Vector3(0, 0, -1.25); coop_node.add_child(run_structure)
	var r_post_mesh = CubeMesh.new(); r_post_mesh.size = Vector3(0.15, 2.0, 0.15); var r_posts = [Vector3(-3.0, 1.0, -6.0), Vector3(3.0, 1.0, -6.0), Vector3(-3.0, 1.0, 0), Vector3(3.0, 1.0, 0)]
	for rp in r_posts:
		var p = MeshInstance.new(); p.mesh = r_post_mesh; p.translation = rp; p.material_override = mat_wood; run_structure.add_child(p)
	var wire_v = CubeMesh.new(); wire_v.size = Vector3(0.02, 2.0, 0.02)
	for x in range(-30, 31, 4):
		for lz in [0.0, -6.0]:
			var w = MeshInstance.new(); w.mesh = wire_v; w.translation = Vector3(x * 0.1, 1.0, lz); w.material_override = mat_wire; run_structure.add_child(w)
	for z in range(-60, 1, 4):
		for lx in [-3.0, 3.0]:
			var w = MeshInstance.new(); w.mesh = wire_v; w.translation = Vector3(lx, 1.0, z * 0.1); w.material_override = mat_wire; run_structure.add_child(w)
	var sb = StaticBody.new(); coop_node.add_child(sb)
	var cs_house = CollisionShape.new(); var shape_house = BoxShape.new(); shape_house.extents = Vector3(1.5, 1.0, 1.25); cs_house.shape = shape_house; cs_house.translation = Vector3(0, 3.0, 0); sb.add_child(cs_house)
	var run_col_pos = [{"pos": Vector3(-3.0, 1.0, -3.0), "size": Vector3(0.1, 2.0, 6.0)}, {"pos": Vector3(3.0, 1.0, -3.0), "size": Vector3(0.1, 2.0, 6.0)}, {"pos": Vector3(0, 1.0, -6.0), "size": Vector3(6.0, 2.0, 0.1)}]
	for col in run_col_pos:
		var cs = CollisionShape.new(); var shape = BoxShape.new(); shape.extents = col.size * 0.5; cs.shape = shape; cs.translation = col.pos; sb.add_child(cs)

# --- MARKET ---

static func add_market_base(container, shared_res):
	add_western_market_building(container, Vector3(-18.0, 2.0, -30), 0, "GENERAL STORE", Color(0.4, 0.3, 0.2), shared_res)
	add_western_market_building(container, Vector3(18.0, 2.0, -30), 0, "MEAT MARKET", Color(0.5, 0.2, 0.2), shared_res)
	add_western_market_building(container, Vector3(0, 2.0, -30), 0, "MARKET HALL", Color(0.2, 0.3, 0.4), shared_res)
	var stall_configs = [
		{"pos": Vector3(-12, 2.0, -5), "rot": 45, "color": Color(0.9, 0.1, 0.1)},
		{"pos": Vector3(12, 2.0, -5), "rot": -45, "color": Color(0.1, 0.4, 0.9)},
		{"pos": Vector3(-15, 2.0, 12), "rot": 150, "color": Color(0.9, 0.8, 0.1)},
		{"pos": Vector3(15, 2.0, 12), "rot": 210, "color": Color(0.1, 0.8, 0.2)},
		{"pos": Vector3(0, 2.0, 28), "rot": 0, "color": Color(0.8, 0.5, 0.2)}
	]
	for cfg in stall_configs:
		add_market_stall(container, cfg.pos, cfg.rot, cfg.color, shared_res)

static func add_market_stall(container, pos, rot_deg, tent_color, shared_res):
	var node = Spatial.new(); node.translation = pos; node.rotation_degrees.y = rot_deg; container.add_child(node)
	var wood_mat = shared_res.get("wood_mat"); var table = MeshInstance.new(); table.mesh = CubeMesh.new(); table.mesh.size = Vector3(4.5, 0.2, 2.0); table.translation = Vector3(0, 1.0, 0); table.material_override = wood_mat; node.add_child(table)
	var tent = MeshInstance.new(); var prism = PrismMesh.new(); prism.size = Vector3(5.0, 1.5, 2.5); tent.mesh = prism; tent.translation = Vector3(0, 3.8, 0); var mat = SpatialMaterial.new(); mat.albedo_color = tent_color; mat.roughness = 0.9; tent.material_override = mat; node.add_child(tent)
	for ox in [-2.2, 2.2]:
		for oz in [-1.1, 1.1]:
			var post = MeshInstance.new(); post.mesh = CubeMesh.new(); post.mesh.size = Vector3(0.15, 3.1, 0.15); post.translation = Vector3(ox, 1.55, oz); post.material_override = wood_mat; node.add_child(post)

static func add_western_market_building(container, pos, rot_y, title, body_color, shared_res):
	var building = Spatial.new(); building.translation = pos; building.rotation_degrees.y = rot_y; container.add_child(building)
	var wood_mat = shared_res.get("wood_mat"); var mat_body = SpatialMaterial.new(); mat_body.albedo_color = body_color
	var body = MeshInstance.new(); body.mesh = CubeMesh.new(); body.mesh.size = Vector3(12, 12, 10); body.translation = Vector3(0, 6, -5); body.material_override = mat_body; building.add_child(body)
	var facade = MeshInstance.new(); facade.mesh = CubeMesh.new(); facade.mesh.size = Vector3(14, 16, 0.5); facade.translation = Vector3(0, 8, 0); facade.material_override = mat_body; building.add_child(facade)
	var sign_bg = MeshInstance.new(); sign_bg.mesh = CubeMesh.new(); sign_bg.mesh.size = Vector3(10, 3, 0.2); sign_bg.translation = Vector3(0, 14, 0.4); sign_bg.material_override = shared_res.get("sign_mat"); building.add_child(sign_bg)
	var p_floor = MeshInstance.new(); p_floor.mesh = CubeMesh.new(); p_floor.mesh.size = Vector3(14, 0.3, 5); p_floor.translation = Vector3(0, 0.15, 2.5); p_floor.material_override = wood_mat; building.add_child(p_floor)
	var p_roof = MeshInstance.new(); p_roof.mesh = CubeMesh.new(); p_roof.mesh.size = Vector3(14, 0.2, 5.2); p_roof.translation = Vector3(0, 5, 2.6); p_roof.rotation_degrees.x = 8; p_roof.material_override = wood_mat; building.add_child(p_roof)
	for x in [-6.5, 0, 6.5]:
		var col = MeshInstance.new(); col.mesh = CubeMesh.new(); col.mesh.size = Vector3(0.4, 5, 0.4); col.translation = Vector3(x, 2.5, 4.8); col.material_override = wood_mat; building.add_child(col)
	var door = MeshInstance.new(); door.mesh = CubeMesh.new(); door.mesh.size = Vector3(2.5, 4, 0.2); door.translation = Vector3(0, 2.1, 0.1); door.material_override = wood_mat; building.add_child(door)
	var sb = StaticBody.new(); var cs = CollisionShape.new(); var shape = BoxShape.new(); shape.extents = Vector3(7, 8, 8); cs.shape = shape; cs.translation = Vector3(0, 8, -4); sb.add_child(cs); building.add_child(sb)

# --- FAIR ---

static func add_livestock_fair(container, shared_res):
	var wood_mat = shared_res.get("wood_mat"); var arena = MeshInstance.new(); var cyl = CylinderMesh.new(); cyl.top_radius = 16.0; cyl.bottom_radius = 16.0; cyl.height = 0.15; arena.mesh = cyl; arena.translation = Vector3(0, 2.05, 0); var sand_mat = SpatialMaterial.new(); sand_mat.albedo_color = Color(0.65, 0.55, 0.4); arena.material_override = sand_mat; container.add_child(arena)
	for i in range(24):
		var angle = i * (TAU / 24.0); var pos = Vector3(cos(angle), 0, sin(angle)) * 16.5; var post = MeshInstance.new(); post.mesh = CubeMesh.new(); post.mesh.size = Vector3(0.4, 2.4, 0.4); post.translation = pos + Vector3(0, 3.2, 0); post.material_override = wood_mat; container.add_child(post)
		var next_angle = (i + 1) * (TAU / 24.0); var next_pos = Vector3(cos(next_angle), 0, sin(next_angle)) * 16.5; var mid = (pos + next_pos) * 0.5
		for h in [3.0, 3.8]:
			var board = MeshInstance.new(); board.mesh = CubeMesh.new(); board.mesh.size = Vector3(0.1, 0.25, 4.5); board.translation = mid + Vector3(0, h, 0)
			var diff = next_pos - pos; board.rotation.y = atan2(diff.x, diff.z); board.material_override = wood_mat; container.add_child(board)
	for side in [-1, 1]: add_bleachers(container, Vector3(0, 2.0, side * 26.0), side == 1, wood_mat)
	for x_side in [-1, 1]:
		for z_side in [-1, 1]: add_covered_corral(container, Vector3(x_side * 28, 2.0, z_side * 18), wood_mat)

static func add_bleachers(container, pos, face_north, mat):
	var node = Spatial.new(); node.translation = pos; if not face_north: node.rotation_degrees.y = 180; container.add_child(node)
	for row in range(4):
		var row_h = row * 1.2 + 0.6; var row_z = row * 1.8; var floor_mesh = MeshInstance.new(); floor_mesh.mesh = CubeMesh.new(); floor_mesh.mesh.size = Vector3(25, 0.25, 1.8); floor_mesh.translation = Vector3(0, row_h, row_z); floor_mesh.material_override = mat; node.add_child(floor_mesh)
		var bench = MeshInstance.new(); bench.mesh = CubeMesh.new(); bench.mesh.size = Vector3(25, 0.15, 0.5); bench.translation = Vector3(0, row_h + 0.45, row_z - 0.4); bench.material_override = mat; node.add_child(bench)
	var roof = MeshInstance.new(); roof.mesh = CubeMesh.new(); roof.mesh.size = Vector3(28, 0.3, 10.0); roof.translation = Vector3(0, 8.5, 3.0); roof.rotation_degrees.x = -12; roof.material_override = mat; node.add_child(roof)
	for x in [-12.5, 12.5]:
		for z in [-1, 8]:
			var col = MeshInstance.new(); col.mesh = CubeMesh.new(); col.mesh.size = Vector3(0.4, 8.5, 0.4); col.translation = Vector3(x, 4.25, z); col.material_override = mat; node.add_child(col)

static func add_covered_corral(container, pos, mat):
	var corral = Spatial.new(); corral.translation = pos; container.add_child(corral)
	var size = 8.0
	for i in range(4):
		var angle = i * PI/2.0; var side_pos = Vector3(cos(angle), 0, sin(angle)) * (size/2.0); var wall = MeshInstance.new(); wall.mesh = CubeMesh.new()
		if i % 2 == 0: wall.mesh.size = Vector3(0.15, 1.6, size)
		else: wall.mesh.size = Vector3(size, 1.6, 0.15)
		wall.translation = side_pos + Vector3(0, 0.8, 0); wall.material_override = mat; corral.add_child(wall)
	var roof = MeshInstance.new(); roof.mesh = CubeMesh.new(); roof.mesh.size = Vector3(size + 1, 0.2, size + 1); roof.translation = Vector3(0, 4.5, 0); roof.rotation_degrees.x = 5; roof.material_override = mat; corral.add_child(roof)
	for ox in [-1, 1]:
		for oz in [-1, 1]:
			var c = MeshInstance.new(); c.mesh = CubeMesh.new(); c.mesh.size = Vector3(0.2, 4.5, 0.2); c.translation = Vector3(ox * 3.5, 2.25, oz * 3.5); c.material_override = mat; corral.add_child(c)

# --- MINE ---

static func add_mine_base(container, shared_res):
	var wood_mat = shared_res.get("wood_mat"); var portal = Spatial.new(); portal.translation = Vector3(0, 2.0, -25); container.add_child(portal)
	for x in [-4, 4]:
		var post = MeshInstance.new(); post.mesh = CubeMesh.new(); post.mesh.size = Vector3(1.2, 8.0, 1.2); post.translation = Vector3(x, 4.0, 0); post.material_override = wood_mat; portal.add_child(post)
	var beam = MeshInstance.new(); beam.mesh = CubeMesh.new(); beam.mesh.size = Vector3(10.0, 1.2, 1.5); beam.translation = Vector3(0, 8.0, 0); beam.material_override = wood_mat; portal.add_child(beam)
	var dark = MeshInstance.new(); var q = QuadMesh.new(); q.size = Vector2(8, 8); dark.mesh = q; dark.translation = Vector3(0, 4, -0.1); var d_mat = SpatialMaterial.new(); d_mat.albedo_color = Color(0, 0, 0); dark.material_override = d_mat; portal.add_child(dark)
	var rails = Spatial.new(); rails.translation = Vector3(0, 2.1, -25); container.add_child(rails)
	for i in range(15):
		var z_pos = i * 3.0; var plank = MeshInstance.new(); plank.mesh = CubeMesh.new(); plank.mesh.size = Vector3(2.5, 0.1, 0.4); plank.translation = Vector3(0, 0, z_pos); plank.material_override = wood_mat; rails.add_child(plank)
		for side in [-0.8, 0.8]:
			var rail = MeshInstance.new(); rail.mesh = CubeMesh.new(); rail.mesh.size = Vector3(0.1, 0.2, 3.1); rail.translation = Vector3(side, 0.1, z_pos); var iron = SpatialMaterial.new(); iron.albedo_color = Color(0.3, 0.3, 0.3); iron.metallic = 0.8; rail.material_override = iron; rails.add_child(rail)
	add_mine_cart(container, Vector3(0, 2.65, -5), shared_res); add_mine_cart(container, Vector3(0, 2.65, 12), shared_res)
	var scaffold = Spatial.new(); scaffold.translation = Vector3(15, 2.0, -15); container.add_child(scaffold)
	for h in range(3):
		var level = MeshInstance.new(); level.mesh = CubeMesh.new(); level.mesh.size = Vector3(6, 0.3, 6); level.translation = Vector3(0, h * 4.0, 0); level.material_override = wood_mat; scaffold.add_child(level)
		for ox in [-2.5, 2.5]:
			for oz in [-2.5, 2.5]:
				var col = MeshInstance.new(); col.mesh = CubeMesh.new(); col.mesh.size = Vector3(0.3, 4.0, 0.3); col.translation = Vector3(ox, h * 4.0 + 2.0, oz); col.material_override = wood_mat; scaffold.add_child(col)
	add_miner_cabin(container, Vector3(-18, 2.0, -10), shared_res)

static func add_mine_cart(container, pos, shared_res):
	var cart = Spatial.new(); cart.translation = pos; container.add_child(cart); var wood_mat = shared_res.get("wood_mat")
	var box = MeshInstance.new(); box.mesh = CubeMesh.new(); box.mesh.size = Vector3(2.0, 1.2, 2.5); box.material_override = wood_mat; cart.add_child(box)
	for ox in [-0.9, 0.9]:
		for oz in [-0.8, 0.8]:
			var wheel = MeshInstance.new(); var c = CylinderMesh.new(); c.top_radius = 0.3; c.bottom_radius = 0.3; c.height = 0.2; wheel.mesh = c; wheel.translation = Vector3(ox, -0.6, oz); wheel.rotation_degrees.z = 90; var w_mat = SpatialMaterial.new(); w_mat.albedo_color = Color(0.1, 0.1, 0.1); wheel.material_override = w_mat; cart.add_child(wheel)

static func add_miner_cabin(container, pos, shared_res):
	var cabin = Spatial.new(); cabin.translation = pos; container.add_child(cabin); var wood_mat = shared_res.get("wood_mat")
	var body = MeshInstance.new(); body.mesh = CubeMesh.new(); body.mesh.size = Vector3(8, 5, 8); body.translation = Vector3(0, 2.5, 0); body.material_override = wood_mat; cabin.add_child(body)
	var roof = MeshInstance.new(); var p = PrismMesh.new(); p.size = Vector3(9, 3, 9); roof.mesh = p; roof.translation = Vector3(0, 6.0, 0); roof.material_override = wood_mat; cabin.add_child(roof)
