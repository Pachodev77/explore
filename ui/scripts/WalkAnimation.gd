extends Spatial

# --- SISTEMA DE ANIMACIÓN PROCEDURAL V9 (OPTIMIZADO) ---

var skel = null  # No usar onready, buscar en _ready()

var phase = 0.0
var walk_speed = 0.0
var is_walking = false

var bones = {
	"Hips": -1,
	"Spine2": -1,
	"Neck": -1, "Head": -1,
	"UpperLegL": -1, "LowerLegL": -1, "FootL": -1,
	"UpperLegR": -1, "LowerLegR": -1, "FootR": -1,
	"UpperArmL": -1, "LowerArmL": -1,
	"UpperArmR": -1, "LowerArmR": -1
}
var idle_phase = 0.0
var idle_weight = 0.0
var run_weight = 0.0
var is_holding_torch = false
var is_milking = false
var is_chopping = false
var chop_phase = 0.0

var last_phase = 0.0

# --- PARÁMETROS DE SUAVIZADO (FLUIDEZ) ---
var curr_crouch = 0.0
var curr_arm_raise = 0.0
var curr_arm_split = 0.0
var curr_leg_fold = 0.0
var curr_leg_split = 0.0
var curr_torso_tilt = 0.0
var animation_smoothing = 15.0

export var speed_multiplier = 4.5
export var step_lift = 0.3
export var swing_angle = 35.0
export var bounce_amp = 0.05

var update_tick = 0
var screen_visible = true

func _ready():
	# ... (Previous skeleton search logic) ...
	yield(get_tree(), "idle_frame")
	_find_skeleton()
	
	# Add VisibilityNotifier for optimization
	var vn = VisibilityNotifier.new()
	vn.connect("screen_entered", self, "_on_screen_entered")
	vn.connect("screen_exited", self, "_on_screen_exited")
	add_child(vn)

func _on_screen_entered(): screen_visible = true
func _on_screen_exited(): screen_visible = false

func _find_skeleton():
	skel = get_parent().get_node_or_null("MeshInstance/HumanoidRig")
	if not skel:
		skel = get_node_or_null("../MeshInstance/HumanoidRig")
	if not skel:
		var mesh_instance = get_parent().get_node_or_null("MeshInstance")
		if mesh_instance:
			for child in mesh_instance.get_children():
				if child is Skeleton:
					skel = child
					break
	if skel:
		for b in bones.keys():
			bones[b] = skel.find_bone(b)

func _process(delta):
	if not skel:
		return
	
	# OPTIMIZACIÓN MÓVIL: Saltar frames si estamos quietos y fuera de cámara
	update_tick += 1
	var is_moving = (is_walking and walk_speed > 0.1) or is_riding or current_jump_state != JumpState.IDLE
	
	if not screen_visible and not is_moving:
		return # No animar si está fuera de pantalla y quieto
	
	# Si estamos quietos, solo actualizamos cada 2 frames (30fps efectivos)
	if not is_moving and update_tick % 2 != 0:
		return
	
	# Actualizar estados de salto
	jump_timer += delta
	if current_jump_state == JumpState.ANTICIPATION and jump_timer > 0.15:
		current_jump_state = JumpState.IN_AIR
		jump_timer = 0.0
	if current_jump_state == JumpState.IMPACT and jump_timer > 0.3:
		current_jump_state = JumpState.IDLE
		jump_timer = 0.0
	
	if is_walking and walk_speed > 0.1:
		var prev_phase = phase
		phase += delta * speed_multiplier * walk_speed
		if phase > TAU: phase -= TAU
		
		# Detectar contacto de pies (2 impactos por ciclo TAU)
		if (prev_phase < PI and phase >= PI) or (prev_phase > phase):
			if is_on_floor:
				AudioManager.play_sfx("footstep_grass", 0.4 if run_weight < 0.5 else 0.6)
	else:
		phase = lerp(phase, 0.0, 5.0 * delta)
	
	idle_weight = lerp(idle_weight, 0.0 if is_moving else 1.0, 4.0 * delta)
	
	var target_run = clamp((walk_speed - 1.0) / 0.8, 0.0, 1.0)
	run_weight = lerp(run_weight, target_run if is_walking else 0.0, 5.0 * delta)
	
	idle_phase += delta * 1.5 
	if idle_phase > TAU: idle_phase -= TAU
	
	var targets = _get_jump_targets()
	curr_crouch = lerp(curr_crouch, targets.crouch, delta * animation_smoothing)
	curr_arm_raise = lerp(curr_arm_raise, targets.arm_raise, delta * animation_smoothing)
	curr_arm_split = lerp(curr_arm_split, targets.arm_split, delta * animation_smoothing)
	curr_leg_fold = lerp(curr_leg_fold, targets.leg_fold, delta * animation_smoothing)
	curr_leg_split = lerp(curr_leg_split, targets.leg_split, delta * animation_smoothing)
	curr_torso_tilt = lerp(curr_torso_tilt, targets.torso_tilt, delta * animation_smoothing)
	
	if is_chopping:
		chop_phase += delta * 8.0
		if chop_phase > TAU: chop_phase -= TAU
	else:
		chop_phase = 0.0
	
	_animate()

func set_walking(walking, s):
	is_walking = walking
	walk_speed = clamp(s / 5.0, 0.0, 2.0)

var is_riding = false
var current_horse = null

# --- NEW JUMP STATES ---
enum JumpState { IDLE, ANTICIPATION, IN_AIR, IMPACT }
var current_jump_state = JumpState.IDLE
var jump_timer = 0.0
var vertical_velocity = 0.0
var horizontal_velocity = Vector3.ZERO
var is_on_floor = true

func set_riding(riding, horse = null):
	is_riding = riding
	current_horse = horse

func set_jumping(jumping):
	# Solo activamos anticipación si estamos en el suelo y en IDLE
	if jumping and current_jump_state == JumpState.IDLE and is_on_floor:
		current_jump_state = JumpState.ANTICIPATION
		jump_timer = 0.0
		AudioManager.play_sfx("jump", 1.0)

func set_torch(active):
	is_holding_torch = active

func set_milking(active):
	is_milking = active

func set_chopping(active):
	is_chopping = active

func update_physics_state(v_vel, full_velocity, grounded):
	vertical_velocity = v_vel
	horizontal_velocity = Vector3(full_velocity.x, 0, full_velocity.z)
	
	# Detectar aterrizaje para entrar en IMPACT (más robusto)
	if grounded and current_jump_state == JumpState.IN_AIR:
		current_jump_state = JumpState.IMPACT
		jump_timer = 0.0
		AudioManager.play_sfx("land", 0.8)
	
	is_on_floor = grounded
	
	# Transición automática de ANTICIPATION a IN_AIR cuando empezamos a subir 
	# o por timeout en _process
	if current_jump_state == JumpState.ANTICIPATION and v_vel > 0.1:
		current_jump_state = JumpState.IN_AIR
		jump_timer = 0.0 # Reset timer for jump pose

func _animate():
	# Si estamos saltando o aterrizando, la animación de salto toma prioridad parcial
	if current_jump_state != JumpState.IDLE:
		_animate_jump_pro()
		return
	
	if is_milking:
		_animate_milking()
		return
	
	if is_chopping:
		_animate_chopping()
		return
	
	var sway = sin(phase) * 0.03
	
	if is_riding:
		_animate_riding(phase)
		return
	
	# Hips (Caminando)
	var h_p = Transform.IDENTITY
	var dynamic_bounce = bounce_amp * lerp(1.0, 2.2, run_weight)
	var bounce = -abs(sin(phase)) * dynamic_bounce
	h_p.origin.y = bounce
	h_p.basis = h_p.basis.rotated(Vector3.FORWARD, sway)
	skel.set_bone_pose(bones["Hips"], h_p)
	
	# Torso (Lean forward when running)
	if bones["Spine2"] != -1:
		var s_p = Transform.IDENTITY
		var lean = deg2rad(lerp(0.0, 25.0, run_weight))
		s_p.basis = s_p.basis.rotated(Vector3.RIGHT, lean)
		s_p.basis = s_p.basis.rotated(Vector3.FORWARD, -sway * 0.8)
		skel.set_bone_pose(bones["Spine2"], s_p)
	
	_animate_limbs(phase)
	
	# --- APLICAR IDLE (BREATHING/SWAY) ---
	if idle_weight > 0.01:
		_apply_idle_pose()

func _apply_idle_pose():
	# 1. Respiración (Hips & Spine)
	var breath = sin(idle_phase) * 0.015 # Bob vertical sutil
	var breath_rot = sin(idle_phase + 0.5) * deg2rad(2.0) # Rotación de pecho
	
	# Mezclar con la posición actual (Hips)
	var h_p = skel.get_bone_pose(bones["Hips"])
	h_p.origin.y += breath * idle_weight
	skel.set_bone_pose(bones["Hips"], h_p)
	
	# Mezclar con la posición actual (Spine2)
	if bones["Spine2"] != -1:
		var s_p = skel.get_bone_pose(bones["Spine2"])
		s_p.basis = s_p.basis.rotated(Vector3.RIGHT, breath_rot * idle_weight)
		skel.set_bone_pose(bones["Spine2"], s_p)
		
	# 2. Brazos relajados (Slight outward sway)
	for side in ["L", "R"]:
		var u_arm = bones["UpperArm" + side]
		var l_arm = bones["LowerArm" + side]
		if u_arm != -1:
			var side_m = 1.0 if side == "L" else -1.0
			var ua_p = skel.get_bone_pose(u_arm)
			# Rotar ligeramente hacia afuera y abajo (antes estaba en -5.0)
			ua_p.basis = ua_p.basis.rotated(Vector3.UP, deg2rad(10.0 * side_m) * idle_weight)
			ua_p.basis = ua_p.basis.rotated(Vector3.RIGHT, deg2rad(15.0) * idle_weight)
			skel.set_bone_pose(u_arm, ua_p)
		if l_arm != -1:
			var la_p = skel.get_bone_pose(l_arm)
			la_p.basis = la_p.basis.rotated(Vector3.RIGHT, deg2rad(-15.0) * idle_weight)
			skel.set_bone_pose(l_arm, la_p)
	
	if is_holding_torch:
		_apply_torch_arm_pose()
	
	# 3. Piernas estables y separadas (BIEN PARACO)
	for side in ["L", "R"]:
		var u_leg = bones["UpperLeg" + side]
		var l_leg = bones["LowerLeg" + side]
		var f_leg = bones["Foot" + side]
		var side_m = 1.0 if side == "L" else -1.0
		
		if u_leg != -1:
			var ul_p = skel.get_bone_pose(u_leg)
			# Slerp hacia posición neutra + separación lateral (reducido de 8 a 4 grados)
			var target_basis = Basis().rotated(Vector3.FORWARD, deg2rad(4.0 * side_m))
			ul_p.basis = ul_p.basis.slerp(target_basis, idle_weight)
			skel.set_bone_pose(u_leg, ul_p)
			
		if l_leg != -1:
			var ll_p = skel.get_bone_pose(l_leg)
			# Forzar estiramiento de rodilla (Identidad)
			ll_p.basis = ll_p.basis.slerp(Basis(), idle_weight)
			skel.set_bone_pose(l_leg, ll_p)
			
		if f_leg != -1:
			var fl_p = skel.get_bone_pose(f_leg)
			# Compensar rotación de cadera (reducido de -8 a -4 grados)
			var target_basis = Basis().rotated(Vector3.FORWARD, deg2rad(-4.0 * side_m))
			fl_p.basis = fl_p.basis.slerp(target_basis, idle_weight)
			skel.set_bone_pose(f_leg, fl_p)

func _animate_limbs(p):
	# Ajustes dinámicos por velocidad
	var dyn_swing = deg2rad(swing_angle * lerp(1.0, 1.4, run_weight))
	var dyn_knee = deg2rad(lerp(40.0, 95.0, run_weight))
	var dyn_arm_swing = deg2rad(swing_angle * lerp(0.7, 1.5, run_weight))
	
	for side in ["L", "R"]:
		var p_side = p if side == "L" else p + PI
		
		# --- PIERNAS ---
		var u_leg = bones["UpperLeg" + side]
		var l_leg = bones["LowerLeg" + side]
		var f_leg = bones["Foot" + side]
		if u_leg != -1 and l_leg != -1:
			var swing = sin(p_side) * dyn_swing
			# Al correr, el swing hacia atrás es un poco menor que hacia adelante para realismo
			if swing < 0: swing *= 0.8
			
			var knee_bend = max(0, -cos(p_side)) * dyn_knee
			
			skel.set_bone_pose(u_leg, Transform(Basis().rotated(Vector3.RIGHT, swing), Vector3.ZERO))
			skel.set_bone_pose(l_leg, Transform(Basis().rotated(Vector3.RIGHT, knee_bend), Vector3.ZERO))
			
			if f_leg != -1:
				# Punta del pie hacia abajo al correr para empuje
				var f_rot = -(swing + knee_bend) + (lerp(0.0, 0.4, run_weight) if cos(p_side) > 0 else 0.0)
				skel.set_bone_pose(f_leg, Transform(Basis().rotated(Vector3.RIGHT, f_rot), Vector3.ZERO))
		
		# --- BRAZOS ---
		var u_arm = bones["UpperArm" + side]
		var l_arm = bones["LowerArm" + side]
		if u_arm != -1 and l_arm != -1:
			var p_arm = p_side + PI
			var a_swing = sin(p_arm) * dyn_arm_swing
			
			# Brazo se dobla más al correr (Pump)
			var elbow_base = lerp(-25.0, -75.0, run_weight)
			var elbow_swing = (cos(p_arm) * 0.5 + 0.5) * deg2rad(elbow_base)
			
			# Hombros rotan hacia adentro un poco al sprintar
			var arm_rot = Basis().rotated(Vector3.RIGHT, a_swing)
			var inward = deg2rad(lerp(5.0, 15.0, run_weight) * (1.0 if side == "L" else -1.0))
			arm_rot = arm_rot.rotated(Vector3.UP, inward)
			
			skel.set_bone_pose(u_arm, Transform(arm_rot, Vector3.ZERO))
			skel.set_bone_pose(l_arm, Transform(Basis().rotated(Vector3.RIGHT, elbow_swing), Vector3.ZERO))
			
			if side == "R" and is_holding_torch:
				_apply_torch_arm_pose()

func _animate_jump_pro():
	# Aplicar Poses con inclinación por inercia (Usando variables suavizadas)
	var h_p = Transform.IDENTITY
	h_p.origin.y = curr_crouch
	
	# Inclinación lateral y frontal basada en velocidad horizontal
	var jump_lean = clamp(horizontal_velocity.length() / 8.0, 0, 1)
	
	skel.set_bone_pose(bones["Hips"], h_p)
	
	if bones["Spine2"] != -1:
		var total_tilt = curr_torso_tilt + (jump_lean * 15.0) # Inclinar hacia adelante si corre
		skel.set_bone_pose(bones["Spine2"], Transform(Basis().rotated(Vector3.RIGHT, deg2rad(total_tilt)), Vector3.ZERO))
		
	for side in ["L", "R"]:
		var u_leg = bones["UpperLeg" + side]
		var l_leg = bones["LowerLeg" + side]
		var u_arm = bones["UpperArm" + side]
		
		# --- PIERNAS ---
		if u_leg != -1:
			var split = curr_leg_split if side == "L" else -curr_leg_split
			skel.set_bone_pose(u_leg, Transform(Basis().rotated(Vector3.RIGHT, deg2rad(-curr_leg_fold + split)), Vector3.ZERO))
		if l_leg != -1:
			# Pierna trasera se flexiona más para realismo
			var knee_factor = 1.2 if side == "L" else 0.8 
			skel.set_bone_pose(l_leg, Transform(Basis().rotated(Vector3.RIGHT, deg2rad(curr_leg_fold * knee_factor)), Vector3.ZERO))
			
		# --- BRAZOS (CORREGIDO: Split real) ---
		if u_arm != -1:
			var side_offset = 15.0 if side == "L" else -15.0
			
			# Lógica de Split: El brazo opuesto a la pierna adelantada va hacia adelante.
			# En nuestro sistema, Pierna L (+) es adelantada.
			# Entonces Brazo L debe ser (-) para ir atrás (Split negativo).
			# Brazo R debe ser (+) para ir adelante (Split positivo).
			var split_multiplier = -1.0 if side == "L" else 1.0
			var a_split_final = curr_arm_split * split_multiplier
			
			# Rotación total del brazo: Upward Reach (-arm_raise) + Split
			# Si curr_arm_raise es alto, ambos pueden ir adelante. 
			# Reducimos curr_arm_raise rítmicamente en el split.
			var actual_raise = curr_arm_raise * (1.0 - abs(a_split_final) / 90.0)
			
			# Rotación hacia afuera (ingravidez)
			var outward = 25.0 if abs(vertical_velocity) <= 2.0 and current_jump_state == JumpState.IN_AIR else 5.0
			
			var a_rot = Basis().rotated(Vector3.RIGHT, deg2rad(-actual_raise + a_split_final))
			a_rot = a_rot.rotated(Vector3.UP, deg2rad(side_offset + (outward if side == "L" else -outward)))
			skel.set_bone_pose(u_arm, Transform(a_rot, Vector3.ZERO))

func _get_jump_targets():
	var t = {
		"crouch": 0.0, "arm_raise": 0.0, "arm_split": 0.0,
		"leg_fold": 0.0, "leg_split": 0.0, "torso_tilt": 0.0
	}
	
	match current_jump_state:
		JumpState.ANTICIPATION:
			var time_f = clamp(jump_timer / 0.15, 0.0, 1.0)
			t.crouch = -0.3 * sin(time_f * PI * 0.5)
			t.arm_raise = -30.0 # Brazos atrás en anticipación
			t.torso_tilt = 15.0
			
		JumpState.IN_AIR:
			if vertical_velocity > 1.0: # Ascenso
				var v = clamp(vertical_velocity / 12.0, 0, 1)
				t.arm_raise = lerp(20.0, 90.0, v)
				t.arm_split = 40.0 # Split activo
				t.leg_fold = 20.0
				t.leg_split = 30.0
				t.torso_tilt = -10.0
			elif abs(vertical_velocity) <= 1.0: # Ápice
				t.arm_raise = 45.0
				t.arm_split = 50.0 # Máximo split
				t.leg_fold = 45.0
				t.leg_split = 40.0
				t.torso_tilt = 5.0
			else: # Descenso
				var v = clamp(abs(vertical_velocity) / 15.0, 0, 1)
				t.arm_raise = lerp(45.0, 0.0, v)
				t.arm_split = lerp(50.0, 10.0, v)
				t.leg_fold = lerp(45.0, -10.0, v) # Piernas estiradas para tocar suelo
				t.leg_split = lerp(40.0, 5.0, v)
				t.torso_tilt = 15.0
				
		JumpState.IMPACT:
			var time_f = clamp(jump_timer / 0.3, 0.0, 1.0)
			var s = sin(time_f * PI)
			t.crouch = -0.4 * s
			t.leg_fold = 50.0 * s
			t.arm_raise = 40.0 * s
			t.torso_tilt = 20.0 * s
			
	return t

func _animate_riding(p):
	# Obtener datos del caballo
	var h_bounce = 0.0
	var h_pitch = 0.0
	if current_horse:
		# Sumar rebote de galope + agachado de salto
		var total_bounce = current_horse.anim_bounce
		if "curr_h_crouch" in current_horse:
			total_bounce += current_horse.curr_h_crouch
		
		# Sumar pitch de galope + inclinación de salto
		var total_pitch = current_horse.anim_pitch
		if "curr_h_pitch" in current_horse:
			total_pitch += deg2rad(current_horse.curr_h_pitch)
			
		h_bounce = total_bounce
		h_pitch = total_pitch
	
	# Detección de intensidad de marcha (gait)
	var ride_intensity = 0.0
	if current_horse and "gait_lerp" in current_horse:
		ride_intensity = current_horse.gait_lerp
		
	# HIPS (Reaccionan al rebote del caballo)
	var h_p = Transform.IDENTITY
	# El jinete sigue al caballo con un poco de suavizado visual (inercia)
	h_p.origin.y = h_bounce * 0.9 + 0.1 
	# El jinete se inclina para compensar el cabeceo del caballo (Menos tambaleo al caminar)
	var hip_counter = lerp(0.1, 0.4, ride_intensity)
	h_p.basis = h_p.basis.rotated(Vector3.RIGHT, -h_pitch * hip_counter)
	skel.set_bone_pose(bones["Hips"], h_p)
	
	# SPINE (Mantiene el equilibrio e inclinación hacia adelante)
	if bones["Spine2"] != -1:
		# Inclinación base: 2 grados al caminar (casi recto), 15 al correr
		var base_tilt = lerp(2.0, 15.0, ride_intensity)
		# Reacción al cabeceo: Sutil al caminar, fuerte al correr
		var pitch_reaction = lerp(0.2, 0.7, ride_intensity)
		
		# Aplicar contrapeso inverso: Si caballo baja (-pitch), jinete sube (+pitch) (Contrapeso)
		# Nota: h_pitch ya viene con signo. Si caballo baja nariz (pitch -), queremos jinete atrás (pitch +)
		
		var s_rot = Basis().rotated(Vector3.RIGHT, deg2rad(base_tilt) - h_pitch * pitch_reaction)
		skel.set_bone_pose(bones["Spine2"], Transform(s_rot, Vector3.ZERO))
	
	# CABEZA (Estabilización/Horizonte)
	if bones["Head"] != -1:
		# Queremos que la cabeza se mantenga nivelada. 
		# Tenemos que contrarrestar la rotación heredada de Hips y Spine2.
		# Inclinación total heredada aprox: -h_pitch * hip_counter + (base_tilt - h_pitch * pitch_reaction)
		
		var head_counter = lerp(0.3, 0.8, ride_intensity) # Más estabilización al correr
		# Contra-rotación: Si el lomo baja, la cabeza sube para seguir mirando al frente
		var h_rot = Basis().rotated(Vector3.RIGHT, h_pitch * head_counter - deg2rad(5.0 * ride_intensity))
		skel.set_bone_pose(bones["Head"], Transform(h_rot, Vector3.ZERO))
		
	if bones["Neck"] != -1:
		# Pequeño ajuste en el cuello para fluidez
		var n_rot = Basis().rotated(Vector3.RIGHT, h_pitch * 0.2)
		skel.set_bone_pose(bones["Neck"], Transform(n_rot, Vector3.ZERO))
	
	# PIERNAS (Sentado estable)
	for side in ["L", "R"]:
		var u_leg = bones["UpperLeg" + side]
		var l_leg = bones["LowerLeg" + side]
		if u_leg != -1:
			var rot = Basis().rotated(Vector3.RIGHT, deg2rad(-80))
			var open_angle = -40.0 if side == "L" else 40.0
			rot = rot.rotated(Vector3.UP, deg2rad(open_angle))
			skel.set_bone_pose(u_leg, Transform(rot, Vector3.ZERO))
		if l_leg != -1:
			skel.set_bone_pose(l_leg, Transform(Basis().rotated(Vector3.RIGHT, deg2rad(90)), Vector3.ZERO))

	# BRAZOS (Sosteniendo riendas moviéndose rítmicamente)
	var arm_bounce = sin(p * 2.0) * 0.05
	for side in ["L", "R"]:
		var u_arm = bones["UpperArm" + side]
		var l_arm = bones["LowerArm" + side]
		if u_arm != -1:
			var rot = Basis().rotated(Vector3.RIGHT, deg2rad(-60 + arm_bounce * 10))
			# Juntar las manos: Rotar hacia adentro
			var inward = 15.0 if side == "L" else -15.0
			rot = rot.rotated(Vector3.UP, deg2rad(inward))
			skel.set_bone_pose(u_arm, Transform(rot, Vector3.ZERO))
		if l_arm != -1:
			# Antebrazo también un poco hacia adentro para cerrar la pose
			var rot = Basis().rotated(Vector3.RIGHT, deg2rad(-20 - arm_bounce * 20))
			var inward_low = 10.0 if side == "L" else -10.0
			rot = rot.rotated(Vector3.UP, deg2rad(inward_low))
			skel.set_bone_pose(l_arm, Transform(rot, Vector3.ZERO))
	
	if is_holding_torch:
		_apply_torch_arm_pose()

func _apply_torch_arm_pose():
	var u_arm = bones["UpperArmR"]
	var l_arm = bones["LowerArmR"]
	if u_arm != -1:
		# Levantar brazo hacia adelante y arriba
		var rot = Basis().rotated(Vector3.RIGHT, deg2rad(-80))
		rot = rot.rotated(Vector3.UP, deg2rad(-15)) # Mano hacia el centro
		skel.set_bone_pose(u_arm, Transform(rot, Vector3.ZERO))
	if l_arm != -1:
		# Doblar antebrazo un poco más
		var rot = Basis().rotated(Vector3.RIGHT, deg2rad(-40))
		skel.set_bone_pose(l_arm, Transform(rot, Vector3.ZERO))

func _animate_chopping():
	# ANIMACIÓN DE TALADO PRO V4 (Corrección Fundamental)
	# El jugador está girado 70 grados a la DER, el árbol está a su IZQ relativa.
	# PERO para generar fuerza, debe levantar el hacha hacia su DERECHA/ATRÁS y golpear hacia la IZQUIERDA (hacia el árbol).
	
	var raw_cycle = fmod(chop_phase, TAU) / TAU
	var t = 0.0
	
	# Curva de potencia: Carga lenta -> Aceleración explosiva -> Impacto seco
	if raw_cycle < 0.5: # Wind-up (Cargar hacia atrás)
		t = ease(raw_cycle / 0.5, 0.6) * 0.4
	else: # Strike (Golpear hacia adelante)
		var strike_t = (raw_cycle - 0.5) / 0.5
		t = 0.4 + ease(strike_t, 2.5) * 0.6
	
	# --- POSTURA DE PIERNAS (Base Sólida) ---
	# Piernas separadas para estabilidad
	for side in ["L", "R"]:
		var u_leg = bones["UpperLeg" + side]
		var l_leg = bones["LowerLeg" + side]
		var side_m = 1.0 if side == "L" else -1.0
		
		if u_leg != -1:
			var rot = Basis().rotated(Vector3.RIGHT, deg2rad(5)) # Leve flexión
			rot = rot.rotated(Vector3.UP, deg2rad(25 * side_m)) # Abiertas 25 grados
			skel.set_bone_pose(u_leg, Transform(rot, Vector3.ZERO))
		if l_leg != -1:
			skel.set_bone_pose(l_leg, Transform(Basis().rotated(Vector3.RIGHT, deg2rad(10)), Vector3.ZERO))

	# --- TORSO Y CADERAS (El Motor) ---
	# Wind-up (t=0): Girar a la DERECHA (Lejos del árbol)
	# Impact (t=1): Girar a la IZQUIERDA (Hacia el árbol)
	
	var h_p = Transform.IDENTITY
	h_p.origin.y = -0.1 - (sin(t * PI) * 0.1) # Compresión en el impacto
	
	# Cadera lidera el movimiento
	var hip_rot = lerp(-30.0, 30.0, t) 
	h_p.basis = h_p.basis.rotated(Vector3.UP, deg2rad(hip_rot))
	skel.set_bone_pose(bones["Hips"], h_p)
	
	if bones["Spine2"] != -1:
		# Torso rota mucho más (Carga elástica)
		var s_rot = Basis().rotated(Vector3.UP, deg2rad(lerp(-60, 50, t)))
		# Crunch abdominal en el impacto (Flexión frontal)
		var crunch = lerp(-10.0, 30.0, t)
		s_rot = s_rot.rotated(Vector3.RIGHT, deg2rad(crunch))
		# Inclinación lateral para alinear hombros
		var tilt = lerp(15.0, -15.0, t)
		s_rot = s_rot.rotated(Vector3.FORWARD, deg2rad(tilt))
		skel.set_bone_pose(bones["Spine2"], Transform(s_rot, Vector3.ZERO))

	# --- BRAZOS (El Swing) ---
	# Arco: De Arriba/Derecha/Atrás -> Abajo/Izquierda/Adelante
	var arm_pitch = lerp(-140.0, -40.0, t) # De muy arriba a abajo
	var arm_yaw = lerp(40.0, -40.0, t)     # De derecha a izquierda
	
	for side in ["L", "R"]:
		var u_arm = bones["UpperArm" + side]
		var l_arm = bones["LowerArm" + side]
		
		if u_arm != -1:
			var rot = Basis().rotated(Vector3.RIGHT, deg2rad(arm_pitch))
			rot = rot.rotated(Vector3.UP, deg2rad(arm_yaw))
			
			# Triángulo de manos (Grip cerrado)
			var inward = 25.0 if side == "L" else -25.0
			rot = rot.rotated(Vector3.UP, deg2rad(inward))
			
			skel.set_bone_pose(u_arm, Transform(rot, Vector3.ZERO))
			
		if l_arm != -1:
			# Extensión dinámica: Doblados al cargar, rectos al impactar
			var elbow = lerp(-45.0, -10.0, t)
			skel.set_bone_pose(l_arm, Transform(Basis().rotated(Vector3.RIGHT, deg2rad(elbow)), Vector3.ZERO))
func _animate_milking():
	# POSE DE ORDEÑO PROCEDURAL (Agachado/Arrodillado)
	var h_p = Transform.IDENTITY
	h_p.origin.y = -0.7 # Bajar mucho las caderas
	h_p.basis = h_p.basis.rotated(Vector3.RIGHT, deg2rad(10)) # Inclinación sutil
	skel.set_bone_pose(bones["Hips"], h_p)
	
	if bones["Spine2"] != -1:
		var s_rot = Basis().rotated(Vector3.RIGHT, deg2rad(25)) # Inclinación hacia adelante
		skel.set_bone_pose(bones["Spine2"], Transform(s_rot, Vector3.ZERO))
		
	# PIERNAS (Dobladas en ángulo agudo para kneeling)
	for side in ["L", "R"]:
		var u_leg = bones["UpperLeg" + side]
		var l_leg = bones["LowerLeg" + side]
		var f_leg = bones["Foot" + side]
		var side_m = 1.0 if side == "L" else -1.0
		
		if u_leg != -1:
			# Muslo muy arriba
			var rot = Basis().rotated(Vector3.RIGHT, deg2rad(-100))
			rot = rot.rotated(Vector3.UP, deg2rad(20 * side_m)) # Abrir un poco las rodillas
			skel.set_bone_pose(u_leg, Transform(rot, Vector3.ZERO))
		if l_leg != -1:
			# Rodilla muy doblada
			skel.set_bone_pose(l_leg, Transform(Basis().rotated(Vector3.RIGHT, deg2rad(120)), Vector3.ZERO))
		if f_leg != -1:
			# Pie plano o estirado
			skel.set_bone_pose(f_leg, Transform(Basis().rotated(Vector3.RIGHT, deg2rad(-20)), Vector3.ZERO))

	# BRAZOS (Posición de ordeño: hacia adelante y abajo)
	for side in ["L", "R"]:
		var u_arm = bones["UpperArm" + side]
		var l_arm = bones["LowerArm" + side]
		if u_arm != -1:
			var rot = Basis().rotated(Vector3.RIGHT, deg2rad(-30))
			var inward = 10.0 if side == "L" else -10.0
			rot = rot.rotated(Vector3.UP, deg2rad(inward))
			skel.set_bone_pose(u_arm, Transform(rot, Vector3.ZERO))
		if l_arm != -1:
			var rot = Basis().rotated(Vector3.RIGHT, deg2rad(-40))
			skel.set_bone_pose(l_arm, Transform(rot, Vector3.ZERO))
