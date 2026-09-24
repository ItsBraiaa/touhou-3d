# F3-00 Plan the Settings feature

Status: done (2026-09-23)
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

## Cut (2026-09-23)

Cut from the 2026-09-24 delivery by the one-pass planning session (commit `plan: write F4-F14 tickets`) to protect the Stage 1 loop. Do not pick it while cut; reinstating it is the user's call (set Status back to `todo`, then run this plan ticket as written).

Consequence while cut: the Options widgets show their authored defaults and apply nothing, `user://settings.cfg` is never written, `CameraRig.apply_settings()` stays uncalled, the buses from F0-03 keep their default volumes, and a controller disconnect does not pause the game.

## Reinstated (2026-09-23)

The PO reinstated F3 the same day in the four-lane sprint plan (`docs/engineering/SPRINT.md`), in a reduced but real form. The reduced form has no remapping and no gamepad glyph icons, applies the resolution in Janela only, and keeps no settings version. That decision supersedes the Cut section above, which stays as the record.

This plan ticket is done. It produced `.scratch/settings/spec.md` and four tickets instead of three:

- `01-settings-core-and-configfile.md` (F3-01, core, parallel-safe, lane glm-b);
- `02-options-screen-binding.md` (F3-02, adapter, lane glm-b);
- `03-input-device-mode-and-controller-disconnect.md` (F3-03, adapter, lane glm-b);
- `04-settings-to-camera-wiring.md` (F3-04, integration, lane trunk).

F3-04 exists because the glm-b lane never edits `scripts/session/game_session.gd`, so pushing camera sensitivity and invert vertical to `CameraRig.apply_settings()` moved from 02 to a trunk ticket after F10-03's `_spawn_player()`. The roadmap rows are replaced by the orchestrator, not by this ticket.
