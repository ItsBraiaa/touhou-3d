# Bosses

Feature F12: Bosses and Stage 2. Started with ticket F12-01 on 2026-09-23. The boss Definitions, the `BossMachine` Rules Core (F12-01) and the `BossController` adapter with its dev boss (F12-02) are CODE_READY. The Lantern Guardian in S1-07 (F12-03) and the Stage 2 bosses (F12-05 to F12-07) are not integrated yet.

## Purpose

`BossMachine` runs one Boss's Phases and named Attacks (PLANEJAMENTO Section 4 "Bosses and named attacks"). Each Phase has its own health, and excess damage never skips a Phase. Depleting a Phase asks for a hostile clear, announces the next Attack's Portuguese name, and starts it after a short readable transition. An Attack is an ordered, cycling sequence of Pattern steps, each with its own Anticipation and a fire-time aim sample. Defeat happens exactly once. The Tempest Sentinel's two Phases and the Guardians' three use the same code.

It does not own any Node, boss movement (the controller hovers the boss), animation cues, the hit sphere, the HUD, or awarding the score (F12-02, F12-03). It emits no Projectile itself: `tick` returns `ProjectileSpawn` requests, and the controller spawns them.

## Files

- `scripts/definitions/boss_definition.gd`, `boss_phase_definition.gd`, `attack_definition.gd`, `attack_step_definition.gd` (authored Resources).
- `scripts/enemies/boss_machine.gd` (Rules Core, `class_name BossMachine extends RefCounted`).
- `scripts/enemies/boss_controller.gd` (Adapter, `class_name BossController extends Node3D`, F12-02), on the `Enemy` root of a boss prefab.
- `scenes/dev/dev_boss.tscn` and `scenes/dev/dev_boss_definition.tres` (the dev boss, `"Guardião (dev)"`, three Phases, its patterns inline; `metadata/dev = true`).
- No test files: the sprint's no-new-tests rule (2026-09-23) voids the tickets' test lists. F12-02's scripted runs are in [validation/bosses.md](../validation/bosses.md).

## Definitions

| Resource | Field | Type | Default | Meaning |
| --- | --- | --- | --- | --- |
| `BossDefinition` | `kind` | `StringName` | `&""` | Wave kind and the Director's key: `lantern_guardian`, `tempest_sentinel`, `storm_guardian`. |
| | `display_name` | `String` | `""` | Short Portuguese name for the boss panel. |
| | `score` | `int` | 1000 | Awarded by the Director on defeat (1,000 per final Boss; 500 for the Sentinel). |
| | `entry_seconds` | `float` | 1.0 | The Boss is visible, and takes damage, before its first step's Anticipation begins. |
| | `phases` | `Array[BossPhaseDefinition]` | `[]` | 2 or 3 (`MIN_PHASES`, `MAX_PHASES`). |
| `BossPhaseDefinition` | `health` | `int` | 1000 | This Phase's segment. |
| | `attack` | `AttackDefinition` | | Played through the Phase. |
| | `transition_seconds` | `float` | 0.75 | No damage and no fire between the previous Phase's depletion and this Attack's first Anticipation; 0 to `MAX_TRANSITION_SECONDS` (0.75, D-07 ruling 1). Unused on the first Phase, where the entry window comes first. |
| `AttackDefinition` | `display_name` | `String` | `""` | Portuguese Attack name, for example "Ritual das Lanternas". |
| | `steps` | `Array[AttackStepDefinition]` | `[]` | At least one, played in order and cycled. |
| | `reposition_seconds` | `float` | 1.0 | Quiet window after the last step, before step 0 again. |
| `AttackStepDefinition` | `pattern` | `PatternDefinition` | | Fired when the Anticipation ends. |
| | `anticipation_seconds` | `float` | 1.0 | The visible charge before this step fires. |
| | `height_offset` | `float` | 0.0 | Emission height relative to the Boss origin (ignored when following the player's height). |
| | `follow_player_height` | `bool` | false | Emit at the player's altitude sampled when the Anticipation ends. |
| | `pause_after` | `float` | 0.0 | Quiet after the Pattern finishes. |

Each has `validate() -> PackedStringArray`. `BossDefinition.validate()` reports its own fields and every Phase, Attack, step and Pattern error, prefixed with the Boss kind and the 1-based Phase and step. Besides the obvious rules (names not empty, health above 0, at least one step, no negative time, valid Patterns), an Attack's cycle (every step's Anticipation, volley span and pause, plus `reposition_seconds`) must take some time, or the machine would loop forever inside one tick.

## BossMachine contract

### Signals

| Signal | Payload | Emitted when |
| --- | --- | --- |
| `phase_changed` | `phase_index: int, attack_name: String` | Phase 0 on `start`; each later Phase when the previous one is depleted, before its transition. The HUD shows the name as the attack cue. |
| `phase_health_changed` | `phase_index: int, ratio: float` | Every accepted hit, with 0.0 for the one that depletes the Phase. |
| `step_started` | `step_index: int` | A step's Anticipation begins. F12-02 plays its step clip and threat warning. |
| `hostile_clear_requested` | | A Phase was depleted, before `phase_changed` or `defeated`. F12-02 calls `ProjectileSystem.clear_hostile_all()`. |
| `defeated` | `enemy_id: StringName, encounter_id: StringName` | The last Phase was depleted. Once. |

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `setup(definition: BossDefinition, enemy_id: StringName, encounter_id: StringName, rng: RandomNumberGenerator)` | F12-02 `spawn_setup` | Asserts a valid Definition and an RNG. Every Phase full; nothing runs until `start`. |
| `start()` | F12-02, right after `boss_started` | Phase 0 full, `phase_changed(0, name)`, then the entry window. Calling it again restarts the fight. |
| `tick(delta: float, origin: Vector3, player_position: Vector3) -> Array[ProjectileSpawn]` | F12-02 `_physics_process` | Advances the timeline; returns the hostile requests in firing order. Empty before `start`, during a transition, once defeated. |
| `take_damage(amount: int) -> int` | F12-02, from its registered hit sphere | Returns the damage applied, capped at the current Phase's remaining health. 0 before `start`, during a transition, once defeated. |
| `get_phase_index()`, `get_phase_count()`, `get_phase_ratio(index)` | F12-02, HUD wiring | Ratio 0.0 for depleted Phases, 1.0 for Phases not reached. |
| `is_in_transition()`, `is_defeated()`, `get_score()` | F12-02, Director | |

### Timeline

1. `start` opens the entry window (`entry_seconds`).
2. Each step: `step_started`, then its Anticipation; when it ends, the player's position is sampled once, as the aim point and as the emission altitude for `follow_player_height`; then the Pattern runs to the end; then `pause_after`.
3. After the last step: `reposition_seconds`, then step 0.
4. The emission origin is `origin + (0, height_offset, 0)`, or `(origin.x, sampled player y, origin.z)` when following the player's height. The Pattern's own `height_offsets` add on top, per volley. The forward direction is from the emission origin to the sampled aim point. Every step reuses one `PatternEmitter`, set up with the injected RNG when the step fires.
5. Large deltas are consumed across states within one `tick`, like `EnemyModel`.

### Phases and damage

- A hit is capped at the current Phase's remaining health; the excess is discarded. A second hit in the same tick lands in the transition and is refused, so no Phase can be skipped (ENGINEERING_BRIEF 4.F and 8).
- Depleting a non-final Phase: the Attack stops, the next Phase becomes current and full, the transition starts, then `phase_health_changed(i, 0.0)`, `hostile_clear_requested`, `phase_changed(i + 1, name)` in that order. After the transition, the new Attack starts at step 0 with its Anticipation.
- Depleting the final Phase: `phase_health_changed(last, 0.0)`, `hostile_clear_requested`, `defeated(enemy_id, encounter_id)`, once.
- The state has moved on before the signals fire, so a listener that calls `take_damage` again gets 0.
- Damage is accepted during the entry window and every step state. It is refused only during the transition, which is capped at 0.75 s by `BossPhaseDefinition.validate()` (PLANEJAMENTO Section 4, D-07 ruling 1: a fixed readability cue, never a timer that pads the encounter).

## BossController contract (F12-02)

`scripts/enemies/boss_controller.gd` (Adapter, `class_name BossController extends Node3D`), on the `Enemy` root of `scenes/dev/dev_boss.tscn` now, and of `scenes/enemies/lantern_guardian.tscn` (F12-03), `tempest_sentinel.tscn` (F12-06) and `storm_guardian.tscn` (F12-07) once attached.

### Exports

| Export | Type | Required | Meaning |
| --- | --- | --- | --- |
| `visual_root` | `Node3D` | yes | `VisualRoot`, the boss visual. |
| `hit_volume` | `Area3D` | yes | `HitVolume`: layer 5 (bit 16), mask 0, monitoring and monitorable off. Its **node position is the hit center** (Target Lock, the HUD marker, Aim Assist, the registered sphere and the off-screen test all use it), and the `SphereShape3D` in its first `CollisionShape3D` child gives the radius. Astra's boss scenes already place the `HitVolume` node itself at the center. |
| `emitter` | `Marker3D` | yes | `Emitters/Main`, the emission origin handed to `BossMachine.tick` (a step's `height_offset` or `follow_player_height` then applies). |
| `animation_player` | `AnimationPlayer` | no | Usually `VisualRoot/Model/AnimationPlayer`. Without it no clip plays. |
| `idle_clip` | `StringName` | no | Played at spawn and queued after every other cue. |
| `step_clip` | `StringName` | no | Played when each step's Anticipation begins. |
| `phase_clip` | `StringName` | no | Played when a Phase after the first begins (the D-03 and D-04 sprint note). |
| `defeat_clip` | `StringName` | no | Played on defeat; the boss is freed when its length has elapsed. |

An empty clip means no cue. At `spawn_setup` each configured clip is checked with `animation_player.has_animation()`: one missing (or set without a player) is reported once with `push_warning` naming the field and skipped. `_ready` reports a missing reference or a first `CollisionShape3D` without a positive-radius sphere with `push_error` and disables the node; physics stays off until `spawn_setup`.

### Signals

Shaped for the HUD boss panel (F4-03); the owner connects them (F12-03, the harness):

| Signal | Payload | Emitted when | HUD call |
| --- | --- | --- | --- |
| `boss_started` | `display_name: String, phase_count: int` | In `spawn_setup`, before Phase 0 | `show_boss(display_name, phase_count)` |
| `phase_changed` | `phase_index: int, attack_name: String` | Phase 0 right after `boss_started`; each later Phase on depletion, after the hostile clear | `show_attack_cue(attack_name, seconds)` |
| `phase_health_changed` | `phase_index: int, ratio: float` | Every accepted hit (0.0 for the depleting one) | `set_phase_health(phase_index, ratio)` |
| `threat_reported` | `side: int` | A step's Anticipation begins while the `HitVolume` center is outside the camera frustum: `EnemyActor.threat_side()`, -1 left, +1 otherwise | `show_threat(side, seconds)` |
| `defeated` | `enemy_id: StringName, encounter_id: StringName` | Once, after the final clear, the boss out of `targetable` and physics off | `hide_boss()`; the Director awards `get_score()` |

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `spawn_setup(definition: BossDefinition, enemy_id: StringName, encounter_id: StringName, rng: RandomNumberGenerator, projectile_system: ProjectileSystem, player: Node3D, bounds: AABB) -> bool` | The Director (F12-03), the harness | `EnemyActor.spawn_setup`'s order and meaning: once, after `add_child` under `RuntimeActors`, at the spawn marker, which becomes the hover anchor (clamped into `bounds`). Refusals as for `EnemyActor` (one `push_error` each, inert, returns false; the caller frees it); `definition.validate()` messages included. Otherwise checks the clips, builds the `BossMachine`, connects its five signals once, joins `targetable`, starts physics, plays `idle_clip`, emits `boss_started`, then calls `machine.start()` (which emits `phase_changed(0, …)`), and returns true. |
| `take_damage(damage: int)` | The `ProjectileSystem` (`on_damage`: shots and the Bomb) | Forwards to `BossMachine.take_damage` (capped per Phase, refused during a transition). Ignored before `spawn_setup`, after defeat, outside the tree, while paused, and for `damage <= 0`. |
| `get_score() -> int` | The Director (F12-03) | The Definition's score; 0 before `spawn_setup`. |

### Each physics tick (after `spawn_setup`)

Priority 0, before `PlayerWeapon` (50) and the `ProjectileSystem` (100): read the player's position while it is valid and in the tree (the last one otherwise); hover (`anchor + (0, HOVER_AMPLITUDE × sin(2π t / HOVER_PERIOD), 0)`, 0.6 units over 4 s, clamped into `bounds`; Claude's placeholder); `machine.tick(delta, emitter.global_position, player_position)`; spawn every request; `register_target(get_instance_id(), hit_volume.global_position, radius, take_damage)`.

### Machine wiring

- `hostile_clear_requested` → `projectile_system.clear_hostile_all()` (safe inside the field's event dispatch: it only removes Projectiles).
- `step_started` → `step_clip`, then the off-screen check.
- `phase_changed` → `phase_clip` for an index above 0, then re-emitted; `phase_health_changed` re-emitted unchanged.
- `defeated` → leave `targetable`, stop physics (no more registration), emit `defeated` once, then `queue_free()` at once, or after `defeat_clip` through a Tween of the boss (so the wait stands still while the tree is paused).

## Dependencies

`PatternDefinition` and `PatternEmitter` (F5-04); `ProjectileSpawn` (F5-01). The Attempt's `RandomNumberGenerator` comes from the Director through `BossController.spawn_setup`. The controller needs the `ProjectileSystem` (F6-02), `EnemyActor.threat_side` (F9-02), and is found by `Targeting` (F1-04) through `targetable` and its `HitVolume`.

## Invariants and tests

| Invariant | Test |
| --- | --- |
| Excess damage cannot skip boss Phases (ENGINEERING_BRIEF 4.F, 8) | None: the sprint's no-new-tests rule. `take_damage` caps each hit at the Phase's remaining health and refuses damage during the transition. |
| Phase transitions clear previous threats (ENGINEERING_BRIEF 4.F) | None (same rule). `hostile_clear_requested` on every depletion, before the next Phase is announced. |
| Exactly-once defeat (ENGINEERING_BRIEF 8) | None (same rule). The DEFEATED state refuses damage, so `defeated` cannot fire twice. |
| Transition damage refusal is bounded (D-07 ruling 1) | None (same rule). `BossPhaseDefinition.validate()` rejects `transition_seconds` above 0.75. |

## Setup for Astra

- **Definitions.** The Lantern Guardian's `.tres` (F12-03 part 1) and the Stage 2 bosses' (F12-06, F12-07) fill these Definitions; Attack names are Portuguese literals there. Keep `transition_seconds` at or below 0.75, and keep every Attack's cycle above zero seconds. In a hand-written `.tres`, declare every `[sub_resource]` before the first one that references it: Godot's parser refuses a forward `SubResource(...)` and the whole file fails to load.
- **Boss scenes.** Your three boss prefabs already have the tree `BossController` needs: an `Enemy` root, `VisualRoot`, `HitVolume` (node at the hit center) and `Emitters/Main` outside the scaled model. The attaching ticket (F12-03, F12-06, F12-07) sets `visual_root`, `hit_volume`, `emitter`, `animation_player` → `VisualRoot/Model/AnimationPlayer`, and the clips you chose: `idle_clip` `Flying_Idle`, `step_clip` `Punch`, `phase_clip` `Yes`, `defeat_clip` `Death`. All four exist in the Lantern Guardian's player (checked at runtime); a name the player lacks is reported, never silently ignored.
- **Hover.** A 0.6-unit, 4-second bob around the spawn marker is Claude's placeholder; retreat containment is out of scope.

## Open issues

- **First run: F12-02's harness.** The dev boss ran its three Phases there (see [validation/bosses.md](../validation/bosses.md)); F12-03's S1-07 is the first real fight.
- **`content/bosses/lantern_guardian.tres` does not load** (F12-03 part 1): a forward `SubResource("Attack_Ritual")` at line 14. Reported for trunk's F12-03 part 2; not fixed here (`content/` is outside F12-02).
- **Locked shots and the lock framing.** From about 45 units the dev boss took most locked shots; closer targets are F6-04's.
- **Entry reading.** `entry_seconds` is a window before step 0's own Anticipation, so the first shot comes at `entry_seconds + anticipation_seconds`. If D-06 or D-07 Part C wants the entry to be the first Anticipation instead, `start` begins step 0 directly.
- **`follow_player_height` ignores `height_offset`.** The ticket says "or the player's sampled Y"; an offset relative to the player can be added if D-07 Part C asks for it.
