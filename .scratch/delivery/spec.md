# F14 Delivery — spec

Status: ready-for-agent
Owner: Claude
Source: PLANEJAMENTO.md Sections 2 (academic requirements, "Submit the compressed project through Classroom"), 11 and 12 (acceptance criteria); ENGINEERING_BRIEF Section 3 ("Full project and exported build must be testable on the presentation computer") and Section 8 "Packaging"; STAGE_DESIGN.md "Acceptance checks for stage progression"; `docs/ASSET_CREDITS.md`; `docs/engineering/project.md` (export preset, blocked export); `.scratch/foundation/issues/03-project-config-main-scene-buses-export.md` Outcome.

## Goal

The academic package exists and is honest.

- A Windows release build exported with the F0-03 preset runs outside the editor on this machine, and on the presentation computer if the user has access to it. Its renderer, resolution and FPS are recorded.
- `tools/package.ps1` produces one zip with the project, minus caches, raw packs and build output, plus the executable. The extracted copy imports cleanly and its executable boots.
- Every acceptance check in PLANEJAMENTO Section 12 and STAGE_DESIGN is recorded as pass, fail, not verified, or not verified (cut), with evidence, in `docs/validation/acceptance.md`.

Submitting through Classroom stays the user's action.

## Tickets

1. `01-export-and-run-outside-editor.md`: export, launch outside the editor, measurements, export-only fixes. It needs the Godot 4.7.2 export templates, which **the user installs**. F0-03 found none, and on 2026-09-23 `%APPDATA%\Godot\export_templates\` was an empty folder. Without them the session sets `Status: blocked` and stops, and it never downloads them.
2. `02-package-and-acceptance-record.md`: `tools/package.ps1`, the extracted-copy check, credits coverage, and the acceptance record.

Neither is parallel-safe: both need the whole game frozen, and 02 needs 01's executable.

## Cross-feature contracts

- The build is `build/Touhou-3D.exe`, with an embedded PCK and x86_64, plus `build/Touhou-3D.console.exe`, the console wrapper, because `debug/export_console_wrapper=1`. `build/` is git-ignored and never committed.
- F14 has no module doc of its own. Its records are `docs/validation/export.md`, `docs/validation/acceptance.md`, and an "Export" section in `docs/engineering/project.md`, which replaces the F0-03 "Windows export blocked" open issue.
- The acceptance record quotes each feature's validation files (`docs/validation/*.md`) and the `STAGE_RESULT` log lines (F11-01), and invents no result.

## Cut pending the user, and what it costs at delivery

These PLANEJAMENTO and STAGE_DESIGN checks are recorded as **not verified (cut)**, never as pass:

- **Stage 2 (F12-04):** direct Stage 2 completion, the Campaign's final victory, the Stage 2 five-minute requirement, the miniboss, the three-Seal challenge and the Storm Guardian.
- **Settings (F3):** "options persist" and "controller disconnection is recoverable".
- **Audio (F13):** the audio half of "3D environments, WorldEnvironment, graphical interfaces, and audio are present". The assignment PDF also requires "graphical interfaces and sound effects".

The user decides whether to reinstate any of them before delivery.

## Done when

- The exported executable boots to the main menu and flies Stage 1 outside the editor. `docs/validation/export.md` records the environment, renderer, resolution and FPS.
- `tools/package.ps1` produces the zip, and its extracted copy passes the import check and the boot check.
- `docs/validation/acceptance.md` covers every check with a status and evidence.
- The roadmap F14 rows are closed.

## Out of scope

- Submitting to Classroom; confirming instructor approval and group membership (the user's).
- Fixing a failing acceptance check. That is a new ticket the user schedules; F14 only records it.
- Code signing, an installer, a Linux build.
