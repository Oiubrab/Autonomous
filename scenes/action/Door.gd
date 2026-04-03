extends StaticBody3D

## Openable door. Slides the door panel up into the wall when opened.
## Player stands in the interaction zone and presses "interact" (E).

signal door_opened
signal door_closed

@export var open_duration: float = 0.8

@onready var panel: AnimatableBody3D = $DoorPanel
@onready var interact_area: Area3D = $InteractArea
@onready var prompt_label: Label3D = $PromptLabel

var _open: bool = false
var _busy: bool = false

func _ready() -> void:
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not prompt_label.visible or _busy:
		return
	if event.is_action_pressed("interact"):
		_toggle()

func _toggle() -> void:
	_busy = true
	prompt_label.visible = false
	var target_y := panel.position.y + (8.0 if not _open else -8.0)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "position:y", target_y, open_duration)
	await tween.finished
	_open = not _open
	_busy = false
	if _open:
		door_opened.emit()
	else:
		door_closed.emit()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		prompt_label.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		prompt_label.visible = false
