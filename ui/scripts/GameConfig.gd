extends Node

# =============================================================================
# GameConfig.gd - CONFIGURACIÓN CENTRALIZADA
# =============================================================================
# Agrupa todas las constantes y ajustes de balanceo en un solo lugar.
# =============================================================================

# Mundo
const TILE_SIZE = 150.0
const RENDER_DISTANCE = 4
const WATER_LEVEL = -8.0

# Biomas
const H_SNOW = 45.0
const H_JUNGLE = 35.0
const H_DESERT = 4.0
const H_PRAIRIE = 2.0

# Jugador
const PLAYER_SPEED = 6.0
const PLAYER_ROTATION_SPEED = 2.0
const PLAYER_GRAVITY = 25.0

# Optimización
const UPDATE_TICK_LONG = 0.5
const UPDATE_TICK_SHORT = 0.1
const PHYSICS_REDUCTION_FACTOR = 2 # Procesar 1 de cada N frames para IAs lejanas
