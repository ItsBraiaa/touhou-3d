# Stage 2 progression — F12-05

2026-09-24, Astra (sol). Godot 4.7.2, main scene with Direct Stage 2.

## Observed game runs

- Windowed D3D12/Forward+ on Radeon RX 9070 XT: opened Selecionar fase, selected Montanha da Tempestade, and entered the rendered stage. HUD showed Health 100%, Shield, Power 2 and two Bombs. The game log had no errors after correcting Seal export ordering (script must precede seal_id in the scene).
- A temporary, uncommitted game-driving script emitted the real menu action, moved the ship with reset_to and damaged enemies/Seals through take_damage. It printed telemetry, with no assertions or new test cases. Two runs used Seal orders 1→2→3 and 3→1→2. This was an accelerated integration walkthrough, not a timed clear or a difficulty/aiming assessment.
- Both runs entered S2-01 at health 100, Shield true, two Bombs, Power 2, progress 0. S2-01 required its ledge exit after the two Spirits; S2-02 spawned its sequential waves.
- All six S2-03 Guards remained disengaged after three seconds. Damage against each still-shielded Seal left health at 10; a hit on its Guard changed that Seal from DORMANT to ENGAGED. Defeating both Guards exposed it; damage then destroyed it. Objectives accumulated in the selected order.
- Runtime pickups included S2-02/power_1, power_2 and shield_1, plus exactly S2-03-Seal1/power_1, Seal2/power_1 and Seal3/power_1. The three completed encounters opened Gate_S2_01..03.
- Entering S2-04 at X=40, outside the checkpoint arch, activated Portão dos Selos first. Retry after the miniboss restored (0,62,-358), with only Gates 1..3 open.
- Traversal through S2-06 followed by S2-07 entry at X=40 activated Limiar do Cume. Retry restored (0,98,-600), with all five Gates open. Defeating the final stand-in completed the Direct Stage run (RunState phase 3) in both orders.
- The first driver version tried to inspect the Director after the Session had freed it on clear; corrected to inspect RunState. The final walkthrough had no SCRIPT ERROR. At process shutdown it reported the known duplicated enemy-visual RID/ObjectDB resource leaks already recorded in stage-director.md; these are outside this ticket. No leak-free gameplay shutdown is claimed.

## Gate and limits

`tools/lane.ps1 land` is the automated gate; its result is recorded by the landing command. No new tests were written. The existing test_stage_02_spatial_contract assertion that the root remained static was minimally changed to expect StageDirector, as this ticket intentionally invalidates that assertion.

Read-only review found no critical or important issues in guard activation, lethal hit ordering, reward delivery, portal lights, scene wiring, checkpoint activation or Retry. Bosses remain dev Sentries pending F12-06/F12-07. The five-minute requirement, physical controls and normal-play difficulty remain human-pass work.
