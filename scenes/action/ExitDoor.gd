extends Node3D

## Exit door — slides open then transitions to the outdoor scene.

@export var target_scene: String = "res://scenes/outdoor/OutdoorScene.tscn"
@export var open_duration: float = 0.8

@onready var panel: AnimatableBody3D = $DoorPanel
@onready var interact_area: Area3D   = $InteractArea

var _player_nearby: bool = false
var _busy: bool = false

func _ready() -> void:
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or _busy:
		return
	if event.is_action_pressed("interact"):
		_open_and_exit()

func _open_and_exit() -> void:
	_busy = true
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "position:y", panel.position.y + 8.0, open_duration)
	await tween.finished
	get_tree().change_scene_to_file(target_scene)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
