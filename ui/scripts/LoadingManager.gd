extends Node

# LoadingManager.gd - GESTOR DE PANTALLA DE CARGA ROBUSTO Y OPACO
# Bloqueo total de pantalla sin transparencias y flujo optimizado.

var overlay: ColorRect
var canvas: CanvasLayer
var label: Label
var is_loading = false

func _ready():
	canvas = CanvasLayer.new()
	canvas.layer = 120 
	add_child(canvas)
	
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 1) # Negro absoluto
	overlay.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(overlay)
	
	var center = CenterContainer.new()
	center.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	overlay.add_child(center)
	
	label = Label.new()
	label.text = "LOADING..."
	label.align = Label.ALIGN_CENTER
	label.modulate = Color(1, 1, 1, 1)
	center.add_child(label)
	
	GameEvents.connect("world_ready", self, "_on_world_ready")

func show_loading():
	is_loading = true
	overlay.modulate.a = 1.0
	overlay.visible = true
	
	# FAIL-SAFE: Si el juego crashea en carga, ocultar negro tras 12 segundos
	var fst = get_tree().create_timer(12.0)
	fst.connect("timeout", self, "hide_instant")

func _on_world_ready():
	if not is_loading: return
	
	# Buffer de estabilidad: 1 segundo es suficiente.
	yield(get_tree().create_timer(1.0), "timeout")
	
	if not is_instance_valid(overlay): return
	
	# Desvanecimiento cinemático suave (1.2 segundos)
	var t = Tween.new()
	add_child(t)
	t.interpolate_property(overlay, "modulate:a", 1.0, 0.0, 1.2, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	t.start()
	
	yield(t, "tween_completed")
	overlay.visible = false
	is_loading = false
	t.queue_free()

func hide_instant():
	is_loading = false
	overlay.visible = false
