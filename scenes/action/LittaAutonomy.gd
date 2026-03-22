extends Node

## Drives Litta autonomously when degradation_level is high.
## Milestone 2 will flesh this out. For now it's a stub that parks until needed.
## This node should be a child of the Litta CharacterBody3D.

@export var litta: CharacterBody3D

func _ready() -> void:
	GameState.degradation_changed.connect(_on_degradation_changed)
	set_process(false)  # Inactive until degradation warrants it

func _on_degradation_changed(level: float) -> void:
	# Activate only at degradation stages that require autonomous behaviour.
	# Thresholds match DegradationSystem constants — read from there in Milestone 2.
	set_process(level >= 0.6)

func _process(_delta: float) -> void:
	# Placeholder: at high degradation, Litta stops and looks around.
	# Full implementation deferred to Milestone 2.
	pass
