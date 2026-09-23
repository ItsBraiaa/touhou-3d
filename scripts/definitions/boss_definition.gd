class_name BossDefinition
extends Resource
## Authored values for a Boss: its name, score, entry window and its two or three Phases
## (CONTEXT "Boss"). Read by [BossMachine].


## Fewest Phases a Boss has (the Tempest Sentinel).
const MIN_PHASES := 2
## Most Phases a Boss has (both Guardians).
const MAX_PHASES := 3

## Boss kind, the wave kind and the Director's key, for example `&"lantern_guardian"`.
@export var kind: StringName = &""
## Short Portuguese name for the boss panel, for example "Guardião das Lanternas".
@export var display_name: String = ""
## Score awarded by the owning Director on defeat (1,000 per final Boss, PLANEJAMENTO
## Section 4).
@export var score: int = 1000
## Seconds the Boss is visible before its first step's Anticipation begins: bosses also
## appear before shooting.
@export var entry_seconds: float = 1.0
## The Phases in order, [constant MIN_PHASES] to [constant MAX_PHASES].
@export var phases: Array[BossPhaseDefinition] = []


## Returns one message naming [member kind] for each invalid value, including every
## invalid Phase and its Attack.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if kind == &"":
		errors.append(_error("kind must not be empty"))
	if display_name.is_empty():
		errors.append(_error("display_name must not be empty"))
	if score < 0:
		errors.append(_error("score must not be negative"))
	if entry_seconds < 0.0:
		errors.append(_error("entry_seconds must not be negative"))
	if phases.size() < MIN_PHASES or phases.size() > MAX_PHASES:
		errors.append(_error("phases must have %d or %d Phases, got %d"
				% [MIN_PHASES, MAX_PHASES, phases.size()]))
	for phase_index: int in phases.size():
		var phase: BossPhaseDefinition = phases[phase_index]
		if phase == null:
			errors.append(_error("phase %d must not be null" % (phase_index + 1)))
			continue
		for phase_error: String in phase.validate():
			errors.append(_error("phase %d: %s" % [phase_index + 1, phase_error]))
	return errors


func _error(message: String) -> String:
	return "BossDefinition '%s': %s" % [kind, message]
