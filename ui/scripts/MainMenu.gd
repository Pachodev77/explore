extends Control

# =============================================================================
# MainMenu.gd - MENÚ PRINCIPAL
# =============================================================================
# Carga la escena del juego en segundo plano para inicio instantáneo.
# =============================================================================

onready var new_game_btn = $ButtonsCont/NewGame
onready var load_game_btn = $ButtonsCont/LoadGame
onready var options_btn = $ButtonsCont/Options
onready var credits_btn = $ButtonsCont/Credits

var _loader: ResourceInteractiveLoader = null
var _main_scene_resource: PackedScene = null

const GAME_SCENE_PATH = "res://ui/scenes/Main3D.tscn"

func _ready():
	new_game_btn.connect("pressed", self, "_on_new_game_pressed")
	load_game_btn.connect("pressed", self, "_on_load_game_pressed")
	options_btn.connect("pressed", self, "_on_options_pressed")
	credits_btn.connect("pressed", self, "_on_credits_pressed")
	
	call_deferred("_start_background_loading")

func _start_background_loading():
	if ResourceLoader.has_cached(GAME_SCENE_PATH):
		_main_scene_resource = ResourceLoader.load(GAME_SCENE_PATH)
		return
	
	_loader = ResourceLoader.load_interactive(GAME_SCENE_PATH)

func _process(_delta):
	if _loader == null:
		return
	
	var t = OS.get_ticks_msec()
	# Usar hasta 15ms por frame para cargar
	while OS.get_ticks_msec() < t + 15:
		var err = _loader.poll()
		if err == ERR_FILE_EOF:
			_main_scene_resource = _loader.get_resource()
			_loader = null
			break
		elif err != OK:
			_loader = null
			break

func _on_new_game_pressed():
	LoadingManager.show_loading()
	if _main_scene_resource:
		get_tree().change_scene_to(_main_scene_resource)
	elif _loader:
		# Forzar completar carga
		while _loader:
			var err = _loader.poll()
			if err == ERR_FILE_EOF:
				_main_scene_resource = _loader.get_resource()
				_loader = null
				get_tree().change_scene_to(_main_scene_resource)
				break
			elif err != OK:
				get_tree().change_scene(GAME_SCENE_PATH)
				break
	else:
		get_tree().change_scene(GAME_SCENE_PATH)

func _on_load_game_pressed():
	LoadingManager.show_loading()
	# TODO: Implementar pantalla de carga de partidas
	pass

func _on_options_pressed():
	# TODO: Implementar panel de opciones
	pass

func _on_credits_pressed():
	# TODO: Implementar pantalla de créditos
	pass
