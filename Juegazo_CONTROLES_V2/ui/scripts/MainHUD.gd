extends Control

signal joystick_moved(vector)
signal camera_moved(vector)

# Joysticks
onready var left_joy = $LeftConsole/JoystickWell/Handle
onready var right_joy = $RightConsole/CamJoystickWell/Handle

var left_center = Vector2(90, 90)
var right_center = Vector2(90, 90)
var joy_radius = 50.0

var left_active = false
var right_active = false

# Botones con feedback
onready var buttons = {
	"fire": $RightConsole/Actions/Fire,
	"jump": $RightConsole/Actions/Jump,
	"magic": $RightConsole/Actions/Magic,
	"attack": $RightConsole/Actions/Attack,
	"bolt": $LeftConsole/Shortcuts/Bolt,
	"shield": $LeftConsole/Shortcuts/Shield,
	"map": $LeftConsole/Shortcuts/LocalMap,
	"inv": $LeftConsole/Shortcuts/Inventory
}

func _ready():
	# Inicializar posiciones de joysticks
	left_joy.rect_position = left_center - left_joy.rect_size / 2
	right_joy.rect_position = right_center - right_joy.rect_size / 2
	
	# Conectar eventos de botones (simulados con ColorRects por el shader)
	for btn_name in buttons:
		var btn = buttons[btn_name]
		btn.connect("gui_input", self, "_on_button_input", [btn_name])

func _input(event):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pos = event.position
		if event.pressed:
			if left_joy.get_global_rect().has_point(pos):
				left_active = true
			elif right_joy.get_global_rect().has_point(pos):
				right_active = true
		else:
			left_active = false
			right_active = false
			left_joy.rect_position = left_center - left_joy.rect_size / 2
			right_joy.rect_position = right_center - right_joy.rect_size / 2
			emit_signal("joystick_moved", Vector2.ZERO)
			emit_signal("camera_moved", Vector2.ZERO)

	if event is InputEventScreenDrag or (event is InputEventMouseMotion and (left_active or right_active)):
		var pos = event.position
		if left_active:
			update_joystick(pos, left_joy, left_center, "joystick_moved")
		elif right_active:
			update_joystick(pos, right_joy, right_center, "camera_moved")

func update_joystick(touch_pos, joy_node, center_local, signal_name):
	var local_pos = joy_node.get_parent().make_input_local(InputEventMouseMotion.new()).position
	# Simplificación para mover el handle
	var parent_rect = joy_node.get_parent().get_global_rect()
	var vector = (touch_pos - (parent_rect.position + center_local))
	if vector.length() > joy_radius:
		vector = vector.normalized() * joy_radius
	
	joy_node.rect_position = center_local + vector - joy_node.rect_size / 2
	emit_signal(signal_name, vector / joy_radius)

func _on_button_input(event, btn_name):
	var btn = buttons[btn_name]
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			animate_button_press(btn)
		else:
			animate_button_release(btn)

func animate_button_press(node):
	var tween = get_tree().create_tween()
	tween.tween_property(node, "rect_scale", Vector2(0.92, 0.92), 0.05)
	# Podríamos cambiar parámetros del shader aquí también

func animate_button_release(node):
	var tween = get_tree().create_tween()
	tween.tween_property(node, "rect_scale", Vector2(1.0, 1.0), 0.1)

func set_health(val_percent):
	$Header/StatusBars/HealthBar/Fill.material.set_shader_param("value", val_percent)

func set_mana(val_percent):
	$Header/StatusBars/HealthBar/ManaBar/Fill.material.set_shader_param("value", val_percent)
