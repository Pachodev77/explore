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
	# No usar tween para la entrada, queremos que sea OPACO YA para tapar glitches
	is_loading = true
	overlay.modulate.a = 1.0
	overlay.visible = true

func _on_world_ready():
	if not is_loading: return
	
	# ESPERA EXTENDIDA: Garantizamos que todo el terreno, decoraciones y animales estén listos.
	yield(get_tree().create_timer(3.0), "timeout")
	
	# Desvanecimiento cinemático lento (2 segundos)
	var t = Tween.new()
	add_child(t)
	t.interpolate_property(overlay, "modulate:a", 1.0, 0.0, 2.0, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	t.start()
	
	yield(t, "tween_completed")
	overlay.visible = false
	is_loading = false
	t.queue_free()

func hide_instant():
	overlay.visible = false
	is_loading = false
