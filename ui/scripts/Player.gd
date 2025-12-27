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
	translation.y = 10.0 # Safety height to avoid spawning inside/below terrain
	var hud = get_tree().root.find_node("MainHUD", true, false)
	if hud:
		hud.connect("joystick_moved", self, "_on_joystick_moved")
		hud.connect("camera_moved", self, "_on_camera_moved")
		hud.connect("zoom_pressed", self, "_on_zoom_pressed")
	
	update_camera_settings()

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

func _physics_process(delta):
	# Camera rotation (Orbital)
	if look_dir.length() > 0.05:
		camera_pivot.rotate_y(-look_dir.x * rotation_speed * delta)
		var target_pitch = camera_pivot.rotation_degrees.x - look_dir.y * rotation_speed * delta * 40
		camera_pivot.rotation_degrees.x = clamp(target_pitch, -60, 30)

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
		translation = Vector3(0, 10, 0)
		velocity = Vector3.ZERO
	
	# Visual rotation
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		$MeshInstance.rotation.y = lerp_angle($MeshInstance.rotation.y, target_rotation, 10 * delta)
	
	# Actualizar Animación Procedural
	var horizontal_vel = Vector3(velocity.x, 0, velocity.z)
	$WalkAnimator.set_walking(is_on_floor() and horizontal_vel.length() > 0.1, horizontal_vel.length())
