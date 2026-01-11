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
		self.hud_ref = hud # Guardar referencia para actualizar botón
		hud.set_health(health) # Initialize Health full
		hud.set_hydration(hydration) # Initialize HUD full
	
	dnc_ref = get_parent().get_node_or_null("DayNightCycle")
	
	# Asegurar que la cámara inicie recta y sin inclinación
	# Asegurar que la cámara inicie recta y sin inclinación
	camera_pivot.rotation = Vector3.ZERO 
	rotation = Vector3.ZERO
	look_dir = Vector2.ZERO
	
	_init_reins()
	update_camera_settings()
	
	wm = get_tree().root.find_node("WorldManager", true, false)

var hud_ref = null
var is_sprinting = false
var is_performing_action = false
var milking_target_cow = null
var current_target_tree_mmi = null
var current_target_tree_idx = -1
var _was_near_tree = false
var wm = null
var health = 1.0
var hydration = 1.0 # Hydration starts full (1.0 = 100%)
var max_hydration = 1.0
var dnc_ref = null # Reference to DayNightCycle


# --- SISTEMA DE RIENDAS ---
var reins_line : ImmediateGeometry

func _init_reins():
	if has_node("ReinsLine"):
		reins_line = get_node("ReinsLine")
	else:
		reins_line = ImmediateGeometry.new()
		reins_line.name = "ReinsLine"
		var m = SpatialMaterial.new()
		m.albedo_color = Color(0.5, 0.35, 0.2) # Cuero más claro y visible
		m.flags_unshaded = true 
		m.params_cull_mode = SpatialMaterial.CULL_DISABLED # Ver por ambos lados
		reins_line.material_override = m
		add_child(reins_line)
	
	_create_torch()

var torch_active = false
var torch_node : Spatial = null

func _create_torch():
	torch_node = Spatial.new()
	torch_node.name = "Torch"
	torch_node.visible = false
	add_child(torch_node)
	
	# Malla de la antorcha (palo) - BAJAR PARA QUE SE VEA EN EL PUÑO
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
	# Bajamos la malla para que el palo "atraviese" la mano y parezca sujeto (antes 0.225)
	mesh_inst.translation.y = 0.05 
	
	# Luz (ELEVAR PARA EVITAR SOMBRAS DEL JUGADOR)
	var light = OmniLight.new()
	light.name = "OmniLight"
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 2.0
	light.omni_range = 22.0
	light.omni_attenuation = 1.0 # Lineal para mayor uniformidad en móviles
	# OPTIMIZACIÓN MÓVIL: Desactivar sombras de antorcha en móviles para ganar FPS
	light.shadow_enabled = not (OS.has_feature("Android") or OS.has_feature("iOS"))
	light.shadow_bias = 1.5 
	light.translation.y = 0.85 
	light.translation.z = 0.25 
	torch_node.add_child(light)
	
	# Fuego (BAJAR CON EL PALO)
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
	# Ajustado para que esté en el nuevo tope del palo (0.05 + 0.225 = 0.275)
	fire_mesh.translation.y = 0.275 + 0.125
	torch_node.add_child(fire_mesh)

func _on_torch_pressed():
	torch_active = !torch_active
	if torch_node:
		torch_node.visible = torch_active
		
		# CONEXIÓN FÍSICA PRO: Usar BoneAttachment para evitar vibraciones
		if torch_active and torch_node.get_parent() == self:
			var hum = $MeshInstance
			if hum and hum.get("hand_r_attachment"):
				var attach = hum.hand_r_attachment
				remove_child(torch_node)
				attach.add_child(torch_node)
				
				# Configurar posición local fija (Ya no se actualiza en _process)
				torch_node.translation = Vector3(0.01, -0.14, 0.02)
				torch_node.rotation_degrees = Vector3(110, 0, 0)
	
	if $WalkAnimator.has_method("set_torch"):
		$WalkAnimator.set_torch(torch_active)
	
	# NOTIFICAR AL SHADER DEL SUELO (Para refuerzo per-pixel en móviles)
	_update_ground_material_torch(torch_active)

func _update_ground_material_torch(active):
	var wm = get_parent().get_node_or_null("WorldManager")
	if wm and wm.shared_res.has("ground_mat"):
		var mat = wm.shared_res["ground_mat"]
		if mat is ShaderMaterial:
			mat.set_shader_param("torch_intensity", 1.0 if active else 0.0)

func _process(_delta):
	# 1. RIENDAS
	if is_riding and current_horse and reins_line:
		_draw_reins()
	elif reins_line:
		reins_line.clear()
	
	# 2. ANTORCHA (Flicker - OPTIMIZADO: cada 3 frames)
	if torch_active:
		_torch_flicker_tick += 1
		if _torch_flicker_tick >= 3:
			_torch_flicker_tick = 0
			if _torch_light_ref == null and torch_node:
				_torch_light_ref = torch_node.get_node_or_null("OmniLight")
			if _torch_light_ref:
				var time = OS.get_ticks_msec() * 0.001
				var noise = sin(time * 20.0) * 0.15 + sin(time * 35.0) * 0.05
				_torch_light_ref.light_energy = 1.8 + noise
				_torch_light_ref.omni_range = 21.0 + noise * 4.0
		
		# Sincronizar posición con el shader del suelo (Uniformidad móvil)
		_ground_shader_tick += 1
		if _ground_shader_tick >= 5: # Cada 5 frames es suficiente
			_ground_shader_tick = 0
			var wm = get_parent().get_node_or_null("WorldManager")
			if wm and wm.shared_res.has("ground_mat"):
				var mat = wm.shared_res["ground_mat"]
				if mat is ShaderMaterial:
					mat.set_shader_param("player_pos", global_transform.origin)
	
	# 3. LOGICA DE HIDRATACION (Meticulosa)
	if dnc_ref:
		# Depleción: 100% en 2 días.
		# duracion_dia = dnc_ref.cycle_duration_minutes * 60 segundos
		# tiempo_total = duracion_dia * 2
		var day_sec = dnc_ref.cycle_duration_minutes * 60.0
		var total_depletion_time = day_sec * 2.0
		if total_depletion_time > 0:
			var depletion_per_sec = 1.0 / total_depletion_time
			hydration = max(0.0, hydration - depletion_per_sec * _delta)
			
			if hud_ref:
				hud_ref.set_hydration(hydration)
			
			if hydration <= 0:
				# Daño: 100% de salud en 0.5 días (12 horas in-game pierdes toda la vida)
				var damage_per_sec = 1.0 / (day_sec * 0.5)
				health = max(0.0, health - damage_per_sec * _delta)
				if hud_ref:
					hud_ref.set_health(health)
	
	# 4. DETECCIÓN DE ORDEÑO (MILK)
	if hud_ref:
		_milk_check_tick += 1
		if _milk_check_tick >= 10: # Cada 10 frames es suficiente
			_milk_check_tick = 0
			var can_milk = false
			var cows = get_tree().get_nodes_in_group("cow")
			for c in cows:
				# Solo vacas del establo que HAN LLEGADO a su posición de dormir (están dentro)
				var is_in_stable = false
				if c.get("is_night_cow") and c.get("has_reached_waypoint"):
					var target = c.get("night_target_pos")
					if target and c.global_transform.origin.distance_to(target) < 2.5:
						is_in_stable = true
				
				if is_in_stable and c.global_transform.origin.distance_to(global_transform.origin) < 4.5:
					can_milk = true
					break
			
			# --- DETECCION DE ARBOLES (OPTIMIZADA) ---
			var can_wood = false
			current_target_tree_mmi = null
			current_target_tree_idx = -1
			
			if not can_milk:
				var tree_mmis = get_tree().get_nodes_in_group("tree_mmi")
				var closest_dist = 7.0 # Rango máximo
				var my_pos = global_transform.origin
				
				for mmi in tree_mmis:
					# OPTIMIZACIÓN: Pre-check - Si el MMI está muy lejos, saltarlo
					var mmi_dist = my_pos.distance_to(mmi.global_transform.origin)
					if mmi_dist > 100.0: # Los MMI pueden tener árboles hasta ~75m del centro
						continue
						
					if mmi is MultiMeshInstance and mmi.multimesh:
						var mm = mmi.multimesh
						# OPTIMIZACIÓN: Limitar búsqueda a los primeros 30 árboles por MMI
						var max_check = min(mm.instance_count, 30)
						for i in range(max_check):
							var itf = mmi.global_transform * mm.get_instance_transform(i)
							var dist = my_pos.distance_to(itf.origin)
							if dist < closest_dist:
								closest_dist = dist
								can_wood = true
								current_target_tree_mmi = mmi
								current_target_tree_idx = i
								# Early exit si encontramos uno muy cerca
								if dist < 2.5:
									break
					# Early exit si ya encontramos un árbol cercano
					if can_wood and closest_dist < 2.5:
						break

			# Actualizar estados persistentes para los botones
			_was_near_cow = can_milk
			_was_near_tree = can_wood
			
			if _was_near_cow:
				hud_ref.set_action_label("MILK")
			elif _was_near_tree:
				hud_ref.set_action_label("WOOD")
			else:
				hud_ref.set_action_label("ACTION")

var _milk_check_tick = 0
var _was_near_cow = false

var _ground_shader_tick = 0

var _torch_flicker_tick = 0
var _torch_light_ref = null

# La función _update_torch_transform ya no es necesaria, 
# se usa el sistema de BoneAttachment de Godot para máxima estabilidad.

func _draw_reins():
	reins_line.clear()
	
	# 1. Obtener posiciones de AMBAS manos
	var origin_base = global_transform.origin
	var rot_y = rotation.y
	var p_l = origin_base + Vector3(-0.3, 1.05, 0.4).rotated(Vector3.UP, rot_y)
	var p_r = origin_base + Vector3(0.3, 1.05, 0.4).rotated(Vector3.UP, rot_y)
	
	if $MeshInstance.get("skel_node"):
		var skel = $MeshInstance.skel_node
		var h_l = skel.find_bone("HandL")
		var h_r = skel.find_bone("HandR")
		if h_l != -1:
			var hand_tf = skel.get_bone_global_pose(h_l)
			# Offset -0.15 en Y local (hacia los dedos)
			p_l = skel.global_transform.xform(hand_tf.xform(Vector3(0, -0.15, 0)))
		if h_r != -1:
			var hand_tf = skel.get_bone_global_pose(h_r)
			p_r = skel.global_transform.xform(hand_tf.xform(Vector3(0, -0.15, 0)))
			
	# --- NUEVO: Si la antorcha está activa, ambas riendas van a la mano izquierda ---
	if torch_active:
		p_r = p_l

	# 2. Punto destino CENTRAL: Boca del caballo
	var mouth_center = current_horse.global_transform.origin + Vector3(0, 1.5, 0.8) 
	var anchor_path = "ProceduralMesh/BodyRoot/NeckBase/NeckMid/Head/ReinAnchor"
	if current_horse.has_node(anchor_path):
		var anchor = current_horse.get_node(anchor_path)
		mouth_center = anchor.global_transform.origin
	elif current_horse.has_node("ProceduralMesh"):
		var pm = current_horse.get_node("ProceduralMesh")
		var anchor = pm.find_node("ReinAnchor", true, false)
		if anchor:
			mouth_center = anchor.global_transform.origin
			
	# 3. Separar puntos en la boca para evitar que se vean juntas
	var horse_right = current_horse.global_transform.basis.x.normalized()
	if horse_right.length_squared() < 0.01: horse_right = Vector3.RIGHT
	
	var spread = 0.12
	var m_l = mouth_center - horse_right * spread
	var m_r = mouth_center + horse_right * spread
	
	# Usar LINE_STRIP con múltiples pasadas
	# (Nota: _draw_rein_curve_thick ya hace begin/end internamente)
	
	# Detectar cruce (Auto-Uncross)
	# Calculamos distancia total en asignación directa vs cruzada
	var dist_straight = p_l.distance_squared_to(m_l) + p_r.distance_squared_to(m_r)
	var dist_crossed = p_l.distance_squared_to(m_r) + p_r.distance_squared_to(m_l)
	
	# Si cruzar es más corto, significa que "m_l" está físicamente más cerca de la mano derecha
	# (posiblemente por rotación extrema o ejes invertidos). 
	# Para NO tener "X", elegimos la configuración de menor longitud visual general.
	if dist_straight < dist_crossed:
		# Directo: L->L, R->R
		_draw_rein_curve_thick(p_l, m_l)
		_draw_rein_curve_thick(p_r, m_r)
	else:
		# Cruzado (Swap para desenredar): L->R_point, R->L_point
		_draw_rein_curve_thick(p_l, m_r)
		_draw_rein_curve_thick(p_r, m_l)

func _draw_rein_curve_thick(start_pos, end_pos):
	# Simular grosor dibujando varias líneas ligeramente desplazadas
	# Offsets para crear un "tubo" cuadrado de 3cm aprox
	var offsets = [
		Vector3.ZERO, 
		Vector3(0, 0.015, 0), Vector3(0, -0.015, 0), 
		Vector3(0.015, 0, 0), Vector3(-0.015, 0, 0)
	]
	
	var mid_point = (start_pos + end_pos) * 0.5
	mid_point.y -= 0.45 
	
	var steps = 10
	
	for offset in offsets:
		# Girar el offset según la dirección de la cuerda sería ideal, 
		# pero usar offset de mundo es más barato y suficiente para líneas finas.
		reins_line.begin(Mesh.PRIMITIVE_LINE_STRIP)
		
		for i in range(steps + 1):
			var t = float(i) / steps
			var q0 = start_pos.linear_interpolate(mid_point, t)
			var q1 = mid_point.linear_interpolate(end_pos, t)
			var p = q0.linear_interpolate(q1, t)
			
			# Aplicar offset (simple world space offset)
			reins_line.add_vertex(reins_line.to_local(p + offset))
		
		reins_line.end()


func _on_mount_pressed():
	if is_riding:
		dismount()
	else:
		try_mount_horse()

func _on_joystick_moved(vector):
	move_dir = Vector2(vector.x, vector.y) # x is strafe, y is forward/back

func _on_camera_moved(vector):
	look_dir = vector

func _on_zoom_pressed():
	current_camera_state = (current_camera_state + 1) % 4
	update_camera_settings()

func _on_run_pressed(is_active):
	is_sprinting = is_active

func _on_jump_pressed():
	# If riding, ONLY tell horse to jump (player follows as child)
	# Animation is handled automatically by WalkAnimation._animate_riding() checking horse.is_jumping
	if is_riding and current_horse:
		if current_horse.has_method("jump"):
			current_horse.jump()
	# Jump if on ground (only when not riding)
	elif is_on_floor():
		velocity.y = 12.0
		# Trigger jump animation
		if $WalkAnimator.has_method("set_jumping"):
			$WalkAnimator.set_jumping(true)

func update_camera_settings():
	var cam = $CameraPivot/Camera
	match current_camera_state:
		CameraState.FIRST_PERSON:
			cam.translation.z = 0.5 # Slightly forward from center
			cam.translation.y = 0.5 # Head height
			camera_pivot.translation.y = 1.6
			$MeshInstance.visible = false # Hide body in 1st person
		CameraState.CLOSE:
			cam.translation.z = 3.5
			cam.translation.y = 0.0
			camera_pivot.translation.y = 1.5
			$MeshInstance.visible = true
		CameraState.FAR:
			cam.translation.z = 10.0
			cam.translation.y = 0.0
			camera_pivot.translation.y = 1.0
			$MeshInstance.visible = true
		CameraState.VERY_FAR:
			cam.translation.z = 25.0
			cam.translation.y = 0.0
			camera_pivot.translation.y = 0.5
			$MeshInstance.visible = true

	# ------------------------------------------------------------------
	# LOGICA DE JINETE (CABALLO)
	# ------------------------------------------------------------------
func _physics_process(delta):
	# Camera rotation (Orbital) - SIEMPRE debe funcionar
	if look_dir.length() > 0.05:
		camera_pivot.rotate_y(-look_dir.x * rotation_speed * delta)
		var target_pitch = camera_pivot.rotation_degrees.x - look_dir.y * rotation_speed * delta * 40
		# COLLISION CHECK: Prevent camera from going underground
		var clamped_pitch = clamp(target_pitch, -60, 30)
		
		if wm and wm.has_method("get_terrain_height_at") and current_camera_state != CameraState.FIRST_PERSON:
			var cam_dist = $CameraPivot/Camera.translation.z
			var pivot_h = camera_pivot.global_transform.origin.y
			var cam_local_y = -sin(deg2rad(clamped_pitch)) * cam_dist
			var pred_cam_y = pivot_h + cam_local_y
			
			# Predecir posición global X/Z (Aproximada, asumiendo que el pitch no cambia X/Z drásticamente para este check de altura)
			# La cámara está detrás, así que X/Z dependen del YAW del pivot
			var yaw = camera_pivot.global_transform.basis.get_euler().y
			var cam_offset_flat = Vector3(0, 0, cam_dist * cos(deg2rad(clamped_pitch))).rotated(Vector3.UP, yaw)
			var pred_cam_pos = camera_pivot.global_transform.origin + cam_offset_flat
			
			var ground_h = wm.get_terrain_height_at(pred_cam_pos.x, pred_cam_pos.z)
			var safe_h = ground_h + 0.5 # Mantener 0.5m sobre el suelo
			
			if pred_cam_y < safe_h:
				# La cámara choca. Calcular el pitch máximo permitido.
				# pivot_h - sin(pitch)*dist = safe_h
				# sin(pitch) = (pivot_h - safe_h) / dist
				var val = (pivot_h - safe_h) / cam_dist
				val = clamp(val, -1.0, 1.0)
				var max_pitch = rad2deg(asin(val))
				
				# Si el pitch actual es mayor que el max (causa bajada), lo limitamos
				if clamped_pitch > max_pitch:
					clamped_pitch = max_pitch
		
		camera_pivot.rotation_degrees.x = clamped_pitch

	# ------------------------------------------------------------------
	# LOGICA DE JINETE (CABALLO)
	# ------------------------------------------------------------------
	if is_riding and current_horse:
		# Transmitir input del jugador al caballo
		current_horse.rider_input = move_dir
		current_horse.rider_sprinting = is_sprinting
		return

	if is_performing_action:
		velocity.x = 0; velocity.z = 0
		# Mantener pegado al suelo si cae
		if not is_on_floor(): velocity.y -= 25.0 * delta
		velocity = move_and_slide(velocity, Vector3.UP)
		return
		
	# ------------------------------------------------------------------
	# FIN LOGICA JINETE
	# ------------------------------------------------------------------

	# Movement (Camera-relative)
	var forward = -camera_pivot.global_transform.basis.z
	var right = camera_pivot.global_transform.basis.x
	
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	
	var direction = (forward * -move_dir.y + right * move_dir.x).normalized()
	
	# SPRINT: Multiply speed by 1.8x when sprinting
	var current_speed = speed * (1.8 if is_sprinting else 1.0)
	
	if direction.length() > 0.1:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = lerp(velocity.x, 0, 10 * delta)
		velocity.z = lerp(velocity.z, 0, 10 * delta)
	
	# Gravity Logic
	if is_on_floor() and velocity.y <= 0:
		velocity.y = -0.1 # Minimal force to keep grounded
	else:
		velocity.y -= 25.0 * delta
	
	# Snap logic to stick to slopes and stop_on_slope = true
	# CRITICAL: Disable snap when jumping (velocity.y > 0)
	var snap = Vector3.DOWN if is_on_floor() and velocity.y <= 0 else Vector3.ZERO
	velocity = move_and_slide_with_snap(velocity, snap, Vector3.UP, true, 4, deg2rad(45))
	
	# Additional fix: If on floor and no movement input, force horizontal velocity to zero
	if is_on_floor() and direction.length() <= 0.1:
		velocity.x = 0
		velocity.z = 0
	
	# Safety check for void
	if translation.y < -50:
		translation = Vector3(0, 60, 0)
		velocity = Vector3.ZERO
	
	# Visual rotation
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		$MeshInstance.rotation.y = lerp_angle($MeshInstance.rotation.y, target_rotation, 10 * delta)
	
	# Actualizar Animación Procedural
	var horizontal_vel = Vector3(velocity.x, 0, velocity.z)
	$WalkAnimator.update_physics_state(velocity.y, velocity, is_on_floor())
	$WalkAnimator.set_walking(is_on_floor() and horizontal_vel.length() > 0.1, horizontal_vel.length())

# --- FUNCIONES DE MONTURA ---
var is_riding = false
var current_horse = null

func try_mount_horse():
	# Buscar caballos cercanos
	var horses = get_tree().get_nodes_in_group("horses")
	var nearest_horse = null
	var min_dist = 99999.0
	
	for h in horses:
		var d = h.global_transform.origin.distance_to(global_transform.origin)
		if d < min_dist:
			min_dist = d
			nearest_horse = h
	
	if nearest_horse:
		if min_dist < 3.0:
			mount(nearest_horse)
		else:
			# El caballo está lejos, lo llamamos
			if nearest_horse.has_method("call_to_player"):
				nearest_horse.call_to_player(self)

func mount(horse_node):
	if is_riding: return
	
	is_riding = true
	current_horse = horse_node
	
	# Desactivar colisiones del jugador para no chocar con el caballo
	$CollisionShape.disabled = true
	
	# Emparentar al mount point
	var old_parent = get_parent()
	old_parent.remove_child(self)
	horse_node.get_node("MountPoint").add_child(self)
	
	# Resetear transform local (con offset de altura)
	translation = Vector3(0, 0.4, 0)
	rotation = Vector3.ZERO
	
	# ALINEAR CÁMARA DETRÁS DEL CABALLO
	camera_pivot.rotation = Vector3.ZERO
	look_dir = Vector2.ZERO # Resetear input de rotación
	
	# Notificar al caballo
	horse_node.interact(self)
	
	# ANIMACION Y ORIENTACION
	$WalkAnimator.set_riding(true, current_horse)
	# Forzar rotación 180 (Mirando hacia adelante si el modelo base mira a +Z)
	$MeshInstance.rotation_degrees.y = 180 
	
	# Ajustar cámara para cabalgata (más lejos)
	current_camera_state = CameraState.VERY_FAR
	update_camera_settings()

func dismount():
	if not is_riding: return
	
	# Restaurar padre original (WorldManager o Main3D)
	# HACK: Asumimos Main3D/WorldManager es el abuelo del caballo
	var world_node = current_horse.get_parent()
	
	var mount_p = get_parent()
	mount_p.remove_child(self)
	world_node.add_child(self)
	
	# Posicionar al lado del caballo
	global_transform.origin = current_horse.global_transform.origin + current_horse.global_transform.basis.x * 1.5
	
	is_riding = false
	$WalkAnimator.set_riding(false, null)
	
	current_horse.dismount()
	current_horse = null
	
	# Reactivar colisiones
	$CollisionShape.disabled = false
	
	# Restaurar cámara normal
	current_camera_state = CameraState.FAR
	update_camera_settings()
	
	if reins_line:
		reins_line.clear()

func _on_action_pressed():
	if is_performing_action or is_riding: return
	
	if _was_near_cow:
		_start_milking_sequence()
	elif _was_near_tree:
		_start_woodcutting_sequence()

func _start_woodcutting_sequence():
	if not current_target_tree_mmi: return
	
	is_performing_action = true
	
	# Orientar al jugador de lado al árbol (Pose de leñador real)
	var mm = current_target_tree_mmi.multimesh
	var itf = current_target_tree_mmi.global_transform * mm.get_instance_transform(current_target_tree_idx)
	
	# Declaración inicial de dirección requerida para el cálculo de posición
	var dir_to_tree = (itf.origin - global_transform.origin).normalized()
	
	# POSICIONAMIENTO AUTOMÁTICO (Acercarse/Alejarse a la distancia ideal)
	var ideal_dist = 1.3 # Distancia perfecta para el hachazo (metros)
	var target_pos = itf.origin - dir_to_tree * ideal_dist # Punto ideal frente al árbol
	target_pos.y = global_transform.origin.y # Mantener altura del suelo actual
	
	# Usar Tween para mover al jugador suavemente a la posición correcta
	var tween = get_tree().create_tween()
	tween.tween_property(self, "translation", target_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	yield(tween, "finished")
	
	# RE-CALCULAR Rotación después de moverse (para precisión al pixel)
	dir_to_tree = (itf.origin - global_transform.origin).normalized()
	var target_rot = atan2(dir_to_tree.x, dir_to_tree.z)
	
	# Rotar 45 grados para que el golpe diagonal intercepte perfectamente el tronco
	$MeshInstance.rotation.y = target_rot - deg2rad(45.0)
	
	# Activar animación de talado
	if $WalkAnimator.has_method("set_chopping"):
		$WalkAnimator.set_chopping(true)
	
	# Esperar 3 segundos
	yield(get_tree().create_timer(3.0), "timeout")
	
	_finish_woodcutting()

func _finish_woodcutting():
	is_performing_action = false
	if $WalkAnimator.has_method("set_chopping"):
		$WalkAnimator.set_chopping(false)
		
	# ELIMINAR EL ÁRBOL ESPECÍFICO (Solo ese índice, en todas sus partes)
	if is_instance_valid(current_target_tree_mmi) and current_target_tree_mmi.multimesh:
		var tile = current_target_tree_mmi.get_parent().get_parent() # DecoContainer -> Tile
		var container = current_target_tree_mmi.get_parent()
		var target_idx = current_target_tree_idx
		var target_group = "tree_mmi" if current_target_tree_mmi.is_in_group("tree_mmi") else "cactus_mmi"
		
		# 1. Persistencia: Informar al Tile que este árbol ha muerto para siempre
		if tile.has_method("mark_instance_as_harvested"):
			tile.mark_instance_as_harvested(target_group, target_idx)
		
		# 2. Visual: Hacerlo invisible inmediatamente en TODAS las partes (MMIs hermanos)
		for child in container.get_children():
			if child is MultiMeshInstance and child.multimesh and child.is_in_group(target_group):
				var mm = child.multimesh
				if target_idx >= 0 and target_idx < mm.instance_count:
					var tf = mm.get_instance_transform(target_idx)
					tf = tf.scaled(Vector3.ZERO)
					mm.set_instance_transform(target_idx, tf)

	# AGREGAR MADERA
	if has_node("/root/InventoryManager"):
		get_node("/root/InventoryManager").add_item("wood", 3)
	
	current_target_tree_mmi = null
	current_target_tree_idx = -1

func _start_milking_sequence():
	# Buscar la vaca más cercana para orientarnos
	var cows = get_tree().get_nodes_in_group("cow")
	var nearest = null
	var min_d = 99.0
	for c in cows:
		var d = c.global_transform.origin.distance_to(global_transform.origin)
		if d < min_d:
			min_d = d
			nearest = c
	
	if nearest:
		is_performing_action = true
		milking_target_cow = nearest
		
		# Orientar al jugador hacia la vaca
		var dir_to_cow = (nearest.global_transform.origin - global_transform.origin).normalized()
		var target_rot = atan2(dir_to_cow.x, dir_to_cow.z)
		$MeshInstance.rotation.y = target_rot
		
		# Acercarse un poco más automáticamente si está lejos
		if min_d > 1.8:
			var target_pos = nearest.global_transform.origin - dir_to_cow * 1.5
			global_transform.origin.x = target_pos.x
			global_transform.origin.z = target_pos.z
		
		# Activar animación en el WalkAnimator
		if $WalkAnimator.has_method("set_milking"):
			$WalkAnimator.set_milking(true)
		
		# Esperar 3 segundos
		yield(get_tree().create_timer(3.0), "timeout")
		
		# Finalizar ordeño
		_finish_milking()

func _finish_milking():
	is_performing_action = false
	if $WalkAnimator.has_method("set_milking"):
		$WalkAnimator.set_milking(false)
		
	# Agregar leche al inventario
	if has_node("/root/InventoryManager"):
		get_node("/root/InventoryManager").add_item("milk", 1)
	
	milking_target_cow = null
