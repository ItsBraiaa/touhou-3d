# F0-04 GUIDE ownership and protocol docs

Status: todo
Type: docs
parallel-safe: no
Depends on: F0-03

## Goal

Make the accepted collaboration rules visible in the shared contract so Codex (Astra) and any other agent see them where they already look: GUIDE.md, `CLAUDE.md`, `AGENTS.md`.

## Read first

- `docs/engineering/CONVENTIONS.md`, "Shared-file protocol", "Git", "Sessions"
- `docs/GUIDE.md` Sections 3, 4, 6, 9, 10
- `docs/HANDOFF_LOG.md` (format)
- `docs/STAGE_01_HANDOFF.md` "Claude can work now" (Astra's own expectations)

## Deliverables

### GUIDE.md edits (shared file; announce in the log)

- Section 3 table: add rows or amend so that Claude owns `project.godot`, `export_presets.cfg`, `default_bus_layout.tres`, `scenes/main.tscn`, `scenes/dev/`, and inside any `.tscn`: script attachment, exported values, collision layers, masks, monitoring flags, instancing of Claude's prefabs. Astra keeps geometry, visuals, layout, markers, materials, `content/*.tres` values. Add the sentence "Every change to a file owned by the other agent is announced in `docs/HANDOFF_LOG.md`."
- Section 6 registry: add `scripts/ui/interface.gd` (attach to `Main/Interface`) and mark `scripts/ui/strings.gd` as optional, code-only. Add a note that Rules Cores are code-only and documented in `docs/engineering/<module>.md`.
- Section 9: add step 0, "Before rerunning any `tools/build_*.py` generator over an integrated scene, reconcile it with the scene's current wiring or retire it."
- Section 10: add rows "Foundation and conventions" (Claude, CODE_READY once F0 is done) and "Stage 1 area" (Astra, SCENE_READY_STATIC, `docs/STAGE_01_HANDOFF.md`).
- Bump the header status to "version 5" and mention `CONVENTIONS.md`, `ROADMAP.md`, and `HANDOFF_LOG.md` in Section 2.

### `CLAUDE.md` and `AGENTS.md`

Keep them identical. Ensure both have the "Start here" and "Collaboration protocol" sections (already drafted) and that the collaboration section links GUIDE Section 3 and the handoff log.

### `docs/engineering/README.md`

Index of the engineering docs: CONVENTIONS, ROADMAP, TEMPLATE, testing, and one line per module doc as they appear.

## Tests required

None. Verify all relative links resolve (open each linked file).

## Out of scope

Any code.

## Definition of Done

- GUIDE.md reflects the ownership and generator rules; `CLAUDE.md` and `AGENTS.md` are identical and link correctly.
- Handoff log entry `[shared]`; commit `docs: [shared] record ownership and collaboration protocol in GUIDE`.
- Roadmap F0 rows all `done`.

## Handoff notes for Astra

Read GUIDE Section 3 again. From here on, when you deliver a scene, add a handoff log entry and a row in the roadmap's "Received from Astra" table.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/foundation/issues/04-guide-ownership-and-protocol-docs.md, then implement that ticket. Finish with its Definition of Done and commit.
```
