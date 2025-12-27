extends Spatial

var skeleton # Skeleton
var bone_ids = {}

func _ready():
	create_skeleton()

func create_skeleton():
	print("=== CREATING HUMANOID SKELETON ===")
	skeleton = Skeleton.new()
	add_child(skeleton)
	print("Skeleton node created and added as child")
	
	# Crear jerarquía de huesos
	# Root (invisible, para transformaciones globales)
	skeleton.add_bone("Root")
	var root_id = skeleton.find_bone("Root")
	print("Root bone ID: ", root_id)
	if root_id >= 0:
		skeleton.set_bone_pose(root_id, Transform(Basis(), Vector3(0, 1, 0)))
	
	# Hips (centro del cuerpo)
	skeleton.add_bone("Hips")
	var hips_id = skeleton.find_bone("Hips")
	print("Hips bone ID: ", hips_id)
	if hips_id >= 0:
		skeleton.set_bone_parent(hips_id, root_id)
		skeleton.set_bone_pose(hips_id, Transform(Basis(), Vector3(0, 0.95, 0)))
	
	# Spine → Chest → Neck → Head
	skeleton.add_bone("Spine")
	var spine_id = skeleton.find_bone("Spine")
	print("Spine bone ID: ", spine_id)
	if spine_id >= 0:
		skeleton.set_bone_parent(spine_id, hips_id)
		skeleton.set_bone_pose(spine_id, Transform(Basis(), Vector3(0, 0.2, 0)))
	
	skeleton.add_bone("Chest")
	var chest_id = skeleton.find_bone("Chest")
	print("Chest bone ID: ", chest_id)
	if chest_id >= 0:
		skeleton.set_bone_parent(chest_id, spine_id)
		skeleton.set_bone_pose(chest_id, Transform(Basis(), Vector3(0, 0.25, 0)))
	
	skeleton.add_bone("Neck")
	var neck_id = skeleton.find_bone("Neck")
	print("Neck bone ID: ", neck_id)
	if neck_id >= 0:
		skeleton.set_bone_parent(neck_id, chest_id)
		skeleton.set_bone_pose(neck_id, Transform(Basis(), Vector3(0, 0.2, 0)))
	
	skeleton.add_bone("Head")
	var head_id = skeleton.find_bone("Head")
	print("Head bone ID: ", head_id)
	if head_id >= 0:
		skeleton.set_bone_parent(head_id, neck_id)
		skeleton.set_bone_pose(head_id, Transform(Basis(), Vector3(0, 0.1, 0)))
	
	# Piernas (ambos lados)
	for side in ["L", "R"]:
		var side_mult = 1.0 if side == "R" else -1.0
		
		skeleton.add_bone("Thigh_" + side)
		var thigh_id = skeleton.find_bone("Thigh_" + side)
		print("Thigh_", side, " bone ID: ", thigh_id)
		if thigh_id >= 0:
			skeleton.set_bone_parent(thigh_id, hips_id)
			skeleton.set_bone_pose(thigh_id, Transform(Basis(), Vector3(0.1 * side_mult, -0.05, 0)))
			bone_ids["Thigh_" + side] = thigh_id
		
		skeleton.add_bone("Calf_" + side)
		var calf_id = skeleton.find_bone("Calf_" + side)
		print("Calf_", side, " bone ID: ", calf_id)
		if calf_id >= 0:
			skeleton.set_bone_parent(calf_id, thigh_id)
			skeleton.set_bone_pose(calf_id, Transform(Basis(), Vector3(0, -0.45, 0)))
			bone_ids["Calf_" + side] = calf_id
		
		skeleton.add_bone("Foot_" + side)
		var foot_id = skeleton.find_bone("Foot_" + side)
		print("Foot_", side, " bone ID: ", foot_id)
		if foot_id >= 0:
			skeleton.set_bone_parent(foot_id, calf_id)
			skeleton.set_bone_pose(foot_id, Transform(Basis(), Vector3(0, -0.45, 0)))
			bone_ids["Foot_" + side] = foot_id
	
	# Brazos (ambos lados)
	for side in ["L", "R"]:
		var side_mult = 1.0 if side == "R" else -1.0
		
		skeleton.add_bone("Shoulder_" + side)
		var shoulder_id = skeleton.find_bone("Shoulder_" + side)
		print("Shoulder_", side, " bone ID: ", shoulder_id)
		if shoulder_id >= 0:
			skeleton.set_bone_parent(shoulder_id, chest_id)
			skeleton.set_bone_pose(shoulder_id, Transform(Basis(), Vector3(0.22 * side_mult, 0.1, 0)))
			bone_ids["Shoulder_" + side] = shoulder_id
		
		skeleton.add_bone("UpperArm_" + side)
		var upper_arm_id = skeleton.find_bone("UpperArm_" + side)
		print("UpperArm_", side, " bone ID: ", upper_arm_id)
		if upper_arm_id >= 0:
			skeleton.set_bone_parent(upper_arm_id, shoulder_id)
			skeleton.set_bone_pose(upper_arm_id, Transform(Basis(), Vector3(0, -0.25, 0)))
			bone_ids["UpperArm_" + side] = upper_arm_id
		
		skeleton.add_bone("Forearm_" + side)
		var forearm_id = skeleton.find_bone("Forearm_" + side)
		print("Forearm_", side, " bone ID: ", forearm_id)
		if forearm_id >= 0:
			skeleton.set_bone_parent(forearm_id, upper_arm_id)
			skeleton.set_bone_pose(forearm_id, Transform(Basis(), Vector3(0, -0.25, 0)))
			bone_ids["Forearm_" + side] = forearm_id
		
		skeleton.add_bone("Hand_" + side)
		var hand_id = skeleton.find_bone("Hand_" + side)
		print("Hand_", side, " bone ID: ", hand_id)
		if hand_id >= 0:
			skeleton.set_bone_parent(hand_id, forearm_id)
			skeleton.set_bone_pose(hand_id, Transform(Basis(), Vector3(0, -0.15, 0)))
			bone_ids["Hand_" + side] = hand_id
	
	# Guardar IDs importantes
	bone_ids["Root"] = root_id
	bone_ids["Hips"] = hips_id
	bone_ids["Spine"] = spine_id
	bone_ids["Chest"] = chest_id
	bone_ids["Neck"] = neck_id
	bone_ids["Head"] = head_id
	
	print("=== SKELETON CREATION COMPLETE ===")
	print("Total bones created: ", skeleton.get_bone_count())
	print("Bone IDs dictionary size: ", bone_ids.size())

func get_skeleton():
	return skeleton

func get_bone_id(bone_name):
	if bone_ids.has(bone_name):
		return bone_ids[bone_name]
	else:
		print("WARNING: Bone '" + bone_name + "' not found in skeleton")
		return -1
