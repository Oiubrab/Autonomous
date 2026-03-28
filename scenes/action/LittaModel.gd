extends Node3D

## Manages Litta's visual mesh and animations.
## Instances the base GLB (Idle) and merges animations from the other per-animation GLBs
## into a single AnimationPlayer at runtime. Works because all GLBs share the same skeleton.

const _DIR = "res://assets/characters/litta/"

# Maps our internal animation names to the GLB files that contain them.
const _SOURCES := {
	"idle":   "Meshy_AI_Icebound_Warrior_biped_Animation_Idle_withSkin.glb",
	"run":    "Meshy_AI_Icebound_Warrior_biped_Animation_Running_withSkin.glb",
	"walk":   "Meshy_AI_Icebound_Warrior_biped_Animation_Walking_withSkin.glb",
	"attack": "Meshy_AI_Icebound_Warrior_biped_Animation_Attack_withSkin.glb",
	"dead":   "Meshy_AI_Icebound_Warrior_biped_Animation_Dead_withSkin.glb",
	"jump":     "Meshy_AI_Animation_Regular_Jump_withSkin.glb",
	"run_jump": "Meshy_AI_Animation_Jump_Over_Obstacle_2_withSkin.glb",
}

var _player: AnimationPlayer

func _ready() -> void:
	_build()

func _build() -> void:
	var base = load(_DIR + _SOURCES["idle"]).instantiate()
	add_child(base)

	_player = _find_player(base)
	if not _player:
		push_error("LittaModel: no AnimationPlayer found in base GLB")
		return

	_rename_first_anim(_player, "idle")

	for anim_name: String in _SOURCES:
		if anim_name == "idle":
			continue
		_import_anim(anim_name, _SOURCES[anim_name])

	play("idle")

# Animations that have root motion baked in — strip their position tracks on import.
const _STRIP_ROOT_MOTION := ["run", "walk", "attack", "dead", "jump", "run_jump"]

func _import_anim(our_name: String, filename: String) -> void:
	var scene = load(_DIR + filename)
	if not scene:
		return
	var inst = scene.instantiate()
	var src = _find_player(inst)
	if src:
		var src_lib = src.get_animation_library("")
		var dst_lib = _player.get_animation_library("")
		for src_name: String in src_lib.get_animation_list():
			if src_name == "RESET":
				continue
			if not dst_lib.has_animation(our_name):
				var anim := src_lib.get_animation(src_name).duplicate()
				if our_name in _STRIP_ROOT_MOTION:
					_strip_root_motion(anim)
				dst_lib.add_animation(our_name, anim)
			break
	inst.queue_free()

func _strip_root_motion(anim: Animation) -> void:
	# Remove all TYPE_POSITION_3D tracks — root motion can be on a plain node
	# or on a root bone (e.g. "Skeleton3D:Hips"), so we strip both cases.
	# Standard biped animations are purely rotational; position tracks == root motion.
	for i in range(anim.get_track_count() - 1, -1, -1):
		if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			anim.remove_track(i)

func _rename_first_anim(player: AnimationPlayer, new_name: String) -> void:
	var lib = player.get_animation_library("")
	for anim_name: String in lib.get_animation_list():
		if anim_name == "RESET" or anim_name == new_name:
			continue
		var anim = lib.get_animation(anim_name)
		lib.add_animation(new_name, anim)
		lib.remove_animation(anim_name)
		break

func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = _find_player(child)
		if result:
			return result
	return null

# Per-animation scale corrections for GLB export inconsistencies.
const _ANIM_SCALES := {
	"run":      1.15,
	"jump":     1.15,
	"run_jump": 1.15,
}

func play(anim_name: String) -> void:
	if _player and _player.has_animation(anim_name):
		if _player.current_animation != anim_name:
			_player.play(anim_name)
			var s: float = _ANIM_SCALES.get(anim_name, 1.0)
			scale = Vector3(s, s, s)

func play_once(anim_name: String, return_to: String = "idle") -> void:
	if not _player or not _player.has_animation(anim_name):
		return
	_player.play(anim_name)
	await _player.animation_finished
	play(return_to)
