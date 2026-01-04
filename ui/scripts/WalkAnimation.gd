extends Spatial

# --- SISTEMA DE ANIMACIÓN PROCEDURAL V9 (OPTIMIZADO) ---

var skel = null  # No usar onready, buscar en _ready()

var phase = 0.0
var walk_speed = 0.0
var is_walking = false

var bones = {
	"Hips": -1,
	"Spine2": -1,
	"UpperLegL": -1, "LowerLegL": -1, "FootL": -1,
	"UpperLegR": -1, "LowerLegR": -1, "FootR": -1,
	"UpperArmL": -1, "LowerArmL": -1,
	"UpperArmR": -1, "LowerArmR": -1
}

export var speed_multiplier = 4.5
export var step_lift = 0.3
export var swing_angle = 35.0
export var bounce_amp = 0.05

func _ready():
	# Buscar skeleton con múltiples intentos
	yield(get_tree(), "idle_frame")  # Esperar un frame para que ProceduralHumanoid termine
	
	# Intentar múltiples rutas
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
	
	# Inicializar IDs de huesos
	if skel:
		print("✅ WalkAnimation: Skeleton encontrado con", skel.get_bone_count(), "huesos")
		for b in bones.keys():
			bones[b] = skel.find_bone(b)
			if bones[b] == -1:
				print("❌ Hueso NO encontrado:", b)
			else:
				print("✅ Hueso encontrado:", b, "=", bones[b])
	else:
		print("❌ ERROR: WalkAnimation NO encontró el skeleton")
		print("   Buscado en: MeshInstance/HumanoidRig")

func _process(delta):
	if not skel:
		return
	
	if is_walking and walk_speed > 0.1:
		phase += delta * speed_multiplier * walk_speed
		if phase > TAU: phase -= TAU
	else:
		phase = lerp(phase, 0.0, 5.0 * delta)
	
	_animate()

func set_walking(walking, s):
	is_walking = walking
	walk_speed = clamp(s / 5.0, 0.0, 2.0)

var is_riding = false
var current_horse = null
func set_riding(riding, horse = null):
	is_riding = riding
	current_horse = horse

func _animate():
	var bounce = -abs(sin(phase)) * bounce_amp
	var sway = sin(phase) * 0.03
	
	if is_riding:
		_animate_riding(phase)
		return
	
	# Hips (Caminando)
	var h_p = Transform.IDENTITY
	h_p.origin.y = bounce
	h_p.basis = h_p.basis.rotated(Vector3.FORWARD, sway)
	skel.set_bone_pose(bones["Hips"], h_p)
	
	# Torso
	if bones["Spine2"] != -1:
		var s_p = Transform.IDENTITY
		s_p.basis = s_p.basis.rotated(Vector3.FORWARD, -sway * 0.8)
		skel.set_bone_pose(bones["Spine2"], s_p)
	
	_animate_limbs(phase)

func _animate_limbs(p):
	for side in ["L", "R"]:
		var p_side = p if side == "L" else p + PI
		
		# --- PIERNAS ---
		var u_leg = bones["UpperLeg" + side]
		var l_leg = bones["LowerLeg" + side]
		var f_leg = bones["Foot" + side]
		if u_leg != -1 and l_leg != -1:
			var swing = sin(p_side) * deg2rad(swing_angle)
			var knee_bend = max(0, -cos(p_side)) * deg2rad(40)
			
			skel.set_bone_pose(u_leg, Transform(Basis().rotated(Vector3.RIGHT, swing), Vector3.ZERO))
			skel.set_bone_pose(l_leg, Transform(Basis().rotated(Vector3.RIGHT, knee_bend), Vector3.ZERO))
			
			if f_leg != -1:
				skel.set_bone_pose(f_leg, Transform(Basis().rotated(Vector3.RIGHT, -(swing + knee_bend)), Vector3.ZERO))
		
		# --- BRAZOS ---
		var u_arm = bones["UpperArm" + side]
		var l_arm = bones["LowerArm" + side]
		if u_arm != -1 and l_arm != -1:
			var p_arm = p_side + PI
			var a_swing = sin(p_arm) * deg2rad(swing_angle * 0.7)
			var elbow_bend = (cos(p_arm) * 0.5 + 0.5) * deg2rad(-25)
			
			skel.set_bone_pose(u_arm, Transform(Basis().rotated(Vector3.RIGHT, a_swing), Vector3.ZERO))
			skel.set_bone_pose(l_arm, Transform(Basis().rotated(Vector3.RIGHT, elbow_bend), Vector3.ZERO))

func _animate_riding(p):
	# Obtener datos del caballo
	var h_bounce = 0.0
	var h_pitch = 0.0
	if current_horse:
		h_bounce = current_horse.anim_bounce
		h_pitch = current_horse.anim_pitch
	
	# HIPS (Reaccionan al rebote)
	var h_p = Transform.IDENTITY
	# El jinete rebota un poco mas (inercia) pero siguiendo al caballo
	h_p.origin.y = h_bounce * 0.8 + 0.1 
	# Inclinación opuesta al caballo (para mantener el equilibrio del torso)
	h_p.basis = h_p.basis.rotated(Vector3.RIGHT, -h_pitch * 0.5)
	skel.set_bone_pose(bones["Hips"], h_p)
	
	# SPINE (Contrarresta el cabeceo del caballo para que la cabeza del jinete este estable)
	if bones["Spine2"] != -1:
		var s_rot = Basis().rotated(Vector3.RIGHT, -h_pitch * 0.7)
		skel.set_bone_pose(bones["Spine2"], Transform(s_rot, Vector3.ZERO))
	
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
