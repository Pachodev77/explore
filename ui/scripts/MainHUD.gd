extends Control

signal joystick_moved(vector)
signal camera_moved(vector)
signal zoom_pressed()
signal mount_pressed()
signal run_pressed(is_active)
signal jump_pressed()
signal torch_pressed()

func set_mount_visible(is_visible):
	if buttons.has("mount"):
		buttons["mount"].visible = is_visible

# Joysticks (Ahora en contenedores flotantes sin panel)
onready var left_joy = $MoveJoystickContainer/JoystickWell/Handle
onready var right_joy = $CamJoystickContainer/JoystickWell/Handle
onready var pause_btn = $Header/PauseBtn

var pause_panel_instance = null

var left_center = Vector2(120, 120)
var right_center = Vector2(120, 120)
var joy_radius = 70.0

var left_touch_index = -1
var right_touch_index = -1

# Tween reutilizable (OPTIMIZACIÓN: evita crear/destruir nodos constantemente)
var button_tween : Tween

# Panel de configuración (Se buscará dinámicamente si es nulo)
var settings_panel : Control

# Botones con estilos premium (Flotantes)
onready var buttons = {
	"attack": $ActionsContainer/Attack,
	"jump": $ActionsContainer/Jump,
	"shield": $ShortcutsContainer/Shield,
	"map": $ShortcutsContainer/Map,
	"zoom": $ShortcutsContainer/Zoom,
	"torch": $ShortcutsContainer/Torch,
	"mount": $ActionsContainer/Mount,
	"run": $ActionsContainer/Run
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
	
	# FIX: Los contenedores padre bloquean input si se solapan. Ponerlos en IGNORE.
	# Solo los hijos interactivos (botones, joysticks) deben capturar input.
	$MoveJoystickContainer.mouse_filter = MOUSE_FILTER_IGNORE
	$CamJoystickContainer.mouse_filter = MOUSE_FILTER_IGNORE
	$ActionsContainer.mouse_filter = MOUSE_FILTER_IGNORE
	$ShortcutsContainer.mouse_filter = MOUSE_FILTER_IGNORE
	$Header.mouse_filter = MOUSE_FILTER_IGNORE
	$Sidebar.mouse_filter = MOUSE_FILTER_IGNORE  # CRÍTICO: Permitir que los toques lleguen a los botones hijos
	
	# Conectar eventos de botones de acción (REVERTIDO A GUI_INPUT para compatibilidad total)
	for btn_name in buttons:
		var btn = buttons[btn_name]
		if not btn: continue
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.focus_mode = Control.FOCUS_NONE 
		btn.connect("gui_input", self, "_on_button_input", [btn_name])
	
	# Conectar eventos de botones de la barra lateral (GUI_INPUT)
	for btn_name in sidebar_buttons:
		var btn = sidebar_buttons[btn_name]
		if not btn: continue
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.focus_mode = Control.FOCUS_NONE
		btn.connect("gui_input", self, "_on_sidebar_button_input", [btn_name])
	
	# Buscar panel de configuración si existe en la raíz
	settings_panel = get_tree().root.find_node("SettingsPanel", true, false)
	
	# Forzar escalado de moneda
	$Header/Currency/Diamonds/H/Icon.rect_min_size = Vector2(36, 36)
	$Header/Currency/Gold/H/Icon.rect_min_size = Vector2(32, 32)
	
	# Instanciar MapPanel
	var map_scene = load("res://ui/scenes/MapPanel.tscn")
	if map_scene:
		var map_panel = map_scene.instance()
		map_panel.name = "MapPanel"
		map_panel.visible = false
		add_child(map_panel)
		
		# Conectar botón cerrar
		var close_btn = map_panel.get_node_or_null("Background/CloseButton")
		if close_btn:
			close_btn.connect("pressed", self, "_on_map_close")
	
	_style_buttons()
	
	# Etiqueta para el botón de antorcha
	if buttons.has("torch"):
		var label = Label.new()
		label.text = "TORCH"
		label.align = Label.ALIGN_CENTER
		label.valign = Label.VALIGN_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE # CRÍTICO: No bloquear clics
		label.set_anchors_and_margins_preset(Control.PRESET_WIDE)
		buttons["torch"].add_child(label)
	
	# FIX Z-ORDER: Sidebar debe estar ENCIMA de los joysticks para recibir input
	$Sidebar.raise()
	
	# SETUP SISTEMA DE PAUSA
	if pause_btn:
		pause_btn.connect("gui_input", self, "_on_pause_btn_input")
	
	var pause_scn = load("res://ui/scenes/PausePanel.tscn")
	if pause_scn:
		pause_panel_instance = pause_scn.instance()
		add_child(pause_panel_instance)
		pause_panel_instance.visible = false
		pause_panel_instance.connect("resume_requested", self, "_on_resume")
		pause_panel_instance.connect("save_requested", self, "_on_save")
		pause_panel_instance.connect("load_requested", self, "_on_load")
		pause_panel_instance.connect("main_menu_requested", self, "_on_main_menu")

func _style_buttons():
	# Crear materiales programáticamente para asegurar consistencia
	var mat_red = ShaderMaterial.new()
	mat_red.shader = load("res://ui/shaders/console_button.shader")
	mat_red.set_shader_param("color_top", Color(0.93, 0.27, 0.27))
	mat_red.set_shader_param("color_bottom", Color(0.6, 0.1, 0.1))
	mat_red.set_shader_param("corner_radius", 0.5)
	
	var mat_blue = ShaderMaterial.new()
	mat_blue.shader = load("res://ui/shaders/console_button.shader")
	mat_blue.set_shader_param("color_top", Color(0.26, 0.6, 1.0))
	mat_blue.set_shader_param("color_bottom", Color(0.06, 0.09, 0.16))
	mat_blue.set_shader_param("corner_radius", 0.5)
	
	# Aplicar a botones derechos (ROJO)
	for b in ["attack", "jump", "mount", "run"]:
		if buttons.has(b): buttons[b].material = mat_red
	
	# Joystick Derecho (Rojo)
	if right_joy: right_joy.material = mat_red
		
	# Aplicar a botones izquierdos (AZUL)
	for b in ["bolt", "shield", "map", "zoom", "torch"]:
		if buttons.has(b): buttons[b].material = mat_blue
	
	# Joystick Izquierdo (Azul)
	if left_joy: left_joy.material = mat_blue

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
			# EXCLUSIÓN: Si el toque cayó sobre un botón de la UI, el joystick NO debe capturarlo.
			# Godot suele manejar esto, pero con toques múltiples a veces se cruzan.
			
			# Solo capturar si está DENTRO de un joystick
			if left_touch_index == -1 and $MoveJoystickContainer/JoystickWell.get_global_rect().has_point(touch_pos):
				left_touch_index = index
				get_tree().set_input_as_handled()
			elif right_touch_index == -1 and $CamJoystickContainer/JoystickWell.get_global_rect().has_point(touch_pos):
				right_touch_index = index
				get_tree().set_input_as_handled()
		else:
			# Release
			if index == left_touch_index:
				left_touch_index = -1
				reset_joy(left_joy, left_center)
				emit_signal("joystick_moved", Vector2.ZERO)
				get_tree().set_input_as_handled()
			elif index == right_touch_index:
				right_touch_index = -1
				reset_joy(right_joy, right_center)
				emit_signal("camera_moved", Vector2.ZERO)
				get_tree().set_input_as_handled()

	if event is InputEventScreenDrag or (event is InputEventMouseMotion and (left_touch_index != -1 or right_touch_index != -1)):
		var move_pos = event.position
		var move_index = event.index if (event is InputEventScreenDrag or event is InputEventScreenTouch) else 0
		
		if move_index == left_touch_index:
			var vec = update_joystick(move_pos, left_joy, left_center)
			emit_signal("joystick_moved", vec)
			get_tree().set_input_as_handled()
		elif move_index == right_touch_index:
			var vec = update_joystick(move_pos, right_joy, right_center)
			emit_signal("camera_moved", vec)
			get_tree().set_input_as_handled()

func update_joystick(touch_pos, joy_node, center_local):
	var parent_rect = joy_node.get_parent().get_global_rect()
	var vector = (touch_pos - (parent_rect.position + center_local))
	if vector.length() > joy_radius:
		vector = vector.normalized() * joy_radius
	
	joy_node.rect_position = center_local + vector - joy_node.rect_size / 2
	return vector / joy_radius

func reset_joy(joy_node, center_local):
	joy_node.rect_position = center_local - joy_node.rect_size / 2

var last_press_time = 0

func _on_button_input(event, btn_name):
	var btn = buttons[btn_name]
	if not btn: return
	
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			# DEBOUNCE: Solo para el inicio de la pulsación
			var now = OS.get_ticks_msec()
			if now - last_press_time < 150: return 
			last_press_time = now
			
			print("DEBUG: Botón clickeado: ", btn_name)
			animate_button_press(btn)
			
			# Acciones Instantáneas (se ejecutan al pulsar)
			if btn_name == "zoom":
				emit_signal("zoom_pressed")
			elif btn_name == "torch":
				print("DEBUG: Emitiendo torch_pressed")
				emit_signal("torch_pressed")
			elif btn_name == "map":
				var map_panel = get_node_or_null("MapPanel")
				if map_panel: map_panel.visible = !map_panel.visible
			elif btn_name == "mount":
				emit_signal("mount_pressed")
			elif btn_name == "jump":
				emit_signal("jump_pressed")
			elif btn_name == "run":
				emit_signal("run_pressed", true)
			elif btn_name == "attack":
				pass # Futuro: emit_signal("attack_pressed", true)
		else:
			# RELEASE: El release siempre se procesa para evitar botones "pegados"
			animate_button_release(btn)
			if btn_name == "run":
				emit_signal("run_pressed", false)

func _on_sidebar_button_input(event, btn_name):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			# DEBOUNCE: Evitar el "doble toggle" en móvil (Touch + Mouse emulado)
			var now = OS.get_ticks_msec()
			if now - last_press_time < 150: return
			last_press_time = now
			
			var btn = sidebar_buttons[btn_name]
			if btn: animate_button_press(btn)
			
			# Lógica de paneles
			if btn_name == "map_sidebar":
				var map_panel = get_node_or_null("MapPanel")
				if map_panel: map_panel.visible = !map_panel.visible
			elif btn_name == "settings":
				if not settings_panel:
					settings_panel = get_tree().root.find_node("SettingsPanel", true, false)
				if settings_panel:
					settings_panel.visible = !settings_panel.visible
					settings_panel.raise()
		else:
			# Release animación
			var btn = sidebar_buttons[btn_name]
			if btn: animate_button_release(btn)

func animate_button_press(node):
	if not button_tween: return
	button_tween.stop_all()
	button_tween.interpolate_property(node, "rect_scale", node.rect_scale, Vector2(0.92, 0.92), 0.05, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	button_tween.start()

func animate_button_release(node):
	if not button_tween: return
	button_tween.stop_all()
	button_tween.interpolate_property(node, "rect_scale", node.rect_scale, Vector2(1.0, 1.0), 0.1, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	button_tween.start()

func set_health(val_percent):
	$Header/StatusBars/HealthBarCont/HealthBar.material.set_shader_param("value", val_percent)

func set_mana(val_percent):
	$Header/StatusBars/ManaBarCont/ManaBar.material.set_shader_param("value", val_percent)

func _process(_delta):
	# Actualizar brújula basado en la rotación de la cámara
	var cam = get_viewport().get_camera()
	if cam:
		# La rotación Y de la cámara nos da la dirección horizontal
		# El norte en Godot suele ser -Z (0 radianes en esta lógica)
		var rot_y = cam.global_transform.basis.get_euler().y
		# Rotamos el nodo completo para que roten las letras
		$Header/CompassCont/Compass.rect_rotation = rad2deg(rot_y)
		# Reseteamos la rotación interna del shader
		$Header/CompassCont/Compass.material.set_shader_param("rotation", 0.0)

func _on_map_close():
	var map_panel = get_node_or_null("MapPanel")
	if map_panel:
		map_panel.visible = false

# LÓGICA DE PAUSA
func _on_pause_btn_input(event):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_toggle_pause()

func _toggle_pause():
	var new_state = !get_tree().paused
	get_tree().paused = new_state
	if pause_panel_instance:
		pause_panel_instance.visible = new_state
		if new_state: pause_panel_instance.raise()

func _on_resume():
	_toggle_pause()

func _on_save():
	print("Game Saved! (Mock)")
	# Aquí iría la lógica real de guardado usando InventoryManager/WorldManager

func _on_load():
	print("Game Loaded! (Mock)")
	# Aquí iría la lógica real de carga

func _on_main_menu():
	get_tree().paused = false # IMPORTANTE: Despausar antes de cambiar escena
	get_tree().change_scene("res://ui/scenes/MainMenu.tscn")
