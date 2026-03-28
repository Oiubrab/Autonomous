extends CharacterBody3D

## Player-controlled character — Litta, Folgim's prime attendant.
## Reads input, applies degradation modifiers, handles health.
## After the reframe, the player understands these inputs are Folgim's reach into her body.

const SPEED = 6.0
const DODGE_SPEED = 14.0
const DODGE_DURATION = 0.25
const JUMP_VELOCITY = 9.0
const GRAVITY = -20.0
const MAX_HP = 100.0
const ROTATION_SPEED = 10.0

@export var max_hp: float = MAX_HP

var hp: float = MAX_HP
var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var is_dead: bool = false
var _jumped_from_run: bool = false

@onready var camera_arm: Node3D = $CameraArm
@onready var camera: Camera3D = $CameraArm/Camera3D
@onready var model: Node3D = $LittaModel

# Camera orbit state
var _camera_pitch: float = -0.3
var _camera_yaw: float = 0.0
const CAMERA_SENSITIVITY = 0.003
const CAMERA_MIN_PITCH = -1.0
const CAMERA_MAX_PITCH = 0.5
const CAMERA_ZOOM_STEP = 0.5
const CAMERA_ZOOM_MIN = 2.0
const CAMERA_ZOOM_MAX = 12.0

var _camera_zoom: float = 6.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_camera_yaw -= event.relative.x * CAMERA_SENSITIVITY
		_camera_pitch = clamp(
			_camera_pitch - event.relative.y * CAMERA_SENSITIVITY,
			CAMERA_MIN_PITCH,
			CAMERA_MAX_PITCH
		)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_zoom = clamp(_camera_zoom - CAMERA_ZOOM_STEP, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_zoom = clamp(_camera_zoom + CAMERA_ZOOM_STEP, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			# Click anywhere to recapture after Escape.
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)

	if is_dodging:
		_process_dodge(delta)
	else:
		_process_movement(delta)
		_check_jump_input()
		_check_dodge_input()
		_check_attack_input()

	_update_camera()
	move_and_slide()
	_update_animation()

func _process_movement(delta: float) -> void:
	var input_dir := _get_input_direction()

	if input_dir != Vector3.ZERO:
		# Use world-space camera yaw so movement is always camera-relative
		var cam_basis := _get_camera_flat_basis()
		var world_dir := (cam_basis * input_dir).normalized()

		velocity.x = world_dir.x * SPEED
		velocity.z = world_dir.z * SPEED

		# Rotate character to face movement direction, then compensate _camera_yaw
		# so the camera stays fixed in world space despite the character rotating.
		var target_angle := atan2(world_dir.x, world_dir.z)
		var prev_y := rotation.y
		rotation.y = lerp_angle(rotation.y, target_angle, ROTATION_SPEED * delta)
		_camera_yaw -= rotation.y - prev_y
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

func _process_dodge(delta: float) -> void:
	dodge_timer -= delta
	velocity.x = dodge_direction.x * DODGE_SPEED
	velocity.z = dodge_direction.z * DODGE_SPEED
	if dodge_timer <= 0.0:
		is_dodging = false

func _check_jump_input() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_jumped_from_run = Vector2(velocity.x, velocity.z).length() > 0.5
		velocity.y = JUMP_VELOCITY

func _check_dodge_input() -> void:
	if Input.is_action_just_pressed("dodge"):
		var input_dir := _get_input_direction()
		if input_dir == Vector3.ZERO:
			input_dir = -transform.basis.z  # dodge forward if no direction held
		var cam_basis := _get_camera_flat_basis()
		dodge_direction = (cam_basis * input_dir).normalized()
		is_dodging = true
		dodge_timer = DODGE_DURATION

func _check_attack_input() -> void:
	if Input.is_action_just_pressed("attack"):
		model.play_once("attack")

func _update_animation() -> void:
	if is_dead:
		model.play("dead")
		return
	if not is_on_floor():
		model.play("run_jump" if _jumped_from_run else "jump")
		return
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	if flat_speed > 0.5:
		model.play("run")
	else:
		model.play("idle")

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

func _update_camera() -> void:
	camera_arm.rotation.y = _camera_yaw
	camera_arm.rotation.x = _camera_pitch
	camera.position.z = _camera_zoom

func _get_input_direction() -> Vector3:
	var raw := Vector3(
		Input.get_axis("move_left", "move_right"),
		0,
		Input.get_axis("move_forward", "move_back")
	)
	if raw.length() > 1.0:
		raw = raw.normalized()
	return raw

func _get_camera_flat_basis() -> Basis:
	# World yaw = Litta's own rotation + arm's local yaw offset
	return Basis(Vector3.UP, rotation.y + _camera_yaw)

# --- Health ---

func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp = max(0.0, hp - amount)
	if hp <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	GameState.on_litta_death()
