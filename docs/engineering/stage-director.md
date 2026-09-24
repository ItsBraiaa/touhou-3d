# Stage Director

Feature F10: the Adapter that plays a stage's authored route. Started with ticket F10-01 on 2026-09-23 (CODE_READY); Gates, Checkpoints and PortalLinks are CODE_READY since F10-02 (sections "Gate", "Checkpoint" and "Progress application"). Retry follows in F10-03, the boss branch in F12-03 and Stage 2 in F12-05; each appends its own section.

## Purpose

`StageDirector` sits on a stage's `Stage` root and plays its `StageDefinition` through an `EncounterMachine` (F8-02). It arms each Encounter's EntryVolume and ExitVolume and reports the ship's traversal, spawns every requested Wave and every reward Pickup under `RuntimeActors`, scores each enemy defeat once and reports it to the machine, relays off-screen threats to the HUD and stage clear to the Session, and exposes the active Encounter's bounds. Enemies report outcomes; the machine decides progression (ENGINEERING_BRIEF 4.G).

It does not own any progression rule (the machine's), enemy behavior (F9's `EnemyActor`), Pickup acceptance (F7-03's `Pickup`), the score or the Run (`RunState`), the refill, commit and Snapshot (`CheckpointStore`, F8-03), Retry (F10-03), the boss (F12-03), or any authored node: it adds only to `RuntimeActors`, and changes only the volumes' and Checkpoints' `monitoring`, the Gates' barrier collision and `ClosedVisual`, and the PortalLinks' visibility.

## Files

- `scripts/progression/stage_director.gd` (`StageDirector`, Adapter on `Stage` in `scenes/stages/stage_01.tscn`).
- `scripts/session/game_session.gd`: `_director`, the pre-check, `setup`, `start_attempt`, `_attempt_seed`, `_on_stage_cleared`, `_on_threat_reported`, `THREAT_CUE_SECONDS`.
- `scripts/progression/gate.gd` (`Gate`, on `Gates/Gate_S1_02..05`) and `scripts/progression/checkpoint.gd` (`Checkpoint`, on `Checkpoints/CP1-A` and `CP1-B`), since F10-02.
- `scenes/stages/stage_01.tscn` [shared]: the scripts on `Stage`, the four Gates and the two Checkpoints, and their exports, nothing else.
- No test file: the sprint's no-new-tests rule (2026-09-23). Verification is in [validation/stage-director.md](../validation/stage-director.md).

## Public contract

### Exports

| Export | Type | Stage 1 value | Meaning |
| --- | --- | --- | --- |
| `stage_definition` | `StageDefinition` | `content/stages/stage_01/stage_01.tres` | The route. Required; it must validate. |
| `actor_scenes` | `Dictionary[StringName, PackedScene]` | `spirit` → `scenes/dev/spirit.tscn`; `sentry` and `lantern_guardian` → `scenes/dev/sentry.tscn` | The actor of every Wave kind; each root an `EnemyActor`. `lantern_guardian` is the dev Sentry until F12-03. |
| `enemy_definitions` | `Dictionary[StringName, EnemyDefinition]` | `spirit` → `content/enemies/spirit.tres`; `sentry` and `lantern_guardian` → `content/enemies/sentry.tres` | The definition of every Wave kind. |
| `power_pickup_scene` | `PackedScene` | `scenes/dev/power_pickup.tscn` | A `Pickup` of kind POWER. Required. |
| `shield_pickup_scene` | `PackedScene` | `scenes/dev/shield_pickup.tscn` | A `Pickup` of kind SHIELD. Required. |
| `reward_spread` | `float` | 1.5 | Radius of the horizontal circle a reward of more than one Pickup is laid out on. Claude's proposal. |
| `guard_links` | `Dictionary[StringName, NodePath]` | `S1-04/Wave1_Sentry1..3` → `Environment/PortalLinks/GuardLink1..3` | The PortalLink each portal guard feeds, relative to the stage root (F10-02). |

### Signals

| Signal | Payload | Emitted when |
| --- | --- | --- |
| `stage_cleared` | — | The machine's `stage_cleared`: the last Encounter completed. The Session connects it `CONNECT_DEFERRED`. |
| `threat_reported` | `side: int` (-1 left, +1 right) | A live enemy re-emitted its `EnemyActor.threat_reported`. |
| `pickup_accepted` | `pickup_id: StringName, kind: Pickup.Kind, score_awarded: int` | A reward Pickup re-emitted its `accepted`. For audio (F13-03); `score_awarded` already reached the Run. |
| `checkpoint_activated` | `checkpoint_id: StringName` | A Checkpoint's first activation succeeded: refilled, committed, recorded (F10-02). For presentation, such as an arch glow. |

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `check_setup() -> PackedStringArray` | Session `_load_stage`, before the stage enters the tree | Every problem, each naming the stage id and the path: an unset required export, `stage_definition.validate()`, a missing `Encounters/<id>` or its `EntryVolume`/`ExitVolume` `Area3D`, a volume with no `CollisionShape3D` child holding a `BoxShape3D` (the Encounter bounds come from them), a Wave marker that is not a `Node3D` under its Encounter, a Wave kind with no `actor_scenes` or `enemy_definitions` entry, an `enemy_definitions` entry whose `validate()` fails, a reward `origin_marker` that is not a `Node3D`, and a missing `RuntimeActors`. Relative paths only. Empty when the stage can play. An enemy refuses an invalid definition, and a Wave that never spawns never completes, so bad content refuses the stage instead of freezing it (reviewer finding). |
| `setup(run_state, combat_state, projectile_system, player)` | Session, once, after the ship and its bindings | Creates the machine, `setup(stage_definition)`, connects `wave_requested`, `rewards_requested`, `encounter_completed` and `stage_cleared` once; sets `monitoring = true` on every EntryVolume and ExitVolume and connects `body_entered` with `CONNECT_DEFERRED`, bound to the Encounter id. Since F10-02 it also connects `gate_opened`, creates the Director's `CheckpointStore`, arms every Checkpoint and connects its `entered` deferred, and ends with `_apply_progress()`. A second call is reported and changes nothing. |
| `start_attempt(attempt_seed: int)` | Session, after every `begin_attempt()` | A new `RandomNumberGenerator` seeded with `attempt_seed`, injected into every enemy of the Attempt; then `notify_entered(first Encounter)`, because `PlayerStart` (Z 20) already lies inside S1-01's EntryVolume. |
| `get_active_encounter_bounds() -> AABB` | Enemies at spawn; F12 boss containment | The world-space merge of the active Encounter's EntryVolume and ExitVolume boxes: X -45..45, Y 0..75 and the Encounter's Z range on Stage 1. `AABB()` when none is active. |
| `get_machine() -> EncounterMachine` | Dev tools and later tickets | The progression core; null before `setup`. |

## Behaviour

- **Volumes.** An EntryVolume reports `notify_entered(id)` and an ExitVolume `notify_exited(id)`, only for `is_instance_valid(body) and body == player`. The machine refuses anything out of order, so flying over a trigger does nothing, and re-entering a completed Encounter spawns nothing. The connections are deferred because entry spawns `Area3D` actors and Pickups, which must not happen inside the physics flush that reports the body.
- **Overlapping volumes.** S1-01's ExitVolume (Z -59..-55) and S1-02's EntryVolume (Z -62..-58) overlap, and a volume the ship is already inside reports no new `body_entered`. So after every `encounter_completed` the Director checks, deferred, whether the ship already overlaps the next Encounter's EntryVolume, and if so reports it.
- **Waves.** For each marker i of the requested Wave: `kind := wave.enemy_kind_at(i)`, `id := EncounterMachine.enemy_id(encounter_id, marker)`; the kind's actor is instanced under `RuntimeActors` at the marker's global transform, then `spawn_setup(enemy_definitions[kind], id, encounter_id, rng, projectile_system, player, get_active_encounter_bounds())`; its `defeated` goes to the Director and its `threat_reported` is re-emitted. A scene whose root is not an `EnemyActor` is reported and skipped.
- **Defeats.** The first `defeated(enemy_id, encounter_id)` of a spawned enemy adds its definition's `score` (100 for the dev Spirit and Sentry, PLANEJAMENTO Section 4) to `RunState` and reports `notify_enemy_defeated`. A repeat scores nothing. The actor frees itself.
- **Rewards.** On `rewards_requested(id)`, each `RewardDefinition` spawns `count` Pickups at its `origin_marker` under `RuntimeActors`, on a horizontal circle of `reward_spread` when `count` is more than 1 (a single one sits on the marker). Ids are `&"<encounter_id>/power_<n>"` and `&"<encounter_id>/shield_<n>"`, n from 1 per kind. Each gets `setup(id, combat_state, player)` and its `accepted` re-emits as `pickup_accepted`. S1-02 and S1-05 drop five Power Pickups at `RewardOrigin`, S1-03 one Shield Pickup at `ShieldPickup`, on completion.
- **Ticking.** `_physics_process` calls `machine.tick(delta)`. The Director is under `WorldRoot` (PAUSABLE), so it stops while paused.
- **Gates and Checkpoints** are F10-02's; see the next three sections.

## Gate

`Gate` (`scripts/progression/gate.gd`, `class_name Gate extends Node3D`) sits on each `Gates/<gate_id>` root. `_ready` resolves `BarrierBody/Collision` (`CollisionShape3D`) and `ClosedVisual` and reports a missing one. `set_open(open)` returns when the Gate is already in that state; otherwise it calls `set_deferred(&"disabled", open)` on the barrier collision, which is safe from any callback and takes effect by the next physics step, and sets `ClosedVisual.visible = not open`. `Arch` stays scenery. `is_open()`. Gates start closed, as authored: the barrier is layer 1 across the route cross-section, so a closed Gate stops the ship at every height and stops Projectiles through the field's layer-1 obstacle ray.

On the machine's `gate_opened(gate_id)`, the Director calls `projectile_system.clear_hostile_all()` first, awarding nothing, then `set_open(true)` (STAGE_DESIGN "Shared encounter rules"). It can arrive inside the field's event emission (a player shot's kill), inside `PlayerWeapon`'s physics step (a Bomb kill) or from a deferred ExitVolume. The field drops a cleared Projectile's pending Graze, and the collision change is deferred, so all three are safe.

## Checkpoint

`Checkpoint` (`scripts/progression/checkpoint.gd`, `class_name Checkpoint extends Area3D`) sits on each `Checkpoints/<id>` root, with `checkpoint_id` (`&"CP1-A"`, `&"CP1-B"`) equal to its `CheckpointDefinition.id`. It emits `entered(checkpoint_id)` from its own `body_entered`, for a `PlayerController` body only. `set_armed(armed)` sets `monitoring` deferred. `get_respawn_transform()` is `Respawn`'s global transform (F10-03 uses it). `_ready` reports a missing id or `Respawn`. It holds no rule.

`setup` creates `_checkpoint_store := CheckpointStore.new()`, one per Director: a stage load and a Restart build a new Director, so a new store starts at Stage Entry. For each `CheckpointDefinition` it resolves the `Checkpoint` at `node_path`, arms it, and connects `entered` with `CONNECT_DEFERRED`, since activation refills, clears and may spawn Waves. On `entered(id)`:

1. It acts only if `machine.is_completed(after_encounter_id)` and the Checkpoint is not yet activated. Otherwise it returns: an early entry or a revisit neither clears nor refills (STAGE_DESIGN "Entering a checkpoint twice cannot repeatedly refill resources").
2. `projectile_system.clear_hostile_all()`: the clear comes before the activation.
3. `CheckpointStore.activate(id, combat_state, run_state, machine)`: refill (Health 100, the Shield, 2 Bombs), commit the Attempt, record the Snapshot; it refuses while combat is paused or defeated. On success, `checkpoint_activated(id)` is emitted, and if the ship already overlaps the resume Encounter's EntryVolume, that Encounter begins at once: the machine refused its entry while the Checkpoint was inactive.

So a Checkpoint arms the next combat Encounter: flying past CP1-A's arch outside its volume arms nothing, and coming back through it arms S1-05. The latest Checkpoint is `_checkpoint_store.latest_checkpoint_id()`; the Director keeps no copy of it.

## Progress application

`_apply_progress()` sets every Gate and PortalLink from the machine's state. It runs at the end of `setup`, and F10-03 calls it after a restore.

- Every Gate named by a definition gets `set_open(gate_id in machine.get_open_gate_ids())`, so a Gate the failed Attempt opened closes again. It is idempotent.
- Every `guard_links` entry is shown unless the Encounter in its enemy id (`S1-04` in `S1-04/Wave1_Sentry1`) is complete.

A guard's first defeat report also hides its link at once (`_hide_guard_link`).

`check_setup()` also requires, since F10-02: a `Gate` with both children for every non-empty `gate_id`, a `Checkpoint` whose `checkpoint_id` equals the definition's and which has a `Respawn` for every `CheckpointDefinition.node_path`, and, for every `guard_links` entry, a key that is one of the route's Wave enemy ids and a path that resolves to a `Node3D` (reviewer finding: a mistyped key would leave its link lit).

## Session wiring

- `_load_stage`: when the stage root is a `StageDirector`, `check_setup()`'s messages join the existing pre-check (after the `PlayerStart`, Flight Volume and ship checks), so a bad stage is refused before anything is unloaded and the menu stays. After the ship's HUD, field and weapon bindings: `setup(_run_state, _combat_state, projectile_system, _player)`, `stage_cleared` → `_on_stage_cleared` (`CONNECT_DEFERRED`), `threat_reported` → `_on_threat_reported`. Every load builds a new Director, so a Restart cannot double a connection.
- `_start_run` and `_restart_stage`: after `begin_attempt()`, `_director.start_attempt(_attempt_seed(attempt_index))`.
- `_attempt_seed(i)` is `hash("<stage id>#<i>")`: deterministic, no global random state (CONVENTIONS "Time and randomness").
- `_on_stage_cleared()` → `_run_state.complete_stage()`, which returns to the menu until F11-01 shows Results.
- `_on_threat_reported(side)` → `Hud.show_threat(side, THREAT_CUE_SECONDS)`, 1.0 s (Claude's proposal).
- `_unload_stage()` sets `_director = null`.
- A stage whose root is not a `StageDirector` (Stage 2 until F12-05) loads and flies as a static stage.

## Dependencies

- `EncounterMachine`, `StageDefinition` and the Definitions (F8-01, F8-02); Stage 1 content (F8-04).
- `EnemyActor` and the dev prefabs and definitions (F9-02).
- `Pickup` and its dev prefabs (F7-03).
- `RunState.add_score`, `complete_stage` (F2-03); `CombatState` (F4-01); `ProjectileSystem` (F6-02); `Hud.show_threat` (F4-03).

## Invariants and tests

The sprint's no-new-tests rule (2026-09-23) replaced the ticket's fifteen scene tests with a driven run of the real main scene; results in [validation/stage-director.md](../validation/stage-director.md).

| Invariant (ENGINEERING_BRIEF 4.G and Section 8, STAGE_DESIGN, the ticket) | Evidence |
| --- | --- |
| Duplicate death callbacks score and count once | validation check 5 |
| Returning through triggers spawns and rewards nothing (re-entry) | check 7 |
| Flying over a trigger out of order cannot start a later Encounter (trigger side of "flying over a locked gate cannot skip the required encounter") | check 6 |
| Waves spawn at their markers, in order, the second after the first is defeated | checks 2, 3 |
| Rewards drop once, at their marker, with the exact count | checks 4, 8 |
| Invalid setup or content refuses the stage before anything unloads | check 10, and the reviewer's invalid-definition probe |
| Stage clear completes the stage, deferred | check 11 |
| Restart builds a new Director with no doubled connections | check 14 |
| A stage without a Director still flies | check 13 |
| A closed Gate blocks the ship at every height and stops Projectiles (F10-02; "flying over or under a locked gate cannot skip") | [validation/stage-01-progression.md](../validation/stage-01-progression.md) checks 4, 5 |
| A Gate opens once, after hostile fire is cleared with no Graze, in any kill order and for a Bomb kill of the last guards | progression checks 3, 7, 8 |
| A Checkpoint activates only after its preceding Encounter, once: a revisit neither refills nor clears ("checkpoint twice cannot refill") | progression checks 9, 10, 11 |
| A Checkpoint arms the next combat Encounter | progression check 12 |
| Stage 1 progresses through all seven segments with the dev enemies | progression checks 13 and the windowed `/run` |

## Setup for Astra

- `stage_director.gd` is on Stage 1's `Stage` with the exports above; nothing else in `stage_01.tscn` changed, and `monitoring` stays false in the file.
- Keep the Encounter, Wave marker, `EntryVolume`, `ExitVolume`, `RewardOrigin`, `ShieldPickup` and `RuntimeActors` names: they are load-bearing. `check_setup()` names any that go missing, and the Session then refuses the stage with that message.
- `get_active_encounter_bounds()` is the value for boss-arena retreat containment (STAGE_01_HANDOFF).
- `lantern_guardian` points at the dev Sentry until F12-03.
- Since F10-02 `gate.gd` is on `Gates/Gate_S1_02..05` and `checkpoint.gd` on `Checkpoints/CP1-A` and `CP1-B`, with their exports. Keep `BarrierBody/Collision`, `ClosedVisual`, `Respawn` and `Environment/PortalLinks/GuardLink1..3`: the Director resolves them, and `check_setup()` names any that go missing.
- For a Checkpoint glow, react to `StageDirector.checkpoint_activated(checkpoint_id)`, for example with an `AnimationPlayer` on the arch. Tell Claude the node, and Claude connects it once.

## Open issues

- **Retry** restores through `_checkpoint_store` and `_apply_progress()` in F10-03; until then Defeat's Retry restarts the stage.
- **No Checkpoint glow or sound yet:** Astra connects presentation to `checkpoint_activated` through Claude.
- **No scene tests** (sprint rule).
- **`tools/validate_stage_01.gd` (Astra's) now fails** its "static stage has no runtime script" check, by design: Stage 1 has its Director. Its owner updates the check; `tools/build_stage_01.py` must never be rerun over the wiring.
- **Exit-time leaks from the enemy visuals** (`spirit_lume.tscn`, `sentry_lantern.tscn` duplicate their glTF children): Astra's, recorded in validation/stage-director.md.
- **EncounterMachine compile fix.** F10-01 found that `encounter_machine.gd` never compiled (two parameters named `enemy_id` shadowed its static `enemy_id()`); commit `be64081` renamed them, with no behavior change.
