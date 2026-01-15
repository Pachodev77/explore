extends Node

# =============================================================================
# AudioManager.gd - SISTEMA DE SONIDO CENTRALIZADO
# =============================================================================
# Gestiona la reproducción de efectos, ambiente y música con pooling de voces.
# =============================================================================

var sfx_pool = []
var pool_size = 12

# Diccionario de sonidos (Rutas a los archivos assets)
# El usuario debe colocar sus archivos en res://assets/sounds/
var sounds = {
	# UI
	"ui_click": "res://assets/sounds/ui_click.wav",
	"ui_popup": "res://assets/sounds/ui_popup.wav",
	
	# JUGADOR
	"footstep_grass": "res://assets/sounds/step_grass.wav",
	"jump": "res://assets/sounds/jump.wav",
	"land": "res://assets/sounds/land.wav",
	"damage": "res://assets/sounds/damage.wav",
	
	# ACCIONES
	"chopping": "res://assets/sounds/chop.wav",
	"milking": "res://assets/sounds/milk.wav",
	"harvest": "res://assets/sounds/harvest.wav",
	
	# AMBIENTE
	"birds": "res://assets/sounds/birds.ogg",
	"crickets": "res://assets/sounds/crickets.ogg",
	"wind": "res://assets/sounds/wind_loop.ogg",
	
	# MUNDO
	"bee_loop": "res://assets/sounds/bees_loop.ogg",
	"bee_sting": "res://assets/sounds/bee_sting.wav",
	"moo": "res://assets/sounds/cow_moo.wav",
	"baa": "res://assets/sounds/goat_baa.wav",
	"cluck": "res://assets/sounds/chicken_cluck.wav"
}

func _ready():
	ServiceLocator.register_service("audio", self)
	
	# Crear pool de AudioStreamPlayers para SFX 2D
	for i in range(pool_size):
		var asp = AudioStreamPlayer.new()
		asp.bus = "SFX"
		add_child(asp)
		sfx_pool.append(asp)

func play_sfx(sound_name: String, volume_mult: float = 1.0):
	if not GameConfig.AUDIO_ENABLED: return
	if not sounds.has(sound_name): return
	
	var stream = load(sounds[sound_name])
	if not stream: return # El archivo no existe todavía
	
	for asp in sfx_pool:
		if not asp.playing:
			asp.stream = stream
			asp.volume_db = linear2db(GameConfig.AUDIO_VOLUME_SFX * volume_mult)
			asp.play()
			return

# Reproducción espacial 3D
func play_sfx_3d(sound_name: String, position: Vector3, volume_mult: float = 1.0):
	if not GameConfig.AUDIO_ENABLED: return
	if not sounds.has(sound_name): return
	
	var stream = load(sounds[sound_name])
	if not stream: return
	
	var asp = AudioStreamPlayer3D.new()
	asp.stream = stream
	asp.unit_db = linear2db(GameConfig.AUDIO_VOLUME_SFX * volume_mult)
	asp.translation = position
	asp.bus = "SFX"
	asp.autoplay = true
	get_tree().root.add_child(asp)
	
	# Auto-destrucción al terminar
	asp.connect("finished", asp, "queue_free")

func play_ambient(sound_name: String, fade_in: float = 1.0):
	# Lógica básica de música/ambiente persistente
	pass
