extends Spatial

# --- SISTEMA DE ANIMACIÓN PROCEDURAL V8 (SIN DESPRENDIMIENTOS) ---

var skel = null
var phase = 0.0
var walk_speed = 0.0
var is_walking = false
var setup_done = false
var timer = 0.0

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

func _process(delta):
	if not setup_done:
		timer += delta
		if timer > 0.5:
			_try_setup()
		return

	if is_walking and walk_speed > 0.1:
		phase += delta * speed_multiplier * walk_speed
		if phase > TAU: phase -= TAU
	else:
		phase = lerp(phase, 0.0, 5.0 * delta)
	
	if skel:
		_animate()

func _try_setup():
	var mesh = get_parent().get_node_or_null("MeshInstance")
	if mesh:
		skel = mesh.get_node_or_null("HumanoidSkeleton")
		if skel:
			print("WalkAnimation V8: Vinculando...")
			for b in bones.keys():
				bones[b] = skel.find_bone(b)
			setup_done = true

func set_walking(walking, s):
	is_walking = walking
	walk_speed = clamp(s / 5.0, 0.0, 2.0)

func _animate():
	var bounce = -abs(sin(phase)) * bounce_amp
	var sway = sin(phase) * 0.03
	
	# Hips
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
			# La rodilla se dobla durante el balanceo hacia adelante (cuando swing disminuye hacia -swing_angle)
			var knee_bend = max(0, -cos(p_side)) * deg2rad(40)
			
			skel.set_bone_pose(u_leg, Transform(Basis().rotated(Vector3.RIGHT, swing), Vector3.ZERO))
			skel.set_bone_pose(l_leg, Transform(Basis().rotated(Vector3.RIGHT, knee_bend), Vector3.ZERO))
			
			# Mantener el pie plano compensando las rotaciones de la pierna
			if f_leg != -1:
				skel.set_bone_pose(f_leg, Transform(Basis().rotated(Vector3.RIGHT, -(swing + knee_bend)), Vector3.ZERO))
		
		# --- BRAZOS ---
		var u_arm = bones["UpperArm" + side]
		var l_arm = bones["LowerArm" + side]
		if u_arm != -1 and l_arm != -1:
			var p_arm = p_side + PI
			var a_swing = sin(p_arm) * deg2rad(swing_angle * 0.7)
			# Codo doblado sutilmente
			var elbow_bend = (cos(p_arm) * 0.5 + 0.5) * deg2rad(-25)
			
			skel.set_bone_pose(u_arm, Transform(Basis().rotated(Vector3.RIGHT, a_swing), Vector3.ZERO))
			skel.set_bone_pose(l_arm, Transform(Basis().rotated(Vector3.RIGHT, elbow_bend), Vector3.ZERO))
