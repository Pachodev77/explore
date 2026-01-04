extends Spatial

# Sistema de configuración de rendimiento
var settings = {
	"day_night": true,
	"decorations": true,
	"shadows": true,
	"fog": true,
	"glow": true
}

onready var day_night_cycle = get_node_or_null("DayNightCycle")
onready var world_manager = get_node_or_null("WorldManager")
onready var directional_light = get_node_or_null("DirectionalLight")
onready var world_environment = get_node_or_null("WorldEnvironment")

func _ready():
	# Conectar con el panel de configuración
	var settings_panel = get_tree().root.find_node("SettingsPanel", true, false)
	if settings_panel:
		settings_panel.connect("setting_changed", self, "_on_setting_changed")

func _on_setting_changed(setting_name, value):
	settings[setting_name] = value
	print("Configuración cambiada:", setting_name, "=", value)
	
	match setting_name:
		"day_night":
			_toggle_day_night(value)
		"decorations":
			_toggle_decorations(value)
		"shadows":
			_toggle_shadows(value)
		"fog":
			_toggle_fog(value)
		"glow":
			_toggle_glow(value)

func _toggle_day_night(enabled):
	if day_night_cycle:
		day_night_cycle.set_process(enabled)
		print("Ciclo día/noche:", "ACTIVO" if enabled else "DESACTIVADO")

func _toggle_decorations(enabled):
	if world_manager:
		# Ocultar/mostrar todas las decoraciones existentes
		for tile_key in world_manager.active_tiles:
			var tile = world_manager.active_tiles[tile_key]
			var decos = tile.get_node_or_null("Decos")
			if decos:
				decos.visible = enabled
		print("Decoraciones:", "VISIBLES" if enabled else "OCULTAS")

func _toggle_shadows(enabled):
	if directional_light:
		directional_light.shadow_enabled = enabled
		print("Sombras:", "ACTIVAS" if enabled else "DESACTIVADAS")

func _toggle_fog(enabled):
	if world_environment and world_environment.environment:
		world_environment.environment.fog_enabled = enabled
		print("Niebla:", "ACTIVA" if enabled else "DESACTIVADA")

func _toggle_glow(enabled):
	if world_environment and world_environment.environment:
		world_environment.environment.glow_enabled = enabled
		print("Glow:", "ACTIVO" if enabled else "DESACTIVADO")
