# F14-00 Plan the Delivery feature

Status: done (2026-09-23)
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

## Outcome (2026-09-23)

The tickets were written in the one-pass planning session (commit "plan: write F4-F14 tickets"): `spec.md`, `01-export-and-run-outside-editor.md`, `02-package-and-acceptance-record.md`. They differ from the planned list above in these ways:

- **01.** It starts with a precondition check for the 4.7.2 templates in `%APPDATA%\Godot\export_templates\4.7.2.stable\`, which was empty on 2026-09-23. If they are absent, the ticket is blocked for the user to install them; a session never downloads them. The densest-boss FPS needs a human pass.
- **02.** The package is built from `git ls-files` on a clean tree, excluding `.claude/` and `.agents/`, as `project/`, `game/` and `LEIA-ME.txt`. Credit gaps become Astra requests, not edits. The cut features' checks are recorded as "not verified (cut)".
