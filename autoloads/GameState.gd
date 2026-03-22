extends Node

## Central source of truth for all persistent game state.
## All scenes read from and write to this singleton.

# --- Milestone 1 properties ---

## Folgim's grip on Litta. 0.0 = full control, 1.0 = full breakdown.
var degradation_level: float = 0.0 :
	set(value):
		degradation_level = clamp(value, 0.0, 1.0)
		degradation_changed.emit(degradation_level)

## Whether the reframe moment has been triggered in this session.
var is_reframe_triggered: bool = false :
	set(value):
		is_reframe_triggered = value
		if value:
			reframe_triggered.emit()

## Name of the currently active scene.
var active_scene: String = ""

# --- Signals ---
signal degradation_changed(new_level: float)
signal reframe_triggered()
signal litta_died()
signal game_over()

# --- Death handling ---

## Called when Litta's HP reaches zero.
## After the reframe: Litta dying continues the game (she is replaceable).
## Before the reframe: treat as a normal death for immersion.
func on_litta_death() -> void:
	litta_died.emit()
	# After the reframe is known to the player, Folgim endures.
	# The scene handles what to show; GameState just signals.

## Called if a Folgim-death condition is ever triggered.
## This is the real game-over — Folgim is the actual player entity.
func on_folgim_death() -> void:
	game_over.emit()
