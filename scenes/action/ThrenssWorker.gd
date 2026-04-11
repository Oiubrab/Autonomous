extends CharacterBody3D

@export var move_speed: float = 2.0
@export var waypoints: Array[NodePath] = []

const GRAVITY      := 9.8
const ARRIVE_DIST  := 1.2
const STUCK_TIME   := 2.0
const STUCK_DIST   := 0.3
const SEPARATION   := 2.0   # min distance to maintain from other workers
const SEP_STRENGTH := 4.0   # how hard to push away when too close

var _waypoint_nodes: Array[Node3D] = []
var _current_wp: int = 0
# Small random offset applied per-instance so two workers heading to the
# same waypoint don't converge on the exact same point.
var _wp_offset: Vector3 = Vector3.ZERO

var _stuck_timer:    float   = 0.0
var _last_check_pos: Vector3 = Vector3.ZERO

var _skel: Skeleton3D = null
var _b: Dictionary = {}
var _base_rot: Dictionary = {}
var _t: float = 0.0

# Gaussian random head motion — two independent channels
var _rng := RandomNumberGenerator.new()

# Y axis — look left/right
var _head_y_rot:       float = 0.0
var _head_y_dir:       float = 0.0
var _head_y_epoch:     float = 2.0
var _head_y_elapsed:   float = 0.0

# Z axis — confirmed forward/back nod
var _head_z_rot:       float = 0.0
var _head_z_dir:       float = 0.0
var _head_z_epoch:     float = 1.5
var _head_z_elapsed:   float = 0.0

# [bone_name, axis (0=X,1=Y,2=Z), amplitude, freq, phase]
# Axes confirmed empirically: Z = forward/back on most bones.
# Body/arm bones need the same base_rot preservation as leg bones.
const BODY_BONES = []  # head handled separately via Gaussian random motion

const LEG_BONES = [
	["rightCentralLeg",    0.12, 0.0],
	["rightFrontUpperLeg", 0.10, 0.0],
	["rightFrontLowerLeg", 0.08, 0.0],
	["rightFrontTarsal",   0.06, 0.0],
	["rightBackUpperLeg",  0.10, PI ],
	["rightBackLowerLeg",  0.08, PI ],
	["rightBackTarsal",    0.06, PI ],
	["leftCentralLeg",     0.12, PI ],
	["leftFrontUpperLeg",  0.10, PI ],
	["leftFrontLowerLeg",  0.08, PI ],
	["leftFrontTarsal",    0.06, PI ],
	["leftBackUpperLeg",   0.10, 0.0],
	["leftBackLowerLeg",   0.08, 0.0],
	["leftBackTarsal",     0.06, 0.0],
]

func _ready() -> void:
	add_to_group("threnss_worker")
	randomize()
	_rng.randomize()
	# Stagger each worker's head epoch so they don't all move in sync
	_head_y_elapsed = _rng.randf_range(0.0, 3.0)
	_head_z_elapsed = _rng.randf_range(0.0, 4.0)
	_wp_offset = Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2))

	_skel = _find_skeleton(self)
	if _skel:
		for entry in LEG_BONES:
			var idx := _skel.find_bone(entry[0])
			if idx >= 0:
				_b[entry[0]] = idx
				_base_rot[entry[0]] = _skel.get_bone_pose_rotation(idx)
		# Cache head bone explicitly for Gaussian animation
		for bn in ["head"]:
			var idx := _skel.find_bone(bn)
			if idx >= 0:
				_b[bn] = idx
				_base_rot[bn] = _skel.get_bone_pose_rotation(idx)

	for np in waypoints:
		var n := get_node_or_null(np)
		if n is Node3D:
			_waypoint_nodes.append(n as Node3D)

	_last_check_pos = global_position

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var r := _find_skeleton(child)
		if r:
			return r
	return null

func _physics_process(delta: float) -> void:
	_t += delta

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var move_dir := Vector3.ZERO

	if not _waypoint_nodes.is_empty():
		var raw_target := _waypoint_nodes[_current_wp].global_position + _wp_offset
		var flat_self  := Vector3(global_position.x, 0.0, global_position.z)
		var flat_tgt   := Vector3(raw_target.x, 0.0, raw_target.z)
		var to_target  := flat_tgt - flat_self

		if to_target.length() < ARRIVE_DIST:
			_current_wp = (_current_wp + 1) % _waypoint_nodes.size()
			# Fresh random offset for the next waypoint
			_wp_offset = Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2))
		else:
			move_dir = to_target.normalized()

	# Separation: push away from nearby workers of the same type
	for other: Node in get_tree().get_nodes_in_group("threnss_worker"):
		if other == self:
			continue
		var away := global_position - (other as Node3D).global_position
		away.y = 0.0
		var dist := away.length()
		if dist < SEPARATION and dist > 0.001:
			move_dir += away.normalized() * (SEPARATION - dist) / SEPARATION * SEP_STRENGTH * delta

	if move_dir.length() > 0.001:
		move_dir = move_dir.normalized()
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		global_basis = global_basis.slerp(Basis.looking_at(move_dir, Vector3.UP), delta * 5.0)

	# Stuck detection — skip waypoint if barely moved
	_stuck_timer += delta
	if _stuck_timer >= STUCK_TIME:
		if global_position.distance_to(_last_check_pos) < STUCK_DIST:
			_current_wp = (_current_wp + 1) % _waypoint_nodes.size()
			_wp_offset  = Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2))
			velocity.x  = 0.0
			velocity.z  = 0.0
		_stuck_timer    = 0.0
		_last_check_pos = global_position

	move_and_slide()

	# Leg speed proportional to actual horizontal velocity
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	var speed_ratio: float = clamp(horiz_speed / move_speed, 0.0, 1.0)

	if _skel:
		for entry in LEG_BONES:
			var bone_name: String = entry[0]
			var amp: float        = entry[1]
			var phase: float      = entry[2]
			if not _b.has(bone_name):
				continue
			var freq := 3.0
			if bone_name.ends_with("LowerLeg"): freq = 3.4
			if bone_name.ends_with("Tarsal"):   freq = 3.8
			# Walk cycle scales with movement; idle sway always present
			var walk_angle: float = sin(_t * freq * speed_ratio + phase) * amp * speed_ratio
			var idle_angle: float = sin(_t * 0.8 + phase) * amp * 0.2
			var angle:      float = walk_angle + idle_angle
			var euler: Vector3
			if bone_name.ends_with("CentralLeg"):
				euler = Vector3(angle, 0, 0)
			else:
				euler = Vector3(0, 0, angle)
			var base: Quaternion = _base_rot[bone_name]
			_skel.set_bone_pose_rotation(_b[bone_name], base * Quaternion.from_euler(euler))

		# Body / head idle animation — accumulate per bone then apply once
		var body_rot: Dictionary = {}
		for entry in BODY_BONES:
			var bn: String    = entry[0]
			var axis: int     = entry[1]
			var bamp: float   = entry[2]
			var freq: float   = entry[3]
			var bphase: float = entry[4]
			if not _b.has(bn):
				continue
			var angle: float = sin(_t * freq + bphase) * bamp
			var ev := Vector3(
				angle if axis == 0 else 0.0,
				angle if axis == 1 else 0.0,
				angle if axis == 2 else 0.0,
			)
			if body_rot.has(bn):
				body_rot[bn] = (body_rot[bn] as Quaternion) * Quaternion.from_euler(ev)
			else:
				body_rot[bn] = Quaternion.from_euler(ev)
		for bn in body_rot:
			var base: Quaternion = _base_rot[bn]
			_skel.set_bone_pose_rotation(_b[bn], base * (body_rot[bn] as Quaternion))

		_animate_head(delta)

func _gaussian_step(elapsed: float, epoch: float, dir: float, amp: float) -> float:
	var gauss_t := (elapsed - epoch * 0.5) / (epoch / 8.0)
	var gaussian := exp(-gauss_t * gauss_t)
	return (PI / 3.0) * dir * gaussian * amp

func _animate_head(delta: float) -> void:
	if not _b.has("head"):
		return

	# Y channel — look left/right
	_head_y_elapsed += delta
	if _head_y_elapsed >= _head_y_epoch:
		_head_y_elapsed = 0.0
		_head_y_dir     = _rng.randf_range(-1.0, 1.0)
		_head_y_epoch   = _rng.randf_range(1.0, 4.0)
	_head_y_rot += _gaussian_step(_head_y_elapsed, _head_y_epoch, _head_y_dir, 1.0) * delta

	# Z channel — nod forward/back (confirmed axis)
	_head_z_elapsed += delta
	if _head_z_elapsed >= _head_z_epoch:
		_head_z_elapsed = 0.0
		_head_z_dir     = _rng.randf_range(-1.0, 1.0)
		_head_z_epoch   = _rng.randf_range(1.5, 5.0)
	_head_z_rot += _gaussian_step(_head_z_elapsed, _head_z_epoch, _head_z_dir, 0.5) * delta

	# Clamp so head doesn't spin wildly
	_head_y_rot = clamp(_head_y_rot, -0.8, 0.8)
	_head_z_rot = clamp(_head_z_rot, -0.4, 0.4)

	var base: Quaternion = _base_rot["head"]
	var q := Quaternion.from_euler(Vector3(0.0, _head_y_rot, _head_z_rot))
	_skel.set_bone_pose_rotation(_b["head"], base * q)
