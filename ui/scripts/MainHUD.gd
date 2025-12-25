extends Control

signal joystick_moved(vector)
signal camera_moved(vector)

# Joysticks (Ahora en contenedores flotantes sin panel)
onready var left_joy = $MoveJoystickContainer/JoystickWell/Handle
onready var right_joy = $CamJoystickContainer/JoystickWell/Handle

var left_center = Vector2(90, 90)
var right_center = Vector2(90, 90)
var joy_radius = 50.0

var left_touch_index = -1
var right_touch_index = -1

# Botones con estilos premium (Flotantes)
onready var buttons = {
	"fire": $ActionsContainer/Fire,
	"jump": $ActionsContainer/Jump,
	"magic": $ActionsContainer/Magic,
	"attack": $ActionsContainer/Attack,
	"bolt": $ShortcutsContainer/Bolt,
	"shield": $ShortcutsContainer/Shield,
	"map": $ShortcutsContainer/Map,
	"inv": $ShortcutsContainer/Inv
}

func _ready():
	# Inicializar posiciones de joysticks originales
	left_joy.rect_position = left_center - left_joy.rect_size / 2
	right_joy.rect_position = right_center - right_joy.rect_size / 2
	
	# Conectar eventos de botones
	for btn_name in buttons:
		var btn = buttons[btn_name]
		btn.connect("gui_input", self, "_on_button_input", [btn_name])

func _input(event):
	var touch_pos = Vector2.ZERO
	var is_touch_event = false
	var index = 0
	
	if event is InputEventScreenTouch:
		touch_pos = event.position
		is_touch_event = true
		index = event.index
	elif event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		touch_pos = event.position
		is_touch_event = true
		index = 0
	
	if is_touch_event:
		if event.pressed:
			if left_touch_index == -1 and $MoveJoystickContainer/JoystickWell.get_global_rect().has_point(touch_pos):
				left_touch_index = index
			elif right_touch_index == -1 and $CamJoystickContainer/JoystickWell.get_global_rect().has_point(touch_pos):
				right_touch_index = index
		else:
			if index == left_touch_index:
				left_touch_index = -1
				reset_joy(left_joy, left_center, "joystick_moved")
			elif index == right_touch_index:
				right_touch_index = -1
				reset_joy(right_joy, right_center, "camera_moved")

	if event is InputEventScreenDrag or (event is InputEventMouseMotion and (left_touch_index != -1 or right_touch_index != -1)):
		var move_pos = event.position
		var move_index = event.index if (event is InputEventScreenDrag or event is InputEventScreenTouch) else 0
		
		if move_index == left_touch_index:
			update_joystick(move_pos, left_joy, left_center, "joystick_moved")
		elif move_index == right_touch_index:
			update_joystick(move_pos, right_joy, right_center, "camera_moved")

func update_joystick(touch_pos, joy_node, center_local, signal_name):
	var parent_rect = joy_node.get_parent().get_global_rect()
	var vector = (touch_pos - (parent_rect.position + center_local))
	if vector.length() > joy_radius:
		vector = vector.normalized() * joy_radius
	
	joy_node.rect_position = center_local + vector - joy_node.rect_size / 2
	emit_signal(signal_name, vector / joy_radius)

func reset_joy(joy_node, center_local, signal_name):
	joy_node.rect_position = center_local - joy_node.rect_size / 2
	emit_signal(signal_name, Vector2.ZERO)

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

func animate_button_release(node):
	var tween = get_tree().create_tween()
	tween.tween_property(node, "rect_scale", Vector2(1.0, 1.0), 0.1)

func set_health(val_percent):
	$Header/StatusBars/HealthBarCont/HealthBar.material.set_shader_param("value", val_percent)

func set_mana(val_percent):
	$Header/StatusBars/ManaBarCont/ManaBar.material.set_shader_param("value", val_percent)
