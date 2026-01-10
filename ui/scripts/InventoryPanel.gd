extends Control

onready var grid = $Background/Content/ScrollContainer/GridContainer
onready var close_btn = $Background/Header/CloseButton
onready var capacity_label = $Background/Footer/CapacityLabel


func _ready():
	# Estilo visual de la fuente
	$Background/Header/Title.add_color_override("font_color", Color(1.0, 0.9, 0.7))
	
	# Conectarse al gestor global para actualizaciones en tiempo real
	if has_node("/root/InventoryManager"):
		get_node("/root/InventoryManager").connect("inventory_updated", self, "update_inventory_ui")
	
	update_inventory_ui()
	
	if close_btn:
		close_btn.connect("pressed", self, "_on_close_pressed")

func update_inventory_ui():
	# Limpiar grid
	for child in grid.get_children():
		child.queue_free()
	
	# Obtener items reales del gestor global
	var real_items = []
	if has_node("/root/InventoryManager"):
		real_items = get_node("/root/InventoryManager").get_items_list()
	
	# Poblar con las tarjetas de items
	for item in real_items:
		var card = create_item_card(item)
		grid.add_child(card)
	
	if capacity_label:
		capacity_label.text = "Capacidad: " + str(real_items.size()) + " / 30"
		capacity_label.add_color_override("font_color", Color(0.8, 0.7, 0.5))

func create_item_card(item_data):
	# Contenedor principal de la tarjeta
	var card = Button.new()
	card.rect_min_size = Vector2(160, 190) # Más compacto
	card.flat = true
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Estilo de la tarjeta (Borde exterior bien definido)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.14, 0.1, 1.0)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(0.35, 0.28, 0.2, 1.0) # Borde oscuro definido
	
	var style_hover = style.duplicate()
	style_hover.bg_color = Color(0.28, 0.22, 0.16, 1.0)
	style_hover.border_color = Color(0.9, 0.7, 0.3, 1.0) # Borde dorado al resaltar
	
	card.add_stylebox_override("normal", style)
	card.add_stylebox_override("hover", style_hover)
	card.add_stylebox_override("pressed", style_hover)
	
	# Panel Interno para dar profundidad (Diseño tipo Tarjeta)
	var inner_panel = Panel.new()
	inner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_panel.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	inner_panel.margin_left = 6; inner_panel.margin_top = 6; inner_panel.margin_right = -6; inner_panel.margin_bottom = -6
	
	var inner_style = StyleBoxFlat.new()
	inner_style.bg_color = Color(0, 0, 0, 0.15)
	inner_style.set_corner_radius_all(8)
	inner_style.set_border_width_all(1)
	inner_style.border_color = Color(1, 1, 1, 0.05)
	inner_panel.add_stylebox_override("panel", inner_style)
	card.add_child(inner_panel)
	
	# Layout Vertical
	var v_box = VBoxContainer.new()
	v_box.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	v_box.margin_left = 12; v_box.margin_top = 12; v_box.margin_right = -12; v_box.margin_bottom = -12
	v_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v_box.add_constant_override("separation", 8)
	card.add_child(v_box)
	
	# 1. Cantidad (En la parte superior, alineada a la derecha)
	var qty_container = HBoxContainer.new()
	qty_container.alignment = BoxContainer.ALIGN_END
	qty_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v_box.add_child(qty_container)
	
	var qty_badge = PanelContainer.new()
	var qty_style = StyleBoxFlat.new()
	qty_style.bg_color = Color(0.5, 0.1, 0.05, 1.0)
	qty_style.set_corner_radius_all(6)
	qty_style.content_margin_left = 8
	qty_style.content_margin_right = 8
	qty_style.content_margin_top = 2
	qty_style.content_margin_bottom = 2
	qty_badge.add_stylebox_override("panel", qty_style)
	
	var qty_label = Label.new()
	qty_label.text = str(item_data.qty)
	qty_label.align = Label.ALIGN_CENTER
	qty_label.add_color_override("font_color", Color(1, 1, 1))
	qty_badge.add_child(qty_label)
	qty_container.add_child(qty_badge)
	
	# 2. Contenedor de Imagen
	var img_container = CenterContainer.new()
	img_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v_box.add_child(img_container)
	
	var icon_rect = TextureRect.new()
	icon_rect.rect_min_size = Vector2(100, 100)
	icon_rect.expand = true
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var tex = load(item_data.icon)
	if tex:
		icon_rect.texture = tex
		img_container.add_child(icon_rect)
	
	# 3. Nombre del objeto
	var name_label = Label.new()
	name_label.text = item_data.name
	name_label.align = Label.ALIGN_CENTER
	name_label.valign = Label.VALIGN_CENTER
	name_label.add_color_override("font_color", Color(0.9, 0.85, 0.75))
	name_label.autowrap = true
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v_box.add_child(name_label)
	
	return card

func _on_close_pressed():
	visible = false
