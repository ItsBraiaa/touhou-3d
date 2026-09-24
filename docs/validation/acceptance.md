# Acceptance record

F14-02 part 2, 2026-09-24, lane `oc-b`. One row per acceptance check in
[PLANEJAMENTO.md Section 12](../PLANEJAMENTO.md) and in
[STAGE_DESIGN.md "Acceptance checks for stage progression"](../STAGE_DESIGN.md).
Part 1b drafted the rows; this page fills in the results after F14-01's export and this
ticket's package run.

Status vocabulary: `pass` (a scripted run or the package proves it), `fail`, `not verified`
(no evidence), `not verified (cut)` (only where the user cut it — none here), `not verified
(not landed)` (the delivering ticket never landed — none here).
[SPRINT.md](../engineering/SPRINT.md) "Product decisions" reinstates F3, F13 and Stage 2, so
nothing is "not verified (cut)".

**Every check below is scripted.** No physical keyboard, DualSense, listening, played-time or
presentation-computer pass was run for this record. Where a check needs one, the row says so
and repeats **owed by the human pass**; those items are collected again in the summary. The
evidence links are the validation pages and the `STAGE_RESULT` lines they quote.

## Header

- Date: 2026-09-24.
- Host: the development PC — Windows 11 Pro 10.0.26200, AMD Radeon RX 9070 XT, D3D12 12_0
  Forward+, monitor 2560 × 1440.
- Commit: `dev-01` `b215f01` with this ticket's docs-only commit on `lane/oc-b` (`F14-02 part
  2`). The packaged commit is the one recorded in [export.md](export.md) "Package".
- Build (from F14-01): `build/Touhou-3D.exe` 129,258,616 bytes and
  `build/Touhou-3D.console.exe` 91,136 bytes, preset "Windows Desktop", re-exported for this
  ticket from the synced tree and byte-identical to F14-01's build
  ([export.md](export.md)). Both are git-ignored.
- Input devices: none physical. Keyboard and gamepad events were scripted
  (`Input.action_press`, `Viewport.push_input`, `joy_connection_changed`,
  `Input.parse_input_event`). A simulated gamepad is not a physical pass
  (ENGINEERING_BRIEF Section 8).
- Physical or scripted: scripted.

## PLANEJAMENTO Section 12 (18 checks)

| # | Check | Source | Delivered by | Status and evidence |
| --- | --- | --- | --- | --- |
| P1 | Campaign runs from Stage 1 to final victory. | PLANEJAMENTO 12, line 300 | F11-02, F10-03, F12-03, F12-07 | **pass (scripted).** [run-flow.md](run-flow.md) F11-02 "Campaign Stage 2 clear: the final victory" (heading `Jornada concluída`, one `run_ended [true]`); [clear-time.md](clear-time.md) "The Campaign's final clear". A played campaign is owed by the human pass. |
| P2 | Both stages launch directly from the menu and can be completed. | PLANEJAMENTO 12, line 301 | F11-02, F12-05, F10-01 | **pass (scripted).** [menus.md](menus.md) Direct Stage 1 and 2 from the menu; [run-flow.md](run-flow.md) "Jogar novamente, Direct Stage 1 and 2"; [stage-01-progression.md](stage-01-progression.md) check 13 and [stage-02-progression.md](stage-02-progression.md) (both Direct Stage 2 orders completed). |
| P3 | Stage 2 provides at least five minutes of active gameplay, including an efficient-clear check without stalling. | PLANEJAMENTO 12, line 302 | F12-04, F12-05, D-06, F11-03 | **not verified — owed by the human pass.** [clear-time.md](clear-time.md) §3 step 5: "not measured, owed by the human pass (F14-02)". [stage-02-pacing.md](stage-02-pacing.md) gives a conditional estimate of about 336 s efficient, not a measured clear. |
| P4 | All-axis movement and boss orbiting materially affect dodging. | PLANEJAMENTO 12, line 303 | F1-01/F1-02, F12-02, F1-03 | **pass (scripted).** [player-flight.md](player-flight.md) measures all six axes, camera-relative motion, the orbit and lock framing at Low/Middle/High targets; [stage-02-pacing.md](stage-02-pacing.md) pass 3 has boss patterns alternating height. The "materially" judgement in motion is owed by the human pass. |
| P5 | Gameplay and menus work completely on keyboard and gamepad. | PLANEJAMENTO 12, line 304 | F2-02, F3-03, F1-02 | **pass (scripted; keyboard and gamepad).** [menus.md](menus.md) "Scripted menu-to-flight pass" runs every step on keyboard and on gamepad; [settings.md](settings.md) run 2 covers the device-mode prompts. A **physical** keyboard and DualSense pass is owed by the human pass. |
| P6 | Combat UI contains essential information only, with no tutorial boxes, written objective lists, or mandatory dialogue. | PLANEJAMENTO 12, line 305 | F4-02, F4-03 | **pass.** [combat-hud.md](combat-hud.md) shows only the bound panel, target marker, boss panel, attack cue and threats (F4-02, F4-03); [stage-01-progression.md](stage-01-progression.md) and [stage-02-progression.md](stage-02-progression.md) drove both routes with no tutorial or objective text. |
| P7 | Shield absorbs exactly one hit; post-hit invulnerability prevents cascading damage. | PLANEJAMENTO 12, line 306 | F4-01, F7-01 | **pass.** [combat.md](combat.md) checks 1–4, 7, 8: the first hit drops the Shield only, a hit during the window is passed through, two Projectiles in one tick count as one hit. |
| P8 | Bomb consumes one charge, clears its intended volume, and cannot generate artificial graze. | PLANEJAMENTO 12, line 307 | F7-02, F5-03 | **pass.** [combat.md](combat.md) Bomb checks 14–21, including check 16b (no artificial graze from the clear) and the one-charge-per-press checks 15 and 20. |
| P9 | Each bullet awards at most one graze; hit detection takes precedence over proximity rewards. | PLANEJAMENTO 12, line 308 | F5-02 | **pass.** [combat.md](combat.md) checks 5–6 (one graze per pass; none while Invulnerable); [stage-director.md](stage-director.md) F10-05 graze and Pickup counts stay single. F5-02 landed (ROADMAP). |
| P10 | Power and familiars evolve through pickups; direct Stage 2 starts at power level 2. | PLANEJAMENTO 12, line 309 | F7-03, F6-03, F11-02 | **pass.** [combat.md](combat.md) check 12 and "Pickups" (ten Pickups reach Power Level 3, the eleventh gives score); [run-flow.md](run-flow.md) "Direct Stage entry values": Direct Stage 2 starts at Power 2. |
| P11 | Each final boss executes three named attacks with reachable gaps; Stage 2 also includes its two-phase miniboss and three-seal challenge. | PLANEJAMENTO 12, line 310 | F12-03, F12-06, F12-07, F9-03 | **pass (scripted).** [bosses.md](bosses.md) "Lantern Guardian in S1-07" (three named Phases) and Tempest Sentinel two-Phase / Storm Guardian three-Phase; [stage-02-progression.md](stage-02-progression.md) drives the three Seals. Gap reachability in a played fight is owed by the human pass. |
| P12 | Checkpoints restore the specified state without duplicating items, bullets, or score. | PLANEJAMENTO 12, line 311 | F8-03, F10-02 | **pass.** [stage-01-progression.md](stage-01-progression.md) F10-02 checks 9–11 and F10-03 checks 1–7; [stage-director.md](stage-director.md) F10-05 (Pickups restored, not duplicated); [stage-02-progression.md](stage-02-progression.md) CP2-A/CP2-B retries. |
| P13 | Pause freezes combat; options persist; controller disconnection is recoverable. | PLANEJAMENTO 12, line 312 | F2-04, F3-01/F3-02, F3-03 | **pass (scripted).** Pause freezes combat: [combat.md](combat.md) check 8, [run-flow.md](run-flow.md) "Frozen under Results". Options persist: [settings.md](settings.md) run 2 relaunch reads the saved values. Controller disconnect: [settings.md](settings.md) run 2 simulated unplug pauses; a **real** unplug is owed by the human pass. |
| P14 | The unique ship has simple animation and bosses have more elaborate animation; at least one boss clearly animates its model. | PLANEJAMENTO 12, line 313 | D-03, D-04, D-02, F12-03 | **pass (scripted).** Bosses: [bosses.md](bosses.md) accepts and plays the `Flying_Idle`, `Punch`, `Yes` and `Death` clips. Ship and effects: [combat-visuals.md](combat-visuals.md) (Familiar hover, Pickup float, Bomb blast), [player-flight.md](player-flight.md) banking. The in-motion look is owed by the human pass. |
| P15 | 3D environments, WorldEnvironment, graphical interfaces, and audio are present. | PLANEJAMENTO 12, line 314 | D-07, D-01, F13-02/F13-03, F4, F2-02 | **pass (scripted).** Environments and lighting: [stage-01-shrine.md](stage-01-shrine.md), [stage-02.md](stage-02.md). Interfaces: [menus.md](menus.md), [combat-hud.md](combat-hud.md). Audio: [audio.md](audio.md) F13-03/F13-04 (17 events, one voice each, cap 8). The **listening pass** is owed by the human pass; the assignment PDF requires sound effects. |
| P16 | Complete runs have no progression blockers. Performance is measured on the presentation computer with an initial target of 60 FPS. | PLANEJAMENTO 12, line 315 | F10-01/F10-02/F10-03, F12-05, F6-02 | **pass on the development PC; the presentation computer is not verified.** No blockers: [clear-time.md](clear-time.md) and [run-flow.md](run-flow.md) complete both routes end to end. 60 FPS: [export.md](export.md) §5 (59–60 FPS in every boss fight, over 1,100 uncapped). The presentation-computer protocol is **owed by the human pass**. |
| P17 | The exported build runs outside the editor on the target computer; the project package includes credits and licenses. | PLANEJAMENTO 12, line 316 | F14-01, F14-02 | **pass on the development PC; the target computer is not verified.** Build runs outside the repository: [export.md](export.md). The package carries `project/docs/ASSET_CREDITS.md` and `project/assets/licenses/` (this record's "Credits coverage"). The target/presentation computer is **owed by the human pass**. |
| P18 | The group has confirmed instructor approval of the chosen adaptation. | PLANEJAMENTO 12, line 317 | the user (not a lane ticket) | **not verified — the user's.** No lane can record the group's instructor approval; it is the user's action before delivery. |

## STAGE_DESIGN "Acceptance checks for stage progression" (14 checks)

| # | Check | Source | Delivered by | Status and evidence |
| --- | --- | --- | --- | --- |
| S1 | Stage 1 progresses through all seven segments and contains no miniboss. | STAGE_DESIGN, line 147 | F10-01, F8-04 | **pass.** [stage-01-progression.md](stage-01-progression.md) check 13 (`encounter_completed` S1-01 to S1-07, `stage_cleared` once, no miniboss); [stage-director.md](stage-director.md) F10-01. |
| S2 | Stage 2 progresses through all seven segments and includes one two-phase miniboss. | STAGE_DESIGN, line 148 | F12-05, F12-06, F12-04 | **pass (scripted).** [stage-02-progression.md](stage-02-progression.md) walks all seven segments; [bosses.md](bosses.md) "Tempest Sentinel (F12-06 part 2)" is the two-Phase miniboss; [clear-time.md](clear-time.md) Stage 2 clears the full route. |
| S3 | Every required enemy and seal is reachable with keyboard and gamepad controls. | STAGE_DESIGN, line 149 | F9-03, F12-05, F3-03 | **pass (scripted).** [menus.md](menus.md) and [run-flow.md](run-flow.md) reach every flow on keyboard and gamepad; [stage-02-progression.md](stage-02-progression.md) reaches all three Seals. A **physical** keyboard and pad pass is owed by the human pass. |
| S4 | All six seal orders can open the Stage 2 gate; revisiting a seal cannot reset it or duplicate a reward. | STAGE_DESIGN, line 150 | F9-03, F12-05 | **pass (scripted).** [stage-02-progression.md](stage-02-progression.md) ran Seal orders 1→2→3 and 3→1→2 and accumulated each in the chosen order; `SealRules` is order-independent (per-Seal guard sets), so the other four orders follow. A hit on a shielded Seal leaves health 10; a defeated Seal does not return. |
| S5 | Flying over/under a locked gate cannot skip the required encounter. | STAGE_DESIGN, line 151 | F10-02, F10-01 | **pass.** [stage-01-progression.md](stage-01-progression.md) check 4: the closed Gate stops the ship at Z −223.45 from Y 5, Y 37.5, Y 74, (40, 40) and (−40, 60). |
| S6 | A bomb kill of the last guard/enemy advances the encounter exactly once. | STAGE_DESIGN, line 152 | F7-02, F8-02, F10-01 | **pass.** [stage-01-progression.md](stage-01-progression.md) check 8: one Bomb sweep kills the last two guards, `gate_opened` and `encounter_completed(S1-04)` fire once, +200 once. |
| S7 | Dying before and after each checkpoint restores the correct segment and resources. | STAGE_DESIGN, line 153 | F8-03, F10-02, F10-03 | **pass.** [stage-01-progression.md](stage-01-progression.md) F10-03 checks 1–4 (before any Checkpoint restarts, after CP1-A resumes at S1-05, after CP1-B at the boss approach). |
| S8 | Death after the miniboss but before CP2-B restores CP2-A; death at the final boss restores CP2-B. | STAGE_DESIGN, line 154 | F12-05, F8-03, F10-03 | **pass.** [clear-time.md](clear-time.md) "Retry after the miniboss rolls back to CP2-A" (3.9333 → 2.0000 s, score back to 4100); [stage-02-progression.md](stage-02-progression.md) S2-07 entry activated `Limiar do Cume` and Retry restored (0, 98, −600). |
| S9 | Power progress, score, graze, bombs-used statistics, and successful-path time restore without farming failed attempts. | STAGE_DESIGN, line 155 | F8-03, F11-03, F10-03 | **pass.** [clear-time.md](clear-time.md) "Retry rolls back the failed segment" and "Failed Attempts cannot inflate Clear Time" (score, graze and bombs-used roll back; a clear with three failed attempts reads 2.0167 s, `attempt=4`); [stage-01-progression.md](stage-01-progression.md) check 5. |
| S10 | Entering a checkpoint twice cannot repeatedly refill resources. | STAGE_DESIGN, line 156 | F8-03, F10-02 | **pass.** [stage-01-progression.md](stage-01-progression.md) check 11 (damaged to 70, out and back: no second activation, still 70) and F10-03 check 7. |
| S11 | Restart Stage and isolated stage selection use the correct stage-entry values. | STAGE_DESIGN, line 157 | F10-03, F11-02 | **pass.** [run-flow.md](run-flow.md) "Direct Stage entry values" (Direct Stage 1 Power 1, Direct Stage 2 Power 2, score 0, Shield, 2 Bombs) and "Restart in Campaign Stage 2"; [stage-01-progression.md](stage-01-progression.md) check 10. |
| S12 | Every route is readable without tutorial boxes or written objective lists. | STAGE_DESIGN, line 158 | F4-02/F4-03, D-05, F10-01 | **pass.** [combat-hud.md](combat-hud.md) and [menus.md](menus.md) show HUD-only combat UI and no objective text; [stage-01-pacing.md](stage-01-pacing.md) routes each segment with a visible exit condition. |
| S13 | Stage 2 uninterrupted efficient clear reaches at least five active minutes through actual gameplay. | STAGE_DESIGN, line 159 | D-06, F12-05, F11-03 | **not verified — owed by the human pass.** [clear-time.md](clear-time.md) §3 step 5 and [stage-02-pacing.md](stage-02-pacing.md) pass 3: a conditional about 336 s efficient estimate, no measured clear. |
| S14 | Boss patterns remain avoidable from different heights and do not permit a permanent risk-free perch. | STAGE_DESIGN, line 160 | F12-01/F12-02, F12-03, F12-06, F12-07 | **pass (pattern design); a full play pass is owed by the human pass.** [stage-02-pacing.md](stage-02-pacing.md) pass 3 (spirals climb and descend, rings alternate high and low with a 72° gap, aim alternates high and low); [stage-01-shrine.md](stage-01-shrine.md) (ring steps alternate high and low, aimed bursts follow the player's height). The pacing page notes these are readable proposals until a play pass checks safe corridors. |

## Credits coverage (F14-02)

Every tracked file under `assets/` was listed and matched to a
[ASSET_CREDITS.md](../ASSET_CREDITS.md) entry, and the result was compared with the in-game
Créditos text in `scenes/ui/credits.tscn`.

| Group | Files | Credit | License |
| --- | --- | --- | --- |
| `assets/models/enemies/`, `assets/models/bosses/` | Quaternius glTFs and their `_Atlas_Monsters.png` copies | ASSET_CREDITS "Stage 1 common enemy visuals", "Boss models" | `assets/licenses/quaternius-ultimate-monsters.txt` (CC0) |
| `assets/models/player/craft_speederA.glb` | Kenney Space Kit | ASSET_CREDITS "Player ship" | `assets/licenses/kenney-space-kit.txt` (CC0) |
| `assets/audio/sfx/interface/`, `digital/`, `scifi/`, `impact/` | 17 Kenney Ogg files | ASSET_CREDITS "Sound effects" | `assets/licenses/kenney-*.txt` (CC0) |
| `assets/ui/*.svg`, `assets/ui/menu_theme.tres` | original project art | ASSET_CREDITS "Menu artwork", "HUD icons" | original, none needed |
| `assets/combat/*.tres` | five original D-02 materials | ASSET_CREDITS "Combat materials" | original, none needed |
| `assets/environment/stage_01/gate_veil.gdshader` | original Stage 1 gate veil shader | ASSET_CREDITS "Stage 1 gate veil" | original, none needed |
| `assets/environment/stage_02/**` | original OBJ meshes and shaders | ASSET_CREDITS "Stage 2 mountain environment" | original, none needed |
| `assets/licenses/*` | the six license texts | the credits above | — |

**Credits gaps closed by Astra (sol):** `ASSET_CREDITS.md` now names the five
original D-02 materials and the original Stage 1 gate veil shader. The in-game
Créditos screen now credits Quaternius's Ultimate Monsters enemy and boss models
alongside the Kenney ship and sound effects.

## Summary

- **Fails:** none. The package script's archive root (the zip did not contain its
  `Touhou-3D/` folder, so the documented verify path failed) was found and fixed inside this
  ticket; see [export.md](export.md) "Package".
- **Not verified:** P3 and S13 (the five-minute Stage 2 clear), P18 (the group's instructor
  approval, the user's).
- **Not verified (cut):** none. [SPRINT.md](../engineering/SPRINT.md) reinstates F3, F13 and
  Stage 2; the user cut nothing at a checkpoint.
- **Owed by the human pass** (each row above says so):
  - the physical keyboard and DualSense passes (P5, P13, S3), including a real controller
    unplug;
  - the sound-effects listening pass (P15);
  - the played Stage 1 and Stage 2 clear times and the five-minute Stage 2 measurement (P3,
    S13), per [clear-time.md](clear-time.md);
  - the presentation-computer run and its 60 FPS reading (P16, P17), per
    [export.md](export.md);
  - the played campaign and boss fights for the in-motion judgements (P1, P4, P11, P14, S14).
- **Astra credits requests:** all three gaps above are closed in the asset record and the
  in-game Créditos screen.
