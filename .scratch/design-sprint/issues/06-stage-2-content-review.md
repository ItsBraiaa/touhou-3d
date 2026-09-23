# D-06 Stage 2 content review

Status: todo
Type: design
Owner: Astra (GPT Sol)
Lane: sol
Depends on: F12-04

## Goal

Stage 2 carries the assignment's duration requirement. PLANEJAMENTO Section 2 asks for at least 5 minutes of active play. STAGE_DESIGN targets 360 s, and sets 300 s of efficient play as the floor.

Astra reviews the Stage 2 content draft Claude flagged `dev` (F12-04) and tunes it toward that target with real encounter content. She confirms that every reward in the STAGE_DESIGN table is exact, and that a Direct Stage 2 player reaches Power 3 before the miniboss. She records a pacing table, and whether the five-minute claim is measured or only estimated.

F12-05 to F12-07 come earlier in lane sol, so the Director, the Tempest Sentinel and the Storm Guardian are usually live by now. When they are, this ticket also tunes their boss values.

## Read first

- `docs/STAGE_DESIGN.md` Stage 2:
  - the table, and "Three-seal progression challenge" (a Seal is "a brief confirmation");
  - "Miniboss — Sentinela da Tempestade" (Phases 20 and 30 s) and "Final boss sequence" (40/40/50 s);
  - "Time and score integrity";
  - the acceptance line "Stage 2 uninterrupted efficient clear reaches at least five active minutes".
- `docs/PLANEJAMENTO.md` Section 2, Section 4 (5 pickups per level; 50 per excess pickup; 1,000 per final boss; no invulnerability padding) and Section 6 (Direct Stage 2 starts at Power Level 2).
- `docs/STAGE_02_HANDOFF.md` "Encounters and markers" and "Seals and gate": entry and exit Z, Seal heights, seven power items in total.
- `.scratch/bosses/issues/04-stage-02-content-draft.md` and its Outcome: the pinned structure, and "Free to change: the wave delay and the Checkpoint `display_name`". Also `05-stage-02-director-integration.md` "Per-Seal rewards": a reward whose `origin_marker` lies under a Seal root spawns when that Seal breaks. And `.scratch/enemies/issues/03-seal-and-guard-rules.md`: `Seal.health` is an export, and F12-05 keeps its default.
- `.scratch/bosses/issues/06-tempest-sentinel-miniboss.md` and `07-storm-guardian.md`: the boss and pattern files, and their content tests.
- `docs/validation/stage-01-pacing.md` (D-05): the same method. The Spirit and Sentry values in it are shared with this stage.

## Files

- **Creates:** `docs/validation/stage-02-pacing.md`. Also `docs/validation/stage-02-results.png`, if a clear is measured.
- **Edits (values only):**
  - `content/stages/stage_02/stage_02.tres`, `s2_01.tres` to `s2_07.tres`, `cp2_a.tres` and `cp2_b.tres` (F12-04). Edit Wave `delay`s and the CP2-A and CP2-B `display_name`, and add `metadata/reviewed = true` to each reviewed file.
  - `scenes/stages/stage_02.tscn` [shared], only after F12-05 has landed: the `health` export of `Encounters/S2-03/Seals/Seal1..3` (`seal.gd`), and nothing else. That is lane sol's own wiring file.
  - If they have landed:
    - `content/bosses/tempest_sentinel.tres`, `content/patterns/sentinel_aimed_burst.tres` and `sentinel_rotating_fan.tres` (F12-06);
    - `content/bosses/storm_guardian.tres`, `storm_spiral.tres`, `storm_thunder_rings.tres` and `storm_aimed_burst.tres` (F12-07).

    Edit Phase `health`, `transition_seconds`, `reposition_seconds`, `entry_seconds`, and the step and pattern numbers.
  - `docs/engineering/ROADMAP.md` (the D-06 row and one "Received from Astra" row); `docs/HANDOFF_LOG.md`.
- **Must not touch:**
  - The approved structure (table below), boss `score`s (500 and 1,000), Attack `display_name`s (the STAGE_DESIGN Portuguese names) and `metadata/dev`.
  - `content/enemies/spirit.tres` and `sentry.tres`, and their two patterns. They are shared with Stage 1 and D-05 tuned them. A Stage-2-only common-enemy value is a request to Claude, logged, not a fork.
  - Everything else in `scenes/stages/stage_02.tscn`: if a marker must move, stop and log it. Also Stage 1 content, `scripts/**`, `tests/**`, `scenes/main.tscn` and `scenes/player/player_ship.tscn`.

## Deliverable contract

- **Structure and rewards match STAGE_DESIGN and STAGE_02_HANDOFF exactly:**

  | ID | Enemies | Rewards | Gate / Checkpoint |
  | --- | --- | --- | --- |
  | S2-01 | 2 Spirits, and the ledge reached | none | `Gate_S2_01` |
  | S2-02 | 2 Waves of 2 Spirits + 1 Sentry, at staggered heights | POWER 2 at `RewardOrigin`, SHIELD 1 at `ShieldPickup` | `Gate_S2_02` |
  | S2-03 | 3 Seals × 2 Guards, any order | POWER 1 per Seal, at that Seal's `RewardOrigin` | `Gate_S2_03`; crossing it activates CP2-A |
  | S2-04 | Tempest Sentinel, 2 Phases | 500 score, SHIELD 1 at `ShieldPickup` | `Gate_S2_04` |
  | S2-05 | 2 Waves of 2 Spirits + 1 Sentry | POWER 2 | `Gate_S2_05` |
  | S2-06 | none (traversal) | none | CP2-B |
  | S2-07 | Storm Guardian, 3 Phases | 1,000 score, victory | none |

  That is seven Power Pickups. A Direct Stage 2 player enters at Power 2: S2-02's 2 and S2-03's 3 make 5, so Power 3 arrives before S2-04 (STAGE_DESIGN). S2-05's two become 50 points each. A Campaign player already at Power 3 scores all seven as excess. Nothing requires collecting them. A mismatch is a content bug: log it for F12-04's lane, do not restructure.
- **Pacing table**, in `stage-02-pacing.md`. One row per segment:
  - the target: 25, 35, 65, 50, 45, 10, 130 s, total 360;
  - the span, from entry Z to exit Z: 111, 93, 123, 70, 108, 28, 125 units;
  - traversal at `base_speed` 12 along the 3D path, including the climbs (the floor rises 0 → 83; Seals at Y 43, 65, 86);
  - combat from `health` ÷ the damage per second at the Power Level held there;
  - Wave delays, Anticipation and Phase transitions.

  Give two totals: an efficient clear (Power 3 from S2-04, both Bombs used before each refill) and a normal clear.
- **Tuning target.** The efficient clear is at least 300 s, from encounter content alone. Levers, in order:
  - the boss Phase health against STAGE_DESIGN's 20/30 and 40/40/50 s;
  - the boss step, pattern and `reposition_seconds` values;
  - Wave `delay`s;
  - Seal health, which stays brief.

  No forced waiting (STAGE_DESIGN). No Phase transition long enough to be padding: D-07's ruling on transition damage applies. `bomb_damage` stays below the smallest Phase health (PLANEJAMENTO: one Bomb never ends a Phase).
- **Checkpoint names**, as in D-05. Proposals from the STAGE_DESIGN segment names, for you to decide: CP2-A `Portão dos Selos` (beyond the S2-03 gate), CP2-B `Limiar do Cume` (S2-06).
- **Measured, or said to be estimated.** If F12-07 and F11-01 have landed, play one Direct Stage 2 with no deaths and strong play. Record Results' Clear Time, Retries, starting Power and Bombs used. Otherwise the table says "estimate; measurement owed by the human pass (SPRINT Human steps, F11-03 protocol)". The requirement is never claimed from an estimate (STAGE_DESIGN "Validate Stage 2 with no deaths and strong play before claiming").

## Acceptance

- `tools/test.ps1` green with no `SCRIPT ERROR`, all over your values. It runs:
  - F8-01's content validation;
  - F12-04's `test_stage_02_content.gd` and `test_stage_02_content_contract.gd`;
  - `test_tempest_sentinel_content.gd` (F12-06) and `test_storm_guardian_content.gd` (F12-07);
  - F12-05's `test_stage_02_director.gd`, which covers the Seal `health` change.
- `docs/validation/stage-02-pacing.md` holds the reward check, both totals against 300 and 360 s, and the measured clear or the "estimate" line.
- If measured: `docs/validation/stage-02-results.png` shows the Results screen with the Clear Time.

## Handoff to Claude

One entry, `— Astra (sol) — Stage 2 content review (D-06)`, State `SCENE_READY`, containing:

- every value changed, as old → new;
- the reward check;
- both totals, and whether each was measured;
- any content bug found, or any Stage-2-only request.

Consumers:

- F12-05: the Director loads the content, with no code change.
- F12-06 and F12-07: boss values.
- F11-03: the expected Clear Time.
- F14-02: the acceptance line "Stage 2 ≥ 300 s", marked measured or not verified.
- The user, at the SPRINT checkpoint, if the efficient estimate is under 300 s.

## Kickoff prompt

```
Read AGENTS.md, docs/engineering/SPRINT.md (lane sol), docs/GUIDE.md Sections 3 and 5 and .scratch/design-sprint/issues/06-stage-2-content-review.md, then deliver it in your worktree, log it in docs/HANDOFF_LOG.md, commit, and run tools/lane.ps1 land.
```
