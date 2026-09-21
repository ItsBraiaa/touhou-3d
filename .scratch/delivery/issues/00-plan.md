# F14-00 Plan the Delivery feature

Status: todo
Type: docs
parallel-safe: no
Depends on: F11-03 (a complete Stage 1 loop); should be planned by 2026-09-23 at the latest

## Goal

Write `.scratch/delivery/spec.md` and the full tickets for F14. Exports have already been attempted at F0-03 and should be repeated at every Feature boundary; this Feature makes the final package.

## Planned tickets

1. `01-export-and-run-outside-editor`: release export with the F0-03 preset, launch on this machine and, if available, on the presentation computer; record resolution, FPS in the densest boss Encounter, and any renderer fallback from D3D12; fix export-only failures.
2. `02-package-and-acceptance-record`: `tools/package.ps1` producing a zip of the project (excluding `.godot/`, raw packs, `build/`) plus the executable; reopen the extracted copy and run it; walk the acceptance checklists of PLANEJAMENTO Section 12 and STAGE_DESIGN, recording pass, fail, or not verified in `docs/validation/acceptance.md`; credits and licenses cover every integrated asset.

## Read first when planning

- `docs/PLANEJAMENTO.md` Sections 2, 11, 12
- `docs/ENGINEERING_BRIEF.md` Section 8 "Packaging" and Section 3
- `docs/STAGE_DESIGN.md` "Acceptance checks for stage progression"
- `docs/ASSET_CREDITS.md`

## Definition of Done

- `spec.md` and two ticket files; roadmap rows replaced; commit `plan: write F14 delivery tickets`.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/delivery/issues/00-plan.md, then write the F14 spec and tickets as described. Finish with its Definition of Done and commit.
```
