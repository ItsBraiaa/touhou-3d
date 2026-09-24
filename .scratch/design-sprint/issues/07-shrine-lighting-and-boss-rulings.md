# D-07 Shrine lighting and boss rulings

Status: done
Type: design
Owner: Astra (GPT Sol)
Lane: sol
Model: GPT Sol (Codex)

> **Order (SPRINT.md):**
> - **Part B (the rulings) comes first in lane sol,** by about T0 + 0.8 h, as its own commit `(D-07 part B)`. F5-02 waits at most until T0 + 1 h for ruling 5.
> - **Parts A and C** run after F12-03 has landed. They close the ticket.
Depends on: F12-03

## Part B outcome

Five rulings landed on lane sol: a 0.75 s maximum invulnerable Phase cue, the existing HUD dimming values, a full-width two-Phase boss bar with authored offsets awaiting a trunk Hud follow-up, the fixed ship visual heading, and strict Graze spending under Invulnerability. Parts A and C remain after F12-03.

## Goal

This ticket closes the last open Stage 1 requests to Astra, in three parts:

- **Part A.** The shrine-lighting clip that changes Stage 1 from corrupted to calm when the Lantern Guardian falls (STAGE_DESIGN: "Defeat clears hostile fire and changes the shrine's lighting"). The Director plays it from its `boss_defeated` signal (F12-03). It waits for F12-03 on the integration branch, because `stage_01.tscn` is trunk's until then (SPRINT "Shared files").
- **Part B.** Five written rulings that Claude's code currently implements as its own readings.
- **Part C.** A values check of the Lantern Guardian content that F12-03 drafted. D-03 carries no gameplay value, so this is the only tuning pass those files get.

## Read first

- `.scratch/bosses/issues/03-lantern-guardian-in-s1-07.md`: `defeat_presentation: AnimationPlayer` and `defeat_animation: StringName`, played on `boss_defeated`. Its handoff note suggests "under `Environment`".
- `.scratch/run-flow/issues/01-defeat-results-retry-restart-screens.md`: `_on_stage_completed` pauses the tree under Results at once.
- `docs/STAGE_01_HANDOFF.md`; `docs/STAGE_DESIGN.md` Stage 1 "Final boss sequence" and the acceptance line on boss patterns; `docs/PLANEJAMENTO.md` Sections 4, 7, 9.
- Each ruling's source, named in the table below: F12-01, F4-02 and F4-03, F1-02 and F6-03, F5-02 (their `.scratch` tickets and module-doc Open issues).

## Files

- **Creates:**
  - `docs/validation/stage-01-shrine.md`, `stage-01-shrine-corrupted.png` and `stage-01-shrine-calm.png`.
- **Edits:**
  - **Part A:** `scenes/stages/stage_01.tscn` [shared], only after F12-03 has landed. Add the `AnimationPlayer` below, and any presentation node it animates under `Environment`. Also `tools/validate_stage_01.gd`: a shrine step.
  - **Part B:** `docs/PLANEJAMENTO.md`, one sentence per ruling (Section 4 for rulings 1 and 5, Section 7 for 2 and 3, Section 9 for 4). Also `scenes/ui/hud.tscn` [shared], only if ruling 2 or 3(b) needs it: overrides on the `HUD` root, and metadata on `BossStatus/Phase1` and `Phase2`.
  - **Part C:** `content/bosses/lantern_guardian.tres` and `content/patterns/lantern_ring.tres`, `lantern_aimed_burst.tres`, `lantern_paired_fan.tres`, values only, plus `metadata/reviewed = true`. Also the S1-07 row of `docs/validation/stage-01-pacing.md` (D-05).
  - `docs/engineering/ROADMAP.md` (the D-07 row and one "Received from Astra" row); `docs/HANDOFF_LOG.md`.
- **Must not touch:**
  - In `stage_01.tscn`: the `Stage` script and its exports (trunk sets `defeat_presentation` and `defeat_animation`). Also every marker, Encounter, Gate, Checkpoint, collision shape, layer, mask, monitoring flag, `RuntimeActors` and `PlayerStart`.
  - `tools/build_stage_01.py`: never run it.
  - `hud.tscn` node names and paths: F4-02 and F4-03 bind by path.
  - `scripts/**`, `tests/**`, and `docs/engineering/*.md` except the ROADMAP rows. The consuming lane closes Open issues.
  - In Part C: `display_name`s, `score` 1000, the three-Phase structure and `metadata/dev` (F12-03's `test_every_file_is_flagged_dev`).

## Part A: deliverable contract

- **Node.** `Environment/ShrineLighting`, relative to `Stage`, of type `AnimationPlayer`. It is the target of `defeat_presentation`.
- **Clip.** `corrupted_to_calm`, in the default library `""`, so `defeat_animation = &"corrupted_to_calm"`. No autoplay and no loop. The length is yours, a "short visual resolution" (STAGE_DESIGN); report it.
- **`process_mode = ALWAYS` on this node.** The Director emits `stage_cleared` right after `boss_defeated`, and F11-01 then pauses the tree under Results. A PAUSABLE player would freeze on its first frame. The clip only ever plays after the boss falls, so running while paused affects nothing else.
- **States.** The scene as authored is the corrupted look. The clip's first keys equal the authored values, so nothing pops, and its last keys are calm. A `RESET` clip, if you add one, equals the corrupted state.
- **Tracks, presentation only.** Lights, `WorldEnvironment` properties, emissive materials, and the visibility of decorative nodes under `Environment` or of the shrine under `Geometry`. Never collision, markers, `Encounters`, `Gates`, `Checkpoints`, `RuntimeActors`, `PlayerStart`, or any script export.
- **No leaks between loads.** Prefer node properties. Any Resource the clip animates (an `Environment`, a material) gets `resource_local_to_scene = true`. A PackedScene's sub-resources are shared by all its instances. Without the flag, a Restart or a Direct Stage replay in the same launch would start calm.

## Part B: rulings

For each ruling, record the decision (confirm or change) and one PLANEJAMENTO sentence. For a change, also name the follow-up code and its lane; none of these has a scheduled ticket.

| # | Question | Claude's current reading, and the test that pins it | Source text | If changed |
| --- | --- | --- | --- | --- |
| 1 | Does a boss take damage during a Phase transition? | No. `BossMachine.take_damage` returns 0 during `transition_seconds` (F12-01, `test_damage_is_ignored_during_the_transition`). | PLANEJAMENTO 4: "start after a short readable transition"; "artificial invulnerability timers must not pad stage duration"; "Excess damage does not skip phases". | Say where transition damage goes without skipping a Phase. `BossMachine` and its test change (glm-a). If confirmed, give the upper bound for `transition_seconds` that stays readable rather than padding. Part C and D-06 apply it. |
| 2 | HUD dimming values | `Hud.dim_modulate` alpha 0.25 for a spent Shield or Bomb (F4-02); `completed_phase_modulate` alpha 0.3 for a finished Phase (F4-03); both are exports on the `HUD` root. | PLANEJAMENTO 7; GUIDE Section 15. | Set the overrides on the `HUD` root of `hud.tscn`. If a test pins the literal, leave the file and log the values for Claude. Judge from `docs/validation/combat-hud-boss-3.png` and `-2.png`, plus a live capture if you can. |
| 3 | Two-Phase boss bar | `show_boss(name, 2)` hides `Phase3`. The bars keep x 16, 214 and 412 (192 wide), so the right third is empty (F4-03). | PLANEJAMENTO 7: "a segmented health bar". | Either (a) accept, or (b) add `metadata/two_phase_offset_left` and `metadata/two_phase_offset_right` (float, `BossStatus` pixels) to `Phase1` and `Phase2`. For example, 16–307 and 313–604 keep the 6 px gap and the 16 px margins. A `hud.gd` follow-up then applies them when `phase_count == 2`. Judge it in the Tempest Sentinel fight if F12-06 has landed. |
| 4 | Does the ship model turn with the camera (F1)? | No. The body and `VisualRoot` never yaw; shots and Familiars follow the camera yaw in code (F6-03); banking is `VisualRoot.rotation.z` (F1-02). | ROADMAP F6 row: "the ship model never turns with the camera". PLANEJAMENTO 9: banking is visual only. | `VisualRoot` eases toward the camera yaw, visual only, as a `PlayerController` follow-up on trunk. `DamageCore` and `GrazeVolume` never move (GUIDE Section 5). |
| 5 | Graze under Invulnerability (F5) | Strict. Any contact while invulnerable spends the Projectile's Graze for good, even after Invulnerability ends (F5-02, `test_invulnerability_does_not_enable_graze`). | PLANEJAMENTO 4: "Disable new graze awards during invulnerability to prevent risk-free scoring". | Lenient: a Projectile touched while invulnerable may still graze once afterwards. A `ProjectileField` change and its test (glm-a). |

**Early delivery.** Part B needs nothing from F12-03. The earlier a ruling lands, the less code it reverses. If lane sol is waiting on a dependency (the SPRINT read-ahead rule), write Part B first:

- its PLANEJAMENTO sentences;
- one entry, `— Astra (sol) — Rulings (D-07 Part B)`;
- commit `design: D-07 part B rulings`, then land.

The ticket stays `doing` until Parts A and C land.

## Part C: Lantern Guardian values

- Tune Phase `health` toward STAGE_DESIGN's 25/25/35 s at Power 3, using the damage per second in `weapon-rendering.md`.
- Keep `transition_seconds` within ruling 1's bound.
- Keep the patterns avoidable from different heights, with no permanent risk-free perch (STAGE_DESIGN acceptance).
- Check that `bomb_damage` stays below the smallest Phase health.
- Put the resulting S1-07 time in D-05's pacing table.

## Acceptance

- **Part A:**
  - `tools/validate_stage_01.gd` checks that the node is an `AnimationPlayer` with `process_mode` ALWAYS, and that the clip exists, does not loop and does not autoplay.
  - Seeking to 0 reproduces the authored values.
  - After seeking to the end, a second `instantiate()` of the stage still reads corrupted.
  - It captures `stage-01-shrine-corrupted.png` and `stage-01-shrine-calm.png`, headless first, then windowed, with zero failures.
- `tools/test.ps1` green with no `SCRIPT ERROR`. It covers F10-04's Stage 1 contract test, F12-03's `test_s1_07_boss_integration.gd` and `test_lantern_guardian_content.gd`, and F4-02's HUD contract test if `hud.tscn` changed.
- **Part B:** five PLANEJAMENTO sentences, and the ruling table in the handoff entry.

## Handoff to Claude

One entry, `— Astra (sol) — Shrine lighting and boss rulings (D-07) [shared]` (plus the early Part B entry, if made). It contains:

- **For trunk:** set `defeat_presentation = NodePath("Environment/ShrineLighting")` and `defeat_animation = &"corrupted_to_calm"` on `Stage`. This is F12-03's wiring. The first trunk ticket that starts after D-07 lands does it, under the late-swap rule in `.scratch/design-sprint/spec.md`.
- **For F11-01's owner:** the clip length. Say whether the calm shrine can be seen behind Results, or needs a short delay before Results (Claude's call).
- **The ruling table**, each ruling with its decision, its follow-up and its lane.
- **Part C:** old → new values, and the S1-07 time.

## Kickoff prompt

## Parts A and C outcome

2026-09-24, Astra (sol): authored `Environment/ShrineLighting` with the non-looping 2.4 s `corrupted_to_calm` clip and `PROCESS_MODE_ALWAYS`. It changes Moonlight from blue to warm and a shrine-local glow from cold blue at energy 0.8 to gold at 2.8. Its first keys match scene values; a fresh instance starts corrupted. The Stage root script and exports were untouched. Lantern Guardian Phase health changed 1500/1500/2100 → 550/550/775, targeting 25/25/35 s at the measured 22.1 Power-3 damage/s. Transitions remain 0/0.75/0.75 s; pattern numbers remain as drafted after the high/low and aimed coverage review. All four content files gained `metadata/reviewed = true`, retaining `metadata/dev = true`. The Bomb's default damage 20 remains below 550. The headless and windowed Stage 1 validators passed, and both shrine images were captured. Trunk's F14-01 swap step must set the two Stage exports. No new tests were written.

```
Read AGENTS.md, docs/engineering/SPRINT.md (lane sol), docs/GUIDE.md Sections 3 and 5 and .scratch/design-sprint/issues/07-shrine-lighting-and-boss-rulings.md, then deliver it in your worktree, log it in docs/HANDOFF_LOG.md, commit, and run tools/lane.ps1 land.
```
