extends Node3D

## Root controller for the action segment.
## Owns the reframe trigger and hooks up death/respawn flow.

const LITTA_SPAWN := Vector3(0, 0.5, 0)

@onready var litta: CharacterBody3D = $Litta
@onready var death_screen: CanvasLayer = $DeathScreen
@onready var reframe_label: Label = $HUD/ReframeLabel

# Reframe trigger: fires after the player has been in the scene long enough.
# Placeholder — will be tied to a story beat in a later pass.
@export var reframe_delay_seconds: float = 10.0
var _reframe_timer: float = 0.0

func _ready() -> void:
	GameState.active_scene = "ActionScene"
	death_screen.respawn_requested.connect(_respawn_litta)
	reframe_label.visible = false

func _process(delta: float) -> void:
	if not GameState.is_reframe_triggered:
		_reframe_timer += delta
		if _reframe_timer >= reframe_delay_seconds:
			_trigger_reframe()

func _trigger_reframe() -> void:
	GameState.is_reframe_triggered = true
	_show_reframe_text()

func _show_reframe_text() -> void:
	# Minimal text reframe — expand to full effect in later milestone.
	reframe_label.visible = true
	reframe_label.text = "You are Folgim.\nShe was never yours to be."
	var tween := create_tween()
	tween.tween_interval(4.0)
	tween.tween_callback(func(): reframe_label.visible = false)

func _respawn_litta() -> void:
	litta.global_position = LITTA_SPAWN
	litta.hp = litta.max_hp
	litta.is_dead = false
	litta.velocity = Vector3.ZERO
