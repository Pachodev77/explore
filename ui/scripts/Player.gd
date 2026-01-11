extends KinematicBody

export(float) var speed = 6.0
export(float) var rotation_speed = 2.0
var velocity = Vector3.ZERO
var move_dir = Vector2.ZERO
var look_dir = Vector2.ZERO
var mouse_sensitivity = 0.1

enum CameraState { FIRST_PERSON, CLOSE, FAR, VERY_FAR }
var current_camera_state = CameraState.FAR

onready var camera_pivot = $CameraPivot

# --- MODULOS ---
var stats = PlayerStats.new()
var actions = PlayerActions.new()

# --- REFERENCIAS Y ESTADOS ---
var hud_ref = null
var is_sprinting = false
var is_performing_action = false
var wm = null
var dnc_ref = null

# --- SISTEMAS VISUALES ---
var reins_line : ImmediateGeometry
var torch_active = false
var torch_node : Spatial = null
var _torch_flicker_tick = 0
var _torch_light_ref = null
var _ground_shader_tick = 0

# --- MONTURA ---
var is_riding = false
var current_horse = null

func _ready():
	add_to_group("player")
	yield(get_tree(), "idle_frame")
	
	var hud = get_tree().root.find_node("MainHUD", true, false)
	if hud:
		hud.connect("joystick_moved", self, "_on_joystick_moved")
		hud.connect("camera_moved", self, "_on_camera_moved")
		hud.connect("zoom_pressed", self, "_on_zoom_pressed")
		hud.connect("mount_pressed", self, "_on_mount_pressed")
		hud.connect("run_pressed", self, "_on_run_pressed")
		hud.connect("jump_pressed", self, "_on_jump_pressed")
		hud.connect("torch_pressed", self, "_on_torch_pressed")
		hud.connect("action_pressed", self, "_on_action_pressed")
		hud_ref = hud
	
	dnc_ref = get_parent().get_node_or_null("DayNightCycle")
	wm = get_tree().root.find_node("WorldManager", true, false)
	
	# Inicializar Modulos
	stats.init(self, hud_ref, dnc_ref)
	actions.init(self, hud_ref)
	
	camera_pivot.rotation = Vector3.ZERO 
	rotation = Vector3.ZERO
	look_dir = Vector2.ZERO
	
	_init_reins()
	update_camera_settings()

func _init_reins():
	if has_node("ReinsLine"):
		reins_line = get_node("ReinsLine")
	else:
		reins_line = ImmediateGeometry.new()
		reins_line.name = "ReinsLine"
		var m = SpatialMaterial.new()
		m.albedo_color = Color(0.5, 0.35, 0.2)
		m.flags_unshaded = true 
		m.params_cull_mode = SpatialMaterial.CULL_DISABLED
		reins_line.material_override = m
		add_child(reins_line)
	_create_torch()

func _create_torch():
	torch_node = Spatial.new()
	torch_node.name = "Torch"
	torch_node.visible = false
	add_child(torch_node)
	
	var mesh_inst = MeshInstance.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.03
	cylinder.bottom_radius = 0.02
	cylinder.height = 0.45
	mesh_inst.mesh = cylinder
	
	var mat = SpatialMaterial.new()
	mat.albedo_color = Color(0.4, 0.2, 0.1)
	mesh_inst.material_override = mat
	torch_node.add_child(mesh_inst)
	mesh_inst.translation.y = 0.05 
	
	var light = OmniLight.new()
	light.name = "OmniLight"
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 2.0
	light.omni_range = 22.0
	light.shadow_enabled = not (OS.has_feature("Android") or OS.has_feature("iOS"))
	light.translation.y = 0.85
	light.translation.z = 0.25 
	torch_node.add_child(light)
	
	var fire_mesh = MeshInstance.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.07
	cone.height = 0.25
	fire_mesh.mesh = cone
	
	var fire_mat = SpatialMaterial.new()
	fire_mat.albedo_color = Color(1.0, 0.45, 0.0)
	fire_mat.flags_unshaded = true 
	fire_mesh.material_override = fire_mat
	fire_mesh.translation.y = 0.4
	torch_node.add_child(fire_mesh)

func _on_torch_pressed():
	torch_active = !torch_active
	if torch_node:
		torch_node.visible = torch_active
		if torch_active:
			var hum = $MeshInstance
			if hum and hum.get("hand_r_attachment"):
				var attach = hum.hand_r_attachment
				if torch_node.get_parent() != attach:
					if torch_node.get_parent():
						torch_node.get_parent().remove_child(torch_node)
					attach.add_child(torch_node)
					torch_node.translation = Vector3(0.01, -0.14, 0.02)
					torch_node.rotation_degrees = Vector3(110, 0, 0)
	
	if $WalkAnimator.has_method("set_torch"):
		$WalkAnimator.set_torch(torch_active)
	_update_ground_material_torch(torch_active)

func _update_ground_material_torch(active):
	if wm and wm.shared_res.has("ground_mat"):
		var mat = wm.shared_res["ground_mat"]
		if mat is ShaderMaterial:
			var intensity = 0.0
			if active:
				intensity = 1.0
			mat.set_shader_param("torch_intensity", intensity)

func _process(delta):
	stats.update_stats(delta)
	
	if is_riding and current_horse and reins_line:
		_draw_reins()
	elif reins_line:
		reins_line.clear()
	
	if torch_active:
		_torch_flicker_tick += 1
		if _torch_flicker_tick >= 3:
			_torch_flicker_tick = 0
			if not _torch_light_ref and torch_node:
				_torch_light_ref = torch_node.get_node_or_null("OmniLight")
			if _torch_light_ref:
				var time = OS.get_ticks_msec() * 0.001
				var noise = sin(time * 20.0) * 0.15 + sin(time * 35.0) * 0.05
				_torch_light_ref.light_energy = 1.8 + noise
				_torch_light_ref.omni_range = 21.0 + noise * 4.0
		
		_ground_shader_tick += 1
		if _ground_shader_tick >= 5:
			_ground_shader_tick = 0
			if wm and wm.shared_res.has("ground_mat"):
				var mat = wm.shared_res["ground_mat"]
				if mat is ShaderMaterial:
					mat.set_shader_param("player_pos", global_transform.origin)
	
	actions.update_interaction_check()

func _physics_process(delta):
	if look_dir.length() > 0.05:
		_update_camera_rotation(delta)

	if is_riding and current_horse:
		current_horse.rider_input = move_dir
		current_horse.rider_sprinting = is_sprinting
		return

	if is_performing_action:
		_apply_action_physics(delta)
		return

	_apply_movement_physics(delta)

func _update_camera_rotation(delta):
	camera_pivot.rotate_y(-look_dir.x * rotation_speed * delta)
	var target_pitch = camera_pivot.rotation_degrees.x - look_dir.y * rotation_speed * delta * 40
	var clamped_pitch = clamp(target_pitch, -60, 30)
	
	if wm and wm.has_method("get_terrain_height_at") and current_camera_state != CameraState.FIRST_PERSON:
		var cam_dist = $CameraPivot/Camera.translation.z
		var pivot_h = camera_pivot.global_transform.origin.y
		var cam_local_y = -sin(deg2rad(clamped_pitch)) * cam_dist
		var pred_cam_y = pivot_h + cam_local_y
		
		var yaw = camera_pivot.global_transform.basis.get_euler().y
		var cam_offset_flat = Vector3(0, 0, cam_dist * cos(deg2rad(clamped_pitch))).rotated(Vector3.UP, yaw)
		var pred_cam_pos = camera_pivot.global_transform.origin + cam_offset_flat
		
		var ground_h = wm.get_terrain_height_at(pred_cam_pos.x, pred_cam_pos.z)
		var safe_h = ground_h + 0.5
		
		if pred_cam_y < safe_h:
			var val = clamp((pivot_h - safe_h) / cam_dist, -1.0, 1.0)
			var max_pitch = rad2deg(asin(val))
			if clamped_pitch > max_pitch:
				clamped_pitch = max_pitch
	
	camera_pivot.rotation_degrees.x = clamped_pitch

func _apply_action_physics(delta):
	velocity.x = 0
	velocity.z = 0
	if not is_on_floor():
		velocity.y -= 25.0 * delta
	velocity = move_and_slide(velocity, Vector3.UP)

func _apply_movement_physics(delta):
	var forward = -camera_pivot.global_transform.basis.z
	var right = camera_pivot.global_transform.basis.x
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	
	var direction = (forward * -move_dir.y + right * move_dir.x).normalized()
	var sprint_mult = 1.0
	if is_sprinting:
		sprint_mult = 1.8
	var current_speed = speed * sprint_mult
	
	if direction.length() > 0.1:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = lerp(velocity.x, 0, 10 * delta)
		velocity.z = lerp(velocity.z, 0, 10 * delta)
	
	if is_on_floor() and velocity.y <= 0:
		velocity.y = -0.1 
	else:
		velocity.y -= 25.0 * delta
	
	var snap = Vector3.ZERO
	if is_on_floor() and velocity.y <= 0:
		snap = Vector3.DOWN
		
	velocity = move_and_slide_with_snap(velocity, snap, Vector3.UP, true, 4, deg2rad(45))
	
	if is_on_floor() and direction.length() <= 0.1:
		velocity.x = 0
		velocity.z = 0
	
	if translation.y < -50:
		translation = Vector3(0, 60, 0)
		velocity = Vector3.ZERO
	
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		$MeshInstance.rotation.y = lerp_angle($MeshInstance.rotation.y, target_rotation, 10 * delta)
	
	var horizontal_vel = Vector3(velocity.x, 0, velocity.z)
	$WalkAnimator.update_physics_state(velocity.y, velocity, is_on_floor())
	$WalkAnimator.set_walking(is_on_floor() and horizontal_vel.length() > 0.1, horizontal_vel.length())

func try_mount_horse():
	var horses = get_tree().get_nodes_in_group("horses")
	if horses.size() == 0:
		return
		
	var nearest_horse = null
	var min_dist = 99999.0
	var my_pos = global_transform.origin
	
	for h in horses:
		if not is_instance_valid(h):
			continue
		var d = h.global_transform.origin.distance_to(my_pos)
		if d < min_dist:
			min_dist = d
			nearest_horse = h
			
	if not is_instance_valid(nearest_horse):
		return
		
	if min_dist < 4.0:
		mount(nearest_horse)
	elif nearest_horse.has_method("call_to_player"):
		nearest_horse.call_to_player(self)

func mount(horse_node):
	if is_riding or not is_instance_valid(horse_node):
		return
	if horse_node.get("is_ridden"):
		return
		
	is_riding = true
	current_horse = horse_node
	$CollisionShape.disabled = true
	
	var old_parent = get_parent()
	if old_parent:
		old_parent.remove_child(self)
		
	var m_point = horse_node.get_node_or_null("MountPoint")
	if m_point:
		m_point.add_child(self)
	else:
		horse_node.add_child(self)
		
	translation = Vector3(0, 0.4, 0)
	rotation = Vector3.ZERO
	camera_pivot.rotation = Vector3.ZERO
	look_dir = Vector2.ZERO
	
	horse_node.interact(self)
	
	if has_node("WalkAnimator"):
		get_node("WalkAnimator").set_riding(true, current_horse)
	
	$MeshInstance.rotation_degrees.y = 180 
	current_camera_state = CameraState.VERY_FAR
	update_camera_settings()

func dismount():
	if not is_riding:
		return
	var world_node = current_horse.get_parent()
	var mount_p = get_parent()
	mount_p.remove_child(self)
	world_node.add_child(self)
	global_transform.origin = current_horse.global_transform.origin + current_horse.global_transform.basis.x * 1.5
	is_riding = false
	$WalkAnimator.set_riding(false, null)
	current_horse.dismount()
	current_horse = null
	$CollisionShape.disabled = false
	current_camera_state = CameraState.FAR
	update_camera_settings()
	if reins_line:
		reins_line.clear()

func _on_mount_pressed():
	if is_riding:
		dismount()
	else:
		try_mount_horse()

func _on_joystick_moved(vector):
	move_dir = Vector2(vector.x, vector.y)

func _on_camera_moved(vector):
	look_dir = vector

func _on_zoom_pressed():
	current_camera_state = (current_camera_state + 1) % 4
	update_camera_settings()

func _on_run_pressed(is_active):
	is_sprinting = is_active

func _on_jump_pressed():
	if is_riding and current_horse:
		if current_horse.has_method("jump"):
			current_horse.jump()
	elif is_on_floor():
		velocity.y = 12.0
		if $WalkAnimator.has_method("set_jumping"):
			$WalkAnimator.set_jumping(true)

func _on_action_pressed():
	actions.execute_action()

func _draw_reins():
	reins_line.clear()
	var origin_base = global_transform.origin
	var rot_y = rotation.y
	var p_l = origin_base + Vector3(-0.3, 1.05, 0.4).rotated(Vector3.UP, rot_y)
	var p_r = origin_base + Vector3(0.3, 1.05, 0.4).rotated(Vector3.UP, rot_y)
	if $MeshInstance.get("skel_node"):
		var skel = $MeshInstance.skel_node
		var h_l = skel.find_bone("HandL")
		var h_r = skel.find_bone("HandR")
		if h_l != -1:
			p_l = skel.global_transform.xform(skel.get_bone_global_pose(h_l).xform(Vector3(0, -0.15, 0)))
		if h_r != -1:
			p_r = skel.global_transform.xform(skel.get_bone_global_pose(h_r).xform(Vector3(0, -0.15, 0)))
	if torch_active:
		p_r = p_l
	var mouth_center = current_horse.global_transform.origin + Vector3(0, 1.5, 0.8) 
	var pm = current_horse.get_node_or_null("ProceduralMesh")
	if pm:
		var anchor = pm.find_node("ReinAnchor", true, false)
		if anchor:
			mouth_center = anchor.global_transform.origin
	var horse_basis = current_horse.global_transform.basis
	var horse_right = horse_basis.x.normalized()
	if horse_right.length_squared() < 0.01:
		horse_right = Vector3.RIGHT
	var spread = 0.12
	var m_l = mouth_center - horse_right * spread
	var m_r = mouth_center + horse_right * spread
	
	var d1 = p_l.distance_squared_to(m_l) + p_r.distance_squared_to(m_r)
	var d2 = p_l.distance_squared_to(m_r) + p_r.distance_squared_to(m_l)
	
	if d1 < d2:
		_draw_rein_curve_thick(p_l, m_l)
		_draw_rein_curve_thick(p_r, m_r)
	else:
		_draw_rein_curve_thick(p_l, m_r)
		_draw_rein_curve_thick(p_r, m_l)

func _draw_rein_curve_thick(start_pos, end_pos):
	var offsets = [
		Vector3.ZERO, 
		Vector3(0, 0.015, 0), 
		Vector3(0, -0.015, 0), 
		Vector3(0.015, 0, 0), 
		Vector3(-0.015, 0, 0)
	]
	var mid_point = (start_pos + end_pos) * 0.5
	mid_point.y -= 0.45 
	for offset in offsets:
		reins_line.begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i in range(11):
			var t = float(i) / 10.0
			var p = start_pos.linear_interpolate(mid_point, t).linear_interpolate(mid_point.linear_interpolate(end_pos, t), t)
			reins_line.add_vertex(reins_line.to_local(p + offset))
		reins_line.end()

func update_camera_settings():
	var cam = $CameraPivot/Camera
	if current_camera_state == CameraState.FIRST_PERSON:
		cam.translation = Vector3(0, 0.5, 0.5)
		camera_pivot.translation.y = 1.6
		$MeshInstance.visible = false
	elif current_camera_state == CameraState.CLOSE:
		cam.translation = Vector3(0, 0, 3.5)
		camera_pivot.translation.y = 1.5
		$MeshInstance.visible = true
	elif current_camera_state == CameraState.FAR:
		cam.translation = Vector3(0, 0, 10.0)
		camera_pivot.translation.y = 1.0
		$MeshInstance.visible = true
	elif current_camera_state == CameraState.VERY_FAR:
		cam.translation = Vector3(0, 0, 25.0)
		camera_pivot.translation.y = 0.5
		$MeshInstance.visible = true
