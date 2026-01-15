extends Control

signal joystick_moved(vector)
signal camera_moved(vector)
signal zoom_pressed()
signal mount_pressed()
signal run_pressed(is_active)
signal jump_pressed()
signal torch_pressed()
signal action_pressed()

func set_mount_visible(is_visible):
	if buttons.has("mount"):
		buttons["mount"].visible = is_visible

func set_action_label(new_text):
	if buttons.has("map"):
		for child in buttons["map"].get_children():
			if child is Label:
				child.text = new_text
				break

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

# Botones de la barra lateral (Izquierda y Derecha)
onready var sidebar_buttons = {
	"backpack": $Sidebar/Backpack,
	"map_sidebar": $Sidebar/Map,
	"social": $Sidebar/Social,
	"settings": $Sidebar/Settings,
	"quests": $RightSidebar/Slot1,
	"crafting": $RightSidebar/Slot2,
	"skills": $RightSidebar/Slot3,
	"inventory_right": $RightSidebar/Slot4
}

var notify_container : VBoxContainer

func _ready():
	ServiceLocator.register_service("hud", self)
	
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
	$RightSidebar.mouse_filter = MOUSE_FILTER_IGNORE
	
	# Pre-configurar pivotes para animaciones (escala desde el centro)
	for b in buttons.values():
		if b: b.rect_pivot_offset = b.rect_size / 2
	for b in sidebar_buttons.values():
		if b: b.rect_pivot_offset = b.rect_size / 2
	
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
	
	# 1. Crear contenedor de notificaciones (Arriba Centrado)
	notify_container = VBoxContainer.new()
	notify_container.name = "NotificationContainer"
	notify_container.set_anchors_and_margins_preset(Control.PRESET_CENTER_TOP)
	notify_container.margin_top = 20 # Un poco de espacio desde el borde superior
	notify_container.margin_left = -115 # Centrado con desplazamiento acumulado a la derecha
	notify_container.margin_right = 185
	notify_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notify_container.add_constant_override("separation", 8)
	add_child(notify_container)
	
	# 2. Conectar al sistema de inventario real
	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		inv.connect("item_added", self, "_on_item_added")
	
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
	
	# Instanciar InventoryPanel
	var inv_scene = load("res://ui/scenes/InventoryPanel.tscn")
	if inv_scene:
		var inv_panel = inv_scene.instance()
		inv_panel.name = "InventoryPanel"
		inv_panel.visible = false
		add_child(inv_panel)
	
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
	
	# Etiqueta para el botón de ACCIÓN (antiguo botón de mapa)
	if buttons.has("map"):
		var label = Label.new()
		label.text = "ACTION"
		label.align = Label.ALIGN_CENTER
		label.valign = Label.VALIGN_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_and_margins_preset(Control.PRESET_WIDE)
		buttons["map"].add_child(label)
	
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
			GameEvents.emit_signal("joystick_moved", vec)
			get_tree().set_input_as_handled()
		elif move_index == right_touch_index:
			var vec = update_joystick(move_pos, right_joy, right_center)
			emit_signal("camera_moved", vec)
			GameEvents.emit_signal("camera_moved", vec)
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
			
			animate_button_press(btn)
			
			# Acciones Instantáneas (se ejecutan al pulsar)
			if btn_name == "zoom":
				emit_signal("zoom_pressed")
			elif btn_name == "torch":
				emit_signal("torch_pressed")
			elif btn_name == "map":
				# Ahora funciona como botón de Acción
				emit_signal("action_pressed")
				GameEvents.emit_signal("action_pressed", "interact")
			elif btn_name == "mount":
				emit_signal("mount_pressed")
			elif btn_name == "jump":
				emit_signal("jump_pressed")
			elif btn_name == "run":
				emit_signal("run_pressed", true)
			elif btn_name == "attack":
				GameEvents.emit_signal("action_pressed", "attack")
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
			if btn_name == "backpack":
				var inv_panel = get_node_or_null("InventoryPanel")
				if inv_panel:
					inv_panel.visible = !inv_panel.visible
					if inv_panel.visible: inv_panel.raise()
			elif btn_name == "map_sidebar":
				var map_panel = get_node_or_null("MapPanel")
				if map_panel: map_panel.visible = !map_panel.visible
			elif btn_name == "settings":
				if not settings_panel:
					settings_panel = get_tree().root.find_node("SettingsPanel", true, false)
				if settings_panel:
					settings_panel.visible = !settings_panel.visible
					settings_panel.raise()
			elif btn_name == "backpack":
				var inv_panel = get_node_or_null("InventoryPanel")
				if inv_panel:
					inv_panel.visible = !inv_panel.visible
					if inv_panel.visible: inv_panel.raise()
			elif btn_name == "quests":
				# Futura lógica de misiones
				pass
			elif btn_name == "crafting":
				# Futura lógica de crafting
				pass
			elif btn_name == "skills":
				# Futura lógica de habilidades
				pass
			elif btn_name == "inventory_right":
				var inv_panel = get_node_or_null("InventoryPanel")
				if inv_panel:
					inv_panel.visible = !inv_panel.visible
					if inv_panel.visible: inv_panel.raise()
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

func set_hydration(val_percent):
	$Header/StatusBars/HydrationBarCont/HydrationBar.material.set_shader_param("value", val_percent)

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
	if ServiceLocator.has_service("save_manager"):
		var sm = ServiceLocator.get_save_manager()
		if sm.save_game():
			# Opcional: Mostrar una notificación de guardado
			_show_item_notification("Partida Guardada", 1, "res://ui/icons/inventory.jpg")

func _on_load():
	if ServiceLocator.has_service("save_manager"):
		var sm = ServiceLocator.get_save_manager()
		if sm.load_game_data():
			get_tree().paused = false
			get_tree().reload_current_scene()

func _on_main_menu():
	get_tree().paused = false # IMPORTANTE: Despausar antes de cambiar escena
	get_tree().change_scene("res://ui/scenes/MainMenu.tscn")

# --- SISTEMA DE NOTIFICACIONES PREMIUM ---
func _on_item_added(id, amount):
	var inv = get_node_or_null("/root/InventoryManager")
	if not inv: return
	
	var item_data = inv.items.get(id)
	if not item_data: return
	
	_show_item_notification(item_data["name"], amount, item_data["icon"])

func _show_item_notification(item_name, amount, icon_path):
	# SOLUCIÓN DE CONFLICTO: Usamos un Wrapper (Control) para que el VBoxContainer 
	# no sobreescriba la posición de nuestra animación.
	var wrapper = Control.new()
	wrapper.rect_min_size = Vector2(240, 50)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Crear el Toast (Panel de diseño premium)
	var toast = Panel.new()
	toast.rect_min_size = Vector2(240, 50)
	toast.rect_size = Vector2(240, 50)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.modulate.a = 0 # Iniciar invisible
	
	# Estilo Glassmorphism / Rústico
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.05, 0.9)
	style.border_width_bottom = 3 
	style.border_color = Color(1.0, 0.8, 0.3, 0.9) 
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_size = 6
	style.shadow_color = Color(0, 0, 0, 0.5)
	toast.add_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	hbox.margin_left = 10
	hbox.alignment = BoxContainer.ALIGN_CENTER
	toast.add_child(hbox)
	
	# Icono
	var tex_rect = TextureRect.new()
	tex_rect.texture = load(icon_path)
	tex_rect.rect_min_size = Vector2(35, 35)
	tex_rect.expand = true
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(tex_rect)
	
	# Texto
	var label = Label.new()
	label.text = "+%d %s" % [amount, item_name]
	label.set("custom_colors/font_color", Color(1, 1, 1))
	label.set("custom_colors/font_color_shadow", Color(0, 0, 0, 0.8))
	label.set("custom_constants/shadow_offset_x", 1)
	label.set("custom_constants/shadow_offset_y", 1)
	hbox.add_child(label)
	
	wrapper.add_child(toast)
	notify_container.add_child(wrapper)
	notify_container.move_child(wrapper, 0) 
	
	# ANIMACIÓN REAL (Sin conflictos con VBoxContainer)
	var t = get_tree().create_tween()
	toast.rect_position.y -= 30 # Offset inicial
	
	# 1. ENTRADA (0.4s)
	t.parallel().tween_property(toast, "modulate:a", 1.0, 0.3)
	t.parallel().tween_property(toast, "rect_position:y", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 2. ESPERA (3.0 segundos) - Ahora secuencial correctamente
	t.tween_interval(3.0) 
	
	# 3. SALIDA (0.5s) - Quitado parallel() del primero para que espere al intervalo
	t.tween_property(toast, "modulate:a", 0.0, 0.5)
	t.parallel().tween_property(toast, "rect_position:y", -30.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# 4. LIMPIEZA
	t.tween_callback(wrapper, "queue_free")
