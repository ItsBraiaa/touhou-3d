# F0 Foundation — spec

Status: ready-for-agent
Owner: Claude

## Goal

Make the repository reproducible and safe for two agents before any gameplay code: version control, a Godot entry point that does not depend on the shell, a test runner, the project configuration Claude owns (warnings, input map, main scene, audio buses, export preset), and the collaboration documents every later session relies on.

## Tickets

1. `01-git-init-and-ignores.md`
2. `02-godot-wrapper-and-test-runner.md`
3. `03-project-config-main-scene-buses-export.md`
4. `04-guide-ownership-and-protocol-docs.md`

Sequential. None is parallel-safe.

## Done when

- `git log` shows the baseline plus one commit per ticket.
- `tools/test.ps1` runs the self-check test and exits 0.
- `tools/godot.ps1 --path . --headless --quit` exits 0 with the main scene set to `res://scenes/main.tscn`.
- GUIDE.md Section 3 and Section 9 state the accepted ownership and generator rules; `CLAUDE.md` and `AGENTS.md` point at the roadmap and the handoff log.

## Out of scope

Any gameplay behavior. Any change to Astra's geometry or menu layouts.
