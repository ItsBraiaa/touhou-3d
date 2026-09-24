# Acceptance record

Draft by lane `oc-b`, F14-02 part 1b (2026-09-24). This page holds one row per
acceptance check in [PLANEJAMENTO.md Section 12](../PLANEJAMENTO.md) and in
[STAGE_DESIGN.md "Acceptance checks for stage progression"](../STAGE_DESIGN.md).
F14-02 part 2 fills in the results after F14-01's export.

Every row starts at **not yet verified** by design. A row becomes `pass` or `fail`
only with evidence recorded in F14-02 part 2 (a validation file, a test name or a
`STAGE_RESULT` line). Stage 2 and every reinstated F3/F13 item are in scope: per
SPRINT.md "Product decisions", nothing is "not verified (cut)" unless the user cuts
it at a checkpoint; a ticket that has not landed by delivery is "not verified (not
landed)".

## Header (filled by F14-02 part 2)

- Date:
- Host:
- Commit:
- Build (from F14-01):
- Input devices:
- Physical or scripted:

## PLANEJAMENTO Section 12 (18 checks)

| # | Check | Source | Delivered by | Status |
| --- | --- | --- | --- | --- |
| P1 | Campaign runs from Stage 1 to final victory. | PLANEJAMENTO 12, line 300 | F11-02 (campaign continuation), F10-03, F12-03, F12-07 | not yet verified |
| P2 | Both stages launch directly from the menu and can be completed. | PLANEJAMENTO 12, line 301 | F11-02 (direct stage), F12-05 (Stage 2 route), F10-01 | not yet verified |
| P3 | Stage 2 provides at least five minutes of active gameplay, including an efficient-clear check without stalling. | PLANEJAMENTO 12, line 302 | F12-04 (content), F12-05, D-06 (pacing review), F11-03 (measurement) | not yet verified |
| P4 | All-axis movement and boss orbiting materially affect dodging. | PLANEJAMENTO 12, line 303 | F1-01/F1-02 (FlightModel), F12-02 (BossController), F1-03 (camera) | not yet verified |
| P5 | Gameplay and menus work completely on keyboard and gamepad. | PLANEJAMENTO 12, line 304 | F2-02 (interface and menu controller), F3-03 (input-device mode and controller disconnect), F1-02 | not yet verified |
| P6 | Combat UI contains essential information only, with no tutorial boxes, written objective lists, or mandatory dialogue. | PLANEJAMENTO 12, line 305 | F4-02 (HUD binding), F4-03 (boss panel and cues) | not yet verified |
| P7 | Shield absorbs exactly one hit; post-hit invulnerability prevents cascading damage. | PLANEJAMENTO 12, line 306 | F4-01 (CombatState core), F7-01 (hit to combat state) | not yet verified |
| P8 | Bomb consumes one charge, clears its intended volume, and cannot generate artificial graze. | PLANEJAMENTO 12, line 307 | F7-02 (bomb clear and invulnerability), F5-03 (bomb-phase clears) | not yet verified |
| P9 | Each bullet awards at most one graze; hit detection takes precedence over proximity rewards. | PLANEJAMENTO 12, line 308 | F5-02 (hit sweep and graze rules) | not yet verified |
| P10 | Power and familiars evolve through pickups; direct Stage 2 starts at power level 2. | PLANEJAMENTO 12, line 309 | F7-03 (pickups and rewards), F6-03 (familiar), F11-02 (direct-stage entry values) | not yet verified |
| P11 | Each final boss executes three named attacks with reachable gaps; Stage 2 also includes its two-phase miniboss and three-seal challenge. | PLANEJAMENTO 12, line 310 | F12-03 (Lantern Guardian), F12-06 (Tempest Sentinel miniboss), F12-07 (Storm Guardian), F9-03 (Seals) | not yet verified |
| P12 | Checkpoints restore the specified state without duplicating items, bullets, or score. | PLANEJAMENTO 12, line 311 | F8-03 (snapshot capture/restore), F10-02 (gate and checkpoint adapters) | not yet verified |
| P13 | Pause freezes combat; options persist; controller disconnection is recoverable. | PLANEJAMENTO 12, line 312 | F2-04 (pause), F3-01/F3-02 (options persistence), F3-03 (controller disconnect) | not yet verified |
| P14 | The unique ship has simple animation and bosses have more elaborate animation; at least one boss clearly animates its model. | PLANEJAMENTO 12, line 313 | D-03 (Lantern Guardian scene), D-04 (Stage 2 boss scenes), D-02 (combat visuals), F12-03 | not yet verified |
| P15 | 3D environments, WorldEnvironment, graphical interfaces, and audio are present. | PLANEJAMENTO 12, line 314 | D-07 (shrine lighting), D-01 (sfx), F13-02/F13-03 (audio wiring), F4 (HUD/UI), F2-02 | not yet verified |
| P16 | Complete runs have no progression blockers. Performance is measured on the presentation computer with an initial target of 60 FPS. | PLANEJAMENTO 12, line 315 | F10-01/F10-02/F10-03 (Director, Gates, Retry), F12-05, F6-02 (benchmark) | not yet verified |
| P17 | The exported build runs outside the editor on the target computer; the project package includes credits and licenses. | PLANEJAMENTO 12, line 316 | F14-01 (export and run), F14-02 (package and credits coverage) | not yet verified |
| P18 | The group has confirmed instructor approval of the chosen adaptation. | PLANEJAMENTO 12, line 317 | the user (not a lane ticket) | not yet verified |

## STAGE_DESIGN "Acceptance checks for stage progression" (14 checks)

| # | Check | Source | Delivered by | Status |
| --- | --- | --- | --- | --- |
| S1 | Stage 1 progresses through all seven segments and contains no miniboss. | STAGE_DESIGN, line 147 | F10-01 (stage director adapter), F8-04 (Stage 1 content) | not yet verified |
| S2 | Stage 2 progresses through all seven segments and includes one two-phase miniboss. | STAGE_DESIGN, line 148 | F12-05 (Stage 2 director integration), F12-06 (Tempest Sentinel miniboss), F12-04 | not yet verified |
| S3 | Every required enemy and seal is reachable with keyboard and gamepad controls. | STAGE_DESIGN, line 149 | F9-03 (Seals), F12-05, F3-03 (input device) | not yet verified |
| S4 | All six seal orders can open the Stage 2 gate; revisiting a seal cannot reset it or duplicate a reward. | STAGE_DESIGN, line 150 | F9-03 (SealRules and adapter), F12-05 | not yet verified |
| S5 | Flying over/under a locked gate cannot skip the required encounter. | STAGE_DESIGN, line 151 | F10-02 (gate adapters), F10-01 | not yet verified |
| S6 | A bomb kill of the last guard/enemy advances the encounter exactly once. | STAGE_DESIGN, line 152 | F7-02 (bomb), F8-02 (EncounterMachine), F10-01 | not yet verified |
| S7 | Dying before and after each checkpoint restores the correct segment and resources. | STAGE_DESIGN, line 153 | F8-03 (Snapshot), F10-02 (checkpoint adapters), F10-03 (retry) | not yet verified |
| S8 | Death after the miniboss but before CP2-B restores CP2-A; death at the final boss restores CP2-B. | STAGE_DESIGN, line 154 | F12-05 (Stage 2 checkpoints), F8-03, F10-03 | not yet verified |
| S9 | Power progress, score, graze, bombs-used statistics, and successful-path time restore without farming failed attempts. | STAGE_DESIGN, line 155 | F8-03 (Snapshot), F11-03 (active and clear time), F10-03 | not yet verified |
| S10 | Entering a checkpoint twice cannot repeatedly refill resources. | STAGE_DESIGN, line 156 | F8-03 (idempotent restore), F10-02 | not yet verified |
| S11 | Restart Stage and isolated stage selection use the correct stage-entry values. | STAGE_DESIGN, line 157 | F10-03 (retry and restart), F11-02 (direct stage) | not yet verified |
| S12 | Every route is readable without tutorial boxes or written objective lists. | STAGE_DESIGN, line 158 | F4-02/F4-03 (HUD only), D-05 (Stage 1 tuning), F10-01 | not yet verified |
| S13 | Stage 2 uninterrupted efficient clear reaches at least five active minutes through actual gameplay. | STAGE_DESIGN, line 159 | D-06 (pacing review), F12-05, F11-03 (measurement) | not yet verified |
| S14 | Boss patterns remain avoidable from different heights and do not permit a permanent risk-free perch. | STAGE_DESIGN, line 160 | F12-01/F12-02 (boss machine and controller), F12-03, F12-06, F12-07 | not yet verified |

## Summary (filled by F14-02 part 2)

- Fails:
- Not verified:
- Not verified (cut):
- Open Astra requests (credits):
