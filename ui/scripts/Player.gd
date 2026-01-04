extends KinematicBody

export var speed = 6.0
export var rotation_speed = 2.0
var velocity = Vector3.ZERO
var move_dir = Vector2.ZERO
var look_dir = Vector2.ZERO
var mouse_sensitivity = 0.1

enum CameraState { FIRST_PERSON, CLOSE, FAR, VERY_FAR }
var current_camera_state = CameraState.FAR

onready var camera_pivot = $CameraPivot

func _ready():
	# translation.y = 60.0 # REMOVED: Managed by WorldManager
	# ------------------------------------------------------------------
	# HUD CONNECTION
	# ------------------------------------------------------------------
	var hud = get_tree().root.find_node("MainHUD", true, false)
	if hud:
		hud.connect("joystick_moved", self, "_on_joystick_moved")
		hud.connect("camera_moved", self, "_on_camera_moved")
		hud.connect("zoom_pressed", self, "_on_zoom_pressed")
		hud.connect("mount_pressed", self, "_on_mount_pressed")
		self.hud_ref = hud # Guardar referencia para actualizar botón
	
	# Asegurar que la cámara inicie recta y sin inclinación
	# Asegurar que la cámara inicie recta y sin inclinación
	camera_pivot.rotation = Vector3.ZERO 
	rotation = Vector3.ZERO
	look_dir = Vector2.ZERO
	
	_init_reins()
	update_camera_settings()

var hud_ref = null

# --- SISTEMA DE RIENDAS ---
var reins_line : ImmediateGeometry

func _init_reins():
	if has_node("ReinsLine"):
		reins_line = get_node("ReinsLine")
	else:
		reins_line = ImmediateGeometry.new()
		reins_line.name = "ReinsLine"
		var m = SpatialMaterial.new()
		m.albedo_color = Color(0.3, 0.2, 0.1) # Cuero marrón
		m.flags_unshaded = true # Visible siempre
		# params_line_width solo funciona en GLES2 o con flags específicos, 
		# pero ImmediateGeometry dibuja líneas finas por defecto.
		reins_line.material_override = m
		add_child(reins_line)

func _process(_delta):
	if is_riding and current_horse and reins_line:
		_draw_reins()
	elif reins_line:
		reins_line.clear()

func _draw_reins():
	reins_line.clear()
	reins_line.begin(Mesh.PRIMITIVE_LINE_STRIP)
	
	# 1. Punto de origen: Promedio de las Manos del jugador
	# Estimación base: Frente al ombligo
	var hand_pos = global_transform.origin + Vector3(0, 1.05, 0.4).rotated(Vector3.UP, rotation.y)
	
	if $MeshInstance.get("skel_node"):
		var skel = $MeshInstance.skel_node
		var h_l = skel.find_bone("HandL")
		var h_r = skel.find_bone("HandR")
		if h_l != -1 and h_r != -1:
			var p_l = skel.global_transform.xform(skel.get_bone_global_pose(h_l).origin)
			var p_r = skel.global_transform.xform(skel.get_bone_global_pose(h_r).origin)
			hand_pos = (p_l + p_r) * 0.5

	# 2. Punto destino: Boca del caballo (Nodo ReinAnchor)
	# IMPORTANTE: La ruta incluye ProceduralMesh
	var mouth_pos = current_horse.global_transform.origin + Vector3(0, 1.5, 0.8) # Fallback
	var anchor_path = "ProceduralMesh/BodyRoot/NeckBase/NeckMid/Head/ReinAnchor"
	if current_horse.has_node(anchor_path):
		mouth_pos = current_horse.get_node(anchor_path).global_transform.origin
	elif current_horse.has_node("ProceduralMesh"):
		# Intento de búsqueda relativa si la estructura varió
		var pm = current_horse.get_node("ProceduralMesh")
		var anchor = pm.find_node("ReinAnchor", true, false)
		if anchor:
			mouth_pos = anchor.global_transform.origin
	
	# 3. Dibujar Curva (Bosal slack)
	var mid_point = (hand_pos + mouth_pos) * 0.5
	mid_point.y -= 0.35 # Más comba para parecer una cuerda suelta de bosal
	
	for i in range(11):
		var t = i / 10.0
		var q0 = hand_pos.linear_interpolate(mid_point, t)
		var q1 = mid_point.linear_interpolate(mouth_pos, t)
		var p = q0.linear_interpolate(q1, t)
		reins_line.add_vertex(reins_line.to_local(p))
	
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
		camera_pivot.rotation_degrees.x = clamp(target_pitch, -60, 30)

	# ------------------------------------------------------------------
	# LOGICA DE JINETE (CABALLO)
	# ------------------------------------------------------------------
	if is_riding and current_horse:
		# Al estar montado, el jugador solo sigue al caballo
		# La posición ya es relativa al mount_point (0,0,0) -> Ajuste visual Y+0.4
		transform.origin = Vector3(0, 0.4, 0)
		rotation = Vector3.ZERO
		
		# Pasamos el input al caballo para que él se mueva
		current_horse.rider_input = move_dir
		
		# Opción: Permitir rotar la cámara independientemente, 
		# pero el cuerpo del jugador sigue al caballo.
		return # Saltamos el resto de física del jugador
		
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
	
	if direction.length() > 0.1:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = lerp(velocity.x, 0, 10 * delta)
		velocity.z = lerp(velocity.z, 0, 10 * delta)
	
	# Gravity Logic
	if is_on_floor():
		velocity.y = -0.1 # Minimal force to keep grounded
	else:
		velocity.y -= 25.0 * delta
	
	# Snap logic to stick to slopes and stop_on_slope = true
	var snap = Vector3.DOWN if is_on_floor() else Vector3.ZERO
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
	$WalkAnimator.set_walking(is_on_floor() and horizontal_vel.length() > 0.1, horizontal_vel.length())

# --- FUNCIONES DE MONTURA ---
var is_riding = false
var current_horse = null

func try_mount_horse():
	# Buscar caballos cercanos
	var area = get_world().direct_space_state
	var shape = SphereShape.new()
	shape.radius = 3.0
	
	# Detectar (simplificado: buscamos grupo "horses" o clase Horse)
	# Por ahora, detección manual fea pero funcional
	var horses = get_tree().get_nodes_in_group("horses")
	for h in horses:
		if h.global_transform.origin.distance_to(global_transform.origin) < 3.0:
			mount(h)
			break

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
