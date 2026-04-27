class_name WeaponHolder
extends Node

## Attaches weapon meshes to Litta's right hand bone via BoneAttachment3D,
## which is driven internally by the skeleton rather than by our _process,
## avoiding the race where _process runs before the AnimationPlayer updates
## bone poses for the current frame.

const WEAPON_DIR = "res://assets/weapons/"

const _HAND_BONE_CANDIDATES = [
	"RightHand", "Right_Hand", "Hand_R", "hand_r", "hand.R",
	"mixamorig:RightHand", "Bip001_R_Hand", "wrist.R",
]

var _blade: Node3D
var _gun: Node3D
var _active: Node3D

func setup(skeleton: Skeleton3D) -> void:
	if not skeleton:
		push_warning("WeaponHolder: no skeleton provided")
		return

	var bone_idx := -1
	var bone_name := ""
	for candidate: String in _HAND_BONE_CANDIDATES:
		bone_idx = skeleton.find_bone(candidate)
		if bone_idx >= 0:
			bone_name = candidate
			break

	if bone_idx < 0:
		var names: Array = []
		for i in range(skeleton.get_bone_count()):
			names.append(skeleton.get_bone_name(i))
		push_warning("WeaponHolder: right hand bone not found. Bones: " + str(names))
		return

	var blade_scene = load(WEAPON_DIR + "weapon_blade.glb")
	var gun_scene   = load(WEAPON_DIR + "weapon_gun.glb")
	if not blade_scene or not gun_scene:
		push_error("WeaponHolder: failed to load weapon GLBs")
		return

	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)

	_blade = blade_scene.instantiate()
	_gun   = gun_scene.instantiate()
	attachment.add_child(_blade)
	attachment.add_child(_gun)

	_blade.scale = Vector3(0.4, 0.4, 0.4)
	_gun.scale   = Vector3(0.4, 0.4, 0.4)

	_gun.visible = false
	_active = _blade
	print("WeaponHolder: attached to bone '", bone_name, "' (idx ", bone_idx, ")")

func show_blade() -> void:
	if _blade: _blade.visible = true
	if _gun:   _gun.visible = false
	_active = _blade

func show_gun() -> void:
	if _blade: _blade.visible = false
	if _gun:   _gun.visible = true
	_active = _gun
