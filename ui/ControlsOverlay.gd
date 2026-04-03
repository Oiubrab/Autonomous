extends CanvasLayer

const ACTIONS: Dictionary = {
	"Move Forward":  "move_forward",
	"Move Back":     "move_back",
	"Move Left":     "move_left",
	"Move Right":    "move_right",
	"Jump":          "jump",
	"Dodge":         "dodge",
	"Interact":      "interact",
	"Attack":        "attack",
}

const SAVE_PATH := "user://keybindings.cfg"

@onready var panel: PanelContainer        = $Panel
@onready var actions_vbox: VBoxContainer  = $Panel/VBox/ActionsVBox
@onready var capture_overlay: PanelContainer = $CaptureOverlay
@onready var hint_label: Label            = $HintLabel

var _capturing := false
var _capture_action := ""

func _ready() -> void:
	panel.visible = false
	capture_overlay.visible = false
	_load_keybindings()
	_build_rows()

func _build_rows() -> void:
	for child in actions_vbox.get_children():
		child.queue_free()

	for display_name: String in ACTIONS:
		var action: String = ACTIONS[display_name]
		if not InputMap.has_action(action):
			continue

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label := Label.new()
		name_label.text = display_name
		name_label.custom_minimum_size = Vector2(140, 0)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var key_label := Label.new()
		key_label.name = "KeyLabel"
		key_label.text = _key_text(action)
		key_label.custom_minimum_size = Vector2(110, 0)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.modulate = Color(0.5, 0.9, 1.0, 1)

		var btn := Button.new()
		btn.text = "Change"
		btn.custom_minimum_size = Vector2(72, 0)
		btn.pressed.connect(_on_change_pressed.bind(action))

		row.add_child(name_label)
		row.add_child(key_label)
		row.add_child(btn)
		actions_vbox.add_child(row)

func _key_text(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.get_physical_keycode_with_modifiers())
	return "(none)"

func _on_change_pressed(action: String) -> void:
	_capture_action = action
	_capturing = true
	capture_overlay.visible = true
	set_process_input(true)

# _input (not _unhandled_input) so we intercept before any action is fired.
func _input(event: InputEvent) -> void:
	if not _capturing:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	get_viewport().set_input_as_handled()

	if event.physical_keycode == KEY_ESCAPE:
		_end_capture()
		return

	# Remove this physical key from all rebindable actions to avoid conflicts.
	for a: String in ACTIONS.values():
		for e in InputMap.action_get_events(a):
			if e is InputEventKey and e.physical_keycode == event.physical_keycode:
				InputMap.action_erase_event(a, e)

	InputMap.action_erase_events(_capture_action)
	var new_event := InputEventKey.new()
	new_event.physical_keycode = event.physical_keycode
	InputMap.action_add_event(_capture_action, new_event)

	_save_keybindings()
	_end_capture()
	_build_rows()

func _end_capture() -> void:
	_capturing = false
	_capture_action = ""
	capture_overlay.visible = false
	set_process_input(false)

func _save_keybindings() -> void:
	var cfg := ConfigFile.new()
	for action: String in ACTIONS.values():
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				cfg.set_value("bindings", action, event.physical_keycode)
				break
	cfg.save(SAVE_PATH)

func _load_keybindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for action: String in ACTIONS.values():
		if not InputMap.has_action(action):
			continue
		if not cfg.has_section_key("bindings", action):
			continue
		var keycode: int = cfg.get_value("bindings", action)
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action, ev)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_controls"):
		panel.visible = not panel.visible
		hint_label.visible = not panel.visible
		if panel.visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().paused = true
		else:
			_end_capture()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_tree().paused = false
