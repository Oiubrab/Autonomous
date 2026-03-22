extends CanvasLayer

## Dev-only debug overlay.
## Shows current degradation_level and lets you adjust it with a slider.
## Toggle with F1. Only compiled in debug builds (use OS.is_debug_build() guard).

@onready var panel: PanelContainer = $Panel
@onready var degradation_label: Label = $Panel/VBox/DegradationRow/Label
@onready var degradation_value: Label = $Panel/VBox/DegradationRow/Value
@onready var degradation_slider: HSlider = $Panel/VBox/DegradationSlider
@onready var stage_label: Label = $Panel/VBox/StageRow/Value
@onready var reframe_button: Button = $Panel/VBox/ReframeButton

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	layer = 100  # Always on top
	visible = false

	degradation_slider.min_value = 0.0
	degradation_slider.max_value = 1.0
	degradation_slider.step = 0.01
	degradation_slider.value = GameState.degradation_level

	degradation_slider.value_changed.connect(_on_slider_changed)
	reframe_button.pressed.connect(_on_reframe_pressed)
	GameState.degradation_changed.connect(_on_degradation_changed)
	_refresh_labels()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_pressed("ui_focus_next"):
		# F1 mapped to ui_focus_next by default — or toggle via F1 key directly
		pass
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		panel.visible = not panel.visible

func _on_slider_changed(value: float) -> void:
	GameState.degradation_level = value
	_refresh_labels()

func _on_degradation_changed(level: float) -> void:
	# Sync slider if something else changed degradation
	if abs(degradation_slider.value - level) > 0.005:
		degradation_slider.set_value_no_signal(level)
	_refresh_labels()

func _on_reframe_pressed() -> void:
	GameState.is_reframe_triggered = not GameState.is_reframe_triggered
	_refresh_labels()

func _refresh_labels() -> void:
	var level := GameState.degradation_level
	degradation_value.text = "%.2f" % level
	stage_label.text = DegradationSystem.get_stage(level)
	reframe_button.text = "Reframe: %s" % ("ON" if GameState.is_reframe_triggered else "OFF")
