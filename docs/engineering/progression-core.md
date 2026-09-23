# Progression Definitions

## Purpose

The progression Definitions describe the authored Stage route as typed Resources. They validate encounter, wave, reward and checkpoint data without owning progression logic; the Stage Director remains responsible for runtime lifecycle, rewards, gates and checkpoint activation.

## Files

- `scripts/definitions/encounter_definition.gd` (`EncounterDefinition` Resource)
- `scripts/definitions/wave_definition.gd` (`WaveDefinition` Resource)
- `scripts/definitions/reward_definition.gd` (`RewardDefinition` Resource)
- `scripts/definitions/checkpoint_definition.gd` (`CheckpointDefinition` Resource)
- `scripts/definitions/stage_definition.gd` (`StageDefinition` Resource)

## Public contract

### Exports

| Resource | Exported data |
| --- | --- |
| `WaveDefinition` | Relative `spawn_markers`, matching `enemy_kinds`, `activation`, and non-negative `delay`. |
| `RewardDefinition` | `kind` (`POWER` or `SHIELD`), positive `count`, and relative `origin_marker`. |
| `EncounterDefinition` | Stable `id` and `next_id`, `completion`, `requires_exit`, `waves`, `rewards`, `gate_id`, `checkpoint_id`, and `required_objective_ids`. |
| `CheckpointDefinition` | Stable `id`, `after_encounter_id`, `resume_encounter_id`, relative `node_path`, and Portuguese `display_name`. |
| `StageDefinition` | Stable `id`, ordered `encounters`, and `checkpoints`. |

### Methods

| Method | Effect |
| --- | --- |
| `validate() -> PackedStringArray` | Returns an empty array for valid data; otherwise returns messages prefixed by the relevant Definition ID. `StageDefinition` validates child Definitions and cross-references. |
| `WaveDefinition.enemy_kind_at(index)` | Returns the mapped kind, or an empty `StringName` for an out-of-range index. |
| `StageDefinition.find_encounter(id)` | Returns the matching Encounter or `null`. |
| `StageDefinition.encounter_index(id)` | Returns the matching route index or `-1`. |
| `StageDefinition.find_checkpoint(id)` | Returns the matching Checkpoint or `null`. |

## Dependencies

Each Definition is plain Resource data. Spawn and checkpoint locations are relative `NodePath`s; these schemas do not hold Nodes, resolve scene paths, load content, or implement Director behavior. `StageDefinition` owns route-level consistency checks over its child Definitions.

## Invariants and validation

| Invariant | Validation |
| --- | --- |
| A Wave has markers, one non-empty enemy kind per marker, unique non-empty marker paths, and a non-negative delay. | `WaveDefinition.validate()`; errors are contextualized by the owning Encounter. |
| A Reward has a positive count and non-empty origin marker. | `RewardDefinition.validate()`; errors are contextualized by the owning Encounter. |
| Completion modes have compatible Waves and objectives; the first Wave starts on entry; marker paths are unique across an Encounter; all child data is valid. | `EncounterDefinition.validate()`. |
| Every Checkpoint has an ID, route references, scene-relative marker path, and display name. | `CheckpointDefinition.validate()`. |
| Stage route IDs and gate/checkpoint IDs are unique; next IDs follow route order; checkpoint references exist and resume after activation. | `StageDefinition.validate()`. |

## Setup for Astra

Create `.tres` Resources of the appropriate Definition class. Use spawn-marker `NodePath`s relative to `Encounters/<ID>` and checkpoint paths relative to the Stage root. Set `next_id` to the following route entry (empty on the final Encounter); set a resume Encounter's `checkpoint_id` to the Checkpoint ID. Encounter completion and one-time reward behavior remain runtime responsibilities of the Director.

## Open issues

Stage-entry resources intentionally remain outside `StageDefinition`; `RunState.ENTRY_POWER_LEVEL` and `CombatState.start()` remain their single source. Stage-specific content is authored by the content tickets.
