# F12-01 BossMachine core and boss Definitions

Status: done
Type: core
parallel-safe: yes
Depends on: F5-04
Lane: path
Model: Claude Opus 5.5, solo

> **Sprint note:** Stage 2 is reinstated, so the Sentinel (F12-06, two Phases) and the Storm Guardian (F12-07, three Phases) will use this core; keep both configurations fully tested. D-07 Part B rules on damage during a Phase transition. Until that ruling lands, keep this ticket's reading, in one named test, so a different ruling flips one assertion.

## Goal

A Node-free `BossMachine` that runs a Boss's Phases (PLANEJAMENTO Section 4 "Bosses and named attacks"). Each Phase has its own health. Excess damage never skips a Phase. Depleting a Phase clears hostile Projectiles, announces the next Attack's Portuguese name and starts it after a short readable transition. An Attack is an ordered, cycling sequence of Pattern steps, each with a visible Anticipation and a fire-time aim sample. Defeat happens exactly once. Two-Phase (Tempest Sentinel) and three-Phase (both Guardians) bosses use the same code. The Definitions it reads are created here too.

## Read first

- `docs/PLANEJAMENTO.md` Section 4 "Bosses and named attacks", "Graze and score" (1,000 per final boss)
- `docs/STAGE_DESIGN.md` Stage 1 "Final boss sequence", Stage 2 "Miniboss" and "Final boss sequence" (what the steps must express: alternating heights, sampled aim after a charge, altitude tracking, repositioning windows)
- `docs/ENGINEERING_BRIEF.md` Section 4.F and Section 8 ("Boss phase overflow and exactly-once defeat")
- `.scratch/projectile-field/issues/04-pattern-emitter-core.md` and its **Outcome** (the `PatternDefinition` fields and `PatternEmitter` API; the Outcome wins)
- `docs/engineering/enemies.md` (F9-01's Anticipation and sampled-aim cycle, which bosses mirror) if it exists; `CONTEXT.md` Boss, Phase, Attack, Anticipation

## Files

- **Creates:** `scripts/definitions/boss_definition.gd`, `scripts/definitions/boss_phase_definition.gd`, `scripts/definitions/attack_definition.gd`, `scripts/definitions/attack_step_definition.gd`, `scripts/enemies/boss_machine.gd`, `tests/unit/definitions/test_boss_definitions.gd`, `tests/unit/enemies/test_boss_machine.gd`, `docs/engineering/bosses.md`.
- **Edits:** none.
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F12-01 row), `docs/HANDOFF_LOG.md`, `docs/engineering/bosses.md` (new) and its line in `docs/engineering/README.md`.
- **Must not touch:** `scripts/combat/pattern_emitter.gd`, `scripts/definitions/pattern_definition.gd` (F5-04), `scripts/enemies/enemy_model.gd` and `scripts/definitions/enemy_definition.gd` (F9-01), `content/` (F12-03).
- **Conflicts with:** none. F9-01 may run alongside it; it creates other files in `scripts/enemies/`, `scripts/definitions/` and `tests/unit/`.

## Deliverables

- `AttackStepDefinition`: `pattern: PatternDefinition`, `anticipation_seconds: float` (the charge before this step fires), `height_offset: float` (emission height relative to the boss origin), `follow_player_height: bool` (emit at the player's sampled altitude, as in Fios de Luz's fans and the Sentinel's altitude tracking), `pause_after: float`.
- `AttackDefinition`: `display_name: String` (Portuguese, for example `"Ritual das Lanternas"`), `steps: Array[AttackStepDefinition]`, `reposition_seconds: float` (a quiet window after the last step before the cycle repeats).
- `BossPhaseDefinition`: `health: int`, `attack: AttackDefinition`, `transition_seconds: float` (the readable pause after a Phase ends, before its Attack starts).
- `BossDefinition`: `kind: StringName` (`&"lantern_guardian"`), `display_name: String`, `score: int`, `entry_seconds: float` (1.0: bosses also appear before shooting), `phases: Array[BossPhaseDefinition]`.
- `validate()` on each: 2 or 3 Phases (CONTEXT "Boss"); non-empty names; `health > 0`; at least one step; valid patterns; no negative time.
- `class_name BossMachine extends RefCounted`:
  - `setup(definition, enemy_id: StringName, encounter_id: StringName, rng: RandomNumberGenerator)` asserts the definition is valid; every Phase is full.
  - `start()` emits `phase_changed(0, phases[0].attack.display_name)`; the first step waits `entry_seconds`.
  - `tick(delta, origin: Vector3, player_position: Vector3) -> Array[ProjectileSpawn]`: for each step, emit `step_started(step_index)` as its Anticipation begins. When the Anticipation ends, sample the aim point once. The emission origin is `origin + (0, height_offset, 0)`, or the player's sampled Y when `follow_player_height`. Run the step's `PatternEmitter` (created with the injected RNG) until `is_finished()`, then `pause_after`, then the next step. After the last step comes `reposition_seconds`, then step 0 again. Nothing is emitted during a transition or once defeated.
  - `take_damage(amount: int) -> int` returns the damage applied. It is ignored (0) once defeated or during a transition. Damage is capped at the current Phase's remaining health, so the excess is discarded, and `phase_health_changed(index, ratio)` fires on every accepted hit. Depleting a non-final Phase emits, in order, `phase_health_changed(i, 0.0)`, `hostile_clear_requested()` and `phase_changed(i + 1, name)`, then starts `transition_seconds`, with the emitter stopped and the step reset. Depleting the final Phase emits `phase_health_changed(last, 0.0)`, `hostile_clear_requested()` and `defeated(enemy_id, encounter_id)`, exactly once.
  - Getters: `get_phase_index()`, `get_phase_count()`, `get_phase_ratio(index)`, `is_in_transition()`, `is_defeated()`, `get_score()`.
- Design reading to confirm with Astra (Open issues): damage is refused only during the short `transition_seconds`, which is a readable transition bounded per Phase and not a padding timer (PLANEJAMENTO forbids "artificial invulnerability timers").

## Tests required

`tests/unit/definitions/test_boss_definitions.gd`: `test_valid_three_phase_boss_has_no_errors`, `test_boss_needs_two_or_three_phases`, `test_phase_and_attack_rules_are_reported`.

`tests/unit/enemies/test_boss_machine.gd` (fixed seed, code-built definitions):

- `test_start_announces_the_first_attack`
- `test_first_step_waits_for_the_entry_anticipation`
- `test_excess_damage_never_skips_a_phase` (10× Phase health in one hit: Phase 1 full, index 1)
- `test_two_hits_in_one_tick_cannot_skip_a_phase`
- `test_depleting_a_phase_clears_then_announces_the_next_attack` (signal order)
- `test_damage_is_ignored_during_the_transition`
- `test_three_phase_boss_is_defeated_once`, `test_two_phase_boss_is_defeated_after_its_second_phase`
- `test_defeat_clears_hostile_projectiles`
- `test_steps_play_in_order_and_cycle_after_the_reposition_window`
- `test_aimed_step_samples_the_player_at_fire_time`, `test_follow_player_height_emits_at_the_player_altitude`
- `test_phase_health_ratio_is_reported_on_every_hit`
- `test_same_seed_gives_the_same_projectiles`

## Out of scope

Nodes, animation cues, the hit sphere, HUD (F12-02); Lantern Guardian values (F12-03); Sentinel and Storm Guardian content (F12-04, cut); boss movement beyond the emission height (the controller hovers the boss).

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR` in the output. Named tests cover ENGINEERING_BRIEF Section 8 "boss phase overflow and exactly-once defeat" and 4.F "excess damage cannot skip boss phases; phase transitions clear previous threats". No Error-level warnings.
- `docs/engineering/bosses.md` written from `TEMPLATE.md`, with its README line.
- Handoff log entry; `Status: done` with an Outcome; ROADMAP row.
- One commit: `enemies: add BossMachine core and boss Definitions`.

## Handoff notes for Astra

Attack names are Portuguese literals in the Definitions (F12-03 content). Clip choices come in F12-02. Nothing to wire.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/bosses/issues/01-boss-machine-core.md, then implement that ticket with /mattpocock-skills:tdd. Finish with its Definition of Done and commit.
```

## Outcome (2026-09-23)

Delivered solo in lane path: the four Definitions and `scripts/enemies/boss_machine.gd`, with the contract in `docs/engineering/bosses.md`. **No unit tests:** the sprint's no-new-tests rule voids the "Tests required" list and the named-test line of the Definition of Done. The five scripts pass Godot's `--check-only` parse check with warnings as errors, and the land gate runs the existing suite and the boot smoke. Nothing runs the machine until F12-02.

- **Ruling 1 applied.** D-07 Part B confirmed no damage during a Phase transition, bounded to 0.75 s. `BossPhaseDefinition.MAX_TRANSITION_SECONDS` is 0.75, and `validate()` rejects anything above it. Damage is accepted in the entry window and in every step state.
- **Entry reading.** `entry_seconds` is a window before step 0's own Anticipation, so every shot, the first included, follows a `step_started` cue. Recorded as an Open issue.
- **`follow_player_height`** emits at `(origin.x, sampled player y, origin.z)` and ignores `height_offset`. The Pattern's own per-volley `height_offsets` still apply on top.
- **Signal order on depletion:** `phase_health_changed(i, 0.0)`, `hostile_clear_requested`, then `phase_changed(i + 1, name)` or `defeated`. The state has already moved on when they fire, so a re-entrant `take_damage` returns 0.
- **Added beyond the ticket, both small:**
  - `AttackStepDefinition.get_duration()`, used by a new `AttackDefinition.validate()` rule: one cycle must take time, or `tick` would loop forever.
  - `start()` resets every Phase, so calling it again restarts the fight.
