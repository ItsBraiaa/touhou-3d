# F4-03 Boss panel, attack cue and threat API

Status: done
Type: adapter
parallel-safe: no
Depends on: F4-02
Lane: trunk
Model: Claude Opus 5.5, solo

## Goal

`Hud` gains the presentation API bosses and encounters call: a segmented boss health bar with a short name (two or three Phases), a brief attack-name cue that clears itself, and left and right threat indicators. The HUD only shows what it is told; it owns no boss or threat rule. After this ticket F10-01 can route `threat_reported(side)` and F12-03 the boss signals to the HUD with no further HUD work. The two-Phase layout (Tempest Sentinel) stays supported although F12-04 is cut pending the user.

## Read first

- `docs/GUIDE.md` Section 15 rows `BossStatus`, `BossName`, `Phase1`..`Phase3`, `AttackName`, `ThreatLeft`, `ThreatRight`, and Section 7 row "Boss phase changed"
- `docs/PLANEJAMENTO.md` Section 4 "Bosses and named attacks" and Section 7 "HUD" (segmented bar, short name, attack names only during transitions, simple directional warnings)
- `docs/STAGE_DESIGN.md` "Final boss sequence" (three Phases) and "Miniboss — Sentinela da Tempestade" (two)
- `.scratch/combat-hud/issues/02-hud-binding-and-target-marker.md` Outcome and `docs/engineering/combat-hud.md` "Hud contract"
- `scenes/ui/hud.tscn` (read only: `BossStatus` hidden, Phase bars side by side at x 16, 214, 412, `AttackName` hidden)

## Files

- **Creates:** `scenes/dev/hud_harness.tscn` and `scenes/dev/hud_harness.gd` (a scripted, input-free sequence over the HUD instance that captures screenshots; dev only, never loaded by `main.tscn`).
- **Edits:** `scripts/ui/hud.gd` (the API below); `tests/scene/test_hud_contract.gd` (new cases).
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F4-03 row), `docs/HANDOFF_LOG.md`, `docs/engineering/combat-hud.md` ("Boss panel, cue and threats" in the Hud contract), `docs/GUIDE.md` Section 6 `hud.gd` row and Section 7 row "Boss phase changed".
- **Must not touch:** `scenes/ui/hud.tscn` (Astra's), `scripts/session/game_session.gd` (the consumers wire it: F10-01, F12-03), `scripts/combat/combat_state.gd`, `tools/validate_hud_handoff.gd`.
- **Conflicts with:** F4-02 (`hud.gd`, `test_hud_contract.gd`; serialized by Depends on).

## Deliverables

All on `Hud`, each with a `##` doc comment. Presentation constants are exports with Claude's proposals for Astra to tune: `completed_phase_modulate: Color = Color(1, 1, 1, 0.3)`.

- `show_boss(display_name: String, phase_count: int)`: `BossStatus` visible, `BossName.text = display_name`, `Phase1`..`Phase<phase_count>` visible at 100 and lit, the others hidden. `phase_count` outside 2..3 is reported with `push_error` and clamped. A two-Phase boss hides `Phase3` and keeps the authored positions (layout is Astra's; see handoff notes).
- `set_phase_health(phase_index: int, ratio: float)`: 0-based; `Phase<index+1>.value = clampf(ratio, 0, 1) * 100`; a Phase at 0 gets `completed_phase_modulate`. An index outside the shown Phases is reported and ignored. The HUD does not infer Phase order: the boss says what each bar is.
- `show_attack_cue(text: String, seconds: float)`: `AttackName.text`, visible, hidden after `seconds`. A new cue replaces the text and restarts the timer. Cleared by `hide_boss()`.
- `hide_boss()`: hides `BossStatus` and `AttackName`, resets the bars to 100 and lit.
- `show_threat(side: int, seconds: float)`: `-1` shows `ThreatLeft`, `+1` `ThreatRight`, each hidden after its own timer; a repeat report extends the timer to `max(remaining, seconds)`. Any other side is reported and ignored.
- Timers count down in `_process` only while `get_tree().paused` is false: the HUD processes during pause (it lives under `Interface`), and PLANEJAMENTO Section 7 freezes combat timers under Pause.
- `unbind()` (F4-02) also calls `hide_boss()` and hides both threats, so a stage unload leaves nothing on screen.
- Portuguese text comes from the caller (Attack display names are in the boss Definitions, F12-01); the HUD adds none.

## Tests required

In `tests/scene/test_hud_contract.gd`:

- `test_show_boss_with_three_phases_shows_three_full_bars`
- `test_show_boss_with_two_phases_hides_the_third` (Tempest Sentinel layout)
- `test_phase_count_outside_two_or_three_is_clamped`
- `test_set_phase_health_moves_only_that_bar_and_dims_it_at_zero`
- `test_attack_cue_hides_after_its_seconds`, `test_a_new_cue_restarts_the_timer`
- `test_threat_left_and_right_show_and_expire_independently`, `test_repeated_threat_extends_its_timer`
- `test_cue_and_threat_timers_freeze_while_the_tree_is_paused` (reset `tree.paused` in `after_each`)
- `test_hide_boss_and_unbind_clear_the_boss_panel`

Grep the output for `SCRIPT ERROR`.

## Out of scope

Boss rules, Phase transitions and bullet clears (F12-01, F12-02); producing threats (F9-02 `threat_reported`, routed by F10-01); wiring either to the HUD in `game_session.gd` (F10-01 threats, F12-03 bosses); cue animation beyond show and hide; audio cues (F13 is cut pending the user); a re-layout of the Phase bars.

## Definition of Done

- `tools/test.ps1` green with no `SCRIPT ERROR`; the tests above exist; no Error-level warnings.
- Verified with `/run`: `scenes/dev/hud_harness.tscn` plays its scripted sequence (three-Phase `Guardião das Lanternas` draining Phase 1, a `Ritual das Lanternas` cue, left then right threats, a two-Phase `Sentinela da Tempestade`, `hide_boss`) headless first, then windowed, capturing `docs/validation/combat-hud-boss-3.png` and `combat-hud-boss-2.png`; recorded in `docs/validation/combat-hud.md`.
- `docs/engineering/combat-hud.md` updated; GUIDE Section 6 `hud.gd` row complete; handoff log entry; ticket `Status: done` with an Outcome; roadmap row.
- One commit: `ui: [shared] add the HUD boss panel, attack cue and threat API`.

## Handoff notes for Astra

With two Phases, `Phase3` is hidden and the right third of `BossStatus` stays empty (bars at x 16, 214, 412). If that reads badly, author a two-Phase arrangement (for example `Phase1` and `Phase2` widened) and say which node positions the code should switch between; the code only toggles visibility today. `completed_phase_modulate` is Claude's proposal. Threat indicators are side warnings only; vertical and behind-the-player coverage stays as GUIDE Section 15 describes (not a full 3D warning system).

## Outcome (2026-09-23)

Delivered in lane trunk, solo, as specified: `show_boss`, `set_phase_health`, `show_attack_cue`, `hide_boss`, `show_threat` and the `completed_phase_modulate` export on `Hud`; `unbind()` clears the panel, the cue and both threats; cue and threat timers stand still while the tree is paused.

- **No new tests.** The user's sprint rule of 2026-09-23 (relayed by the planning session) drops the "Tests required" section. The ten listed cases are covered instead by `scenes/dev/hud_harness.tscn`, a self-checking scripted run (26 checks, `HUD_HARNESS_OK` headless and windowed) that also captures `combat-hud-boss-3.png` and `combat-hud-boss-2.png`. The existing suite stays green at 225.
- **Readings:** a Phase raised above 0 is lit again; a node's timer runs while it is visible, so a cue of 0 seconds hides on the next unpaused frame; with two Phases the right third of the panel stays empty (handoff note below).

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/combat-hud/issues/03-boss-panel-and-attack-cue-api.md, then implement that ticket. Use /run to verify the boss panel, attack cue and threat indicators in scenes/dev/hud_harness.tscn. Finish with its Definition of Done and commit.
```
