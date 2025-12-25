extends KinematicBody

export var speed = 10.0
var velocity = Vector3.ZERO
var move_dir = Vector2.ZERO
var look_dir = Vector2.ZERO

func _ready():
	var hud = get_parent().get_node_or_null("MainHUD")
	if hud:
		hud.connect("joystick_moved", self, "_on_joystick_moved")
		hud.connect("camera_moved", self, "_on_camera_moved")

func _on_joystick_moved(vector):
	move_dir = vector

func _on_camera_moved(vector):
	look_dir = vector

func _physics_process(delta):
    if is_on_floor():
        velocity.y = -0.1
    
    # Rotate player to movement direction
    if move_dir.length() > 0.1:
        var target_rotation = atan2(-move_dir.x, -move_dir.z)
        rotation.y = lerp_angle(rotation.y, target_rotation, 10 * delta)
