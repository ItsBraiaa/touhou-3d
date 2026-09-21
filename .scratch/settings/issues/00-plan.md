# F3-00 Plan the Settings feature

Status: todo
Type: docs
parallel-safe: no
Depends on: F2-04

## Goal

Write `.scratch/settings/spec.md` and the full tickets for F3 using the ticket template from `docs/engineering/CONVENTIONS.md` ("Sessions") and the F0 to F2 tickets as examples.

## Planned tickets (from the roadmap)

1. `01-settings-core-and-configfile`: `Settings` Rules Core with defaults, validation and clamping for every field in GUIDE Section 14 "Options values and fields"; `ConfigFile` at `user://settings.cfg`, written on explicit change, read once at start, corrupt or missing values fall back to defaults; `capture()`-style dictionary for tests.
2. `02-options-screen-binding`: populate widgets before connecting change callbacks; apply Master, Music, SFX to the buses created in F0-03 (zero maps to mute); window mode; resolution with layout preserved; Defaults button; camera sensitivity and invert vertical pushed to `CameraRig.apply_settings`.
3. `03-input-device-mode-and-controller-disconnect`: Automático, Teclado, Controle; prompt icons; controller disconnect pauses the game and keyboard recovers; footer hint behavior consolidated.

## Read first when planning

- `docs/GUIDE.md` Section 14 "Options values and fields" and "Focus and responsive layout"
- `docs/PLANEJAMENTO.md` Section 7 (settings list, disconnect behavior)
- `docs/ENGINEERING_BRIEF.md` Section 4.I
- `docs/HANDOFF_LOG.md` for anything Astra changed in `options.tscn` since 2026-09-20

## Definition of Done

- `spec.md` and three ticket files exist with all template sections and kickoff prompts.
- Roadmap rows for F3 replaced by the three tickets, statuses `todo`.
- Commit `plan: write F3 settings tickets`.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/settings/issues/00-plan.md, then write the F3 spec and tickets as described. Finish with its Definition of Done and commit.
```
