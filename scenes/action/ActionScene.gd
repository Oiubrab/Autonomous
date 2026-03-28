extends Node3D

## Root controller for the action segment.
## Owns the reframe trigger and hooks up death/respawn flow.

const LITTA_SPAWN := Vector3(0, 0.5, 0)

@onready var litta: CharacterBody3D = $Litta
@onready var death_screen: CanvasLayer = $DeathScreen
@onready var reframe_label: Label = $HUD/ReframeLabel

func _ready() -> void:
	GameState.active_scene = "ActionScene"
	death_screen.respawn_requested.connect(_respawn_litta)
	reframe_label.visible = false

func trigger_reframe() -> void:
	if GameState.is_reframe_triggered:
		return
	GameState.is_reframe_triggered = true
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
