# F2 Menus and Session skeleton — spec

Status: ready-for-agent
Owner: Claude
Source: GUIDE.md Section 14 (menu registry, focus rules, runtime text); ADR-0002; ENGINEERING_BRIEF Section 4.H and 4.I.

## Goal

From the main menu a player can, without a mouse, start a Campaign or a Direct Stage, see Stage 1 load under `WorldRoot` with the ship flying in it, pause and resume, open Options from the pause menu without unpausing, restart, return to the main menu, and quit. Every screen sets initial focus and Back returns to the caller. The run itself (defeat, results, checkpoints) arrives in later Features; here the Session only owns start, pause, and end.

## Tickets

1. `01-screen-router-core.md` (parallel-safe)
2. `02-interface-and-menu-controller.md`
3. `03-run-state-core.md` (parallel-safe)
4. `04-game-session-start-pause-quit.md`

Tickets 01 and 03 can run in parallel with each other and with F1 core tickets.

## Done when

- All F2 tests pass. Manual: the full menu tree is navigable with keyboard and gamepad; the footer hint hides on gamepad; pause freezes the ship and Active Time.
- GUIDE Section 6 rows for `game_session.gd`, `interface.gd`, `menu_controller.gd` are complete; Section 10 "Main composition and session" and "Menus/options" advance to CODE_READY.

## Out of scope

Settings application (F3), HUD binding (F4), defeat and results binding (F11), stage completion.
