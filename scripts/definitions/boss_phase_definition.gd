class_name BossPhaseDefinition
extends Resource
## Authored values for one Boss Phase: its health bar segment, its Attack, and the short
## readable transition that precedes the Attack.


## Longest transition allowed. The Boss takes no damage during it, so it is a fixed cue
## for readability, never a timer that lengthens the encounter (PLANEJAMENTO Section 4,
## ruling 1 of D-07 Part B).
const MAX_TRANSITION_SECONDS := 0.75

## Health of this Phase's segment. Excess damage never carries into the next Phase.
@export var health: int = 1000
## Attack played through this Phase.
@export var attack: AttackDefinition
## Seconds between this Phase starting (after the previous one is depleted) and its
## Attack's first Anticipation; 0 to [constant MAX_TRANSITION_SECONDS]. The first
## Phase's value is unused: the Boss's entry window comes first instead.
@export var transition_seconds: float = 0.75


## Returns one message for each invalid value, including the Attack's; the owning
## [BossDefinition] adds which Phase it is.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if health <= 0:
		errors.append("health must be above 0")
	if attack == null:
		errors.append("attack is required")
	else:
		errors.append_array(attack.validate())
	if transition_seconds < 0.0 or transition_seconds > MAX_TRANSITION_SECONDS:
		errors.append("transition_seconds must be in 0..%s" % MAX_TRANSITION_SECONDS)
	return errors
