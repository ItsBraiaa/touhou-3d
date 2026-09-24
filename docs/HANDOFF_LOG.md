# Handoff Log

Append-only, newest entry first. One entry per change set that another agent must know about. Both agents write here. Never rewrite or delete an earlier entry; add a new one that supersedes it.

Entry format:

```
## YYYY-MM-DD HH:MM — <agent> — <short title>
State: <PLANNED | SCENE_READY | CODE_READY | INTEGRATED_VERIFIED | docs | dev>
Files: <paths touched>
Change: <what changed>
Why: <reason>
Action required by <other agent>: <what they must do, or "none">
```

---

## 2026-09-24 01:46 UTC — Astra — Stage 1 night forest and both-stage rails
State: SCENE_READY
Files: scenes/stages/stage_01.tscn, scenes/stages/stage_02.tscn, assets/environment/stage_01/gate_veil.gdshader, Stage 1 and Stage 2 validation captures and handoffs, ROADMAP, local issue.
Change: Stage 1 has a navy night palette, moon, warm sparse lanterns, textured forest detail and low blue gate veils; both stages have visible side rails along every route terrace. Stage 1 rails sit on the bank tops. No runtime node names, markers, gate collision, collision layers, masks or script wiring changed.
Why: User review requested a stronger Stage 1 night presentation, removal of the pink sky column, and readable out-of-bounds edges on both stages.
Action required by Claude: preserve Environment/BoundaryRails and the authored lighting/veil when attaching Stage Director and stage actors. The existing FlightBounds walls continue to provide physical containment; include them in the integrated flight pass. No wiring change is required for the rails.


## 2026-09-23 23:40 — Claude (path) — F6-04: Aim Assist follows the Target Lock under lock framing
State: CODE_READY
Files: `scripts/combat/player_weapon.gd` (the fire path and one new export), `docs/validation/enemies.md` (re-measurement; the F9-02 finding marked resolved), `docs/engineering/weapon-rendering.md` ("Aim Assist under a lock"), `docs/GUIDE.md` (Section 6 `player_weapon.gd` row), the ROADMAP F6-04 row.
Change:
- **The rule.** Under a Target Lock, the Aim Assist angle is measured from the camera, between the view and the lock's `HitVolume`. Each shot compares it with its cone widened by `lock_assist_degrees − main_assist_degrees`: main 25°, Familiars 25° at Power Level 2 and 35° at Power Level 3. Inside the cone the shot flies straight at the target. Unlocked fire is unchanged (no assist without a lock).
- **New export** `lock_assist_degrees` 25.0, a code default. `player_ship.tscn` is untouched.
- **Measured:** a locked Spirit at 10, 16, 30 and 50 units now falls in 2.02, 2.12, 2.35 and 2.68 s. Before, it never fell at 10 or 16. `CameraRig` and `Targeting` are unchanged.
- **Tests:** none (sprint rule).
Why: F6-04, from path's F9-02 finding (PLANEJAMENTO Section 4: Aim Assist toward the lock).
Action required by Astra: `lock_assist_degrees` (25°) is yours to tune (D-05 or D-07 Part C). Report the value to trunk for F14-01's swap step.
Action required by Claude (trunk): none now. F13-03 adds `shots_fired` to the same `_fire`, which is still the single fire path. `WeaponModel.assist_direction` is no longer called by the weapon; it stays in the core.
## 2026-09-24 02:00 — OpenCode (oc-a) — F9-03 part 1: SealRules core
State: CODE_READY
Files: `scripts/progression/seal_rules.gd`, `docs/engineering/enemies.md`
Change: Added the Node-free SealRules lifecycle core. It activates linked Guards once, counts each linked defeat once, exposes the Seal only after all Guards are defeated, ignores early damage including Bomb damage, and emits exactly-once progression signals. Capture and restore preserve state without emitting signals.
Why: F9-03 part 1 supplies the Stage 2 Seal progression contract for the adapter in part 2.
Action required by other agent: none; continue with F9-03 part 2.

## 2026-09-24 01:45 — Claude (plan) — land compiles every script; EncounterMachine fix landed early
State: dev
Files: `tools/check_resources.gd`, `tools/lane.ps1`, `docs/engineering/SPRINT.md`, `scripts/progression/encounter_machine.gd` (cherry-picked from trunk's `be64081`, byte-identical).
Change:
- **The fault.** F8-02's `encounter_machine.gd` never compiled: a parameter shadowed a function, which this project treats as an error. It passed `land` because no test or scene loaded it. Trunk found it in F10-01 and fixed it.
- **The early landing.** That exact fix is landed now, so no lane is blocked while trunk is still in F10-01. The change is identical, so trunk's own branch merges cleanly.
- **The gate.** `tools/check_resources.gd` now also compiles every `.gd` under `scripts/` and `tools/`: 53 scripts and 70 resources, clean.

Why: a core that nothing loads yet would otherwise break the first lane that uses it.

Action required by Astra: none.

## 2026-09-23 23:05 — Claude (path) — F12-02: BossController and dev boss prefab
State: CODE_READY
Files:
- New: `scripts/enemies/boss_controller.gd`, `scenes/dev/dev_boss.tscn`, `scenes/dev/dev_boss_definition.tres`, `docs/validation/bosses.md`, `docs/validation/bosses-dev-boss.png`.
- Edited: `scenes/dev/arena_harness.gd` and `.tscn` (export `spawn_dev_boss`, marker `EnemySpawns/DevBoss`, HUD boss-panel wiring, readout lines; additions in their own functions).
- Docs: `docs/engineering/bosses.md` (BossController contract, Setup for Astra), `docs/GUIDE.md` (Section 6 `boss_controller.gd`, Section 7 "Boss phase changed"), the ROADMAP F12-02 row.

Change:
- **`BossController`** on a boss's `Enemy` root. `spawn_setup(definition, enemy_id, encounter_id, rng, projectile_system, player, bounds) -> bool` works as for `EnemyActor`. Each physics tick at priority 0 it hovers the boss (placeholder bob), ticks the `BossMachine` from `Emitters/Main`, spawns its shots and registers its `HitVolume` sphere. It also:
  - clears every hostile Projectile when a Phase is depleted;
  - plays the optional clips `idle_clip`, `step_clip`, `phase_clip` (the sprint note) and `defeat_clip` only if `has_animation()` finds them, and otherwise warns once and skips them;
  - emits `boss_started`, `phase_changed`, `phase_health_changed`, `threat_reported` and `defeated` once, shaped for the HUD boss panel;
  - provides `get_score()`.
- **Dev boss:** "Guardião (dev)", three Phases of 40, a primitive sphere, hit radius 2.5. In the harness, `spawn_dev_boss` spawns it and wires the HUD as GUIDE Section 7 says.
- **Tests:** none added or changed (sprint rule). Scripted runs are in `docs/validation/bosses.md`.

Why: F12-02; F12-03, F12-06 and F12-07 attach this controller to Astra's boss scenes.
Action required by Claude (trunk): `content/bosses/lantern_guardian.tres` (F12-03 part 1) **does not load**. Line 14 references `SubResource("Attack_Ritual")` before it is declared, and Godot's parser refuses that. Reorder the sub-resources (steps, then attacks, then phases) before F12-03 part 2. To attach the controller to `lantern_guardian.tscn`, set `visual_root`, `hit_volume`, `emitter`, `animation_player` → `VisualRoot/Model/AnimationPlayer` and the clips `Flying_Idle`, `Punch`, `Yes`, `Death`. All four were checked at runtime.
Action required by Astra: none. Your boss trees already fit, with `HitVolume` placed at the hit center.
## 2026-09-24 01:30 — Claude (plan) — lantern_guardian.tres loads again; land now loads every resource [shared]
State: dev
Files: `content/bosses/lantern_guardian.tres` (sub-resources reordered, values unchanged), `tools/check_resources.gd` (new gate tool), `tools/lane.ps1`, `docs/engineering/SPRINT.md`.
Change:
- **The fault.** F12-03 part 1 landed `lantern_guardian.tres` with each Phase declared before the Attack and Steps it references. Godot's text parser rejects forward `SubResource` references ("Parse Error" at line 14), so the Boss Definition did not load. Path found it while checking F12-02.
- **The fix.** The blocks are now ordered so each comes after everything it references, with no value changed; the file loads and validates.
- **Why the gate missed it.** It never loaded `content/`: no content-validation test exists under the no-tests rule.
- **The new gate step.** `land` now also runs `tools/check_resources.gd`: every `.tres` and `.tscn` under `content/` and `scenes/` must load, and each Definition's `validate()` must pass. It checks 70 files, clean.

Why: trunk's F12-03 part 2 was blocked on this file, and a hand-written `.tres` can break the same way again.

Action required by Astra: when you hand-write or tune a `.tres` with sub-resources, declare each one after the ones it references. `land` now refuses the file otherwise.
## 2026-09-23 22:27 — OpenCode (oc-b) — F14-02 part 1 package script
State: CODE_READY
Files: `tools/package.ps1`, `docs/HANDOFF_LOG.md`
Change: Added the PowerShell 5.1-compatible package script for the first split part. It refuses a missing export with exit 2 and a dirty tree with exit 3, stages tracked project files while excluding agent directories, copies both exported executables, writes the Portuguese LEIA-ME, creates the dated zip, and includes extracted-copy import, test and executable boot verification plus `-SkipVerify`.
Why: F14-02 part 1 prepares the delivery tooling before trunk's F14-01 export is available; the final acceptance record and package run remain part 2.
Action required by trunk: none. For the next oc-b session (F14-02 part 2): sync after F14-01, run the script without `-SkipVerify`, record the package evidence and acceptance matrix, then close the ticket.

## 2026-09-23 22:20 — OpenCode (oc-b) — F3-01 Settings core and ConfigFile persistence
State: CODE_READY
Files: `scripts/settings/settings.gd`, `docs/engineering/settings.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md`, `.scratch/settings/issues/01-settings-core-and-configfile.md`, `docs/HANDOFF_LOG.md`
Change: Added the Node-free `Settings` Rules Core with GUIDE Section 14 defaults, typed getters, per-field sanitising and validation, idempotent `changed` signal emission, deep `capture`/`restore`, explicit ConfigFile load/save, corrupt-file fallback and static volume helpers. The new settings module contract documents the audio/display/controls file layout and invariants. No tests were written per the sprint rule.
Why: F3-01 supplies F3-02 with the validated settings state and persistence boundary without coupling the core to buses, windows, devices or camera behavior.
Action required by Astra: none. For path F3-02: construct `Settings`, call `load_file()` once at startup, apply the typed getters to widgets and call `save_file()` only after explicit user changes.

## 2026-09-24 01:00 — Claude (plan) — F6-04: Aim Assist under lock framing, queued in path
State: PLANNED
Files: `.scratch/weapon-rendering/issues/04-aim-assist-under-lock-framing.md` (new), `docs/engineering/SPRINT.md` (path row 7a), `docs/engineering/ROADMAP.md`.
Change: Path's F9-02 finding (locked shots miss enemies 10 to 16 units away once the lock framing blends in) becomes F6-04, in path after F12-02. It changes `PlayerWeapon`'s fire path so a Target Lock is aimed at against the lock itself, not the off-center framed view. The camera framing is untouched.
Why: Aim Assist toward the Target Lock is a PLANEJAMENTO Section 4 rule, and trunk is on the critical path.
Action required by Astra: tune `lock_assist_degrees` if F6-04 adds it, through D-05 or D-07 Part C.

## 2026-09-23 22:15 — Claude (path) — F9-02: EnemyActor and dev Spirit and Sentry prefabs [shared]
State: CODE_READY
Files:
- New: `scripts/enemies/enemy_actor.gd`, `scenes/dev/spirit.tscn`, `scenes/dev/sentry.tscn`, `docs/validation/enemies.md`, `docs/validation/enemies-arena.png`.
- New, Astra's values **[shared]**: `content/enemies/spirit.tres`, `content/enemies/sentry.tres`, `content/patterns/spirit_aimed_burst.tres`, `content/patterns/sentry_fan.tres` (all `metadata/dev = true`).
- Edited: `scenes/dev/arena_harness.gd` and `.tscn` (an `EnemySpawns` node with `Spirit` and `Sentry` markers; additions in their own functions).
- Docs: `docs/engineering/enemies.md` (EnemyActor contract, Setup for Astra), `docs/GUIDE.md` (Section 6 `enemy_actor.gd`, Section 7 "Enemy defeated", Section 10 "Common enemies and miniboss"), the ROADMAP F9-02 row.

Change:
- **`EnemyActor`** on the `Enemy` root: `spawn_setup(definition, enemy_id, encounter_id, rng, projectile_system, player, bounds)` after `add_child` under `RuntimeActors` (the Director's call in F10-01), then each physics tick at priority 0 it ticks the `EnemyModel`, spawns its hostile shots and registers its `HitVolume` sphere; `targetable`; a dev scale pulse over each Anticipation; `threat_reported(side)` when an attack starts off-screen; `defeated(enemy_id, encounter_id)` once, then `queue_free()`.
- **Dev prefabs** instance your `spirit_lume` and `sentry_lantern` as `VisualRoot`. The `HitVolume` sits at the root origin, where your visuals are centered (radius 1.0 and 0.9).
- **Arena harness:** a Spirit and a Sentry spawn in front of the ship with a seeded RNG; R respawns them; the readout shows their health, the defeats and the last off-screen side.
- **Tests:** none added or changed (sprint rule). Scripted runs in `docs/validation/enemies.md`.
- **Merge with trunk's F7-03:** conflicts in `scenes/dev/arena_harness.gd`, `scenes/dev/arena_harness.tscn` and `docs/GUIDE.md` (Section 6 rows) resolved on `lane/path`, keeping both sides: the harness spawns the Pickups and then the enemies, the readout shows both lines (its box grown to 440 px), and `EnemySpawns` is now a validated export like `pickup_root`.

Why: F9-02; the Director (F10-01) spawns through this API, and D-05 tunes these files.
Action required by Astra: D-05 may now tune `content/enemies/*.tres`, `content/patterns/*.tres` and the `HitVolume` radii (move the `HitVolume` node itself to re-center: its position is the aim point). Your final `scenes/enemies/spirit.tscn` and `sentry.tscn` can copy the dev tree one to one (enemies.md "Setup for Astra").
Action required by Claude (trunk): locked shots miss enemies 10 to 16 units away once the camera's lock framing blends in, by about 3.5 units, just outside the 10° main Aim Assist cone; from 30 units they hit. `PlayerWeapon` forward/cone against `CameraRig` lock framing (F6-03); see `docs/validation/enemies.md` "Finding for another lane". F10-01 can call `spawn_setup` as documented; score comes from `definition.score` on `defeated`.
## 2026-09-23 22:11 — OpenCode (oc-b) — F8-03 Snapshot and CheckpointStore
State: CODE_READY
Files: `scripts/progression/snapshot.gd`, `scripts/progression/checkpoint_store.gd`, `docs/engineering/progression-core.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md`, `.scratch/progression-core/issues/03-snapshot-capture-restore.md`, `docs/HANDOFF_LOG.md`
Change: Added the Checkpoint pair of STAGE_DESIGN's "Checkpoint contract": `Snapshot`, the immutable deep-copy value object of the `CombatState`, `RunState` and `EncounterMachine` captures (`capture_from`, `restore_into` with a fresh deep copy per core, `get_checkpoint_id` / `get_stage_id` / `get_resume_encounter_id`, `to_dict` / `from_dict`), and `CheckpointStore`, the Rules Core around it (`activate` asking `notify_checkpoint_entered` first and refusing while defeated or paused; refill, then `commit_checkpoint`, then the record, so the bombs-used statistic survives; `latest`, `latest_checkpoint_id`; `retry_into` restoring the latest Snapshot without a refill; `restart_into` as the core-level Restart proof F10 never calls; `reset`). Both contracts, the 4.H invariant rows and the Retry and Restart call sequence F10-03 follows are documented in `progression-core.md`. No tests were written per the sprint rule.
Why: F8-03 gives trunk's F10-02/F10-03 the Checkpoint rules: Defeat's Retry offer, the retry location and the Restart split.
Action required by Astra: none. For trunk (F10-02/F10-03): create the `CheckpointStore` in the Director's `setup()` (it survives Retry); call `store.activate(id, combat, run, encounters)` on a Checkpoint Area's entry; on Retry call `retry_into` and, when it returns false, Restart; never call `restart_into` — Restart keeps F2-04's full stage reload.

## 2026-09-24 00:30 — Claude (plan) — OpenCode runs on one shared meter: power models out, F3-02 and F3-03 to path
State: docs
Files: `docs/engineering/SPRINT.md` ("Model budgets" rewritten, oc-a, oc-b and path queues, Escalation, Overflow, Human steps, Shared files), `.scratch/settings/issues/02-*.md` and `03-*.md` (lane path), `.scratch/enemies/issues/03-seal-and-guard-rules.md` (part 2 on Luna), `docs/engineering/ROADMAP.md`.
Change:
- **The user's correction.** OpenCode has one usage meter shared by every model. A power-model request costs 10 to 20 times a Luna request and about 200 times a DeepSeek V4.1 Flash one.
- **Routing.** The remaining OpenCode tickets run on GPT 5.6 Luna, with V4.1 Flash as fallback. F9-03 part 2 moves from Qwen3.8 Max to Luna. F3-02 and F3-03 (planned on GLM-5.3) move to lane path, which has an Opus gap before its F3-04 part 1.
- **Escalation.** A stuck ticket now goes straight to rescue (Opus), not to Kimi K3.
- **Cost.** The rest of the OpenCode plan is about 22 % of one 5-hour window.

Why: on a shared meter, a single GLM-5.3 ticket would have spent most of a window.

Action required by Astra: none.

## 2026-09-23 21:54 — Claude (trunk) — F7-03: Pickup adapter and dev pickup prefabs
State: CODE_READY
Files:
- New: `scripts/combat/pickup.gd` (`Pickup`), `scenes/dev/power_pickup.tscn`, `scenes/dev/shield_pickup.tscn`, `docs/validation/pickups-arena.png`.
- Edited: `scenes/dev/arena_harness.gd` and `.tscn` (a `Pickups` node, the row spawn, the readout lines, dev key H).
- Docs: `docs/engineering/damage-pickups.md` ("Pickup contract"), `docs/validation/combat.md` ("Pickups"), `docs/GUIDE.md` (Section 6 `pickup.gd` row, Section 7 "Pickup accepted" row), the ROADMAP F7-03 row and "Requests to Astra" F7 row, and the ticket.

Change:
- **`Pickup`** is the Adapter on a Pickup root `Area3D`: accepted once on contact with the player body through `CombatState.collect_power_pickup()` or `collect_shield_pickup()`, then `accepted(pickup_id, kind, score_awarded)` and `queue_free()`. A Shield Pickup stays, unattracted, while the ship is shielded and is taken on the first tick after the Shield breaks. It drifts toward the player within `attraction_range` (6.0) at `attraction_speed` (14.0).
- **Dev prefabs** instance Astra's D-02 `power_pickup_visual.tscn` and `shield_pickup_visual.tscn` as `Visual` (no file of Astra's edited; no swap pending). Root: layer 0, mask 2, monitoring on, monitorable off, a 0.9 sphere.
- **Arena harness:** eleven Power Pickups in a row and one Shield Pickup; readout shows progress, Shield, Pickups taken and excess score; H breaks the Shield.
- **Tests.** None added (sprint rule). A throwaway script drove the harness: `PICKUPS_OK` headless and windowed.

Why: F7-03, which feeds F10-01's reward spawning.
Action required by Astra: none now. For final Pickup scenes keep the root contract in damage-pickups.md "Pickup contract", tune `attraction_range` and `attraction_speed` there, and send Claude the paths.
## 2026-09-23 22:00 — OpenCode (oc-a) — F12-03 part 1 Lantern Guardian content [shared]
State: dev
Files: `content/bosses/lantern_guardian.tres`, `content/patterns/lantern_ring.tres`, `content/patterns/lantern_aimed_burst.tres`, `content/patterns/lantern_paired_fan.tres`, and F12-03's ticket.
Change: Added the dev-flagged Lantern Guardian BossDefinition with three named Portuguese attack phases, health proposals of 1500/1500/2100, and authored ring, aimed-burst, and paired-fan patterns. Phase 1 alternates high/low rings and sparse aimed bursts; Phase 2 follows player height for charged aimed bursts and paired fans; Phase 3 combines rings, aimed bursts, and a reposition window.
Why: F12-03 part 1, content deliverables for the later Stage 1 Director integration.
Action required by Claude: Part 2 should reference these resources, preserve `kind = &"lantern_guardian"`, score 1000, the three attack names, and the dev placeholders until Astra tunes the values. No tests were added under the sprint rule.

## 2026-09-23 21:35 — Astra (sol) — Stage 2 content review (D-06 pass 1) [shared]
State: SCENE_READY
Files: `content/stages/stage_02/*.tres`, `docs/validation/stage-02-pacing.md`, `docs/engineering/ROADMAP.md`, `docs/HANDOFF_LOG.md`, and D-06's ticket.
Change: CP2-A `display_name` changed `CP2-A` → `Portão dos Selos`; CP2-B changed `CP2-B` → `Limiar do Cume`. All ten reviewed Stage 2 resources gained `metadata/reviewed = true`; `metadata/dev = true` remains. The S2-02 and S2-05 second-Wave delays remain 1.0 s. Reward audit confirms 20 common enemies, two bosses, seven Power and two Shield Pickups, including three per-Seal Power rewards. Direct Stage 2 reaches Power 3 before S2-04 if its first five Power items are collected. Conditional planning estimates are about 319 s efficient and 392 s normal; neither is measured. No content bug or Stage-2-only common-enemy request was found.
Why: D-06 pass 1 fixes the checkpoint names and supplies a transparent five-minute pacing budget before the Seal and boss values exist.
Action required by Claude: F12-05 loads the reviewed content with no structural change; F11-03 and F14-02 must treat the ≥300 s result as unverified until a measured uninterrupted clear. Astra keeps D-06 todo for pass 2 Seal health and pass 3 boss tuning.

## 2026-09-23 21:21 — Claude (trunk) — F7-02: Bomb clear, radius damage and bombs used [shared]
State: CODE_READY
Files:
- `scripts/session/game_session.gd`, `scripts/combat/projectile_system.gd` (`damage_targets_in_radius`), `scripts/combat/player_weapon.gd` (the "Bomb" exports and physics priority 50).
- `scenes/player/player_ship.tscn` **[shared]**: only `Weapon.bomb_visual_scene` = `scenes/dev/bomb_blast.tscn`.
- New: `scenes/dev/bomb_blast.gd` and `.tscn`, `docs/validation/combat-bomb.png`.
- Edited: `tools/validate_combat.gd` (checks 14 to 21).
- Docs: `docs/engineering/damage-pickups.md` ("Bomb"), `docs/engineering/weapon-rendering.md`, `docs/validation/combat.md`, `docs/GUIDE.md` (Section 6 rows for `player_weapon.gd`, `projectile_system.gd` and `game_session.gd`), and the ROADMAP F7-02 row.

Change:
- **What a Bomb press does.** It spends one Bomb, clears hostile fire within 10 units of the Core (awarding no Graze), counts in `bombs_used`, shows a translucent dev blast, and damages every registered enemy in range once for 20.
- **Where it is refused.** No Bomb under Pause, from the gamepad B that resumes Pause, with none left, or when defeated.
- **Weapon order.** `PlayerWeapon` now ticks after the actors, at physics priority 50. A Bomb sees this tick's enemies, and shots use this tick's yaw and lock.
- **Tests.** None added or changed (sprint rule). `validate_combat.gd` gives `COMBAT_OK`.

Why: F7-02.

Action required by Astra:
- **Tuning.** `PlayerShip/Weapon` has a "Bomb" group: `bomb_radius` (10.0), `bomb_damage` (20) and `bomb_visual_scene`, all yours to tune.
- **Swap pending: D-02.** Put the final blast inside a `BombBlast` root (`setup(radius)`, unit radius). It must keep later attacks readable.
- **Boss Phases.** Keep `bomb_damage` below the smallest boss Phase health.
## 2026-09-23 21:17 — OpenCode (oc-a) — F13-02 AudioController adapter
State: CODE_READY
Files: `scripts/audio/audio_controller.gd`, `docs/engineering/audio.md`, `docs/GUIDE.md` (Section 6 `audio_controller.gd` row), `docs/engineering/ROADMAP.md`, `.scratch/audio/issues/02-audio-controller-adapter.md`
Change: Added the AudioController adapter: limiter-gated SFX pool on `SFX`, crossfading music pair on `Music`, coalesced UI sounds from the Viewport and `Interface.action_requested` (accept outranks focus, one per frame), loud `_ready` validation, bad mapping entries reported and ignored. Not attached to any scene; F13-03 attaches it to `Main/Audio` and fills `event_streams` from D-01's files. No tests by the sprint rule; verified headless with a throwaway `tools/zz_audio_check.gd` (three events granted and logged, in-interval repeat refused, `missing_events` exact; deleted after the run). Headless audio runs on the Dummy driver, recorded in audio.md.
Why: F13-02; the playback half of the audio feature.
Action required by Astra: none now. After the D-01 listening pass, send Claude the event-to-file table and volume proposals; the `EVENT_RULES` intervals, caps and priorities are Claude's proposals for you to tune.

## 2026-09-23 21:09 — OpenCode (oc-b) — F12-04 Stage 2 content draft (dev) [shared]
State: dev
Files: `content/stages/stage_02/stage_02.tres`, `s2_01.tres` … `s2_07.tres`, `cp2_a.tres`, `cp2_b.tres`, `docs/engineering/progression-core.md`, `docs/engineering/ROADMAP.md`, `.scratch/bosses/issues/04-stage-02-content-draft.md`, `docs/HANDOFF_LOG.md`
Change: Transcribed STAGE_DESIGN's Stage 2 table into typed `.tres` Definitions that validate: seven Encounters in route order with the `next_id` chain, S2-01 with `requires_exit`, S2-03 as OBJECTIVES over `S2-03-Seal1..3` with its three ON_ENTRY guard waves, gates `Gate_S2_01` to `Gate_S2_05`, CP2-A guarding S2-04 and CP2-B guarding S2-07, 7 POWER and 2 SHIELD Pickups, and the new kinds `tempest_sentinel` and `storm_guardian`. Every file is flagged `metadata/dev = true`. The one-off headless scratch script (not committed) also cross-checked every marker, reward origin, gate and checkpoint against `scenes/stages/stage_02.tscn`, including the Seals' `seal_id` and `guard_spawn` metadata; no tests were written per the sprint rule.
Why: F12-05 loads `stage_02.tres`; Astra tunes the values in D-06 while the approved structure stays.
Action required by Astra: these files are yours. Free to change: the AFTER_PREVIOUS_WAVE delay (draft proposal 1.0 s) and the checkpoint `display_name`s (currently `"CP2-A"`/`"CP2-B"`). Must stay: the route order and completion conditions, the markers, 7 Power and 2 Shield Pickups, the five Gates and the resume points. Delete `metadata/dev` from a file once you have reviewed it.

## 2026-09-23 21:07 — Claude (trunk) — F6-03 part 2: PlayerWeapon, Familiars, target dummies; closes F6-03 [shared]
State: CODE_READY
Files:
- `scripts/combat/player_weapon.gd` (Astra's placeholder replaced by `PlayerWeapon`), `scripts/player/player_controller.gd`, `scripts/session/game_session.gd`.
- `scenes/player/player_ship.tscn` **[shared]**: only the `PlayerShip` `weapon` reference and the `Weapon` exports `muzzle`, `familiar_anchors`, `camera_rig`, `familiar_scene`; no transform, mesh, shape, layer or monitoring change.
- New: `scenes/dev/familiar.tscn`, `scenes/dev/target_dummy.gd` and `.tscn`, `docs/validation/weapon-rendering-familiars.png`.
- Edited: `scenes/dev/arena_harness.gd` and `.tscn`.
- Docs: `docs/engineering/weapon-rendering.md` ("WeaponModel", "PlayerWeapon contract", "TargetDummy"), `docs/validation/weapon-rendering.md`, `docs/GUIDE.md` (Section 5 Weapon line; Section 6 `player_weapon.gd` and `player_controller.gd` rows; Section 13 "Familiar anchors"), and the ROADMAP F6-03 row.

Change:
- **The ship shoots.** Holding `fire` spawns player Projectiles at the `WeaponModel` cadence (oc-a's part 1) from `Muzzle`, and from Power Level 2 also from both Familiar anchors, rotated by the camera yaw.
- **Aim Assist.** Shots aim at the view's center point at the lock's depth and are bent onto the locked `HitVolume` inside each shot's cone.
- **Familiars.** Two dev Familiars orbit the anchors from Power Level 2.
- **Bomb button.** It is tracked from events and fed to `CombatState.update_bomb_input()`: one press spends one Bomb.
- **Controls.** `PlayerController` gains the required `weapon` export, and `set_controls_enabled()` also turns fire off and on, so pause and Defeat stop firing.
- **Dev harness.** Three `TargetDummy`s count hits and flash; keys 1 to 3 set the Power Level.
- **Tests.** None were changed or added (sprint rule). A harness run gave `WEAPONCHECK_OK` headless and windowed.

Why: F6-03 part 2, which closes the ticket.

Action required by Astra:
- **Tuning.** Shot values, cadences and Aim Assist cones are Inspector exports on `PlayerShip/Weapon`, Claude's proposals.
- **Swap pending: D-02.** A final Familiar scene must have a `Node3D` root and no `CollisionObject3D` anywhere (the weapon refuses one that does).
- **HitVolume placement.** Keep each target's `HitVolume` centered on its visible body, because Aim Assist aims at it.
## 2026-09-23 21:05 — Astra (sol) — Combat visuals (D-02) [shared]
State: SCENE_READY
Files: `scenes/combat/visuals/*`, `assets/combat/*`, `assets/ui/menu_theme.tres`, `tools/validate_combat_visuals.gd`, `docs/validation/combat-visuals.md`, `docs/validation/combat-visuals.log`, `docs/validation/combat-visuals.png`, `docs/validation/menus-options-entry.png`, D-02's ticket, and the D-02 ROADMAP row.
Change: Player Projectile is a cyan unit octahedron (6 vertices); hostile Projectile is a coral unit sphere (54 vertices); the dev sphere uses 104 vertices. `familiar.tscn` is a cyan/gold star of radius 0.58 with looping `hover`; `power_pickup_visual.tscn` is a gold crystal of radius 0.78; `shield_pickup_visual.tscn` is a blue orb of radius 0.76; each Pickup loops `float`. `bomb_blast_visual.tscn` uses see-through cyan rings with a unit outer edge and a non-looping/autoplay `blast` clip of 0.4 s that hides them. All scenes have no script or collision. Offline QA passed headless and windowed; the gallery was inspected. The Options slider focus fill is gold, distinct from unfocused teal, and its focused screenshot was recaptured.
Why: Friendly shots, hostile patterns, Familiars and Pickups have distinct silhouettes while the Bomb shows its clear radius without hiding the next pattern.
Action required by Claude: Trunk F6-02 sets `Main/ProjectileRoot`'s `player_projectile_mesh` and `hostile_projectile_mesh` exports to the two resources; trunk F6-03 sets `PlayerShip/Weapon.familiar_scene` to `familiar.tscn`; trunk F7-02 instances `bomb_blast_visual.tscn` inside its Bomb wrapper, scales it by `bomb_radius`, and frees it after `blast`; path F7-03 instances the Power and Shield scenes as `Visual` under its existing `Pickup` roots. Full paths are in `docs/validation/combat-visuals.md`.
## 2026-09-23 20:56 — OpenCode (oc-b) — F8-04 Stage 1 content draft (dev) [shared]
State: dev
Files: `content/stages/stage_01/stage_01.tres`, `s1_01.tres` … `s1_07.tres`, `cp1_a.tres`, `cp1_b.tres`, `docs/engineering/progression-core.md`, `docs/engineering/ROADMAP.md`, `.scratch/progression-core/issues/04-stage-01-content-draft.md`, `docs/HANDOFF_LOG.md`
Change: Transcribed STAGE_DESIGN's Stage 1 table into typed `.tres` Definitions that validate: seven Encounters in route order with the `next_id` chain, completion conditions (S1-03 with `requires_exit`), waves whose markers match `scenes/stages/stage_01.tscn` exactly (17 common enemies plus `Wave1_Boss1`), gates `Gate_S1_02` to `Gate_S1_05`, CP1-A guarding S1-05 and CP1-B guarding S1-07, and rewards of 5 + 5 POWER at `RewardOrigin` plus one SHIELD at `ShieldPickup`. Every file is flagged `metadata/dev = true`. Created once with a headless scratch script that is not committed; no generator may ever overwrite Astra's tuning. No tests were written per the sprint rule.
Why: The Director (F10-01) loads `stage_01.tres`; Astra tunes the values while the approved structure stays.
Action required by Astra: these files are yours. Free to change: the AFTER_PREVIOUS_WAVE delay (draft proposal 1.0 s) and the checkpoint `display_name`s (currently `"CP1-A"`/`"CP1-B"`, matching MenuController's `Último checkpoint · <id>`; Portuguese place names welcome). Must stay: the route order and completion conditions, wave counts and markers, 5 + 5 Power Pickups, one Shield Pickup, the gates and the resume points. Delete `metadata/dev` from a file once you have reviewed it.

## 2026-09-23 20:56 — Claude (path) — F12-01 BossMachine core and boss Definitions
State: CODE_READY
Files:
- New: `scripts/definitions/boss_definition.gd`, `boss_phase_definition.gd`, `attack_definition.gd`, `attack_step_definition.gd`, `scripts/enemies/boss_machine.gd` (and their `.uid`), `docs/engineering/bosses.md`.
- Edited: `docs/engineering/README.md` (one line), `docs/engineering/ROADMAP.md` (the F12-01 row, and the F5-02 row now says ruling 5 is confirmed), `docs/engineering/projectile-field.md` (ruling 5 confirmed), `.scratch/bosses/issues/01-boss-machine-core.md` (Status, Outcome).

Change:
- **Definitions.** `BossDefinition` has 2 or 3 `BossPhaseDefinition`s. Each Phase has health, an `AttackDefinition` and `transition_seconds`, which is capped at 0.75 by `validate()` (D-07 ruling 1). An `AttackDefinition` is a Portuguese name, cycling `AttackStepDefinition`s and `reposition_seconds`. A step is a Pattern, its Anticipation, its height or `follow_player_height`, and `pause_after`.
- **`BossMachine`** runs, in order:
  - the entry window;
  - each step: `step_started`, then its Anticipation, then an aim and altitude sample at fire time, then the Pattern, then the pause;
  - the reposition window, then the steps again.
  - A hit is capped at the Phase's remaining health, and damage is refused only during the transition. A depleted Phase emits `phase_health_changed(i, 0.0)`, `hostile_clear_requested`, then `phase_changed(i + 1, name)`, or `defeated` exactly once for the last Phase.
- **No unit tests,** by the sprint rule. The five scripts pass `--check-only` with warnings as errors.

Why: F12-01 unblocks F12-02 (path) and F12-03 part 1 (oc-a).

Action required by Astra: when writing boss `.tres` content (D-07 Part C, D-06), keep each `transition_seconds` at or below 0.75, and keep every Attack's cycle above zero seconds; `validate()` enforces both. Attack names are Portuguese literals in the Definitions.

## 2026-09-23 20:32 — OpenCode (oc-a) — F6-03 part 1 WeaponModel
State: CODE_READY
Files: `scripts/combat/weapon_model.gd`, `.scratch/weapon-rendering/issues/03-weapon-model-and-player-weapon.md`
Change: Added the Node-free WeaponModel cadence, per-source cooldown, Power Level Familiar count and static Aim Assist direction rules. No tests were added per the sprint rule.
Why: This is F6-03's oc-a part 1; part 2 in trunk owns PlayerWeapon and scene integration.
Action required by Astra: None for part 1; shot values remain tuning proposals.
## 2026-09-23 20:43 — Astra (sol) — Stage 2 boss scenes (D-04) [shared]
State: SCENE_READY
Files: `scenes/enemies/tempest_sentinel.tscn`, `scenes/enemies/storm_guardian.tscn`, `assets/models/bosses/Dragon_Evolved.gltf` and copied atlas plus `.import` files, `tools/validate_boss_scenes.gd`, `docs/validation/boss-scenes.log`, `docs/validation/tempest-sentinel.png`, `docs/validation/storm-guardian.png`, `docs/ENEMY_VISUAL_HANDOFF.md`, `docs/ASSET_CREDITS.md`, `docs/engineering/ROADMAP.md`, and D-04's ticket.
Change: Both scenes have an identity `Enemy` Node3D root with no script; `VisualRoot/Model`, `HitVolume/Collision`, and `Emitters/Main`; no collision object under `VisualRoot`. HitVolume is layer 16, mask 0, and both monitoring flags off. `tempest_sentinel.tscn` uses Goleling at scale `(3.1, 3.1, 3.1)`, hit radius 2.5 at `(0, 6.9, 0)`, and emitter `(0, 7.1, -1.7)`. Its three storm rings spin through independent `VisualRoot/OrnamentPlayer` clip `storm_orbit` (loop/autoplay). `storm_guardian.tscn` uses Dragon_Evolved at scale `(5, 5, 5)`, hit radius 5.0 at `(0, 8.8, 0)`, and emitter `(0, 9.5, -3.5)`. Each model player is `VisualRoot/Model/AnimationPlayer`: idle `Flying_Idle` (loop/autoplay), step `Punch`, Phase gesture `Yes` (for later `phase_clip`), defeat `Death` (non-looping). The headless and windowed QA reported zero failures; S2-04 and S2-07 approach renders were inspected.
Why: F12-06 and F12-07 can integrate the approved Stage 2 boss art without changing encounter geometry or content values.
Action required by Claude: F12-06 attaches `boss_controller.gd` to the Tempest root, sets its exports, and points `stage_02.tscn`'s `actor_scenes[&"tempest_sentinel"]` at it. F12-07 does the same for Storm Guardian and `actor_scenes[&"storm_guardian"]`. Both roots currently have no script.
## 2026-09-23 20:35 — OpenCode (oc-b) — F8-02 EncounterMachine core
State: CODE_READY
Files: `scripts/progression/encounter_machine.gd`, `docs/engineering/progression-core.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md`, `.scratch/progression-core/issues/02-encounter-machine-core.md`, `docs/HANDOFF_LOG.md`
Change: Added the `EncounterMachine` Rules Core (ADR-0001): Encounter lifecycle with route-ordered entry behind activated Checkpoints, Wave scheduling with delays, idempotent completion emitting `gate_opened` → `rewards_requested` → `encounter_completed` → `stage_cleared`, Objective and Checkpoint flags, and `capture`/`restore`/`reset`. Documented its contract in `progression-core.md`. No tests were written per the sprint rule.
Why: F8-02 gives trunk's F10-01 the progression core it drives; the capture/restore slice feeds F8-03's CheckpointStore.
Action required by Astra: none. For trunk (F10-01): call `setup` in the Director's `setup()`, connect the six signals there, tick from `_physics_process` while the tree runs; CP1-B sits inside S1-06, so a Retry from CP1-B restores S1-06 as completed.
## 2026-09-23 23:10 — Claude (plan) — lane.ps1 handles Godot .uid and .import sidecars
State: docs
Files: `tools/lane.ps1`, `docs/engineering/SPRINT.md` ("Git worktrees", Conflicts); the missing `scripts/definitions/enemy_definition.gd.uid`, `scripts/enemies/enemy_model.gd.uid` and `tools/validate_boss_scenes.gd.uid`, committed by the new land step.
Change:
- **The fault.** Godot writes a random-uid sidecar the first time any worktree imports a new script or asset. Landings were blocked by untracked sidecars (oc-a on F6-03 part 1), and the next `sync` in trunk and oc-b would fail on untracked copies of files `dev-01` now tracks.
- **The fix.** `sync` and `land` delete a local sidecar that `dev-01` already tracks, commit one whose source is tracked, and resolve sidecar-only merge conflicts with `dev-01`'s copy. The three uids missing on `dev-01` are now tracked, using oc-a's and sol's copies.

Why: a tooling fault, not a lane's. No escalation was needed.

Action required by Astra: none. Your untracked `enemy_definition.gd.uid` and `enemy_model.gd.uid` are replaced by `dev-01`'s at your next sync. Your boss-model files are untouched.

## 2026-09-23 20:32 — Astra (sol) — Lantern Guardian scene (D-03) [shared]
State: SCENE_READY
Files: `scenes/enemies/lantern_guardian.tscn`, `assets/models/bosses/Ghost.gltf` and copied atlas plus `.import` files, `tools/validate_boss_scenes.gd`, `docs/validation/boss-scenes.log`, `docs/validation/lantern-guardian.png`, `docs/ENEMY_VISUAL_HANDOFF.md`, `docs/ASSET_CREDITS.md`, `docs/engineering/ROADMAP.md`, and D-03's ticket.
Change: `Enemy` is an identity Node3D with no script; `VisualRoot/Model` is the imported Ghost at scale `(2.6, 2.6, 2.6)`. Eight amber `VisualRoot/Lanterns/Lantern1..8` meshes orbit through `VisualRoot/LanternMotion` clip `orbit` (loop/autoplay). `HitVolume/Collision` is a sphere of radius 3.0, centered at `(0, 4.3, 0)` relative to Enemy, with layer 16, mask 0 and both monitoring flags off. `Emitters/Main` is `(0, 5, -1.5)`. The model player is `VisualRoot/Model/AnimationPlayer`: idle `Flying_Idle` (loop/autoplay), step `Punch`, Phase gesture `Yes` (recorded for later `phase_clip`), defeat `Death` (non-looping). The validator passed headless and windowed; the S1-07 dusk screenshot was inspected at 35 units.
Why: F12-03 can use the approved Stage 1 boss art without changing its gameplay model or markers.
Action required by Claude: trunk F12-03 attaches `boss_controller.gd` to Enemy; sets `visual_root`, `hit_volume`, `emitter`, `animation_player`, `idle_clip`, `step_clip`, and `defeat_clip`; and replaces the dev boss in `stage_01.tscn`'s `actor_scenes[&"lantern_guardian"]`. The root currently has no script. A future `phase_clip` may use `Yes`.


## 2026-09-23 20:29 — OpenCode (oc-a) — Generated script UIDs
State: docs
Files: `scripts/combat/pattern_emitter.gd.uid`, `scripts/definitions/pattern_definition.gd.uid`, `scripts/definitions/checkpoint_definition.gd.uid`, `scripts/definitions/encounter_definition.gd.uid`, `scripts/definitions/reward_definition.gd.uid`, `scripts/definitions/stage_definition.gd.uid`, `scripts/definitions/wave_definition.gd.uid`, `tools/validate_audio_selection.gd.uid`, `docs/HANDOFF_LOG.md`
Change: Tracked eight stable Godot script UIDs generated while importing scripts already integrated from F5-04, F8-01 and D-01; no source scripts were changed.
Why: Godot's import created these metadata files and the lane gate requires generated `.uid` files to be tracked beside their scripts.
Action required by the owning lanes: No source changes; these generated UIDs are now tracked.

## 2026-09-23 20:26 — OpenCode (oc-a) — F9-01 EnemyModel core
State: CODE_READY
Files: `scripts/definitions/enemy_definition.gd`, `scripts/enemies/enemy_model.gd`, `docs/engineering/enemies.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md`, `.scratch/enemies/issues/01-enemy-model-core.md`
Change: Added EnemyDefinition validation and the EnemyModel core for bounded movement, exactly-once defeat, Anticipation, sampled-aim PatternEmitter attacks and cooldowns. No tests were added per the sprint rule.
Why: F9-01 provides the reusable common Enemy rules core for F9-02's scene adapter.
Action required by Astra: Tune the proposed DRIFT/HOVER movement values against the authored Spirit and Sentry scenes when they are available.

## 2026-09-23 20:24 — OpenCode (oc-a) — AudioLimiter generated UID
State: docs
Files: `scripts/audio/audio_limiter.gd.uid`, `docs/HANDOFF_LOG.md`
Change: Committed the stable Godot script UID generated during the F13-01 land import.
Why: The lane gate requires generated `.uid` metadata to be tracked beside its script.
Action required by Astra: None.

## 2026-09-23 20:22 — OpenCode (oc-a) — F5-04 PatternDefinition and PatternEmitter
State: CODE_READY
Files: `scripts/definitions/pattern_definition.gd`, `scripts/combat/pattern_emitter.gd`, `docs/engineering/projectile-field.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md`, `.scratch/projectile-field/issues/04-pattern-emitter-core.md`
Change: Added typed pattern definitions and a Node-free emitter for timed hostile ring, fan, spiral, burst and sampled-aim volleys. Documented the public contract and STAGE_DESIGN mapping. No tests were added per the sprint rule.
Why: F5-04 makes shared pattern data and emission reusable by the enemy and boss cores.
Action required by Astra: Pattern field defaults are engineering proposals; authored `.tres` patterns remain with the content tickets.

## 2026-09-23 20:22 — Claude (trunk) — F7-01: hits, Graze and Defeat wired into GameSession [shared]
State: CODE_READY
Files:
- `scripts/session/game_session.gd`; `scripts/player/player_controller.gd` (on Astra's `scenes/player/player_ship.tscn`, which is unchanged).
- New: `tools/validate_combat.gd`, `docs/engineering/damage-pickups.md`, `docs/validation/combat.md`, `combat-hit-flicker.png` and `combat-defeat.png`.
- Docs: `docs/GUIDE.md` (Section 6 `game_session.gd` and `player_controller.gd` rows, Section 7 "Player defeated"), `docs/engineering/README.md`, and the ROADMAP F7-01 row.

Change:
- The ship can be hurt in the real game:
  - Core hits reach `CombatState.take_hit`.
  - A Graze adds 1 Graze and 10 score to `RunState`.
  - Invulnerability reaches the `ProjectileSystem` (no Graze during it), and `VisualRoot` blinks at 12 Hz while the Core stays lit.
  - Excess-Power score reaches `RunState`.
  - Defeat pauses the tree, Active Time, the controls and the core, under the Defeat overlay with `Início da fase`.
- `retry` restarts the stage until F10-03.
- No test changed. Per the sprint rule there is no new test file; `tools/validate_combat.gd` checks the 13 behaviours in the real main scene (`COMBAT_OK` headless and windowed).

Why: F7-01.

Action required by Astra:
- `PlayerShip` has a new Inspector export, `invulnerability_flicker_hz` (12.0, "Feedback" group), yours to tune.
- Keep `CoreVisual` under `DamageCore`, outside `VisualRoot`, or the Core would blink too.
- Defeat has no animation yet.
## 2026-09-23 20:21 — Astra (sol) — D-01 SFX selection and import [shared]
State: SCENE_READY
Files: `assets/audio/sfx/` (16 Ogg files and their `.import` settings), four `assets/licenses/kenney-*.txt` pack licenses, `docs/ASSET_CREDITS.md`, `scenes/ui/credits.tscn`, `docs/validation/audio-selection.md`, `docs/validation/menu-credits.png`, `tools/validate_audio_selection.gd`, and D-01's ticket.
Change: All 17 F13 events have a selected non-looping CC0 Kenney stream and proposed `volume_db` in [audio-selection.md](validation/audio-selection.md). The Credits screen now names the four packs. No music is shipped: the local Touhou-titled files lack documented redistribution permission. Godot import and 17-stream validation exited zero, the menu QA rendered the credit with zero failures, and the 16 copied streams match their originals byte for byte. No F13 event rule values are requested to change.
Why: F13 needs a concrete event-to-stream mapping and distributable credits. The menu credit names only packs used.
Action required by Claude: F13-03 copies the table's paths and `volume_db` values into `Main/Audio`. No music track table applies. Human listening approval is still needed before D-01 can be marked done; this agent cannot hear the selected files, so the ticket is blocked on that perceptual pass.

## 2026-09-23 20:18 — OpenCode (oc-b) — F8-01 progression Definitions
State: CODE_READY
Files: `scripts/definitions/encounter_definition.gd`, `wave_definition.gd`, `reward_definition.gd`, `checkpoint_definition.gd`, `stage_definition.gd`, `docs/engineering/progression-core.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md`, `.scratch/progression-core/issues/01-definition-schemas-and-content-validation.md`
Change: Added typed Resource schemas, local validation and Stage-level route/checkpoint validation, plus the module contract. No tests were written per the sprint rule.
Why: F8-01 provides the authored-data contract required by EncounterMachine and the later Stage 1 content draft.
Action required by Astra: Author content against the exported fields and validation rules in `docs/engineering/progression-core.md`; none for this ticket.
## 2026-09-23 20:17 — OpenCode (oc-a) — F13-01 AudioLimiter core
State: CODE_READY
Files: `scripts/audio/audio_limiter.gd`, `docs/engineering/audio.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md`, `.scratch/audio/issues/01-audio-limiter-core.md`
Change: Added the Node-free AudioLimiter core with event intervals, per-event/global caps, strict-priority oldest-voice stealing, monotonic ids, epsilon-based ticking and clear semantics. No tests were added per the sprint rule.
Why: F13-01 supplies the rules core used by F13-02's playback adapter.
Action required by Astra: None for this ticket; event rule values remain provisional until D-01's listening pass.

## 2026-09-23 20:13 — Astra (sol) — Rulings (D-07 Part B) [shared]
State: docs
Files: `docs/PLANEJAMENTO.md`, `scenes/ui/hud.tscn`, `.scratch/design-sprint/issues/07-shrine-lighting-and-boss-rulings.md`, `docs/engineering/ROADMAP.md`, `docs/HANDOFF_LOG.md`
Change: Five rulings below are recorded in PLANEJAMENTO Sections 4, 7 and 9. `Phase1` and `Phase2` carry authored two-Phase offset metadata, preserving their current three-Phase positions until Hud applies it. The D-07 ticket remains doing for Parts A and C.

| Ruling | Decision | Follow-up |
| --- | --- | --- |
| 1 Phase transition damage | Confirm no damage during the cue, bounded to 0.75 s so it does not pad the encounter. Excess damage cannot skip a Phase. | Path F12-01: keep `transition_seconds` at or below 0.75; no new code behavior requested. Sol D-07 Part C and D-06 apply the bound to values. |
| 2 HUD dimming | Confirm 0.25 alpha for spent Shield/Bomb and 0.30 for finished Phase. | None. |
| 3 two-Phase bar | Change to two equal segments across the full 620 px panel, with 16 px side margins and a 6 px center gap. | Trunk `Hud` follow-up: when `phase_count == 2`, read `two_phase_offset_left/right` metadata from Phase1 and Phase2 and apply those offsets; restore their authored offsets when three Phases show. No scheduled ticket owns this yet. |
| 4 ship yaw | Confirm the ship model does not yaw with the camera; the weapon and Familiars aim by camera yaw and visual banking stays cosmetic. | None. |
| 5 Graze under Invulnerability | Confirm strict spending: contact while invulnerable consumes that Projectile's one Graze opportunity. | None. |

Why: The existing boss cue, scoring and ship orientation remain readable and consistent with the source design; the two-Phase HUD capture showed unused panel width.
Action required by Claude: path observes the transition cap in F12-01; trunk applies the two-Phase HUD layout in a follow-up. Parts A and C remain with sol after F12-03.

## 2026-09-23 20:10 — Claude (trunk) — F6-02: ProjectileSystem on ProjectileRoot [shared]
State: CODE_READY
Files:
- New: `scripts/combat/projectile_system.gd`, `scenes/dev/dev_spray.gd`, `scenes/dev/projectile_player_mesh.tres` and `projectile_hostile_mesh.tres`, `docs/engineering/weapon-rendering.md`, `docs/engineering/spikes/projectile-rendering.md`, `docs/validation/weapon-rendering.md` and `weapon-rendering-spray.png`.
- Edited: `scenes/main.tscn` (script and meshes on `ProjectileRoot`; `Main.projectile_system`), `scripts/session/game_session.gd`, `scenes/dev/arena_harness.gd` and `.tscn`, `tests/scene/test_game_session_flow.gd` (the Return to Menu case, adjusted), `docs/GUIDE.md` (Section 5 `ProjectileRoot` line, Section 6 `game_session.gd` and `projectile_system.gd` rows), `docs/engineering/menus-session.md`, `docs/engineering/project.md`, `docs/engineering/README.md`, and the ROADMAP F6-02 row.

Change:
- The F5 field now runs in the game:
  - It ticks after the actors, with physics priority 100.
  - A layer-1, bodies-only ray kills Projectiles on scenery.
  - The ship's `DamageCore` and `GrazeVolume` spheres drive hits and Grazes (`player_hit` and `grazed` signals; nothing is fed to `CombatState` yet, that is F7-01).
  - Registered targets get `on_damage(damage)` callbacks.
  - Each faction is drawn by one `MultiMeshInstance3D`, capacity 2048.
- `GameSession.projectile_root` is renamed and retyped to `projectile_system: ProjectileSystem`. The Session sets it up on every stage load and calls `clear_all()` on unload, instead of freeing `ProjectileRoot`'s children.
- The arena harness sprays rings of hostile dev bullets.
- **Test adjusted, as the sprint rule allows:** `test_game_session_flow.gd::test_return_to_menu_unloads_everything_and_shows_the_main_menu` now spawns a Projectile and expects `count() == 0`, because `ProjectileRoot`'s children are the renderers.
- Measured with other lanes running: 3000 Projectiles at 1118 FPS, a 3.84 ms system physics step at 1280 × 720. No mitigation is needed.

Why: F6-02, with F6-01 folded in.

Action required by Astra:
- **Swap pending: D-02.** Deliver unit-radius Projectile meshes, one material per faction. Trunk points `Main/ProjectileRoot`'s two mesh exports at them.
- **Keep the ship's spheres as they are.** `DamageCore` and `GrazeVolume` stay `SphereShape3D` with monitoring off; their radii are the hit and Graze sizes.
- **Keep barriers on layer 1.** Closed Gate barriers and solid scenery stay `StaticBody3D` on layer 1.
- **D-07 Part B, a ruling to consider:** a bullet on a head-on path grazes a few ticks before it hits the Core, so every hit also scores a Graze. Should a hit cancel its own Graze?

## 2026-09-23 20:30 — Claude (path) — F5-03 ProjectileField clears and hit spheres
State: CODE_READY
Files:
- Edited: `scripts/combat/projectile_field.gd`, `docs/engineering/projectile-field.md`, `docs/engineering/README.md` (one line), `docs/engineering/ROADMAP.md` (F5-03 row), `.scratch/projectile-field/issues/03-bomb-phase-clears-and-hit-spheres.md` (Status, Outcome).

Change:
- `clear_hostile_in_radius(center, radius) -> int` is the Bomb; `clear_hostile_all() -> int` covers Gates, Checkpoints and boss Phases. Both remove HOSTILE Projectiles only, award and emit nothing, and from a listener take back a removed Projectile's pending `grazed`.
- `register_target(target_id, center, radius)` adds a hit sphere for the next tick only, keyed by `get_instance_id()`. `targets_in_radius(center, radius) -> PackedInt64Array` lists the registered spheres a blast reaches.
- PLAYER Projectiles are swept against the registered spheres and hit only the first target along their segment, reported as `enemy_hit(target_id, projectile_id, damage)` after the pass. The obstacle check still comes first.
- **No unit tests,** by the sprint rule. A reviewer found no defects.
- The projectile-field core chain (F5-01 to F5-03) is complete: F6-02 can wrap it, F7-01 and F7-02 can connect its signals and clears, and F9-02 can register spheres.

Why: F5-03 is the last Projectile Field core ticket before F6-02, the trunk critical path.

Action required by Astra: none (code only). Each enemy's hit sphere comes from its `HitVolume` shape, read by its adapter.

## 2026-09-23 22:50 — Claude (trunk) — F4-03: HUD boss panel, attack cue and threat API [shared]
State: CODE_READY
Files:
- `scripts/ui/hud.gd` (on the root of Astra's `scenes/ui/hud.tscn`, which is unchanged).
- New `scenes/dev/hud_harness.tscn` and `.gd`; new `docs/validation/combat-hud-boss-3.png` and `combat-hud-boss-2.png`.
- Docs: `docs/engineering/combat-hud.md`, `docs/validation/combat-hud.md`, `docs/GUIDE.md` Section 6 `hud.gd` row and Section 7 "Boss phase changed" row, ROADMAP F4-03 row.

Change:
- `Hud` gains `show_boss(display_name, phase_count)` (2 or 3 bars, else clamped), `set_phase_health(phase_index, ratio)` (dimmed at 0), `show_attack_cue(text, seconds)`, `hide_boss()`, and `show_threat(side, seconds)` (-1 left, +1 right, each on its own timer).
- Cue and threat timers stand still while the tree is paused. `unbind()` clears all of it, so a stage unload leaves nothing on screen.
- F10-01 (threats) and F12-03 (bosses) can now route to the HUD with no further HUD work.
- No new test file: the user's no-new-tests rule for the sprint (relayed 2026-09-23) replaced the ticket's tests with the self-checking harness run.

Why: F4-03.

Action required by Astra (D-07 Part B, optional):
- With two Phases, `Phase3` is hidden and the right third of `BossStatus` stays empty (`combat-hud-boss-2.png`). If that reads badly, author a two-Phase arrangement and say which node positions the code should switch between.
- Review `completed_phase_modulate` (alpha 0.3, an export on the HUD root). A spent Phase currently reads as an empty track.
- `BossStatus`, `BossName`, `Phase1`..`Phase3`, `AttackName`, `ThreatLeft` and `ThreatRight` are now load-bearing paths.
## 2026-09-23 20:05 — Claude (path) — F5-02 ProjectileField Core sweep and Graze rules
State: CODE_READY
Files:
- Edited: `scripts/combat/projectile_field.gd`, `docs/engineering/projectile-field.md`, `docs/engineering/README.md` (one line), `docs/engineering/ROADMAP.md` (F5-02 row), `.scratch/projectile-field/issues/02-core-hit-sweep-and-graze-rules.md` (Status, Outcome).

Change:
- `set_player(previous_center, center, core_radius, graze_radius, invulnerable)` and `clear_player()`, with signals `player_hit(projectile_id, damage)` and `grazed(projectile_id)`, buffered during the pass and emitted after it in slot order.
- The HOSTILE sweep uses the relative segment's closest distance. A hit removes the Projectile and never grazes. Graze happens at most once per life. Invulnerability passes Core contacts through and spends Graze on any contact (the strict reading). The first hit of a tick makes the rest of that tick invulnerable.
- `spawn` now also asserts a positive damage, because `CombatState.take_hit` asserts it.
- **No unit tests,** by the user's no-new-tests rule, which arrived mid-ticket. The ticket's "Tests required" list is not delivered. The existing 12 F5-01 tests pass against the extended core, and a reviewer found no defects.
- **Ruling 5 pending:** D-07 Part B had not landed. If Astra chooses the lenient reading, the Graze spend moves into the `grazed` branch of `tick`.

Why: F5-02 unblocks F5-03, and then F6-02 and F7-01, which wire these signals.

Action required by Astra: none (code only). D-07 Part B ruling 5 decides strict or lenient Graze under Invulnerability.
## 2026-09-23 22:30 — Claude (plan) — No new tests, ever: the user's rule for the sprint [shared]
State: docs
Files: `docs/engineering/SPRINT.md` ("Product decisions", workflow shapes, escalation, overflow, Claude guard, every kickoff prompt), `docs/engineering/CONVENTIONS.md` ("Tests", Definition of Done), `docs/engineering/ROADMAP.md` (F10-04, F11-03, Risk), `tools/lane.ps1` (a boot smoke and a wider error scan), `.scratch/stage-director/issues/04-stage-01-contract-smoke-test.md` (cut), `.scratch/run-flow/issues/03-active-and-clear-time-verification.md` (note), `CLAUDE.md`, `AGENTS.md` (shared).
Change:
- **The rule.** Nobody writes unit or scene tests or does TDD, in any lane. Every ticket's "Tests required" section and tdd kickoff are void.
- **The gate.** `tools/lane.ps1 land` still runs the existing suite (no token cost), and now also boots the main scene headless for 300 frames. A red run, `SCRIPT ERROR`, parse error or failed script load stops a landing, and so does any `ERROR:` line during the boot. Adapters are also checked by running the game.
- **Workflow shapes.** The 3-agent shape is now implementer, verifier (runs the game) and reviewer. Cores use implementer and reviewer.
- **Tickets.** F10-04, a test-only ticket, is cut; F11-03 keeps only its manual protocol.
- **Old tests.** If an old test fails only because a ticket intentionally changed that behavior, delete or minimally adjust that test and name it in the handoff.
- **Running lanes.** Trunk and path were told directly and have switched.

Why: The user's decision, to spend every lane's quota on the game itself.

Action required by Astra: none beyond the new sol kickoff in SPRINT.md. Your F tickets (F12-05 to F12-07) are code without tests, checked by `land` and a game run.

## 2026-09-23 22:10 — Claude (trunk) — F4-02: HUD bound to CombatState and Targeting [shared]
State: CODE_READY
Files:
- `scripts/ui/hud.gd`: Astra's placeholder replaced by `class_name Hud extends Control`, attached to the root of `scenes/ui/hud.tscn` (the scene itself is unchanged).
- `scripts/ui/interface.gd` (`get_hud() -> Hud`; a non-`Hud` root is refused), `scripts/session/game_session.gd` (one `CombatState`, `get_combat_state()`, start, pause, HUD bind and unbind).
- `scenes/dev/arena_harness.gd` and `.tscn`: new `HudLayer/HUD`, bound to a harness-owned `CombatState`.
- New `tests/scene/test_hud_contract.gd`; four cases in `tests/scene/test_game_session_flow.gd`.
- Docs: `docs/engineering/combat-hud.md` ("Hud contract"), new `docs/validation/combat-hud.md` and `combat-hud-marker.png`, `docs/GUIDE.md` Section 6 `hud.gd` row and Section 7 "Combat state changed" row, ROADMAP F4-02 row.

Change:
- The HUD renders the player panel from the Session's `CombatState` (Health bar and `"90%"`, Shield and Bomb icons lit or dim, Power Level, Power Progress) and centers `TargetMarker` on the locked target's projected `HitVolume`, hidden with no lock, a freed target or a target behind the camera. It calls no `CombatState` method but the getters.
- A Run from the main menu now shows real entry values: 100 %, Shield, two Bombs, Power Level 1, or 2 for a Direct Stage 2.

Why: F4-02. The HUD observes and never mutates (ENGINEERING_BRIEF 4.I); F4-03, F6-03 and F7 build on this binding.

Action required by Astra:
- None to integrate. Every GUIDE Section 15 path under `PlayerStatus`, and `TargetMarker`, is now load-bearing: renaming one needs a matching code change.
- D-07 Part B, optional: review `dim_modulate` (alpha 0.25, an export on the HUD root) and say if Power Level 3 should read differently than a full `PowerProgress` bar.
## 2026-09-23 19:40 — Claude (path) — F5-01 ProjectileField spawn, move and cull
State: CODE_READY
Files:
- New: `scripts/combat/projectile_spawn.gd`, `scripts/combat/projectile_field.gd` (and their `.uid`), `tests/unit/combat/test_projectile_field.gd`, `docs/engineering/projectile-field.md`.
- Edited: `docs/engineering/README.md` (one line), `docs/engineering/ROADMAP.md` (F5-01 row), `.scratch/projectile-field/issues/01-field-core-spawn-move-cull.md` (Status, Outcome).

Change:
- `ProjectileSpawn` is the request value; `ProjectileField` holds every Projectile in packed arrays and ticks them: lifetime, obstacle query, move, bounds, in ascending slot order.
- A full field refuses the new request and counts it; nothing is evicted.
- Ids are 64-bit ints (slot in the low 16 bits, a spawn serial above) and are never reused, even across `clear_all` and a new `setup`. Keep them in `int` or `PackedInt64Array`.
- The events rule for F5-02 and F5-03 is in the class comment and the module doc; no signal exists yet.

Why: F5-01 is the base of the projectile chain (F5-02, F5-03, F5-04, F6-02).

Action required by Astra: none (code only).

## 2026-09-23 21:00 — Claude (trunk) — Sprint re-routed: six lanes, per-ticket models [shared]
State: PLANNED
Files:
- `docs/engineering/SPRINT.md`, rewritten: lanes, queues with workflow shapes and models, model budgets, escalation, overflow, Claude usage, kickoff prompts, checkpoints.
- The `Lane:` and new `Model:` header lines of all 48 open tickets, plus split notes on F6-03, F9-03, F12-03, F3-04 and F14-02, and pass/order notes on D-06 and D-07.
- `docs/engineering/ROADMAP.md` (Lane column, Risk), `docs/engineering/CONVENTIONS.md`, `CLAUDE.md`, and `AGENTS.md` (shared).

Change:
- **Why the re-route.** OpenCode quotas are per model and per 5 hours, and GLM-5.3 allows only 220 requests, which cannot carry two lanes. The sprint is re-routed from a sizing of all 48 open tickets (about 6,230 mid-tier requests) and the public model evidence.
- **Lanes:**
  - `trunk` (Opus) keeps every Session and scene edit.
  - The new `path` lane (a second Opus session, stopped in its gaps) takes the critical-path cores and actor adapters: F5-01 to F5-03, F12-01, F9-02, F7-03, F12-02, F11-03.
  - `oc-a` and `oc-b` (OpenCode) replace `glm-a` and `glm-b`. Each ticket names its model, and the user switches it by hand: GPT 5.6 Luna as the workhorse; GLM-5.3 for F8-02, F3-02 and F3-03, each in a fresh window; Qwen3.8 Max for F13-02 and the Seal adapter; DeepSeek V4.1 Flash for content; Kimi K3 as the escalation reserve.
  - `rescue` (Opus, on demand) takes over stuck tickets.
  - `terra` (Codex Terra) and OpenRouter (GLM-5.2 or DeepSeek) are overflow with explicit switch rules.
- **Ticket moves.** F4-03 moved from sol to trunk, and F9-02 and F12-02 from sol to path.

Why: The critical path runs on Opus without hand-offs, the hardest OpenCode tickets get the strongest models within their quotas, and nothing waits on a spent quota.

Action required by Astra:
- Your queue is shorter and starts with D-07 Part B (the rulings), then D-01, D-03, D-04, D-02, D-06 pass 1, D-05, F12-05, D-06 pass 2, F12-06, F12-07, D-07 Parts A and C, and D-06 pass 3.
- Run `tools/lane.ps1 sync` first: your worktree is behind.
- D-05 has a timing rule (SPRINT.md "Shared files").
- `AGENTS.md` step 0 lists the new lanes.

## 2026-09-23 19:30 — Claude — Four-lane sprint: F3, F13 and Stage 2 reinstated; worktrees per lane [shared]
State: PLANNED
Files:
- New: `docs/engineering/SPRINT.md`; `tools/lane.ps1`; `.scratch/settings/{spec.md,issues/01..04}`; `.scratch/audio/{spec.md,issues/01..03}`; `.scratch/bosses/issues/04..07`; `.scratch/design-sprint/{spec.md,issues/01..07}`.
- Deleted: the F12-04 cut stub.
- Edited:
  - a `Lane:` line on every open ticket, and sprint notes in F6-02, F6-03, F7-02, F7-03, F12-01 to F12-03, F11-02, F11-03, F14-01 and F14-02;
  - F6-01 marked `cut` (folded into F6-02);
  - `.scratch/bosses/spec.md`, `.scratch/enemies/{spec.md,issues/03}`, and the settings, audio and bosses `00-plan.md`;
  - `docs/engineering/ROADMAP.md` (Lane column, new rows, Risk, "Requests to Astra") and `docs/engineering/CONVENTIONS.md` ("Git", "Sessions", "Shared-file protocol");
  - `.gitattributes` (union merge for this log and the engineering README), `CLAUDE.md`, and `AGENTS.md` (shared).

Change:
- **Scope.** The product decision reverses today's cuts in reduced but real form: Settings (F3-01 to F3-04), Audio (F13-01 to F13-03), and Stage 2 gameplay with its miniboss and final boss (F12-04 to F12-07, with F9-03 Seals).
- **Lanes.** The work runs in four lanes, each in its own git worktree on its own `lane/<name>` branch: `trunk` (Claude, Opus), `sol` (Astra, on GPT Sol), `glm-a` and `glm-b` (OpenCode with GLM 5.3).
  - Each lane lands ticket by ticket with `tools/lane.ps1 land` onto the integration branch that the primary tree has checked out (`dev-01`). The primary tree stays clean, and nobody works in it.
- **Your open requests to Astra** became seven design tickets, D-01 to D-07, in lane `sol`, each naming its consumer ticket and its exact node and clip contract. The lane also takes the adapter tickets F4-03, F9-02, F12-02 and F12-05 to F12-07.
- **Ownership during the sprint.** A ticket's Files section is its edit boundary, whoever runs it. SPRINT.md "Shared files" says which lane may touch the session, main, player and stage scenes.

Why: Two of the cuts each broke an assignment requirement (sound effects; a stage of at least five minutes, which is Stage 2). Four tools in parallel make the reinstated scope reachable before 2026-09-24.

Action required by Astra:
1. Open Codex in `C:\Users\Braia\Documents\touhou-3d-sol` (run `tools/lane.ps1 setup sol` if it is missing).
2. Paste the sol kickoff prompt from `docs/engineering/SPRINT.md`.
3. Work the sol queue: D-01, D-02, then D-07 Part B (the rulings, early), then F4-03, and onward.
4. Never edit `scenes/stages/stage_01.tscn` before F12-03 has landed.
5. `AGENTS.md` gained step 0 (the sprint); nothing else in it changed.

## 2026-09-23 16:00 — Claude — F4 to F14 tickets written; F3, F13 and F12-04 cut pending the user
State: PLANNED
Files: `.scratch/{combat-hud,projectile-field,weapon-rendering,damage-pickups,progression-core,enemies,stage-director,run-flow,bosses,delivery}/spec.md` (new) and their `issues/NN-*.md` tickets (31 `todo` plus the F12-04 `cut` stub, new); every F4 to F14 `issues/00-plan.md` (`Status: done` and an Outcome); `.scratch/settings/issues/00-plan.md` and `.scratch/audio/issues/00-plan.md` (`Status: cut`); `docs/engineering/ROADMAP.md` (the ticket rows, a `cut` status, "Order to 2026-09-24", Risk, "Requests to Astra"). No code, scene, content or GUIDE change.
Change: The per-feature planning sessions were collapsed into one pass. Each ticket names its exact files (Creates, Edits, Serialized at session end, Must not touch, Conflicts with) and carries a parallel-safe flag. Each `spec.md` lists under "Cross-feature contracts" the class, method and signal names the later features share. Those names were written against the real `CombatState` from F4-01. F3 Settings, F13 Audio and F12-04 (the Tempest Sentinel, the Storm Guardian and Stage 2 gameplay) are cut from the 2026-09-24 delivery until the user decides. Two of the cuts each break an assignment requirement: sound effects (F13), and the five-minute stage (planned for Stage 2, so F12-04). See the roadmap Risk section.
Why: The deadline is tomorrow; the Stage 1 loop comes first.
Action required by Astra: see the updated "Requests to Astra" rows F4-02, F6, F7, F8-04, F9, F10 and F12. The new requests are the tuning of Claude's proposed weapon, pattern, enemy and HUD values; Portuguese names for CP1-A and CP1-B; a Lantern Guardian scene with its clip names and the shrine-lighting clip; and a ruling on whether a boss takes damage during a Phase transition. The Stage 1 content, enemy and boss `.tres` files will be drafted by Claude and marked `dev` when those tickets run. Keep the load-bearing names in `stage_01.tscn` listed in the F10 row.

## 2026-09-23 15:10 — Claude — CombatState core (F4-01)
State: CODE_READY
Files: `scripts/combat/combat_state.gd` and `tests/unit/combat/test_combat_state.gd` (new), `docs/engineering/combat-hud.md` (new), `docs/engineering/README.md`, `docs/engineering/ROADMAP.md` (a new F4-01 row; F4-00 stays `todo` for `spec.md`, 02 and 03), `.scratch/combat-hud/issues/01-combat-state-core.md` (new, written from the 00-plan bullet).
Change: `CombatState` is the Node-free Rules Core for the player's combat resources in one life. It covers Health 0 to 100 (int percent, 10 per common hit) and a one-charge Shield that absorbs a hit of any size. Any accepted hit starts 1 s of Invulnerability, which rejects every later hit, including a second hit in the same tick. The player has two Bombs, spent only on the rising edge of the button: one press, one Bomb, and 2 s of Invulnerability. A press that began before a pause, a `start()` or a `restore()` never fires, so B pressed on the Pause menu never bombs on resume. Power Level runs 1 to 3 with 5 Power Pickups per level; at level 3 each extra pickup emits `score_awarded(50)`. A Shield Pickup is refused while shielded, so it stays in the world. `defeated` fires once per life. `refill()` is for a Checkpoint's first activation; `capture()` and `restore()` save the five resource values, and Retry clears defeat and Invulnerability. Hits, Bombs, pickups, refills and ticks are ignored while paused or defeated. Signals fire only on change. `take_hit` returns `REJECTED`, `ABSORBED`, `DAMAGED` or `DEFEATED`, so the Projectile Field can put a hit ahead of Graze. No scene, attached script or Astra-owned file changed. Verified: 26 tests (every ENGINEERING_BRIEF 4.C invariant has a named test), suite green at 198, no script errors. At the user's request, the core and the tests were written in parallel from one fixed API, and there was no mutation pass.
Why: F4-01. The HUD binding (F4-02), the damage, bomb and pickup flow (F7) and the Checkpoint Snapshot (F8-03) all read or drive these resources.
Action required by Astra: none. The tuning constants are PLANEJAMENTO Section 4's initial values; the F7 adapter will expose them if you want to tune them. The design readings are listed in `combat-hud.md` Open issues.

## 2026-09-23 14:12 — Claude — GameSession start, pause, restart, quit (F2-04) [shared]
State: CODE_READY
Files: `scripts/session/game_session.gd`, `scenes/main.tscn` (Claude's: new `player_scene`, `stage_scenes`, `stage_flight_bounds` on `Main`), `tests/scene/test_game_session_flow.gd` (new), `tools/validate_menus.gd`, `docs/validation/menus.md`, `docs/validation/menus-flight.png` (new) and `menus-pause-return.png` (re-captured), `docs/engineering/menus-session.md`, `project.md`, `README.md`, `ROADMAP.md` (the F2-04 row and a new "Requests to Astra" row), `.scratch/menus-session/issues/04-game-session-start-pause-quit.md`. Shared: `docs/GUIDE.md` (status line, Sections 5, 6, 7, 10, 14). None of your scenes changed: `stage_01.tscn`, `stage_02.tscn` and `player_ship.tscn` are only referenced from `Main`.
Change: The game plays from the main menu. Iniciar starts a Campaign on Stage 1 and a Stage Select card a Direct Stage 1 or 2: `GameSession` instances the stage under `WorldRoot`, spawns `PlayerShip` beside it at the stage's `PlayerStart`, keeps it inside the stage's Flight Volume (Stage 2's from your `FlightBounds/Limits` metadata, Stage 1's from `Main`: X -45..45, Y 0..75, Z -570..35, the inner faces of its walls), starts the Run and shows the HUD. Escape or Start over the HUD pauses the tree, Active Time and the ship's controls under Pause, which shows the Run's score and Graze; Continuar, Escape, B or Start resume; Opções from Pause keeps the game paused, and Start is ignored under it; Reiniciar fase reloads the stage and a new ship from the stage entry; Voltar ao menu unloads the stage, the ship and every projectile and ends the Run; Sair quits. A stage with no scene, no `PlayerStart` or no Flight Volume is refused with an error and the menu stays. Stage completion and victory return to the menu until F11 builds Results. Verified: 172 tests green (20 new flow tests), sixteen mutants each caught by assertion, `tools/validate_menus.gd` now playing the flow through the real Session on keyboard and gamepad events (`MENUS_OK` headless and windowed: the ship flies 11.80 units in one second and holds still while paused with the input held), a clean windowed boot of the real main scene, and Sair exiting with code 0. All input was synthetic; no pad was connected.
Why: F2-04, the last ticket of Feature F2. The menus requested actions nobody carried out, and nothing put the ship in a stage.
Action required by Astra: three things. (1) Every stage root must keep a `PlayerStart` `Node3D` and stay at the origin; a stage without `PlayerStart` is refused. (2) Optional: give Stage 1 the same `FlightBounds/Limits` marker Stage 2 has (`min` (-45, 0, -570), `max` (45, 75, 35)), so its scene is the single source of its flight interior; tell Claude and `Main`'s entry goes. (3) When a stage is added or its flight interior changes, send Claude the id and bounds: `Main` lists the stage scenes. Also note Stage 1 flies only up to the closed `Gate_S1_02` until F10 opens Gates. The physical keyboard and pad pass on the menus and the flight is still owed.

## 2026-09-23 13:30 — Claude — Interface and MenuController wiring (F2-02) [shared]
State: CODE_READY
Files: `scripts/ui/menu_controller.gd` (was the placeholder your eight menu roots attach), `scripts/ui/interface.gd` (new), `scripts/ui/screen_router.gd`, `scripts/session/game_session.gd`, `scenes/main.tscn`, `project.godot` (`[input]`: `ui_accept`, `ui_cancel`), `tests/scene/test_menu_registry_contract.gd` and `tests/scene/test_interface_contract.gd` (new), `tests/unit/ui/test_screen_router.gd`, `tests/unit/project/test_input_map.gd`, `tools/validate_menus.gd` (new), `docs/validation/menus.md` and five `menus-*.png` (new), `docs/engineering/menus-session.md`, `project.md`, `README.md`, `CONVENTIONS.md` ("Input actions"), `ROADMAP.md` (the F2-02 row and a new "Requests to Astra" row), `.scratch/menus-session/issues/02-interface-and-menu-controller.md`, `.scratch/menus-session/issues/04-game-session-start-pause-quit.md` (one added note). Shared: `docs/GUIDE.md` (status line, Sections 5, 6, 10, 14). None of your scenes, the theme or the HUD changed.
Change: The menus work. `MenuController` is now `class_name MenuController extends Control`, on the script your eight roots already attach: it knows its screen from the root name, connects every Section 14 button by path to `action_requested(action, payload)` (`start_campaign`, `open_stage_select`, `open_options`, `quit`, `start_direct_stage` with `{"stage": &"stage_01"}` or `&"stage_02"`, `back`, `open_controls`, `restore_defaults`, `open_credits`, `resume`, `restart_stage`, `return_to_menu`, `retry`, `continue_campaign`, `replay_stage`), focuses the first focusable control on entry and the remembered one on return, writes Pause's `Layout/Score`, Defeat's `Layout/RetryLocation` (`Início da fase` or `Último checkpoint · <id>`) and Results' mode (Continue, Replay or neither, `Jornada concluída` on final victory, a focus loop without the hidden buttons), and hides `Layout/NavigationHint` while a gamepad is in use. `Interface` on `Main/Interface` instances the eight menus and the HUD once (HUD first, so it draws under every menu), drives them through `ScreenRouter`, resolves Back — Back buttons and `ui_cancel` return to the caller, request `resume` on Pause, request `back_refused` on the main menu, Defeat and Results, and are left to the Session over gameplay — and passes every other action up. `GameSession` now opens the main menu with `interface.show_home(MAIN_MENU)`. Two defects found by a scripted keyboard and gamepad pass, fixed here: Godot 4.7 binds `ui_accept` and `ui_cancel` to keys only, so gamepad A and B did nothing in menus (A and B are now added in `project.godot`), and `ScreenRouter` handed a screen's old focus to a fresh entry of the same screen (it now emits hides before its stack changes). Verified: 153 tests green (15 + 11 new scene tests, one router regression, one input-map test), thirteen mutants each caught by assertion, and `tools/validate_menus.gd` printing `MENUS_OK` headless and windowed: arrows and the D-pad reach every control on every screen, and the keyboard and gamepad walks return to each caller with its focus. All input was synthetic; no pad was connected.
Why: F2-02. The menu scenes had no behavior; F2-04's Session needs action requests and a screen stack to start, pause and end a Run.
Action required by Astra: three things. (1) The Section 14 button paths, the root names and `Layout/Score`, `Layout/RetryLocation`, `Layout/Heading`, `Layout/NavigationHint` are now load-bearing: announce a rename here first, since `MenuController` needs the same change; tree order sets each screen's initial focus. (2) A focused slider is barely visible: Godot 4.7's `Slider` never draws `HSlider/styles/focus`, and `grabber_area_highlight` is the same `SliderFill` as `grabber_area`, so only a slightly brighter grabber marks it (`docs/validation/menus-options-entry.png`, and Options opens on the Geral slider). Please give `menu_theme.tres` a gold `HSlider/icons/grabber_highlight` or a distinct `grabber_area_highlight`. (3) Optional: Results with neither Continue nor Replay leaves an empty slot above Menu principal (`menus-results-final.png`). Also note gamepad B is now Back in menus and still `bomb` in play. The physical keyboard and pad pass on the menus is still owed.

## 2026-09-22 23:58 — Claude — RunState core (F2-03)
State: CODE_READY
Files: `scripts/session/run_state.gd` and `tests/unit/session/test_run_state.gd` (new), `docs/engineering/menus-session.md` (RunState sections), `docs/engineering/README.md`, `docs/engineering/ROADMAP.md` (the F2-03 row), `.scratch/menus-session/issues/03-run-state-core.md`, `.scratch/menus-session/issues/04-game-session-start-pause-quit.md` (one added note).
Change: `RunState` is the Node-free Rules Core that owns the Run. `start(mode, first_stage)` plays `[&"stage_01", &"stage_02"]` from `first_stage` in a Campaign and `[first_stage]` in a Direct Stage; `begin_attempt()` counts the Attempt, discards what the last one had not committed and unpauses; `tick_active(delta)` adds Active Time only in a stage and unpaused; `add_score`, `add_graze` and `note_bomb_used` feed the current Attempt; `commit_checkpoint()` folds it into the committed values, `rollback_attempt()` (Retry) returns to them, `restart_stage()` (Restart) returns to the stage-entry values; `clear_time()` is committed plus current Active Time; `complete_stage()`, `advance(power_level)` and `end_run(victory)` drive `stage_completed(result)`, `stage_started(stage)` and `run_ended(victory)`, each once per transition; `paused_changed` fires only on a change. Direct Stage 2 starts at Power Level 2, Stage 1 at 1, Campaign Stage 2 at the level passed to `advance()`. Score is carried into Campaign Stage 2; Clear Time, Graze and bombs used are per stage. Once a stage completes, nothing changes its result. `capture()` / `restore()` hold the committed values, the entry values and the stage position as a copied Dictionary, in both directions. No scene, no attached script and no Astra-owned file changed. Verified: 19 tests written test-first, suite green at 125, and twelve mutations each caught by a named assertion (none only by a runtime error, which the runner would have reported as PASS).
Why: F2-03. F2-04's `GameSession` needs the Run's lifecycle and time accounting in a testable core, and F8-03 and F10 build the Snapshot and Retry flow on its capture and rollback rules.
Action required by Astra: none. Two design readings are recorded in `menus-session.md` Open issues for review: Graze in Results is per stage, not a Run total, and replaying an isolated stage starts a new Run.

## 2026-09-22 23:53 — Claude — ScreenRouter core (F2-01)
State: CODE_READY
Files: `scripts/ui/screen_router.gd` and `tests/unit/ui/test_screen_router.gd` (new), `docs/engineering/menus-session.md` (new), `docs/engineering/README.md`, `docs/engineering/ROADMAP.md` (the F2-01 row), `.scratch/menus-session/issues/01-screen-router-core.md`, `.scratch/menus-session/issues/02-interface-and-menu-controller.md` (one added note).
Change: `ScreenRouter` is a Node-free Rules Core for menu navigation. Everything shown is one stack: a full screen (main menu, stage select, options, controls, credits, HUD) covers everything below it, an overlay (pause, defeat, results) leaves it visible. `home(id)` starts a new stack, `replace(id, params)` opens a full screen and `push(id, params)` an overlay over the current one, and `back()` removes the top entry: Options from the main menu returns to it, Options from Pause returns to Pause with the HUD under it and `has_overlay(PAUSE)` true throughout, Credits from Results returns to Results with its original params. `back()` returns false on a single screen and on Defeat or Results, which GUIDE Section 14 gives no Back row. Each transition emits `screen_hidden` for every screen that stops being visible, then `screen_shown(id, params)` for every one that becomes visible. Focus memory lives on the stack entry, so it survives while a screen waits for Back and is forgotten when it leaves: a Pause reopened after Resume starts on its initial button, not on "End run". No scene, no attached script and no Astra-owned file changed. Verified: 13 new tests written test-first, suite green, and five mutations each caught by a named test.
Why: F2-01, the first ticket of Feature F2. F2-02's `Interface` needs the navigation rules in a testable core so it only has to show, hide and focus.
Action required by Astra: none. The screen ids are code; which scene root maps to which id arrives with `MenuController` in F2-02.

## 2026-09-22 23:36 — Astra — F1 design decisions and generator retirement; flight tuning blocked [shared]
State: docs
Files: `docs/engineering/player-flight.md` (Open issues and retired-generator notice), `docs/engineering/ROADMAP.md`, `docs/GUIDE.md` Section 13, `.scratch/player-flight/issues/05-astra-design-pass.md`, `docs/HANDOFF_LOG.md`, `docs/validation/player-flight-design-tests.log`, both `assets/models/enemies/{Hywirl,Goleling}_Atlas_Monsters.png.import`, `tools/build_scene_handoff.py` moved unchanged to `docs/archive/build_scene_handoff.py.txt`, `docs/archive/README.md`.
Change: Recorded the requested F1 design decisions. (a) Accept the rectangular volume and open corners in the dev harness only; production stage boundaries still require presentation. (b) Choose proximity-driven ship transparency; a hull filling the view at 0.75 units is unacceptable for bullet readability. (c) Do not accept the measured 6.5-unit gate snap as final production presentation; keep collision-safe behavior until Claude can improve and revalidate the transition. (d) Keep left-to-right cycling with wrap as the design rule, with feel acceptance still pending. Solid stage trunks/substantial branches should occlude acquisition and Aim Assist using fitted layer-1 collision; this also deliberately blocks ship/camera, while decorative foliage should not. No collision was authored in this pass. Reaffirmed the Node3D / targetable / HitVolume contract with own volumes off layer 1. Retired the obsolete generator without executing it or changing its contents; scenes are authoritative. Chose the user's lossless alternative for both enemy atlases: `compress/mode=0`, `detect_3d/compress_to=0`; reimported successfully. No scene, Inspector value, node reference, collision setting, runtime script or test was edited. No request to change pinned speed 12.0, Focus 0.45, follow distance 8.5 or follow height 3.2.
Why: F1-05 is this session's single ticket. The live harness was opened and observed at the authored start (0, 6, 18), camera 9.08 / pitch -9 / roll 0, and later moving at speed 12 with bank. Computer Use then reported a physical Escape stop. The user authorized continuation on the secondary monitor; Godot was relaunched with `--screen 1`, but Computer Use still refused with the same stopped message. Thus the Inspector tuning and motion/physical-device acceptance are explicitly **blocked**, not signed off. The obstruction judgements use Claude's measurements and existing screenshots; no new gate or wall motion pass is claimed. All numeric proposals remain unchanged and listed in the module doc for resumption.
Validation: `tools/test.ps1 -Import` reimported the two atlases and passed 93/93, exit 0, with sandbox user-directory/cache diagnostics. Re-ran `tools/test.ps1` with normal user-directory access: **93 passed, 0 failed, exit 0**, evidence in `docs/validation/player-flight-design-tests.log`. Remaining ERROR/WARNING lines are intentional missing-reference/HitVolume negative tests followed by PASS. No test failures to report. `git diff --check` clean; integrated scenes/scripts/tests unchanged. The pre-existing untracked `.agents/` directory is excluded from this commit.
Action required by Claude: read the decisions in `player-flight.md` Open issues. Plan the proximity visual fade and investigate the gate transition without easing through geometry; coordinate fitted tree collision in a later scene pass. Preserve target prefab conventions and use the integrated scenes directly, never the archived generator. Astra still owes the numeric Inspector flight pass and motion acceptance once Computer Use resumes; a full human keyboard and DualSense pass is still unverified. F1-05 and its roadmap row remain blocked for that reason; F1-02 to F1-04 code completion is unchanged.

## 2026-09-22 23:26 — Claude — TargetSelector core and Targeting adapter (F1-04) [shared]
State: CODE_READY
Files: `scripts/player/target_selector.gd` (new), `scripts/player/targeting.gd` (was your placeholder), `scripts/player/player_controller.gd`, `scenes/dev/arena_harness.gd`, `tests/unit/player/test_target_selector.gd` and `tests/scene/test_targeting_contract.gd` (new), `tests/scene/test_player_ship_contract.gd`, `tools/validate_player_flight.gd`, `docs/engineering/player-flight.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md` (the F1-04 row and a new "Requests to Astra" row), `docs/validation/player-flight.md`, `docs/validation/player-flight-camera-lock.png` (re-captured) and `player-flight-targeting-occluded.png` (new), `.scratch/player-flight/issues/04-target-selector-and-targeting.md`. Astra-owned: `scenes/player/player_ship.tscn` (the `PlayerShip` root's references and the `Targeting` node only), `docs/GUIDE.md` (status line, Sections 6, 7, 10, 13).
Change: Target Lock works. `TargetSelector` is a Node-free Rules Core: a fresh lock takes the visible, in-range target nearest the screen center (distance breaks a tie); `next_target` steps to the next visible, in-range target to the right on screen, wrapping to the leftmost; a held lock is dropped only when its target disappears or leaves range, never for occlusion; `target_changed` fires once per change. `scripts/player/targeting.gd` is now `class_name Targeting extends Node`: every physics tick with a lock or a press it describes each `targetable` node to the core — screen position from the camera, distance from the ship, one occlusion ray from the camera to its `HitVolume` on layer 1 — reads `lock_target` (toggle) and `next_target` (switch), and emits `target_changed(target: Node3D)`, null on release; `get_current_target()` returns the lock. **In `player_ship.tscn`**: the root gained `"targeting"` in its `node_paths` marker and `targeting = NodePath("Targeting")` — `PlayerController` has a new required `targeting` export and connects `targeting.target_changed` to `camera_rig.set_lock_target` once in `_ready` — and the `Targeting` node gained `node_paths=PackedStringArray("camera")` with `camera = NodePath("../CameraRig/Camera3D")`. Nothing else in that file changed, and your `combat_arena.tscn` is untouched. The four selection exports stay at their defaults, so the file does not list them. The harness's F1-03 lock stand-in is gone; its readout now shows `lock <name> at <distance> of 60.0`. Two rules differ from the ticket as written, both found against the real camera: the switch order is left to right on screen instead of by angle around the center, and the 0.85 screen radius gates a fresh lock only — with it in the switch ring, locking High pushed Low to x -0.965 and cycling never reached it. Verified: 93 tests green (14 core, 10 scene contract), 11 mutations each caught by a named test, and `tools/validate_player_flight.gd` printing `FLIGHT_OK` headless and in a real window: from the open-air start `lock_target` picks Middle (worked by hand from your positions), `next_target` visits Middle → High → Low and wraps to Middle with the camera framing each, the release holds its heading, flying away releases the lock at 60.047 against 60.0, and a lock on Middle survives with the ship parked past the shrine gate, where the camera's line to Middle hits `BeamBody`. Every run was simulated input; no joypad was connected this time.
Why: F1-04, the last ticket of Feature F1. The camera could frame a lock but nothing chose one, lost one, or respected scenery.
Action required by Astra: four things. (1) Tune `max_distance` 60 and `max_screen_radius` 0.85 on `PlayerShip/Targeting` (under **Selection**) in the harness; both are proposals, and whether left-to-right switching reads well on `Tab`/`X` is your judgement. (2) Every future targetable prefab — enemies, bosses, anything lockable — must be a `Node3D` in the `targetable` group with a `HitVolume` child, with its own volumes off layer 1; a member without `HitVolume` is skipped with one warning. (3) Only layer-1 collision hides a target. The arena's trees, lanterns and peaks are meshes without collision, so they never hide one; stage trees that should block acquisition and Aim Assist need layer-1 collision. (4) `tools/build_scene_handoff.py` now also misses the `targeting` wiring on the root and on the `Targeting` node; reconcile before any rerun. The physical keyboard and pad pass is still owed for F1-02 to F1-04.

## 2026-09-22 15:10 — Claude — CameraRig follow, orbit, lock framing and obstruction (F1-03) [shared]
State: CODE_READY
Files: `scripts/player/camera_rig.gd` (was your placeholder), `scripts/player/player_controller.gd`, `scenes/dev/arena_harness.gd` and `scenes/dev/arena_harness.tscn`, `tests/scene/test_camera_rig_contract.gd` (new), `tests/scene/test_player_ship_contract.gd`, `tools/validate_player_flight.gd`, `docs/engineering/player-flight.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md` (the F1-03 row and two new "Requests to Astra" rows), `docs/validation/player-flight.md` and four new `player-flight-camera-*.png`, `.scratch/player-flight/issues/03-camera-rig.md`. Astra-owned: `scenes/player/player_ship.tscn` (the `CameraRig` node only), `docs/GUIDE.md` (Sections 6, 10, 13).
Change: `scripts/player/camera_rig.gd` is now `class_name CameraRig extends Node3D`. It sets `top_level` on itself in `_ready` and places itself every physics tick at the ship's position with a basis that is a pure yaw rotation, so the banking body cannot tilt the camera; the camera is placed at the authored offset rotated by that yaw and by a pitch, and its basis is rebuilt from the same two angles with an explicit zero roll. The `camera_*` actions orbit it at `orbit_speed_degrees`, the pitch is clamped to `pitch_limits_degrees`, `set_lock_target()` / `clear_lock_target()` fade a Target Lock framing in and out, and a ray from the ship to the desired camera position shortens the rig against scenery, immediately on the way in and eased on the way out. `apply_settings()` is there for F3. **The yaw lives in the `CameraRig` node's own `global_rotation.y`** — the rig reads it, modifies it and writes it back each tick — and `get_yaw()` publishes it; `PlayerController.camera_rig` is retyped from `Node3D` to `CameraRig` and `_camera_yaw()` now calls `get_yaw()`. **In `player_ship.tscn` only the `CameraRig` node changed**: it gained `node_paths=PackedStringArray("camera")`, `camera = NodePath("Camera3D")` and your camera offset as `follow_distance` 8.5 and `follow_height` 3.2. Your `Camera3D` node, its FOV, near, far and every other node in that file are untouched — but the rig now writes that camera's transform every frame, so the node's authored position and rotation are the documented rest pose rather than the live value. `scenes/dev/arena_harness.gd` grew a camera readout (yaw, pitch, roll, distance) and a dev stand-in for F1-04: `K`/`Y` locks the selected arena target, `Tab`/`X` cycles the three. Verified: 69 tests green, 22 of them the two scene contracts, plus `tools/validate_player_flight.gd` printing `FLIGHT_OK` over 24 new camera measurements in a real window — rest pose, orbit rate on both axes, both pitch limits, a camera-relative flight after a quarter turn, lock framing on all three arena targets with ship and target inside the field of view, the release holding its heading, shortening against the west wall, and the shrine gate pass — with the roll measured as exactly 0 in every one of them. Reproducible across runs; four new screenshots are in `docs/validation/`. Mutation-checked both ways: making `_camera_yaw()` return 0 fails only the new round-trip test, and running the obstruction ray on mask 0 fails only the shortening test.
Why: F1-03. The camera was still your static `Camera3D` and camera-relative movement had never been exercised with a turned rig, which is the failure the ticket called silent.
Action required by Astra: four things. (1) Tune the camera in `scenes/dev/arena_harness.tscn`. Everything on `PlayerShip/CameraRig` except `follow_distance` 8.5 and `follow_height` 3.2 is Claude's first guess: `default_pitch_degrees` -9 (the export form of your -0.16 rad), `pitch_limits_degrees` (-60, 35), `orbit_speed_degrees` 120, `position_damping` 10, `rotation_damping` 8, `lock_blend_speed` 4, `obstruction_margin` 0.4. Move the camera with those exports, not by dragging `Camera3D` — the rig overwrites its transform every frame. FOV, near and far are still read from your node. (2) Two feel judgements are yours: turned into a wall the camera collapses to 0.75 units from the ship and the hull fills the frame (`player-flight-camera-obstruction.png`) — a minimum distance, or the ship transparency PLANEJAMENTO Section 3 already mentions, would fix it; and the shortening under the shrine gate is a 6.5-unit change in a single frame (`player-flight-camera-gate.png`), which is the ray rule working as specified but may read as a pop. (3) `tools/build_scene_handoff.py` now also misses the `CameraRig` wiring, on top of the five `PlayerShip` lines F1-02 listed; without the `camera` reference the rig disables itself and the camera stops following. (4) The physical pass is still owed, on both flight and camera: this host has a DualSense pad that Godot recognises with a standard mapping, but no key or button has been pressed by a human — everything measured is simulated input.


## 2026-09-22 10:40 — Claude — PlayerController adapter and arena harness (F1-02) [shared]
State: CODE_READY
Files: `scripts/player/player_controller.gd`, `scenes/dev/arena_harness.tscn` and `scenes/dev/arena_harness.gd` (new), `tests/scene/test_player_ship_contract.gd` (new), `tools/validate_player_flight.gd` (new), `docs/engineering/player-flight.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md` (the F1-02 row and a new "Requests to Astra" row), `docs/validation/player-flight.md` and four `player-flight-*.png` (new), `.scratch/player-flight/issues/02-player-controller-adapter.md`. Astra-owned: `scenes/player/player_ship.tscn` (root node only), `docs/GUIDE.md` (header, Sections 3, 6, 10, 13).
Change: `scripts/player/player_controller.gd` was your placeholder and is now `class_name PlayerController extends CharacterBody3D`. It reads the input actions, asks `CameraRig` for its yaw, drives the `FlightModel` core, calls `move_and_slide()`, then clamps the position into the Flight Volume and updates the edge feedback; `_process` only eases `VisualRoot.rotation.z` toward the core's bank angle. Its owner injects the Flight Volume with `setup(bounds)` and controls it with `set_controls_enabled(enabled)` and `reset_to(transform)`; it reports `edge_proximity_changed(value)` and `focus_changed(active)`. **In `player_ship.tscn` only the root `PlayerShip` node changed**: `metadata/base_speed` and `metadata/focus_multiplier` are gone, replaced by the exports `base_speed` 12.0, `focus_multiplier` 0.45, `edge_margin` 4.0, `max_bank_angle_degrees` 25.0, `bank_smoothing` 8.0 and the four node references `visual_root`, `camera_rig`, `damage_core`, `graze_volume`; the node line gained `node_paths=PackedStringArray(...)`, without which Godot hands the script raw `NodePath` values and every reference reads as unset; and the body gained `motion_mode = 1` (floating, no gravity, layer 2, mask 1). Your geometry, materials, collision shapes, camera placement and every other node in that file are untouched. `scenes/dev/arena_harness.tscn` is Claude's dev scene: it instances your `combat_arena.tscn` unmodified, reads the `FlightBounds` metadata `min_corner`/`max_corner`, hands the volume to the controller, and draws a debug readout of position, speed and edge proximity. Verified: 57 tests green, ten of them the new scene contract test (body wiring, exports resolving, a pushed error plus disabled processing when a reference is missing, banking that moves `VisualRoot/EngineL` while `DamageCore`, `GrazeVolume` and `Muzzle` stay put, `reset_to`, disabled controls, `focus_changed`, and the injected volume clamping the ship); the clamp assertion was checked by mutation. `tools/validate_player_flight.gd` then flew the harness in a real window and measured 12.000 units per second on each of the six axes, 12.000 on a full three-axis diagonal against 20.78 unbounded, 5.400 under Focus, a stop at y 0.400 on the platform, y 0.000 on the clamped floor past the platform rim, x -38.000 against the west wall with the readout at 0.75, and a -24.5° roll strafing right. Four screenshots are in `docs/validation/`.
Why: F1-02. The ship had a scene and a movement core but nothing joining them; F1-03 and F1-04 need a flying ship to build a camera and targeting against.
Action required by Astra: three things. (1) Fly `scenes/dev/arena_harness.tscn` and tune `edge_margin`, `max_bank_angle_degrees` and `bank_smoothing` — they are Claude's proposals, and no design document fixes them. `base_speed` 12.0 and `focus_multiplier` 0.45 are pinned by the contract test, so say so before changing those two. (2) The rectangular Flight Volume's corners are open void past the circular platform, where the clamp holds the ship at y 0 over nothing with the feedback at 1.0 (`player-flight-clamp.png`); decide whether the volume should become a cylinder or the scenery should fill the corners. (3) `tools/build_scene_handoff.py` no longer reproduces the integrated `player_ship.tscn` — it still writes the two retired metadata entries and none of the exports, the `node_paths` marker or `motion_mode`. Reconcile those five lines before any rerun; it was left unchanged because this host has no Python to verify a rerun with. Also keep `DamageCore`, `GrazeVolume` and `Muzzle` outside `VisualRoot`, and tell Claude before renaming `VisualRoot`, `CameraRig`, `DamageCore` or `GrazeVolume`: each is a required reference and the ship refuses to move without it.

## 2026-09-22 00:15 — Claude — Gameplay roots stop while paused (F0-03 review fix) [shared]
State: CODE_READY
Files: `scenes/main.tscn`, `tests/scene/test_main_contract.gd`, `tests/run_tests.gd`, `docs/GUIDE.md` (Section 5 "Main composition", two lines), `docs/engineering/project.md`, `docs/engineering/testing.md`, `docs/engineering/ROADMAP.md` (the F0-03 row), `.scratch/foundation/issues/03-project-config-main-scene-buses-export.md`.
Change: `Main/WorldRoot` and `Main/ProjectileRoot` are now `process_mode = PAUSABLE`. They had been left at INHERIT under a `Main` that is ALWAYS, so both kept receiving `_process` and `_physics_process` while the tree was paused; the 2026-09-22 review of the F0/F1 commits caught it with a runtime probe (P2). Two regression tests pin the contract: `test_world_and_projectile_roots_are_pausable` checks the modes, and `test_only_interface_and_audio_keep_processing_while_paused` pauses the tree and counts callbacks on probe nodes under all four roots (gameplay roots receive none and `can_process()` is false, `Interface` and `Audio` keep processing, gameplay roots resume on unpause). The second test failed against the old scene with three `_process` calls and one `_physics_process` call per root. The runner's watchdog is now ALWAYS, so a test that pauses the tree and then hangs still times out; a test that pauses the tree resets `tree.paused` in `after_each`. 47 tests green.
Why: F2-04 and F11 pause the tree from `GameSession`; with the old modes the stage, enemies, and projectiles would have kept simulating behind the pause menu.
Action required by Astra: none. `docs/GUIDE.md` is shared, which is why this entry carries the tag; only the two Section 5 lines for `WorldRoot` and `ProjectileRoot` changed.

## 2026-09-22 00:12 — Claude — Editor re-save of theme, enemy texture imports, and settings (retroactive for commit e54b7d6) [shared]
State: dev
Files: `assets/ui/menu_theme.tres`, `assets/models/enemies/Goleling_Atlas_Monsters.png.import`, `assets/models/enemies/Hywirl_Atlas_Monsters.png.import`, `project.godot`.
Change: Commit `e54b7d6` (2026-09-21 13:37) tracked Godot 4.7.2 editor side effects with no authored change and shipped without a log entry; this entry closes that gap (P3 in the 2026-09-22 review). `menu_theme.tres` was re-saved with a `uid` and sorted properties, serialization only. `project.godot` had two `[rendering]` keys reordered. The two enemy atlas textures were re-imported as VRAM-compressed: `detect_3d` fired the first time the editor rendered them on 3D meshes, so `compress/mode` went from 0 (lossless) to 2 (VRAM compressed, S3TC/BPTC) and `detect_3d/compress_to` from 1 to 0.
Why: running the project from the editor during F0-03 triggered the re-import and re-save; committing them stops the files from showing as dirty in every later session.
Action required by Astra: confirm the VRAM-compressed import is acceptable for the Hywirl and Goleling atlases. It is Godot's standard mode for 3D textures; quality loss shows mainly on flat colour gradients. If the lossless look is wanted, set `compress/mode=0` and `detect_3d/compress_to=0` in the two `.import` files so the editor does not switch them again. Nothing else in that commit touched your files.

## 2026-09-21 14:26 — Claude — FlightModel core (F1-01)
State: CODE_READY
Files: `scripts/player/flight_model.gd`, `tests/unit/player/test_flight_model.gd` (and their `.uid` files), `docs/engineering/player-flight.md` (new), `docs/engineering/README.md`, `docs/engineering/ROADMAP.md` (the F1-01 row), `.scratch/player-flight/issues/01-flight-model-core.md`.
Change: `FlightModel` is the first Rules Core, `class_name FlightModel extends RefCounted`, with `configure()`, `set_bounds()`, `compute_velocity()`, `clamp_position()`, `edge_proximity()` and `bank_angle()`. Horizontal input is rotated by the camera yaw around world Y only and the vertical axis is world Y, so the horizon stays stable; the combined 3D input vector is clamped to length 1 before it is scaled by `base_speed` and, under Focus, by `focus_multiplier`, so a full three-axis diagonal flies at 12.0 and not at 12 * sqrt(3). `compute_velocity` takes no delta and keeps no state: the adapter integrates `velocity * delta`, which is what makes movement frame-rate independent. `clamp_position` is the identity until `set_bounds` is called. `edge_proximity` is 0 farther than `edge_margin` from every face, rises linearly to 1 at the nearest face and stays at 1 outside, and emits `edge_proximity_changed(value: float)` only when the value moves more than 0.01 from the last one emitted. `bank_angle` returns a clamped roll for `VisualRoot` from the camera-lateral part of the velocity; negative leans into a turn to the ship's right. Eighteen tests, written test-first, cover the nine cases the ticket lists plus the wiring of `configure()` itself; one of them walks `get_property_list()` and rejects any script variable of a position type and then re-asks the same three questions after a long varied call sequence, which is how "banking cannot move the damage Core" is enforced rather than asserted. The suite was checked by mutation: hardcoding the authored values in `configure()`, comparing edge drift against the previous call instead of the last emitted value, moving the 0.01 threshold to 0.2 or 0.0051, dropping `limit_length`, flipping the bank sign and dropping the yaw rotation are all caught. Turning `>` into `>=` on the threshold is not, because no position produces a proximity exactly equal to 0.01 in binary floating point; the case is one hundredth of a feedback value and a test for it would be a rounding coin-flip. Suite is 45 green.
Why: F1-01, the first ticket of Feature F1. Movement rules had to exist before the adapter, the camera and targeting can be built on them.
Action required by Astra: none. The core is code-only, is never attached to a node, and does not appear in the GUIDE Section 6 registry. Exports and scene wiring arrive with F1-02, which also proposes `edge_margin` 4.0 and a 25-degree maximum bank for you to tune once the feedback is visible.

## 2026-09-21 13:56 — Claude — Ownership and collaboration protocol recorded in GUIDE (F0-04) [shared]
State: docs
Files: `docs/GUIDE.md` (header, Sections 2, 3, 4, 6, 9, 10, 13, 14, 15), `docs/engineering/README.md` (new), `CLAUDE.md`, `AGENTS.md`, `docs/engineering/ROADMAP.md`, `docs/HANDOFF_LOG.md`, `.scratch/foundation/issues/04-guide-ownership-and-protocol-docs.md`.
Change: GUIDE.md is now version 5 and Section 2 points at `CONVENTIONS.md`, `ROADMAP.md`, and `HANDOFF_LOG.md`. Section 3 records the ownership split: Claude owns `project.godot`, `export_presets.cfg`, `default_bus_layout.tres`, `scenes/main.tscn`, `scenes/dev/`, and inside any `.tscn` the script attachment, exported values, collision layers, masks, monitoring flags, and the instancing of Claude's prefabs; Astra keeps geometry, visuals, layout, markers, materials, and the `content/*.tres` values. The same section states that every change to a file owned by the other agent is announced in `docs/HANDOFF_LOG.md`. Section 6 adds `scripts/ui/interface.gd` (attached to `Main/Interface`), marks `scripts/ui/strings.gd` optional and code-only, and notes that Rules Cores are code-only and documented in `docs/engineering/<module>.md`. Section 9 gains step 0: before rerunning any `tools/build_*.py` generator over an integrated scene, reconcile it with the scene's current wiring or retire it. Section 10 gains the rows "Foundation and conventions" (Claude, CODE_READY) and "Stage 1 area" (Astra, SCENE_READY_STATIC, `docs/STAGE_01_HANDOFF.md`). New `docs/engineering/README.md` indexes the engineering docs. `CLAUDE.md` and `AGENTS.md` are kept identical and their collaboration section links GUIDE Section 3 and this log. No code changed. Two reconciliations came out of the same pass: Section 10's pre-existing "Stage 1 progression" row said SCENE_READY and described the authored area; it is now the runtime row (PLANNED, arrives with F10) while the new "Stage 1 area" row (SCENE_READY_STATIC) carries the scene and the `STAGE_01_HANDOFF.md` link. Sections 13, 14 and 15 still said the project main scene was `scenes/ui/main_menu.tscn` and that `scenes/main.tscn` remained planned; both have been false since F0-03 set `run/main_scene` to `res://scenes/main.tscn`, and they now say so. Section 4 now lists `SCENE_READY_STATIC` as a legal handoff state, since Section 10 already used it, and the "Stage 2 progression" row was split the same way as Stage 1 into "Stage 2 area" (SCENE_READY_STATIC) and "Stage 2 progression" (PLANNED). The one-line owner summary at the top of `CLAUDE.md` and `AGENTS.md` now matches Section 3 instead of saying Astra owns all of `scenes/`.
Why: F0-04. The accepted collaboration rules were only in the engineering docs and in this log; they now live in the shared contract both agents already read.
Action required by Astra: read GUIDE Section 3 again. Note the Section 10 state change on "Stage 1 progression". From here on every delivered scene gets an entry in this log plus a row in the roadmap's "Received from Astra" table. `docs/GUIDE.md` is a shared file, which is why this entry exists.

## 2026-09-21 13:46 — Claude — Project config, main scene, audio buses, export preset (F0-03) [shared]
State: CODE_READY
Files: `project.godot`, `default_bus_layout.tres`, `export_presets.cfg`, `scenes/main.tscn`, `scripts/session/game_session.gd`, `tools/godot.sh`, `tools/test.sh`, `tests/scene/test_main_contract.gd`, `tests/unit/project/test_input_map.gd`, `tests/unit/project/test_audio_buses.gd` (and `.uid` files), `docs/GUIDE.md` (Sections 5, 6, 10), `docs/engineering/project.md`, `docs/engineering/testing.md`, `docs/engineering/ROADMAP.md`, `.scratch/foundation/issues/03-project-config-main-scene-buses-export.md`. Astra-owned, annotated only: `tools/validate_hud_handoff.gd`, `tools/validate_menu_handoff.gd`, `tools/validate_scene_handoff.gd`, `tools/validate_stage_01.gd`.
Change: Claude now owns the four shared project files. `project.godot` treats `untyped_declaration`, `unused_variable`, `unused_parameter`, `shadowed_variable` as errors, declares the sixteen gameplay actions (deadzone 0.2, physical keys plus Xbox bindings, no mouse, `ui_*` untouched), references `default_bus_layout.tres` (`Master`, `Music`, `SFX`), and boots `scenes/main.tscn`: `Main` (`GameSession`, process ALWAYS) with `WorldRoot`, `ProjectileRoot`, `Interface` (ALWAYS), `Audio` (ALWAYS). `GameSession` validates its four exports and instances `scenes/ui/main_menu.tscn` under `Interface`; nothing else yet (F2). `export_presets.cfg` holds the "Windows Desktop" preset; the export itself is blocked because this Linux host has no export templates. `tools/godot.sh` and `tools/test.sh` mirror the PowerShell wrappers since PowerShell is absent here. Six of your validator `for` loops iterate untyped arrays and stopped compiling under the new setting; they now carry a type annotation (`for path: String in ...`), nothing else changed. Verified: 27 tests green, `--quit` clean, every `.gd` passes `--check-only`, the project runs windowed on Vulkan and the menu renders as before.
Why: F0-03. The warnings are the CONVENTIONS baseline, the composition root is ADR-0002, F3 needs the buses, and a Linux session needs one command for Godot and one for the tests.
Action required by Astra: none on scenes. Review the one-line diffs in `tools/validate_*.gd`; from now on type `for` iterators over untyped arrays. F5 starts `main.tscn`; keep previewing menus with F6.

## 2026-09-21 — Astra — Stage 2 texture, color and life revision
State: SCENE_READY
Files: `scenes/stages/stage_02.tscn`, `tools/build_stage_02.py`, `assets/environment/stage_02/`, `tools/validate_stage_02.gd`, `tests/scene/test_stage_02_contract.gd`, `.scratch/stage-02-area/issues/02-mountain-art-pass.md`, Stage 2 handoff/validation, credits, roadmap.
Change: Replaced repeated blue cones/slabs with original irregular crags, moss/gravel/granite texture and terrain ramps. Added green/amber vegetation, vermilion shrine structures, warm lanterns, bronze inlays, water flow, foliage/cloth wind and fading gate wisps. Terrain collision matches its mesh; the old step-floor lookup is no longer exact. Encounter IDs, spawn/checkpoint positions, full gate coverage and seal links are preserved. No production gameplay scripts or project settings edited.
Why: User rejected the monochrome and lifeless blockout. Six views reviewed on Godot 4.7.2 Compatibility, including player height; ambient motion check passed. All 16 tests passed, including physics terrain clearance and front-facing ramp collision. Review docs/validation/stage-02.md for limits.
Action required by Claude: Use actual sculpted terrain collision for floor constraints; see STAGE_02_HANDOFF.md. Shader motion is cosmetic and requires no gameplay binding. Generator now also authors the terrain/stream/crag OBJ meshes; reconcile before reruns. Gameplay integration and duration testing remain pending.

## 2026-09-21 — Astra — Stage 2 art revision announced
State: PLANNED
Files: `tools/build_stage_02.py`, `scenes/stages/stage_02.tscn`, original environment assets/shaders, QA, Stage 2 docs.
Change: User rejected the monochrome blockout. Rework terrain presentation, mountain silhouettes, surface texture, vegetation, lighting and ambient movement. Generator and scene were reconciled against bda60cd: no subsequent integration edits exist. Keep encounter/gate/checkpoint contracts; terrain collision follows any changed terrain surface.
Why: Improve visual quality and environmental life while preserving combat readability.
Action required by Claude: review the updated Stage 2 handoff after this ticket; no production GDScript changes planned.

## 2026-09-21 — Astra — Stage 2 mountain spatial pass delivered
State: SCENE_READY
Files: `scenes/stages/stage_02.tscn`, `scenes/tests/stage_02_preview.tscn`, `tools/build_stage_02.py`, `tools/validate_stage_02.gd`, `tests/scene/test_stage_02_contract.gd` (and UIDs), `.scratch/stage-02-area/`, `docs/STAGE_02_HANDOFF.md`, `docs/GUIDE.md`, `docs/engineering/ROADMAP.md`, `docs/validation/stage-02*`.
Change: Static route with seven encounters, 20 common-enemy and two boss markers, three seals with independent approach volumes and guard links, five full-volume gates, and CP2-A/CP2-B. Original mountain primitives, cyan route guidance, separate duel/summit platforms. Added an offline scene contract to Claude's test discovery tree; no production GDScript or existing scenes changed.
Why: First Stage 2 ticket requested by user. Godot MCP confirmed 4.7.2; the direct Linux test entry point passed 15 tests with zero failures. Five Compatibility renders completed and were inspected. PowerShell is unavailable on this host.
Action required by Claude: Read STAGE_02_HANDOFF.md for exact paths, seal/guard mapping, resource rewards, checkpoint prerequisites and remaining runtime checks. Author typed Definitions and attach runtime actors/director. Static scene completion does not claim gameplay or the five-minute requirement. Reconcile before rerunning the generator.

## 2026-09-21 — Astra — Stage 2 spatial pass announced
State: PLANNED
Files: new `scenes/stages/stage_02.tscn`, `scenes/tests/stage_02_preview.tscn`, `tools/build_stage_02.py`, offline QA, `.scratch/stage-02-area/`, `docs/STAGE_02_HANDOFF.md`, `docs/GUIDE.md`, `docs/engineering/ROADMAP.md`.
Change: Begin one static mountain-route ticket with seven encounters, three guarded seals, gates and two checkpoints. New scene collision defaults follow Stage 1; no integrated scenes or production scripts are edited. Offline contract QA will be added to the test discovery tree.
Why: User requested starting Stage 2.
Action required by Claude: preserve these new authored paths during subsequent integration; existing dirty project/theme/import files belong to other work.

## 2026-09-21 00:25 — Claude — Godot wrapper and headless test runner (F0-02)
State: CODE_READY
Files: `tools/godot.ps1`, `tools/godot.cmd`, `tools/test.ps1`, `tests/run_tests.gd`, `tests/framework/test_case.gd`, `tests/unit/framework/test_self_check.gd` and their `.uid` files, `docs/engineering/testing.md`, `docs/engineering/ROADMAP.md` (row F0-02 only), `.scratch/foundation/issues/02-godot-wrapper-and-test-runner.md`.
Change: One command runs Godot (`tools/godot.ps1`, resolving `$env:GODOT_BIN` then the verified Downloads path) and one runs the tests (`tools/test.ps1`, exit 0 only when every test passed). `TestCase` provides the `assert_*` helpers, `before_each`/`after_each`, and `signal_recorder()`; the runner discovers `tests/unit/**` and `tests/scene/**`, awaits coroutine tests, honours `-Filter`, and fails on load errors, assertion-free tests, and hangs over 30 seconds. Because `class_name` resolution needs Godot's class cache in `.godot/`, `tools/test.ps1` runs a headless editor import (about three seconds) whenever a `.gd` file is newer than its last import. Self-check: 14 tests green; the exit-1 path and a warnings-as-errors run were verified.
Why: Every Rules Core from ADR-0001 is tested headless from now on; a session needs one green/red command.
Action required by Astra: none. `tools/godot.ps1` replaces "set `$godotExe` first" in the validation docs: `tools/godot.ps1 --headless --path . --script res://tools/validate_scene_handoff.gd`. The existing `tools/validate_*.gd` scripts keep working unchanged. Note that `tools/test.ps1` may create `.uid` files next to new scripts and import new assets, exactly as opening the editor does; commit `.uid` files with their scripts.

## 2026-09-21 — Astra — Stage 1 enemy visual variants
State: SCENE_READY
Files: `assets/models/enemies/`, `assets/licenses/quaternius-ultimate-monsters.txt`, `scenes/enemies/visuals/`, `scenes/tests/enemy_variants_preview.tscn`, `tools/build_enemy_visuals.gd`, `tools/validate_enemy_visuals.gd`, `docs/ENEMY_VISUAL_HANDOFF.md`, credits, roadmap, validation outputs.
Change: Imported Hywirl and Goleling; authored two Spirit and two Sentry recolor/resize variants, with one/two rings for Sentries and looping Flying_Idle. Visual scenes contain no stats or collision components. Existing Player/Menu/Stage scenes and production scripts were not edited.
Why: User approved visual variety while explicitly keeping health identical within each enemy type.
Action required by Claude: Read ENEMY_VISUAL_HANDOFF.md. Instance visuals under Enemy independently from HitVolume/Emitters; reuse each type's health configuration. These components do not replace the pending Enemy adapter contract. Project-wide test runner is not yet present; dedicated Godot visual QA passed.

## 2026-09-20 23:58 — Claude — Repository initialized (F0-01)
State: docs
Files: `.gitignore`, `docs/engineering/ROADMAP.md`, `docs/HANDOFF_LOG.md`, `.scratch/foundation/issues/01-git-init-and-ignores.md`; removed the empty root folders `export_templates/`, `feature_profiles/`, `script_templates/`, `text_editor_themes/`.
Change: `git init` on branch `main` with repo-local `core.autocrlf false` (`.gitattributes` already normalizes to LF). `.gitignore` now also excludes `/build/`, `/All models/`, `/all-sounds/`, `/Music/`, and `*.tmp`; `*.import` files stay tracked. One baseline commit, `chore: baseline import of scenes, docs, and planning`, holds everything in the tree including `.scratch/`.
Why: Every later session commits small, reviewable changes. The raw download packs (about 400 MB) stay on disk but out of history.
Action required by Astra: none. Repository initialized; Astra may commit scene work with `[shared]` tags (message format `scenes: summary`) or leave commits to Claude. Keep `All models/`, `all-sounds/`, and `Music/` on disk; they are untracked on purpose.

## 2026-09-20 23:30 — Claude — Engineering planning baseline
State: docs
Files: `CONTEXT.md`, `docs/adr/0001` to `0004`, `docs/engineering/CONVENTIONS.md`, `docs/engineering/TEMPLATE.md`, `docs/engineering/ROADMAP.md`, `docs/HANDOFF_LOG.md`, `.scratch/<feature>/` tickets for all fourteen engineering Features, `CLAUDE.md`, `AGENTS.md`.
Change: Recorded the accepted vocabulary, the four architectural decisions, the coding conventions, the ordered roadmap, and full tickets for Foundation, Player flight, and Menus/Session. No scene, script, or `project.godot` changes yet.
Why: Result of the planning grill with the user; establishes how Claude writes and verifies GDScript for this project.
Action required by Astra: read `docs/engineering/ROADMAP.md`, especially "Requests to Astra". From ticket F0-03 onward Claude owns `project.godot`, `export_presets.cfg`, `default_bus_layout.tres`, and `scenes/main.tscn`; the `tools/build_*.py` generators must not be rerun over integrated scenes without reconciling first. Astra's `.scratch/stage-01-area/` and `docs/STAGE_01_HANDOFF.md` were read and are reflected in the roadmap.
