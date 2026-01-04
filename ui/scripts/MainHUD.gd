extends Control

signal joystick_moved(vector)
signal camera_moved(vector)
signal zoom_pressed()
signal mount_pressed()

func set_mount_visible(is_visible):
	if buttons.has("mount"):
		buttons["mount"].visible = is_visible

# Joysticks (Ahora en contenedores flotantes sin panel)
onready var left_joy = $MoveJoystickContainer/JoystickWell/Handle
onready var right_joy = $CamJoystickContainer/JoystickWell/Handle

var left_center = Vector2(120, 120)
var right_center = Vector2(120, 120)
var joy_radius = 70.0

var left_touch_index = -1
var right_touch_index = -1

# Tween reutilizable (OPTIMIZACIÓN: evita crear/destruir nodos constantemente)
var button_tween : Tween

# Panel de configuración
onready var settings_panel = get_node_or_null("../SettingsPanel")

# Botones con estilos premium (Flotantes)
onready var buttons = {
	"jump": $ActionsContainer/Jump,
	"magic": $ActionsContainer/Magic,
	"attack": $ActionsContainer/Attack,
	"bolt": $ShortcutsContainer/Bolt,
	"shield": $ShortcutsContainer/Shield,
	"map": $ShortcutsContainer/Map,
	"zoom": $ShortcutsContainer/Zoom,
	"mount": $ActionsContainer/Mount
}

# Botones de la barra lateral
onready var sidebar_buttons = {
	"backpack": $Sidebar/Backpack,
	"map_sidebar": $Sidebar/Map,
	"social": $Sidebar/Social,
	"settings": $Sidebar/Settings
}

func _ready():
	# Crear Tween reutilizable
	button_tween = Tween.new()
	add_child(button_tween)
	
	# Inicializar posiciones de joysticks originales
	left_joy.rect_position = left_center - left_joy.rect_size / 2
	right_joy.rect_position = right_center - right_joy.rect_size / 2
	
	# Conectar eventos de botones de acción
	for btn_name in buttons:
		var btn = buttons[btn_name]
		btn.connect("gui_input", self, "_on_button_input", [btn_name])
	
	# Conectar eventos de botones de la barra lateral
	for btn_name in sidebar_buttons:
		var btn = sidebar_buttons[btn_name]
		btn.connect("gui_input", self, "_on_sidebar_button_input", [btn_name])
	
	# Forzar escalado de moneda (los contenedores a veces ignoran el tscn)
	$Header/Currency/Diamonds/H/Icon.rect_min_size = Vector2(36, 36)
	$Header/Currency/Diamonds/H/Value.rect_scale = Vector2(1.6, 1.6)
	$Header/Currency/Gold/H/Icon.rect_min_size = Vector2(32, 32)
	$Header/Currency/Gold/H/Value.rect_scale = Vector2(1.6, 1.6)

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
			if btn_name == "zoom":
				emit_signal("zoom_pressed")
			elif btn_name == "map":
				# Abrir panel de configuración
				if settings_panel:
					settings_panel.visible = !settings_panel.visible
			elif btn_name == "mount":
				emit_signal("mount_pressed")
		else:
			animate_button_release(btn)

func animate_button_press(node):
	# Usar el Tween reutilizable (OPTIMIZACIÓN)
	button_tween.stop_all()
	button_tween.interpolate_property(node, "rect_scale", node.rect_scale, Vector2(0.92, 0.92), 0.05, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	button_tween.start()

func animate_button_release(node):
	# Usar el Tween reutilizable (OPTIMIZACIÓN)
	button_tween.stop_all()
	button_tween.interpolate_property(node, "rect_scale", node.rect_scale, Vector2(1.0, 1.0), 0.1, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	button_tween.start()

func _on_sidebar_button_input(event, btn_name):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			print("Botón sidebar presionado:", btn_name)
			if btn_name == "settings":
				# Abrir panel de configuración
				if settings_panel:
					settings_panel.visible = !settings_panel.visible
					print("Panel de configuración:", "VISIBLE" if settings_panel.visible else "OCULTO")
				else:
					print("ERROR: settings_panel no encontrado")

func set_health(val_percent):
	$Header/StatusBars/HealthBarCont/HealthBar.material.set_shader_param("value", val_percent)

func set_mana(val_percent):
	$Header/StatusBars/ManaBarCont/ManaBar.material.set_shader_param("value", val_percent)
