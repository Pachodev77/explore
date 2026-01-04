extends Control

signal setting_changed(setting_name, value)

onready var day_night_toggle = $VBox/DayNightToggle/CheckBox
onready var decorations_toggle = $VBox/DecorationsToggle/CheckBox
onready var shadows_toggle = $VBox/ShadowsToggle/CheckBox
onready var fog_toggle = $VBox/FogToggle/CheckBox
onready var glow_toggle = $VBox/GlowToggle/CheckBox
onready var close_button = $CloseButton

func _ready():
	# Conectar señales
	day_night_toggle.connect("toggled", self, "_on_day_night_toggled")
	decorations_toggle.connect("toggled", self, "_on_decorations_toggled")
	shadows_toggle.connect("toggled", self, "_on_shadows_toggled")
	fog_toggle.connect("toggled", self, "_on_fog_toggled")
	glow_toggle.connect("toggled", self, "_on_glow_toggled")
	close_button.connect("pressed", self, "_on_close_pressed")
	
	# Valores iniciales
	day_night_toggle.pressed = true
	decorations_toggle.pressed = true
	shadows_toggle.pressed = true
	fog_toggle.pressed = true
	glow_toggle.pressed = true

func _on_day_night_toggled(value):
	emit_signal("setting_changed", "day_night", value)

func _on_decorations_toggled(value):
	emit_signal("setting_changed", "decorations", value)

func _on_shadows_toggled(value):
	emit_signal("setting_changed", "shadows", value)

func _on_fog_toggled(value):
	emit_signal("setting_changed", "fog", value)

func _on_glow_toggled(value):
	emit_signal("setting_changed", "glow", value)

func _on_close_pressed():
	hide()
