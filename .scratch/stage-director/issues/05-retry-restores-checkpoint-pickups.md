# F10-05 Retry restores the checkpoint's pickups

Status: todo
Type: adapter
parallel-safe: no
Depends on: F10-03, F12-03
Lane: path
Model: Claude Opus 5.5, solo

## Goal

F10-03 (commit `519d687`) made `StageDirector.retry_from_checkpoint` remove every child of `RuntimeActors`. That removes every uncollected Pickup, including rewards left behind before the Checkpoint, such as S1-02's five Power Pickups and S1-03's Shield Pickup. `EncounterMachine.restore` then brings their Encounters back completed and rewarded, so those Pickups never return. STAGE_DESIGN "Checkpoint contract" says to remove pickups only "from the failed segment". F10-03's Outcome raised the question.

**Astra's decision (2026-09-24, translated from Portuguese).** On Retry, the Director restores the set of Pickups that existed when the Checkpoint was activated:

- Pickups collected before the Checkpoint stay collected.
- Pickups available at the Checkpoint reappear, even if they were collected during the failed Attempt. This includes the five Power Pickups of S1-02 left behind.
- Pickups generated after the Checkpoint are removed. They come back through the rewards of the replayed Encounters.

Retry then restores the same opportunities, without duplicating rewards or permanently penalizing a death. The whole change stays inside the Director.

## Read first

- `scripts/progression/stage_director.gd`: `retry_from_checkpoint`, `_on_checkpoint_entered`, `_on_rewards_requested`, `_spawn_pickup`, `_checkpoint_store`.
- `scripts/progression/checkpoint_store.gd` (`activate`, `retry_into`) and `scripts/progression/snapshot.gd`. A Snapshot holds only the three core captures, as primitives.
- `scripts/progression/encounter_machine.gd` `restore`: every Encounter before the resume Encounter comes back COMPLETED and rewarded, and every other one INACTIVE and unrewarded.
- `scripts/combat/pickup.gd`: `setup`, `accepted(pickup_id, kind, score_awarded)` and `kind`. `_pickup_id` has no getter, so the Director records each Pickup when it spawns it.
- `docs/engineering/stage-director.md` "Behaviour" (Rewards) and "Retry and Restart"; `docs/validation/stage-01-progression.md` "Retry and Restart" (the driver method, and the open item this ticket closes).

## Files

- **Edits:**
  - `scripts/progression/stage_director.gd`, limited to:
    - the two members and three private functions below;
    - a guard and two lines in `_spawn_pickup`;
    - one call line each in `_on_checkpoint_entered` and `retry_from_checkpoint`;
    - one clause each in the doc comments of `retry_from_checkpoint` and the class.
  - `docs/validation/stage-director.md`: a new "F10-05" section.
- **Serialized at session end:**
  - `docs/engineering/stage-director.md`:
    - the `retry_from_checkpoint` row of "Retry and Restart", and a short "Checkpoint Pickups" subsection under it;
    - the `retry_location_name()` row, which still says `"CP1-A"`. Since D-05 it reads `Portal Selado` and `Entrada do Santuário`.
  - `docs/validation/stage-01-progression.md`: only the "Uncollected earlier rewards are lost on Retry" bullet, marked resolved by F10-05.
  - `docs/engineering/ROADMAP.md`: add the F10-05 row.
  - `docs/HANDOFF_LOG.md`.
  - `docs/GUIDE.md` Section 6, the `stage_director.gd` row: one "Since F10-05" clause.
- **Must not touch:**
  - `checkpoint_store.gd`, `snapshot.gd`, `encounter_machine.gd` (F8 cores);
  - `pickup.gd`;
  - `scenes/stages/*.tscn`, `content/`;
  - every trunk-only file (SPRINT.md "Lanes"), including `game_session.gd`. The Session's `_retry` order does not change.
- **Conflicts with:** `stage_director.gd` is also edited by:
  - sol's F12-05, then F12-06 part 2 and F12-07 part 2;
  - trunk's F13-03.

  Trunk's F12-03 part 2 is a dependency, so it lands before this ticket. Run `tools/lane.ps1 sync` right before starting, keep every addition in its own private function with a one-line call site, and let the second lander merge both.
  - If F12-05 has landed and moved Checkpoint activation into a shared function (its `activate_checkpoint_on_entry` path), put the record line in that function, so both activation paths record.
  - If F12-05 spawns its Seal Power Pickups without `_spawn_pickup`, route them through it (one line) so CP2-A records them.

## Deliverables

**Where the record lives.** The record lives in the Director, beside `_checkpoint_store`, not in the Snapshot, for three reasons:
- A `Snapshot` holds only the three core captures, as primitives and never a Node. It carries no Director data today, and its files are F8's.
- Pickups are runtime actors, and GUIDE Section 8 gives the Director its own actors on Retry.
- The record keeps each Pickup's prefab scene.

The record stays in step with the store. It is replaced only when `CheckpointStore.activate` returns true, which is exactly when `latest()` changes. A Restart builds a new Director, so the record and the store both start empty.

```gdscript
## Every Pickup spawned and not yet accepted, by pickup id:
## {"scene": PackedScene, "position": Vector3}, its prefab and its spawn point.
var _live_pickups: Dictionary[StringName, Dictionary] = {}
## A copy of _live_pickups taken when the latest Checkpoint activated: what Retry spawns
## again. Empty before any Checkpoint.
var _checkpoint_pickups: Dictionary[StringName, Dictionary] = {}
```

- **`_spawn_pickup(scene, pickup_id, at)`:**
  - At its top, an id already in `_live_pickups` is reported with `push_error` and not spawned, so an id is live at most once.
  - At its end: `pickup.accepted.connect(_on_pickup_accepted)` and `_live_pickups[pickup_id] = {"scene": scene, "position": at}`.
  - The scene stands in for `kind`, because the prefab fixes it. So no kind-to-scene mapping is needed, and a later prefab respawns as itself.
  - The record keeps the spawn point, not the position at activation. A Pickup that drifted toward the ship reappears where it was laid out (PLANEJAMENTO Section 4, "predictable power and shield placement").
- **`_on_pickup_accepted(pickup_id: StringName, _kind: Pickup.Kind, _score_awarded: int)`:** `_live_pickups.erase(pickup_id)`.
- **`_record_checkpoint_pickups()`:** `_checkpoint_pickups = _live_pickups.duplicate(true)`. The inner Dictionaries are copied; the `PackedScene` stays a reference. Its call site is one line in `_on_checkpoint_entered`, right after `_checkpoint_store.activate(...)` returned true and before `checkpoint_activated.emit`.
- **`_restore_checkpoint_pickups()`:**
  - First `_live_pickups.clear()`: the removal loop already freed every node.
  - Then `_spawn_pickup(record["scene"], pickup_id, record["position"])` for each entry of `_checkpoint_pickups`, in its order.
  - Its call site is one line in `retry_from_checkpoint`, after `_player = player` and the new `_rng` (each Pickup binds the new ship in `setup`) and before `_apply_progress()`.
- **Unchanged:**
  - The removal loop still frees every enemy and every Pickup of the failed Attempt.
  - The Pickups generated after the Checkpoint are not in the record. Their Encounters are at or after the resume point, so they come back INACTIVE and unrewarded, and `rewards_requested` fires again when they are replayed.

**Nothing is credited twice:**
- A Pickup taken before the Checkpoint was erased on `accepted`, so it is not in the record.
- A recorded Pickup taken during the failed Attempt did credit `CombatState`. But `retry_into` puts back the Snapshot's `power_level`, `power_progress` and `has_shield`, and `RunState`'s committed score (the 50 excess points). Taken again after Retry, it counts once.
- Ids stay stable:
  - A restored Pickup keeps its recorded id, and a replayed Encounter gets the same `&"<encounter_id>/power_<n>"` ids as before.
  - No id is both in the record and requested again. The resume Encounter cannot begin before its Checkpoint activates, and every Encounter before it comes back rewarded. The guard in `_spawn_pickup` enforces this; it must never fire in the checks.
- A second Retry from the same Checkpoint spawns the same set. Pickups accepted after the activation change `_live_pickups`, never `_checkpoint_pickups`.

## Verification (no tests: SPRINT.md "No new tests")

- `tools/lane.ps1 land` passes: the existing suite, the boot smoke and the resource check.
- **Driven pass on `scenes/main.tscn`:** a throwaway `SceneTree` script, not in the repo, as in F10-03. It teleports with `reset_to()`, kills through `EnemyActor.take_damage`, forces Defeat with `get_combat_state().take_hit(...)` and presses Defeat's focused Retry with `ui_accept`. Run it headless first, and grep for `SCRIPT ERROR` and the guard's `ERROR:`. The four cases:
  1. **The five come back.** Clear S1-02 and leave its five Power Pickups, then activate CP1-A and die in S1-05. Defeat reads `Último checkpoint · Portal Selado`. After Retry:
     - `RuntimeActors` holds `S1-02/power_1..5`, each 1.500 horizontally from `RewardOrigin` (0, 9, -130);
     - it also holds `S1-03/shield_1` at (12, 24, -218), if that was left;
     - a second Defeat and Retry gives the same set.
  2. **Collected before stays collected.** Take `S1-02/power_1` before CP1-A. After Retry, only `S1-02/power_2..5` are back.
  3. **Collected during the failed Attempt comes back, credited once.** After CP1-A, fly back and take `S1-02/power_3`, then die. After Retry it is back, and Power Level and Progress equal the Snapshot's. Taking it again adds exactly one Progress.
  4. **Generated after is removed.** Complete S1-05 (its five spawn), then die before CP1-B. After Retry no `S1-05/power_*` is left. Replaying S1-05 spawns `S1-05/power_1..5` once, with no guard `ERROR:`.
  - Extra, one line: leave S1-02's and S1-05's Pickups, activate CP1-B, die in S1-07. After Retry all ten are back.
- **Windowed capture** `stage-director-retry-pickups.png`, after case 1: the ship placed with `reset_to()` about 15 units on +Z of S1-02's `RewardOrigin`, facing -Z, with the five Power Pickups in their ring.
- Record the four cases, the extra case and the capture in `docs/validation/stage-director.md`.

## Out of scope

- **An Encounter still active when its Checkpoint activates** (between `after_encounter_id` and `resume_encounter_id`, such as S1-06 at CP1-B) is restored completed and rewarded. If one dropped rewards after the activation, they would not return. Neither stage has such an Encounter (S1-06 and S2-06 are traversals without rewards), so nothing changes; add one line to the module doc's Open issues.
- The Session, the F8 cores, `Pickup`, the scenes and the content.
- Astra's open items: the duplicated parts in the enemy visuals, and the `validate_stage_01.gd` check.

## Definition of Done

`tools/lane.ps1 land` passes. The driven cases and the capture are recorded, and the module doc has the "Checkpoint Pickups" subsection. The F10-03 open item is marked resolved, the handoff entry is written, the ticket is `Status: done` with an Outcome, and the ROADMAP row is updated. One commit: `progression: Retry restores the checkpoint's pickups`.

## Handoff notes for Astra

- Your decision is implemented as written. None of your files change.
- Restored Pickups reappear at their spawn point: the ring around `RewardOrigin`, or the `ShieldPickup` marker. They do not reappear where they had drifted. Tell Claude if you want otherwise; it is a one-line change.
- For F12-05 (lane sol): spawn each Seal Power Pickup through the Director's `_spawn_pickup`, so a Retry at CP2-A restores the ones left in S2-03.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/SPRINT.md and .scratch/stage-director/issues/05-retry-restores-checkpoint-pickups.md, then implement that ticket solo in lane path with no tests. Run tools/lane.ps1 sync right before you start, since stage_director.gd is shared. Verify it with the driven Retry pass on main.tscn, headless first, then the windowed capture. Finish with its Definition of Done, commit, and run tools/lane.ps1 land.
```
