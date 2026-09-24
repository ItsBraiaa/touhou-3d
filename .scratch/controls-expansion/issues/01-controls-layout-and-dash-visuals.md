# F16-01 controls-layout-and-dash-visuals

Status: todo
Type: design
Owner: Astra
Lane: sol
Depends on: F16-00
Parallel-safe: yes, only within the orchestration plan's disjoint file boundaries

## Read first

- [Spec](../spec.md): product rules, exact widget paths, data shapes and proposed APIs.
- [Execution plan](../../../docs/engineering/controls-expansion-plan.md): ownership, task steps and review focus.
- docs/engineering/SPRINT.md in the worktree: no-new-tests rule and lane loop.

## Goal

Deliver the exact Controls layout, modal states and reusable visual components Claude will wire.

## Files

- scenes/ui/controls.tscn
- scenes/ui/components/binding_row.tscn (new)
- scenes/ui/components/dash_cooldown.tscn (new)
- scenes/player/visuals/dash_visual.tscn (new)
- assets/ui/controls/* (new original glyphs/materials and import sidecars)
- assets/vfx/dash/* (new cosmetic assets and import sidecars)
- docs/ASSET_CREDITS.md (only new-asset entries)
- docs/validation/controls-expansion.md (layout/component section)

Also update this ticket's Outcome, only its own docs/engineering/ROADMAP.md row, and append a newest-first docs/HANDOFF_LOG.md entry. New production scripts/assets include their generated .uid/.import sidecars. No files outside this boundary without first coordinating the owner and recording the expansion.

## Work

- [ ] Use the spec's widget paths and 1280×720 layout; preserve root wiring, BackButton and NavigationHint.
- [ ] Create the row template, all four overlays, explicit focus styling and Portuguese copy.
- [ ] Author keyboard/Xbox/PlayStation glyphs with text fallback and the cyan dash/cooldown components.
- [ ] Record node inventory, states and screenshots; hand off before Claude's controls binding starts.

## Manual acceptance / existing gate

- Inspect 1280×720, 1600×900 and 1920×1080: no text/footer overlap or cropped binding columns.
- Focused rows, long key names, two slots and all modal/error states remain legible.
- Trail never hides the Core and has no collision; no scripts or trunk-owned scene edits.

Write no new tests or disposable test drivers. Run the existing tools/lane.ps1 land gate after the scoped commit. A static/headless result does not certify physical device feel. Failures belong in Outcome and the handoff; never bypass the gate.

## Outcome

Not started. Runtime interaction acceptance belongs to F16-03/F16-07; this ticket establishes the visual contract.
