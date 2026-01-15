# =============================================================================
# PlayerStats.gd - GESTION DE ESTADISTICAS Y SUPERVIVENCIA
# =============================================================================
# Controla la salud, hidratacion y los efectos del ciclo dia/noche en el jugador.
# =============================================================================

extends Node
class_name PlayerStats

var health: float = 1.0
var hydration: float = 1.0
var max_hydration: float = 1.0

var player = null
var hud_ref = null
var dnc_ref = null

func init(p_node, h_ref, d_ref):
	player = p_node
	hud_ref = h_ref
	dnc_ref = d_ref
	if hud_ref:
		hud_ref.set_health(health)
		hud_ref.set_hydration(hydration)

func update_stats(delta):
	if not dnc_ref: return
	
	# Deplecion de hidratacion: 100% en 2 dias
	var day_sec = dnc_ref.cycle_duration_minutes * 60.0
	var total_depletion_time = day_sec * 2.0
	
	if total_depletion_time > 0:
		var depletion_per_sec = 1.0 / total_depletion_time
		hydration = max(0.0, hydration - depletion_per_sec * delta)
		
		if hud_ref:
			hud_ref.set_hydration(hydration)
		
		if hydration <= 0:
			# Daño por deshidratacion: 100% salud en 0.5 dias
			var damage_per_sec = 1.0 / (day_sec * 0.5)
			health = max(0.0, health - damage_per_sec * delta)
			if hud_ref:
				hud_ref.set_health(health)

func take_damage(amount):
	health = max(0.0, health - amount)
	if hud_ref:
		hud_ref.set_health(health)
		if hud_ref.has_method("show_damage_flash"):
			hud_ref.show_damage_flash()
	if health <= 0:
		GameEvents.emit_signal("player_died")

func add_healing(amount):
	health = min(1.0, health + amount)
	if hud_ref: hud_ref.set_health(health)

func add_hydration(amount):
	hydration = min(max_hydration, hydration + amount)
	if hud_ref: hud_ref.set_hydration(hydration)
