# F10-02 Gate and Checkpoint adapters

Status: done
Type: adapter
parallel-safe: no
Depends on: F10-01, F8-03, F7-02
Lane: trunk
Model: Claude Opus 5.5, 3-agent workflow (implementer, test-writer, reviewer)

## Goal

Stage 1 becomes a full route:

- The four Gates open when their Encounter completes, and clear hostile fire first. They block both the ship and Projectiles while closed.
- The S1-04 PortalLinks disappear as their guards die.
- CP1-A and CP1-B activate only after the Encounter before them is complete. The first activation clears hostile fire, refills, commits and records a Snapshot through the Director's own `CheckpointStore`; a revisit does nothing.
- Each Checkpoint arms the next combat Encounter.

This ticket also builds the Director's `_apply_progress()`, which sets every Gate and PortalLink from the machine's state. F10-03's Retry reuses it. There is no Session edit: the Director already holds `RunState`, `CombatState` and the `ProjectileSystem` from `setup`.

## Read first

- `docs/STAGE_01_HANDOFF.md`:
  - "Gates and portal presentation": Gate roots at Z -140, -225, -315 and -425. Each has `BarrierBody/Collision`, `ClosedVisual` and `Arch`. Opening disables the collision and hides `ClosedVisual`, idempotently, including on reconstruction. `Environment/PortalLinks/GuardLink1..3`.
  - "Checkpoints": `Area3D` roots with `Collision` and `Respawn`, monitoring off. The Director must require activation before arming the next combat Encounter.
- `docs/STAGE_DESIGN.md`:
  - "Checkpoint contract" (activation and restore defaults).
  - "Shared encounter rules": clear hostile bullets when a gate opens and before a checkpoint activates.
  - The acceptance checks.
- `docs/engineering/progression-core.md`:
  - `CheckpointStore.activate(checkpoint_id, combat, run, encounters) -> bool`: it refuses while combat is defeated or paused, and calls `notify_checkpoint_entered` itself.
  - `EncounterMachine.is_checkpoint_activated`, `get_open_gate_ids()`, and `EncounterDefinition.checkpoint_id`.
  - `cp1_a.tres` and `cp1_b.tres`.
- `docs/engineering/stage-director.md` (F10-01) and `docs/engineering/damage-pickups.md` "Bomb" (`damage_targets_in_radius`).

## Files

- **Creates:** `scripts/progression/gate.gd`, `scripts/progression/checkpoint.gd`, `tests/scene/test_gates_and_checkpoints.gd`, `docs/validation/stage-01-progression.md`.
- **Edits:**
  - `scripts/progression/stage_director.gd`:
    - The Gate, Checkpoint and PortalLink handling below; the `_checkpoint_store` member.
    - `guard_links` export, `checkpoint_activated` signal, and `_apply_progress()`.
    - `check_setup()` extended to Gates, Checkpoints and links.
  - `scenes/stages/stage_01.tscn` [shared]:
    - `gate.gd` on `Gates/Gate_S1_02` to `Gate_S1_05`.
    - `checkpoint.gd` on `Checkpoints/CP1-A` and `CP1-B`, with `checkpoint_id` `&"CP1-A"` and `&"CP1-B"`.
    - On `Stage`, the Director's `guard_links`: `&"S1-04/Wave1_Sentry1"` → `^"Environment/PortalLinks/GuardLink1"`, and likewise for 2 and 3.
    - Script attachment and exports only; `monitoring` stays false in the file.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F10-02 row.
  - `docs/HANDOFF_LOG.md`: one entry, announcing the scene change.
  - `docs/engineering/stage-director.md`: "Gate", "Checkpoint" and "Progress application" sections.
  - `docs/GUIDE.md`: Section 6 rows `gate.gd`, `checkpoint.gd` and `stage_director.gd`, the Section 7 row "Checkpoint entered", and the Section 10 row "Checkpoints/gates/seals".
- **Must not touch:**
  - `scripts/session/game_session.gd`: not in this ticket's slice.
  - F8's cores and definitions: `checkpoint_store.gd`, `snapshot.gd`, `encounter_machine.gd` and `scripts/definitions/*`.
  - `content/**`.
  - `Geometry/CP1-AArch` and `CP1-BArch`, and any Gate mesh, material or `Arch`. The shared arch trim material is Astra's.
  - `scripts/progression/seal*.gd` (F9-03).
- **Conflicts with:** `stage_director.gd` and `stage_01.tscn` (F10-01 before; F10-03 and F12-03 after).

## Deliverables

### `Gate` (`class_name Gate extends Node3D`)

- `_ready` resolves its own `BarrierBody/Collision` (`CollisionShape3D`) and `ClosedVisual`, reporting a missing one with `push_error`.
- `set_open(open: bool)`: if the Gate is already in that state, it returns. Otherwise it calls `_collision.set_deferred(&"disabled", open)`, which is safe from any callback, and sets `_closed_visual.visible = not open`. The `Arch` stays scenery.
- `is_open() -> bool`. Gates start closed, as authored.

### `Checkpoint` (`class_name Checkpoint extends Area3D`)

- `@export var checkpoint_id: StringName`.
- `signal entered(checkpoint_id: StringName)`, emitted from its own `body_entered` for a `PlayerController` body only.
- `set_armed(armed: bool)` sets `monitoring` deferred.
- `get_respawn_transform() -> Transform3D` returns `Respawn`'s global transform. `_ready` reports a missing id or `Respawn`.
- It holds no rule: the Director decides.

### Director additions

- **The store.** `setup` creates `_checkpoint_store := CheckpointStore.new()`, one per Director. Stage loads and Restart build a new Director, so a new store starts at Stage Entry.
- **`gate_opened(gate_id)`.** `_projectile_system.clear_hostile_all()` first, then `Gates/<gate_id>.set_open(true)`. The clear awards nothing.
- **Checkpoints.** For each `CheckpointDefinition`, the Director resolves the `Checkpoint` at `node_path`, calls `set_armed(true)`, and connects `entered` with `CONNECT_DEFERRED`. On `entered(id)`:
  1. It acts only if `machine.is_completed(def.after_encounter_id)` and `not machine.is_checkpoint_activated(id)`. Otherwise it returns, so neither a revisit nor an early entry can clear or refill.
  2. It calls `_projectile_system.clear_hostile_all()`, clearing before activation.
  3. If `_checkpoint_store.activate(id, _combat_state, _run_state, _machine)` returns true: set `_latest_checkpoint_id`, emit `checkpoint_activated(id)`, and, if the ship already overlaps the resume Encounter's EntryVolume (`overlaps_body`), call `notify_entered(resume id)`. The machine refused that entry while the Checkpoint was inactive.
- **PortalLinks.** `_on_enemy_defeated` (first report) hides `guard_links[enemy_id]` when present.
- **`_apply_progress()`** is called at the end of `setup` and by F10-03 after a restore:
  - every Gate named by the definition gets `set_open(gate_id in machine.get_open_gate_ids())`, so a Gate the failed Attempt opened closes again;
  - every guard link is shown unless `machine.is_completed(<encounter part of its enemy id>)`.
- **`check_setup()` additions.** Every non-empty `gate_id` must resolve to a `Gate` with its two children. Every checkpoint `node_path` must resolve to a `Checkpoint` whose `checkpoint_id` equals the definition's id and which has a `Respawn`. Every `guard_links` path must resolve.

## Tests required

`tests/scene/test_gates_and_checkpoints.gd` runs headless. The Gate and Checkpoint cases instance `stage_01.tscn` alone; the others run through `main.tscn` with a Direct Stage 1 and teleports.

- `test_gate_open_and_close_are_idempotent`: after a physics frame the collision is disabled and `ClosedVisual` is hidden; `set_open(false)` restores both.
- `test_checkpoint_reports_the_player_body_only`
- `test_s1_02_completion_clears_hostile_fire_then_opens_its_gate`: a hostile Projectile in flight is gone and Graze is unchanged.
- `test_closed_gate_blocks_the_ship_at_every_height`: pushed into `Gate_S1_03` at Y 5 and at Y 74, the ship stops near Z -225 (STAGE_DESIGN "Flying over/under a locked gate cannot skip").
- `test_closed_gate_stops_projectiles`
- `test_guard_link_hides_when_its_guard_dies`
- `test_s1_04_guards_open_the_gate_in_two_orders`: all six orders are F8-02's machine test.
- `test_bomb_kill_of_the_last_two_guards_opens_the_gate_once`: one `damage_targets_in_radius` kills both. Score is +200 once, `gate_opened` fires once, and there are no rewards (STAGE_DESIGN acceptance).
- `test_cp1_a_before_s1_04_completes_does_nothing`
- `test_first_cp1_a_activation_clears_refills_and_commits`: Health 60 becomes 100 with the Shield and two Bombs, `clear_time()` is committed, `checkpoint_activated` fires once, and `bombs_used` is kept.
- `test_revisiting_cp1_a_does_not_refill` (STAGE_DESIGN "Entering a checkpoint twice cannot repeatedly refill resources")
- `test_s1_05_is_armed_only_after_cp1_a`: flying past the arch arms nothing; coming back through it arms S1-05.
- `test_full_stage_1_route_with_dev_enemies`: every Encounter completes, all four Gates open, both Checkpoints activate, and `stage_cleared` fires once after the S1-07 stand-in. There is no miniboss (STAGE_DESIGN acceptance "Stage 1 progresses through all seven segments").

## Out of scope

- Retry and Restart, respawn, and the Defeat location (F10-03).
- Checkpoint glow and sound (requested from Astra; F13 is cut).
- Seals and Stage 2 guard links (F9-03, and cut with F12-04).
- The boss arena (F12-03).

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR`.
- Named tests for these STAGE_DESIGN acceptance items: gate bypass, bomb kill of the last guard exactly once, checkpoint twice cannot refill, all seven segments. No Error-level warnings.
- `/run`, headless first, then windowed: fly Stage 1 from the menu on keyboard. Gates open as Encounters clear, and CP1-A and CP1-B refill once. Record it in `docs/validation/stage-01-progression.md` with a gate screenshot.
- Module doc, GUIDE rows, handoff log, `Status: done` with an Outcome, ROADMAP row.
- One commit: `progression: [shared] add Gate and Checkpoint adapters to Stage 1`.

## Handoff notes for Astra

- `gate.gd` and `checkpoint.gd` are attached with their exports. Keep `BarrierBody/Collision`, `ClosedVisual`, `Respawn` and `Environment/PortalLinks/GuardLink1..3`: the Director resolves them.
- For a Checkpoint glow, react to `StageDirector.checkpoint_activated(checkpoint_id)`, for example with an `AnimationPlayer` on the arch. Tell Claude the node, and Claude connects it once.

## Outcome

Done 2026-09-23 by trunk (Claude: implementer, plus a verifier agent that ran the game and a reviewer agent).

`Gate`, `Checkpoint` and the Director additions follow the Deliverables. Each addition to `stage_director.gd` sits in its own private function with a one-line call site, for sol's F12-05 merge. `stage_01.tscn` [shared] gained two `ext_resource` lines, the scripts on the four Gates and two Checkpoints, their `checkpoint_id`s and the Director's `guard_links`; `monitoring` stays off in the file.

- **No new tests** (the user's sprint rule): `tests/scene/test_gates_and_checkpoints.gd` was not written. A throwaway driver ran the ticket's thirteen cases in the real game headless, and the windowed `/run` flew Stage 1 from the main menu on keyboard actions with no teleport: the Gates opened in order, and CP1-A and CP1-B each refilled once. Results and two captures are in `docs/validation/stage-01-progression.md`. The suite stays at 225, `validate_combat.gd` still gives `COMBAT_OK`, and F10-01's pass still passes.
- **Deviation:**
  - There is no `_latest_checkpoint_id` member. `CheckpointStore.latest_checkpoint_id()` already records the latest successful activation, and a copy would be duplicate state. F10-03 reads it from `_checkpoint_store`, with `Checkpoint.get_respawn_transform()`.
  - The reviewer agreed.
- **Reviewer finding, fixed:** `check_setup()` also requires every `guard_links` key to be one of the route's Wave enemy ids. Before, a mistyped key would have left its link lit for the whole Attempt.
- **Noted, unchanged:** the "ship already inside the resume EntryVolume" branch cannot happen on Stage 1, because the volumes are 10 units past the Checkpoints. It was exercised with a synthetic entry. A Checkpoint entry handled in the same tick as a defeating hit clears fire, and the store then refuses; Retry clears everything anyway.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/stage-director/issues/02-gate-and-checkpoint-adapters.md, then implement that ticket. Use /run to verify the whole Stage 1 route from the main menu: Gates open as Encounters clear and CP1-A and CP1-B refill once. Finish with its Definition of Done and commit.
```
