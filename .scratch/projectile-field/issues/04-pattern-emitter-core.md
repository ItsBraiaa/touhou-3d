# F5-04 PatternDefinition and PatternEmitter core

Status: todo
Type: core
parallel-safe: yes
Depends on: F5-01
Lane: glm-a

## Goal

This ticket adds a typed `PatternDefinition` Resource and a Node-free `PatternEmitter` that turns it into timed hostile `ProjectileSpawn` requests. It covers the five shapes the design uses: ring, fan, spiral, burst, and aimed with a sampled position. Volleys, spacing, rotation and alternating heights come from data, and the only randomness is the injected RNG. One emitter class expresses every Enemy and Boss pattern in STAGE_DESIGN without duplicated lifecycle code (ENGINEERING_BRIEF Section 5, "Pattern data versus scripted behavior"). The Anticipation before firing and the choice of Attack are the caller's (F9-01, F12-01).

## Read first

- `docs/PLANEJAMENTO.md` Section 10 ("Patterns share configurable ring, fan, spiral, and burst emitters"; reuse and bounded counts) and Section 4 "Bosses and named attacks" (reachable gaps, attacks at different heights)
- `docs/STAGE_DESIGN.md` "Shared encounter rules" (Spirit aimed bursts, Sentry spaced fans, 1 s Anticipation, aimed attacks sample the position before firing), the three boss sequences and the miniboss
- `docs/ENGINEERING_BRIEF.md` Section 5 row "Pattern data versus scripted behavior" and Section 4.F
- `docs/adr/0003-typed-resources-for-authored-content.md`; `docs/engineering/CONVENTIONS.md` "Data and content", "Time and randomness" (one RNG per Attempt, no global `randf()`)
- `.scratch/projectile-field/spec.md` and `scripts/combat/projectile_spawn.gd` (F5-01)

## Files

- **Creates:** `scripts/definitions/pattern_definition.gd`, `scripts/combat/pattern_emitter.gd`, `tests/unit/definitions/test_pattern_definition.gd`, `tests/unit/combat/test_pattern_emitter.gd`.
- **Edits:** nothing else.
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F5-04 row), `docs/HANDOFF_LOG.md`, `docs/engineering/projectile-field.md` ("PatternDefinition" and "PatternEmitter" sections).
- **Must not touch:**
  - `scripts/combat/projectile_field.gd` and `tests/unit/combat/test_projectile_field.gd` (the F5-02/F5-03 lane).
  - Every other file in `scripts/definitions/`, and `tests/unit/definitions/test_content_validation.gd` (both F8-01's).
  - `content/` (F5 ships no `.tres`; dev patterns come with F9-02 and F12-03).
- **Conflicts with:** none. Its code files are disjoint from F5-02, F5-03 and F8-01, and its test files differ from F8-01's.

## Deliverables

### `PatternDefinition` (`scripts/definitions/pattern_definition.gd`)

`class_name PatternDefinition extends Resource` (ADR-0003). Every default is Claude's proposal; the values in real content are Astra's.

- `enum Shape { RING, FAN, SPIRAL, BURST, AIMED }`.
- `@export var id: StringName`.
- `@export var shape: Shape = Shape.RING`.
- `@export var projectiles_per_volley: int = 12`.
- `@export var volley_count: int = 1`.
- `@export var volley_interval: float = 0.2`, in seconds.
- `@export var speed: float = 8.0`, in units per second.
- `@export var lifetime: float = 6.0`.
- `@export var projectile_radius: float = 0.25`.
- `@export var damage: int = 10` (`CombatState.HIT_DAMAGE`).
- `@export var spread_degrees: float = 60.0`: the FAN and AIMED arc, and the full BURST cone.
- `@export var gap_degrees: float = 0.0`: the empty arc of a RING.
- `@export var rotation_step_degrees: float = 0.0`: added about world up at each volley. This gives a spiral, a rotating gap or a rotating fan.
- `@export var pitch_degrees: float = 0.0`: elevation of every direction.
- `@export var height_offsets: PackedFloat32Array = PackedFloat32Array()`: world-up origin offsets, cycled per volley, for alternating heights. Empty means 0.
- `@export var speed_variance: float = 0.0`: BURST only, a ± fraction.

`validate() -> PackedStringArray` returns one message per error, each naming `id`:

- `projectiles_per_volley` must be at least 1, and so must `volley_count`.
- `volley_interval` must be at least 0, and above 0 when `volley_count` is above 1.
- `speed`, `lifetime` and `projectile_radius` must be above 0, and `damage` at least 1.
- `spread_degrees` must be in 0..360 (and above 0 for BURST).
- `gap_degrees` must be in 0..360, and a RING's gap must leave at least one Projectile.
- `speed_variance` must be in 0..1.
- A SPIRAL with `rotation_step_degrees` 0 is reported (it is only a ring).

### `PatternEmitter` (`scripts/combat/pattern_emitter.gd`)

`class_name PatternEmitter extends RefCounted`, with no Node and no global random.

- `setup(definition: PatternDefinition, rng: RandomNumberGenerator)` asserts that both are non-null, and then `reset()`. It keeps the definition and reads it; it never edits it.
- `start()` begins a run, or restarts one: volley 0 is due at once. `reset()` goes back to before `start` and clears the rotation and the sampled aim.
- `tick(delta: float, origin: Vector3, forward: Vector3, aim_point: Vector3) -> Array[ProjectileSpawn]`:
  - The elapsed time advances by `delta`, then every volley `k` with `k × volley_interval <= elapsed` (tolerance 1e-6) that has not fired yet is emitted, in order. A long `delta` therefore emits every due volley and none is lost.
  - Before `start()` or after the last volley it returns an empty array.
  - Every spawn is `HOSTILE`, with the definition's speed, lifetime, radius and damage. Its origin is `origin + Vector3.UP × height_offsets[k % size]`.
- Directions per shape. The horizontal base is `forward` flattened on XZ, and `Vector3.FORWARD` when it is vertical. Volley `k` adds `k × rotation_step_degrees` about world up. `pitch_degrees` tilts every direction.
  - RING and SPIRAL: `projectiles_per_volley` directions evenly spaced around world up. RING skips those inside the `gap_degrees` arc centered on the rotated base; SPIRAL has no gap.
  - FAN: evenly spaced across `spread_degrees`, centered on `forward` (its pitch is kept), in the plane of `forward` and the horizontal right. One Projectile flies straight along `forward`.
  - BURST: random directions inside the `spread_degrees` cone around `forward`, with speed × (1 ± `speed_variance`), all drawn from `rng`. It is the only shape that consumes the RNG.
  - AIMED: like FAN, centered on `aim_point - origin` as **sampled at the run's first volley and held for the rest of the run**. It never tracks the player during the burst (STAGE_DESIGN "Aimed attacks sample the player's position before firing").
- `is_finished() -> bool`: true once the last volley has fired.

### How STAGE_DESIGN's patterns map (recorded in the module doc)

| Source | Expressed as |
| --- | --- |
| Spirit aimed bursts; Sentinela phase 1; Fios de Luz burst | AIMED, `volley_count` 3, short interval |
| Sentry spaced fans; Fios de Luz paired fans | FAN (a pair is two emitters or `height_offsets` ±h) |
| Ritual das Lanternas rings at alternating heights with a rotating gap | RING, `gap_degrees` > 0, `rotation_step_degrees`, `height_offsets` [low, high] |
| Sentinela phase 2 rotating fans; Espiral da Tempestade | FAN or SPIRAL with `rotation_step_degrees` (the height drift is the boss's movement, F12-01) |
| Círculos do Trovão high and low rings | RING with `height_offsets` (the ring cue is the caller's Anticipation) |

## Tests required

In `tests/unit/combat/test_pattern_emitter.gd`, with a fixed RNG seed:

- `test_ring_spaces_projectiles_evenly_around_the_up_axis`
- `test_ring_gap_leaves_no_projectile_inside_the_gap`
- `test_gap_rotates_between_volleys`
- `test_spiral_rotates_each_volley`
- `test_fan_spreads_across_its_arc_around_forward`
- `test_burst_is_deterministic_for_a_seed` (two emitters with the same seed give the same spawns)
- `test_only_burst_consumes_the_rng`
- `test_aimed_samples_the_aim_point_once_per_run` (a moved `aim_point` in later volleys is ignored until the next `start()`)
- `test_volleys_follow_the_interval`
- `test_large_delta_emits_every_due_volley`
- `test_height_offsets_cycle_per_volley`
- `test_nothing_is_emitted_before_start_or_after_the_last_volley`
- `test_reset_restarts_the_run_from_its_first_volley`
- `test_spawns_are_hostile_with_the_definition_values`
- `test_one_emitter_expresses_a_ring_an_aimed_burst_and_a_spiral` (ENGINEERING_BRIEF Section 5)

In `tests/unit/definitions/test_pattern_definition.gd`: `test_default_definition_is_valid`, and `test_validate_reports_each_invalid_field` (one case per rule above).

Grep the output for `SCRIPT ERROR`.

## Out of scope

- Anticipation timing and visuals (F9-01, F12-01).
- Attack sequencing, boss movement and height drift (F12-01).
- Authored pattern `.tres` files (F9-02 for Spirit and Sentry, F12-03 for the Lantern Guardian).
- The content-validation test over `content/`, which is F8-01's and picks up `PatternDefinition` automatically.
- Player shots (F6-03 `WeaponModel`).

## Definition of Done

- `tools/test.ps1` is green with no `SCRIPT ERROR`, every test above exists, and there are no Error-level warnings.
- `docs/engineering/projectile-field.md` gains the definition fields with their meaning, the emitter contract and the STAGE_DESIGN mapping table.
- A handoff log entry, ticket `Status: done` with an Outcome, and the roadmap row.
- One commit: `combat: add PatternDefinition and PatternEmitter`.

## Handoff notes for Astra

Patterns become `.tres` files under `content/patterns/` from F9-02 on, tuned in the Inspector with the fields above. Every default is Claude's proposal. Speeds, counts, gaps and intervals are yours to set against PLANEJAMENTO's "reachable gaps, readable speeds, and reaction time".

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/projectile-field/issues/04-pattern-emitter-core.md, then implement that ticket with /mattpocock-skills:tdd. Finish with its Definition of Done and commit.
```
