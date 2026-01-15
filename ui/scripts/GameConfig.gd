extends Node

# =============================================================================
# GameConfig.gd - CONFIGURACIÓN CENTRALIZADA (Mejorado)
# =============================================================================
# Agrupa todas las constantes y ajustes de balanceo en un solo lugar.
# Modificar valores aquí afecta todo el juego sin tocar código.
# =============================================================================

# =============================================================================
# MUNDO Y TERRENO
# =============================================================================

# Tamaño de cada tile en unidades
const TILE_SIZE: float = 150.0

# Distancia de renderizado (en tiles)
const RENDER_DISTANCE: int = 4

# Nivel del agua (Y global)
const WATER_LEVEL: float = -8.0

# =============================================================================
# BIOMAS - Multiplicadores de altura
# =============================================================================

const H_SNOW: float = 45.0      # Montañas nevadas (más elevadas)
const H_JUNGLE: float = 35.0    # Selva (terreno montañoso)
const H_DESERT: float = 4.0     # Desierto (terreno plano)
const H_PRAIRIE: float = 2.0    # Pradera (terreno muy plano)

# =============================================================================
# JUGADOR
# =============================================================================

const PLAYER_SPEED: float = 6.0
const PLAYER_SPRINT_MULT: float = 1.8
const PLAYER_ROTATION_SPEED: float = 2.0
const PLAYER_GRAVITY: float = 25.0
const PLAYER_JUMP_FORCE: float = 12.0

# =============================================================================
# CABALLO
# =============================================================================

const HORSE_SPEED: float = 10.0
const HORSE_SPRINT_MULT: float = 1.5
const HORSE_CALL_SPRINT_MULT: float = 1.8
const HORSE_ROTATION_SPEED: float = 3.0
const HORSE_JUMP_FORCE: float = 12.0

# =============================================================================
# ANIMALES
# =============================================================================

const ANIMAL_ACTIVE_DIST: float = 60.0    # Distancia máxima para procesar física
const ANIMAL_VISIBLE_DIST: float = 80.0   # Distancia máxima para renderizar
const CHICKEN_SIZE_UNIT: float = 0.28

# Velocidades base
const COW_SPEED: float = 1.5
const GOAT_SPEED: float = 4.2
const CHICKEN_SPEED: float = 2.0

# =============================================================================
# OPTIMIZACIÓN / RENDIMIENTO
# =============================================================================

# Intervalos de actualización (segundos)
const UPDATE_TICK_LONG: float = 0.5    # Para operaciones lentas
const UPDATE_TICK_SHORT: float = 0.1   # Para operaciones frecuentes

# Factor de reducción de física para IAs lejanas
# Procesar 1 de cada N frames
const PHYSICS_REDUCTION_FACTOR: int = 2

# LOD
const LOD_UPGRADE_INTERVAL: float = 2.0  # Segundos entre upgrades de LOD
const LOD_UPGRADE_DISTANCE: float = 200.0  # Distancia para upgrade a HIGH

# =============================================================================
# UI
# =============================================================================

const NOTIFICATION_DURATION: float = 3.0
const BUTTON_DEBOUNCE_MS: int = 150

# =============================================================================
# CICLO DÍA/NOCHE
# =============================================================================

const DEFAULT_CYCLE_DURATION_MINUTES: float = 5.0
const NIGHT_THRESHOLD: float = 0.7  # Valor de day_phase bajo el cual es "noche"

# =============================================================================
# AUDIO
# =============================================================================

const AUDIO_ENABLED: bool = true
const AUDIO_VOLUME_SFX: float = 1.0
const AUDIO_VOLUME_MUSIC: float = 0.6
const AUDIO_VOLUME_AMBIENT: float = 0.5
