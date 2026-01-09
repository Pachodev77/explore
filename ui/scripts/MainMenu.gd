extends Control

onready var new_game_btn = $ButtonsCont/NewGame
onready var load_game_btn = $ButtonsCont/LoadGame
onready var options_btn = $ButtonsCont/Options
onready var credits_btn = $ButtonsCont/Credits

var _loader : ResourceInteractiveLoader = null
var _main_scene_resource : PackedScene = null

const GAME_SCENE_PATH = "res://ui/scenes/Main3D.tscn"

func _ready():
	new_game_btn.connect("pressed", self, "_on_new_game_pressed")
	load_game_btn.connect("pressed", self, "_on_load_game_pressed")
	options_btn.connect("pressed", self, "_on_options_pressed")
	credits_btn.connect("pressed", self, "_on_credits_pressed")
	
	# Usar ResourceInteractiveLoader en lugar de Threads para mayor estabilidad
	call_deferred("_start_background_loading")

func _start_background_loading():
	if ResourceLoader.has_cached(GAME_SCENE_PATH):
		print("MainMenu: Scene already cached.")
		_main_scene_resource = ResourceLoader.load(GAME_SCENE_PATH)
		return

	print("MainMenu: Starting interactive load of game scene...")
	_loader = ResourceLoader.load_interactive(GAME_SCENE_PATH)

func _process(_delta):
	if _loader == null:            
		return

	var t = OS.get_ticks_msec()
	# Usar hasta 15ms por frame para cargar (mantiene 60fps aprox en menú)
	while OS.get_ticks_msec() < t + 15:
		var err = _loader.poll()
		if err == ERR_FILE_EOF: # Carga terminada
			_main_scene_resource = _loader.get_resource()
			_loader = null
			print("MainMenu: Background load complete! Game is ready.")
			break
		elif err != OK: # Error
			print("MainMenu: Error loading scene interactively.")
			_loader = null
			break

func _on_new_game_pressed():
	if _main_scene_resource:
		print("MainMenu: Instant start!")
		get_tree().change_scene_to(_main_scene_resource)
	elif _loader:
		print("MainMenu: Scene loading... forcing completion.")
		# Si el usuario presiona antes de terminar, bloqueamos y terminamos de cargar
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
		# Fallback por si acaso
		get_tree().change_scene(GAME_SCENE_PATH)

func _on_load_game_pressed():
	print("MainMenu: Load Game pressed")

func _on_options_pressed():
	print("MainMenu: Options pressed")

func _on_credits_pressed():
	print("MainMenu: Credits pressed")
