extends CanvasLayer

## Handles the death screen inversion — the core mechanical storytelling of Milestone 1.
##
## Litta dying:  "Litta has fallen — Folgim endures"  → fade out → respawn → continue
## Folgim dying: "You died"                            → game over, no continue

@onready var panel: ColorRect = $Panel
@onready var message_label: Label = $Panel/VBox/MessageLabel
@onready var sub_label: Label = $Panel/VBox/SubLabel
@onready var continue_label: Label = $Panel/VBox/ContinueLabel
@onready var anim: AnimationPlayer = $AnimationPlayer

signal respawn_requested()

func _ready() -> void:
	visible = false
	set_process_unhandled_input(false)
	GameState.litta_died.connect(_on_litta_died)
	GameState.game_over.connect(_on_game_over)

func _on_litta_died() -> void:
	visible = true
	if GameState.is_reframe_triggered:
		# Player knows they are Folgim — Litta is the expendable puppet.
		message_label.text = "Litta has fallen"
		sub_label.text = "Folgim endures."
		continue_label.text = "[ Press any key to continue ]"
		continue_label.visible = true
		_await_continue(false)
	else:
		# Pre-reframe: player believes they are Litta. Treat as normal death for now.
		message_label.text = "You died"
		sub_label.text = ""
		continue_label.text = "[ Press any key to continue ]"
		continue_label.visible = true
		_await_continue(false)

func _on_game_over() -> void:
	visible = true
	message_label.text = "You died"
	sub_label.text = ""
	continue_label.text = ""
	continue_label.visible = false
	# No continue — this is the real game over.

func _await_continue(is_game_over: bool) -> void:
	if is_game_over:
		return
	# Wait for any input, then signal the scene to respawn Litta.
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			set_process_unhandled_input(false)
			visible = false
			respawn_requested.emit()
