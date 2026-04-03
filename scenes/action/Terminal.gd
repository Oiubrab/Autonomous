extends StaticBody3D

## Interactable terminal. Emits interacted signal when player activates it.
## Extend this with specific terminal behaviour (data logs, unlock events, etc.)

signal interacted(terminal: Node)

@onready var interact_area: Area3D = $InteractArea
@onready var prompt_label: Label3D = $PromptLabel
@onready var screen_light: OmniLight3D = $ScreenLight

@export var terminal_id: String = ""
@export var idle_color: Color = Color(0.1, 0.9, 0.6, 1)
@export var active_color: Color = Color(0.9, 0.5, 0.1, 1)

var _player_nearby: bool = false
var _activated: bool = false

func _ready() -> void:
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	prompt_label.visible = false
	screen_light.light_color = idle_color

func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby:
		return
	if event.is_action_pressed("interact"):
		_activate()

func _activate() -> void:
	_activated = not _activated
	var tween := create_tween()
	tween.tween_property(screen_light, "light_color",
		active_color if _activated else idle_color, 0.3)
	interacted.emit(self)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		prompt_label.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		prompt_label.visible = false
