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
onready var exit_btn = $ButtonsCont/Exit

var _loader: ResourceInteractiveLoader = null
var _main_scene_resource: PackedScene = null

const GAME_SCENE_PATH = "res://ui/scenes/Main3D.tscn"

func _ready():
	new_game_btn.connect("pressed", self, "_on_new_game_pressed")
	load_game_btn.connect("pressed", self, "_on_load_game_pressed")
	options_btn.connect("pressed", self, "_on_options_pressed")
	credits_btn.connect("pressed", self, "_on_credits_pressed")
	exit_btn.connect("pressed", self, "_on_exit_pressed")
	
	# Desactivar botón de carga si no hay archivo
	if ServiceLocator.has_service("save_manager"):
		load_game_btn.disabled = not ServiceLocator.get_save_manager().has_save_file()
	
	call_deferred("_start_background_loading")
	
	# Aplicar bordes redondeados al logo
	var title = $TitleCont/Title
	var shader = load("res://ui/shaders/rounded_logo.shader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		title.material = mat

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
	# Si empezamos juego nuevo, asegurarnos de que no haya una carga pendiente vieja
	if SaveManager.has_method("clear_pending_load"):
		SaveManager.clear_pending_load()
		
	# Detener cargador de fondo para evitar conflictos de acceso al archivo
	_loader = null
	set_process(false)
	
	LoadingManager.show_loading()
	if _main_scene_resource:
		get_tree().call_deferred("change_scene_to", _main_scene_resource)
	else:
		get_tree().call_deferred("change_scene", GAME_SCENE_PATH)

func _on_load_game_pressed():
	# Acceso directo al Autoload para mayor velocidad y evitar delays del ServiceLocator
	if SaveManager.load_game_data():
		# Detener cargador de fondo
		_loader = null
		set_process(false)
		
		# Mostrar pantalla de carga
		LoadingManager.show_loading()
		
		# Cambiar escena de forma diferida para asegurar un estado limpio del árbol
		if _main_scene_resource:
			get_tree().call_deferred("change_scene_to", _main_scene_resource)
		else:
			get_tree().call_deferred("change_scene", GAME_SCENE_PATH)
	else:
		print("MainMenu: No se pudo cargar la partida o no existe.")

func _on_options_pressed():
	# TODO: Implementar panel de opciones
	pass

func _on_credits_pressed():
	# TODO: Implementar pantalla de créditos
	pass

func _on_exit_pressed():
	get_tree().quit()
