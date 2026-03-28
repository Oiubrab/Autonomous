extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var hint_label: Label = $HintLabel

func _ready() -> void:
	panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_controls"):
		panel.visible = not panel.visible
		hint_label.visible = not panel.visible
		if panel.visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
