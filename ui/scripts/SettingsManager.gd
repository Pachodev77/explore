# =============================================================================
# SettingsManager.gd - GESTOR DE CONFIGURACIÓN DE RENDIMIENTO
# =============================================================================
# Controla opciones de gráficos: ciclo día/noche, decoraciones, sombras, etc.
# =============================================================================

extends Spatial

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
	var settings_panel = get_tree().root.find_node("SettingsPanel", true, false)
	if settings_panel:
		settings_panel.connect("setting_changed", self, "_on_setting_changed")

func _on_setting_changed(setting_name: String, value: bool):
	settings[setting_name] = value
	
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

func _toggle_day_night(enabled: bool):
	if day_night_cycle:
		day_night_cycle.set_process(enabled)

func _toggle_decorations(enabled: bool):
	if world_manager:
		for tile_key in world_manager.active_tiles:
			var tile = world_manager.active_tiles[tile_key]
			var decos = tile.get_node_or_null("Decos")
			if decos:
				decos.visible = enabled

func _toggle_shadows(enabled: bool):
	if directional_light:
		directional_light.shadow_enabled = enabled

func _toggle_fog(enabled: bool):
	if world_environment and world_environment.environment:
		world_environment.environment.fog_enabled = enabled

func _toggle_glow(enabled: bool):
	if world_environment and world_environment.environment:
		world_environment.environment.glow_enabled = enabled
