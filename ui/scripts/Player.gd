extends KinematicBody

export var speed = 10.0
export var rotation_speed = 2.0
var velocity = Vector3.ZERO
var move_dir = Vector2.ZERO
var look_dir = Vector2.ZERO
var mouse_sensitivity = 0.1

onready var camera_pivot = $CameraPivot

func _ready():
	translation.y = 10.0 # Safety height to avoid spawning inside/below terrain
	var hud = get_tree().root.find_node("MainHUD", true, false)
	if hud:
		hud.connect("joystick_moved", self, "_on_joystick_moved")
		hud.connect("camera_moved", self, "_on_camera_moved")

func _on_joystick_moved(vector):
	move_dir = Vector2(vector.x, vector.y) # x is strafe, y is forward/back

func _on_camera_moved(vector):
	look_dir = vector

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
		velocity.y = -0.5
	else:
		velocity.y -= 25.0 * delta
	
	velocity = move_and_slide(velocity, Vector3.UP)
	
	# Safety check for void
	if translation.y < -50:
		translation = Vector3(0, 10, 0)
		velocity = Vector3.ZERO
	
	# Visual rotation (ONLY the MeshInstance, not the body, to avoid camera feedback loop)
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		$MeshInstance.rotation.y = lerp_angle($MeshInstance.rotation.y, target_rotation, 10 * delta)
