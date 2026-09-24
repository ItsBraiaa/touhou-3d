# D-05 Stage 1 tuning and pacing

Status: done
Type: design
Owner: Astra (GPT Sol)
Lane: sol
Model: GPT Sol (Codex)
Depends on: F8-04

## Goal

Stage 1 should read as its STAGE_DESIGN target: about 240 s of active play across seven segments, with Power 1 → 2 → 3 earned in play. Astra reviews and tunes the drafts Claude flagged `dev`:

- the Stage 1 Encounter content (F8-04);
- the Spirit and Sentry Definitions and patterns (F9-02, earlier in lane sol);
- the `HitVolume` radii.

She also names CP1-A and CP1-B in Portuguese and picks an Anticipation clip. She writes a pacing table, and a note on how Stage 1 could reach five minutes. That note is SPRINT's cut step 4 if Stage 2 slips: it is recorded here, not applied.

## Read first

- `docs/STAGE_DESIGN.md`: "Shared encounter rules", the Stage 1 table, "Final boss sequence", "Time and score integrity".
- `docs/PLANEJAMENTO.md` Section 2 (at least 5 minutes, no artificial waiting) and Section 4 (100 per enemy, 5 pickups per level, "One use must not eliminate an entire boss phase").
- `docs/STAGE_01_HANDOFF.md` "Spatial contract": the entry and exit Z of each Encounter.
- `docs/ENEMY_VISUAL_HANDOFF.md`: the clip list, and "No casting/contact attack is implied by an animation name".
- `.scratch/progression-core/issues/04-stage-01-content-draft.md` (the pinned structure and its tests), `docs/engineering/progression-core.md` "Stage 1 content".
- `docs/engineering/enemies.md` "Setup for Astra" (F9-02; does `EnemyActor` export an `anticipation_clip`?).
- `docs/engineering/weapon-rendering.md`: F6-03's shot damage and cadence, Familiar cadence, and F7-02's Bomb values. These give the player's damage per second at each Power Level.

## Files

- **Creates:** `docs/validation/stage-01-pacing.md`; `docs/validation/stage-01-anticipation.png`.
- **Edits (values only):**
  - `content/stages/stage_01/s1_02.tres` and `s1_05.tres`: the second Wave's `delay`.
  - `cp1_a.tres` and `cp1_b.tres`: `display_name`.
  - Every file you review: add `metadata/reviewed = true`.
  - `content/enemies/spirit.tres` and `sentry.tres`: `health`, `attack_interval`, `move_speed`, `move_range`, `anticipation_seconds`.
  - `content/patterns/spirit_aimed_burst.tres` and `sentry_fan.tres`: pattern numbers.
  - `scenes/dev/spirit.tscn` and `scenes/dev/sentry.tscn` [shared]: the `HitVolume` sphere radius and position, with `Emitters/Main` kept at the hit center. Also `anticipation_clip` on the `Enemy` root, if that export exists.
  - Only if that export does not exist: `metadata/anticipation_clip` on the `VisualRoot` root of the four `scenes/enemies/visuals/*.tscn`.
  - `docs/engineering/ROADMAP.md` (the D-05 row and one "Received from Astra" row); `docs/HANDOFF_LOG.md`.
- **Must not touch:**
  - The structure F8-04's tests pin: seven Encounters in order, completion conditions, the Wave markers and kinds (17 plus 1), 5 + 5 Power, one Shield at S1-03 `ShieldPickup`, the Gates, CP1-A → S1-05 and CP1-B → S1-07.
  - `score` (100), `kind`, `movement` and `pattern` references; `metadata/dev`.
  - `HitVolume` layer 16, mask 0, `monitoring` off, and its `SphereShape3D` type.
  - `scenes/stages/stage_01.tscn`, `scenes/player/player_ship.tscn`, `content/bosses/**` and `content/patterns/lantern_*.tres` (D-07 Part C), `content/stages/stage_02/**` (D-06), `scripts/**`, `tests/**`.

## Deliverable contract

- **Content stays loadable as is.** The Director (F10-01) and F10-04's contract test read these files unchanged in shape. `validate()` stays empty. A test that pins a number you changed wins: F9-02's `test_first_shots_follow_the_anticipation` expects 1 s. Revert that number and log the one you wanted.
- **Checkpoint names.** `display_name` is short Portuguese text. Defeat shows it as `Último checkpoint · <display_name>` (`scripts/ui/menu_controller.gd`), and GUIDE Section 14 asks for "concisely". Proposals taken from the STAGE_DESIGN segment names, for you to decide: CP1-A `Portal Selado` (beyond S1-04), CP1-B `Entrada do Santuário` (S1-06).
- **Hit radii.** Keep each radius the same across a type's visual variants (ENEMY_VISUAL_HANDOFF). Center it on the visible body: Aim Assist aims at `HitVolume` (F6-03).
- **Anticipation clip.** Pick one clip per Enemy Type from `Model/AnimationPlayer`: `Death`, `Fast_Flying`, `Flying_Idle`, `Headbutt`, `HitReact`, `No`, `Punch`, `Yes`. Judge it by eye. It must read within `anticipation_seconds` (1 s initial, STAGE_DESIGN); record its length, and the speed scale needed to fit.
  - If `EnemyActor` has no `anticipation_clip` export, the metadata records your choice. The dev Tween pulse stays the shipped cue, and the log names this as a follow-up for Claude.
- **Weapon and Bomb values** live on `PlayerShip/Weapon`, which only trunk edits. If pacing needs them changed, write "old → proposed" lines in the log:
  - the F6-03 shot and Tuning values;
  - `bomb_radius` and `bomb_damage`, keeping `bomb_damage` below the smallest Lantern Guardian Phase health.
- **Pacing table**, in `stage-01-pacing.md`. One row per segment:
  - the STAGE_DESIGN target: 15, 30, 25, 35, 40, 10, 85 s, total 240;
  - the route span, from entry Z to exit Z: 77, 77, 77, 82, 82, 27, 97 units;
  - traversal at the pinned `base_speed` 12;
  - combat: summed enemy `health` ÷ the damage per second at the Power Level the player holds there;
  - Wave delays, and the 1 s Anticipation before first fire.

  Power Level by segment: 1 in S1-02, 2 from S1-03 after S1-02's five pickups, and 3 from S1-06 after S1-05's. S1-07 uses `lantern_guardian.tres` if F12-03 has landed; otherwise use STAGE_DESIGN's 25/25/35 s, and mark it so. Straight flight covers 77 units in about 6.4 s, so S1-01 and S1-06 undershoot their targets. Say whether that is acceptable.
- **Measured clear.** If F10-03 and F11-01 have landed, play one Direct Stage 1. Record Results' Clear Time, whether checkpoints were retried, the starting Power, and Bombs used (STAGE_DESIGN "Time and score integrity"). Otherwise write "not measured". Never state an estimate as a measurement.
- **Five-minute fallback note.** List how Stage 1 would reach at least 300 s of efficient play, ranked by cost, each with its estimated seconds and its cost in feel:
  - common-enemy `health` and `attack_interval`;
  - second-Wave `delay`;
  - Lantern Guardian Phase health;
  - a third Wave in S1-02 or S1-05. This needs new markers in `stage_01.tscn` after F12-03, new content, and F8-04 test changes by Claude.

  Hard limits: no forced waiting (STAGE_DESIGN), no invulnerability padding (PLANEJAMENTO Section 4), and the approved structure stays. The user applies it at the SPRINT checkpoint, not this ticket.

## Acceptance

- `tools/test.ps1` green with no `SCRIPT ERROR`. It runs `test_content_validation.gd` (F8-01), `test_stage_01_content.gd` (F8-04) and `test_enemy_actor_contract.gd` (F9-02) over your values.
- If a visual scene got metadata: `tools/validate_enemy_visuals.gd` reports zero failures.
- `docs/validation/stage-01-anticipation.png`: the chosen clip mid-pose, one image per type, from `scenes/tests/enemy_variants_preview.tscn`, headless first, then windowed.
- `docs/validation/stage-01-pacing.md` holds the table, its total against 240 s, the measured clear or "not measured", and the fallback note.

## Handoff to Claude

One entry, `— Astra (sol) — Stage 1 tuning and pacing (D-05) [shared]`, State `SCENE_READY`, containing:

- every value changed, as old → new;
- the two names;
- the clip per type, and whether it has a consumer;
- the weapon and Bomb proposals for trunk;
- the estimated total and the fallback summary.

Consumers:

- F10-01 and F10-04: the content, which needs no code change;
- F11-01: Defeat shows the names;
- F11-03: takes the pacing total as its expected Clear Time;
- F14-02: the acceptance record;
- trunk: applies the weapon proposals;
- the user: the fallback, at the SPRINT checkpoint.

## Outcome

Reviewed the ten Stage 1 resources, two common-enemy Definitions, two patterns and both dev hit spheres. Health is 20 → 30 for Spirits and 30 → 45 for Sentries; attack intervals are 1.5 → 1.4 s and 2.0 → 1.8 s; spreads are 12 → 14° and 70 → 78°. The 1 s second-Wave delays, hit radii, movement and other pattern values remain as authored. `metadata/reviewed = true` accompanies each reviewed Resource while `metadata/dev = true` stays for existing validation. CP1-A is `Portal Selado`; CP1-B is `Entrada do Santuário`.

The four visuals carry candidate Anticipation metadata: Spirit `Yes`, Sentry `Punch`, both 1.167 s at source speed and about 1.17× for a one-second cue. The inspected mid-pose render is `docs/validation/stage-01-anticipation.png`; `EnemyActor` still plays its scale pulse because it has no clip export. No PlayerShip weapon or Bomb change is proposed; keep the measured 25° lock assist and the current 10-unit, 20-damage Bomb for now, with D-07 Part C keeping boss Phase health above Bomb damage.

`docs/validation/stage-01-pacing.md` estimates about 221 s for an efficient Stage 1 clear against the 240 s target. It labels the Lantern Guardian duration provisional, records no measured Clear Time, and lists an unapplied five-minute fallback for the user. A direct Results measurement awaits F10-03, F11-01 and F12-03. The D-06 pass 1 Stage 2 estimate used provisional 20/30 common-enemy health and must be recomputed in its later pass.

## Kickoff prompt

```
Read AGENTS.md, docs/engineering/SPRINT.md (lane sol), docs/GUIDE.md Sections 3 and 5 and .scratch/design-sprint/issues/05-stage-1-tuning-and-pacing.md, then deliver it in your worktree, log it in docs/HANDOFF_LOG.md, commit, and run tools/lane.ps1 land.
```
