extends Node
class_name DegradationSystem

## Degradation threshold constants — define them once here.
## All systems that need to act on degradation ranges import these.

const STAGE_CLEAR_MAX     = 0.2   # 0.0–0.2: no effect
const STAGE_LAG_MAX       = 0.4   # 0.2–0.4: input lag
const STAGE_DRIFT_MAX     = 0.6   # 0.4–0.6: input drift
const STAGE_PAUSE_MAX     = 0.8   # 0.6–0.8: Litta stops and looks around
const STAGE_BREAKDOWN_MAX = 1.0   # 0.8–1.0: full autonomy, player ignored

const INPUT_LAG_MIN  = 0.2   # seconds of lag at stage start
const INPUT_LAG_MAX  = 0.5   # seconds of lag at stage end

## Returns the named stage for a given degradation level.
static func get_stage(level: float) -> String:
	if level < STAGE_CLEAR_MAX:
		return "clear"
	elif level < STAGE_LAG_MAX:
		return "lag"
	elif level < STAGE_DRIFT_MAX:
		return "drift"
	elif level < STAGE_PAUSE_MAX:
		return "pause"
	else:
		return "breakdown"
