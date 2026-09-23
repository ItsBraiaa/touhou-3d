# F14-02 Package and acceptance record

Status: todo
Type: tooling
parallel-safe: no
Depends on: F14-01

## Goal

`tools/package.ps1` builds the academic submission as one zip. The zip holds the Godot project, excluding the `.godot/` cache, the raw asset packs (`All models/`, `all-sounds/`, `Music/`), `build/` and agent tooling, plus the exported executable and a short Portuguese read-me. The script then extracts the zip and checks the copy independently: the project imports and its tests pass, and the executable boots (ENGINEERING_BRIEF Section 8 "Packaging": "Reopen an extracted copy and run the exported executable independently before claiming delivery readiness").

The session also checks that credits and licenses cover every integrated asset. It walks every acceptance check of PLANEJAMENTO Section 12 and STAGE_DESIGN and records each in `docs/validation/acceptance.md` as pass, fail, not verified, or not verified (cut), with evidence. Uploading to Classroom is the user's action.

## Read first

- `docs/PLANEJAMENTO.md` Sections 2, 11 and 12.
- `docs/STAGE_DESIGN.md` "Acceptance checks for stage progression".
- `docs/ENGINEERING_BRIEF.md` Sections 3 and 8 "Packaging" and "Manual and integration checks" (record the environment, devices, build and every unverified check).
- `docs/ASSET_CREDITS.md`, `assets/licenses/`, and `scenes/ui/credits.tscn` (read only: the in-game Créditos text).
- `.gitignore`: `.godot/`, `/build/` and the three raw packs are ignored. The empty root folders `export_templates/`, `feature_profiles/`, `script_templates/` and `text_editor_themes/` are untracked.
- `docs/validation/export.md` (F14-01) and every `docs/validation/*.md` a feature wrote.
- `.scratch/delivery/spec.md` "Cut pending the user".

## Files

- **Creates:** `tools/package.ps1`, `docs/validation/acceptance.md`. The zip is written under `build/package/`, which is git-ignored and never committed.
- **Edits:** `docs/validation/export.md`, adding a "Package" section with the zip name, size, file count and the verification output.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F14-02 row, plus a "Requests to Astra" row for any credit gap.
  - `docs/HANDOFF_LOG.md`: one entry.
  - `docs/engineering/project.md` "Export": a line pointing at the package script.
- **Must not touch:**
  - `docs/ASSET_CREDITS.md` and `scenes/ui/credits.tscn`, which are Astra's. A gap is a request, unless the user says otherwise.
  - Any gameplay code, scene or content. A failing acceptance check is recorded, not fixed.
  - `.gitignore`.
- **Conflicts with:** none after F14-01.

## Deliverables

### `tools/package.ps1` (PowerShell 5.1, no dependency beyond Git and `tools/godot.ps1`)

- **Parameters.** `-Exe` (default `build/Touhou-3D.exe`) and `-OutDir` (default `build/package`).
- **Refusals.**
  - It exits 2 with a message when the executable is missing: run F14-01's export first.
  - It exits 3 when `git status --porcelain` is not empty, so the package always equals a commit. The message names the dirty paths.
- **Staging.** It copies every path from `git ls-files` into `<OutDir>/Touhou-3D/project/`, except `.claude/` and `.agents/`, which are agent tooling. Tracked files are exactly the project without `.godot/`, `build/`, the raw packs and untracked strays, because those are ignored or untracked.
- **The rest of the package.**
  - `<OutDir>/Touhou-3D/game/` gets `Touhou-3D.exe` and `Touhou-3D.console.exe`.
  - `<OutDir>/Touhou-3D/LEIA-ME.txt` is Portuguese text, 20 lines or fewer: how to run `game/Touhou-3D.exe`, how to open `project/` in Godot 4.7.2, the controls summary from PLANEJAMENTO Section 8, and where the credits and licenses are.
- **Archive.** `Compress-Archive` writes `<OutDir>/Touhou-3D-<yyyyMMdd>.zip`. The script prints its size and file count.
- **Verify.** It extracts the zip to `<OutDir>/verify/` and runs three checks:
  1. `tools/godot.ps1 --headless --path <verify>/Touhou-3D/project --import` exits 0.
  2. `tools/godot.ps1 --headless --path <verify>/Touhou-3D/project --script res://tests/run_tests.gd` exits 0 with no `SCRIPT ERROR`.
  3. `<verify>/Touhou-3D/game/Touhou-3D.console.exe --headless --quit-after 300` exits 0 with no `ERROR:` line.

  It prints `PACKAGE_OK` or the failing step, and exits non-zero on any failure.
- **Options.** `-SkipVerify` exists for a quick rebuild; the Definition of Done needs a run without it.

### Credits coverage

List every file under `assets/` and match each to an `ASSET_CREDITS.md` entry, either original or third-party with its license under `assets/licenses/`. Compare the list with the in-game Créditos text. Record the result in `acceptance.md`. Each gap becomes an Astra request naming the file. The `scenes/dev/` placeholders are original primitives and need no credit, but list them.

### `docs/validation/acceptance.md`

- **Header.** Date, host, the commit, the build from F14-01, the input devices, and whether each pass was physical or scripted. A simulated gamepad is not a physical pass (ENGINEERING_BRIEF Section 8).
- **PLANEJAMENTO Section 12.** One row per checkbox, all 18: status, evidence link (validation file, test name or `STAGE_RESULT` line) and a note.
- **STAGE_DESIGN.** One row per acceptance check, all 14.
- **Not verified (cut), never pass.** Every Stage 2 item (F12-04 cut), including the five-minute requirement. "Options persist" and "controller disconnection is recoverable" (F3 cut). The audio part of the WorldEnvironment, interfaces and audio item (F13 cut), noting that the assignment PDF requires sound effects.
- **Not verified.** Anything without evidence, such as the 60 FPS target on the presentation computer or physical-device passes.
- **The user's.** "The group has confirmed instructor approval".
- **Summary.** A closing section lists the fails, the not verified items and the cut items, for the user's delivery decision.

## Tests required

This is tooling, so no unit test. The evidence is one full `tools/package.ps1` run ending in `PACKAGE_OK`, with its output pasted into `export.md`. The refusal paths (missing exe, dirty tree) are run once each and their exit codes recorded. `tools/test.ps1` is green.

## Out of scope

- Uploading to Classroom, and instructor approval (the user's).
- Fixing any failing check (new tickets, the user's call).
- Editing credits (Astra's).
- A Linux package; trimming unused assets out of `assets/` (Astra's selection).

## Definition of Done

- `tools/package.ps1` runs end to end with `PACKAGE_OK` on a clean tree.
- `acceptance.md` covers all 32 checks with evidence or an explicit reason.
- The credits coverage is recorded, and any gap is requested from Astra.
- `export.md` "Package" section, handoff log, `Status: done` with an Outcome, ROADMAP row.
- One commit: `delivery: add package script and acceptance record`. Commit before the final package run, so the package equals a commit. If the record is updated afterwards, commit that separately and repackage.

## Handoff notes for Astra

`acceptance.md` lists any asset missing from `ASSET_CREDITS.md` or the Créditos screen. Please add those entries; Claude does not edit either.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/delivery/issues/02-package-and-acceptance-record.md, then implement that ticket. Use /run to verify the extracted package imports, passes its tests and boots its executable. Finish with its Definition of Done and commit.
```
