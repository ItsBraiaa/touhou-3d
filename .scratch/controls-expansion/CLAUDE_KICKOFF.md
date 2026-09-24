# Claude orchestration kickoff — F16

Read AGENTS.md, docs/engineering/SPRINT.md, docs/engineering/controls-expansion-plan.md and .scratch/controls-expansion/spec.md. The user requested the full controls/settings expansion and explicitly chose dash invulnerability. Plan and implement F16 in the named worktrees; do not reopen the invulnerability decision or invent a second spec.

You are the engineering orchestrator. Astra (sol) owns F16-01 layout/visual components and F16-07 visual acceptance. Claude (trunk) owns F16-02, 03, 05 and 06, including every project.godot, player_ship.tscn and Session edit. Claude (path) owns F16-04 CameraRig only. Verify each lane is idle before dispatch; never put two agents in one worktree, and do not interrupt other work without coordination.

Start by checking F16-00 landed and dependencies with tools/lane.ps1 status. Run F16-01 and F16-02 concurrently if sol is available. After 02 lands, run path 04 beside trunk 03 then 05. Serialize 06 after 03/04/05. Finally coordinate sol 07 and any engineering corrections. If a lane is unavailable, keep the same ownership and run sequentially.

Use one ticket per session. Each ticket has an exact Files boundary, dependency list, work steps and manual acceptance. Before expanding the boundary, record why and serialize any new shared-file owner. Required behavior and proposed interfaces live in the spec; reconcile any interface change there before a consumer begins. Avoid broad refactors.

No new tests of any kind or disposable test scripts. No TDD despite old skill/ticket text. Run the existing tools/lane.ps1 land gate and manual game acceptance. Do not replace a physical Xbox/DualShock/DualSense pass with synthetic input; unavailable hardware stays not verified.

Critical rules:
- All gameplay/menu bindings editable, independent keyboard/mouse and normalized controller profiles, drift-safe capture, context-aware conflict decisions and safe menu-binding rollback.
- Real Portuguese prompts reflect saved controls and Xbox/PlayStation family; no permanently hardcoded footer shortcuts.
- Mouse camera releases on menus/pause/focus loss and discards stale motion; recenter respects lock and scenery.
- Dash: camera-relative left/right, 3 units in 0.15 s, 0.8 s shared cooldown from activation, invulnerable for 0.15 s. Walls block it. No health/Shield consumption or Graze during protection. Use the existing CombatState authority and preserve longer Bomb/hit protection.
- Protect the activation and last active physics ticks; field sweep ordering is part of F16-05 acceptance.
- Astra does not edit trunk-owned scenes to instance components. Trunk wires the authored HUD/dash assets.
- Existing pinned flight/camera values stay unchanged.

Finish each ticket with Outcome, its ROADMAP row, append-only HANDOFF_LOG, a scoped commit and land. Report the integrated commit and manual limitations. Do not push, amend or rebuild/publish a release package unless separately requested.

For Astra, paste this when its lane is available:

"Read the F16 spec and controls-expansion-plan, then execute F16-01 in lane sol. Own only the authored screen, binding-row/cooldown/dash visual components, glyph assets and their documentation. Preserve existing Controls root wiring, Layout/BackButton and Layout/NavigationHint. Follow the exact widget paths. Do not implement scripts, InputMap, camera or dash rules. Use no new tests; inspect the layouts manually and land through the lane gate. Hand Claude the node inventory and screenshots."

When F16-06 has landed, use the same pattern for F16-07; do not claim hardware checks that were not performed.
