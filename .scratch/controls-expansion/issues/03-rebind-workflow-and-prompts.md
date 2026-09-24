# F16-03 rebind-workflow-and-prompts

Status: todo
Type: adapter
Owner: Claude
Lane: trunk
Depends on: F16-01, F16-02, F16-08
Parallel-safe: no

## Read first

- [Spec](../spec.md): product rules, exact widget paths, data shapes and proposed APIs.
- [Execution plan](../../../docs/engineering/controls-expansion-plan.md): ownership, task steps and review focus.
- docs/engineering/SPRINT.md in the worktree: no-new-tests rule and lane loop.

## Routing (2026-09-24, Claude)

- **Consumes F16-08:** `BindingLabels.describe()`, `glyph_id()` and `glyph_path()`, plus `InputDeviceState.set_glyph_override()`, `get_prompt_family()` and `prompt_family_changed`. Do not rebuild them. If F16-08 has not landed when this ticket starts, do its deliverables here first and record that in both Outcomes.
- **Glyph files:** `res://assets/ui/controls/glyphs/<glyph_id>.png` (F16-08's list). Fall back to text when a file is missing.
- **Docs:** fill only the pre-made sections "F16 capture workflow and prompts (F16-03)" in settings.md and the F16-03 section of `docs/validation/controls-expansion.md`.

## Goal

Make the authored screen a safe, persistent editor with truthful current-input prompts.

## Files

- scripts/ui/controls_screen.gd (new)
- scripts/ui/interface.gd
- scripts/ui/menu_controller.gd
- scripts/ui/input_device_state.gd
- scripts/ui/options_screen.gd
- scenes/ui/controls.tscn (wiring only; preserve Astra layout)
- scenes/ui/options.tscn (existing entry/camera labels only if needed)
- docs/engineering/settings.md (capture/prompt contract)
- docs/validation/controls-expansion.md (rebinding observations)

Also update this ticket's Outcome, only its own docs/engineering/ROADMAP.md row, and append a newest-first docs/HANDOFF_LOG.md entry. New production scripts/assets include their generated .uid/.import sidecars. No files outside this boundary without first coordinating the owner and recording the expansion.

## Work

- [ ] Bind ControlsScreen.setup to the authored paths and catalog; implement context-aware primary/secondary/reset rows and real focus loops.
- [ ] Implement wait-release, capture, candidate review, conflict decisions, timeout and modal input consumption.
- [ ] Implement draft Apply, tab defaults, dirty exit, save failure, 10-second new-binding confirmation and rollback on timeout/disconnect/focus loss.
- [ ] Update all menu/gameplay control hints from current bindings and glyph family; integrate existing device preference and global Defaults.

## Manual acceptance / existing gate

- Capture ordinary keys, Escape, mouse buttons, D-pad, sticks and triggers; held opener/repeat/drift never auto-binds.
- Try Trocar/Substituir/Cancelar and preserve required menu bindings.
- Navigate entirely by controller after changing confirm/back; rollback restores access without restarting.
- No fire, dash, recenter or pause leaks during listening; no hidden widget owns focus.
- Save, quit and relaunch; exact bindings and glyph override return.

Write no new tests or disposable test drivers. Run the existing tools/lane.ps1 land gate after the scoped commit. A static/headless result does not certify physical device feel. Failures belong in Outcome and the handoff; never bypass the gate.

## Outcome

Not started. Owns Interface and menu adapters sequentially in trunk; camera lifecycle integration is F16-06.
