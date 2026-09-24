# F16-09 targeting-ignores-the-resume-press

Status: todo
Type: adapter
Owner: OpenCode
Lane: oc-a
Model: DeepSeek V4.1 Flash
Depends on: F16-06
Parallel-safe: yes. F16-07 (sol) and F16-10 (oc-b) touch none of these files.

## Problem

`scripts/player/targeting.gd` `_physics_process` polls `Input.is_action_just_pressed(&"lock_target")` and `(&"next_target")`. Since F16-03 the player can remap either action onto gamepad B, which is also `ui_cancel`. B on Pause resumes play (Interface consumes that press as an event). A poll still sees it, though: in Godot 4.7, "just pressed" stays true on the first unpaused physics tick, and a release does not clear it (`docs/engineering/menus-session.md`, "Open issues", the B/`bomb` note). So resuming with B locks or switches the target at once. Starting a stage with A, with Lock remapped to A, does the same.

This was found by F16-06 and is recorded in its risks.

## The fix: copy the pattern the dash already uses

`PlayerController` has `_dash_input_armed` (read `set_controls_enabled()` and `_try_start_dash()`, and the doc comment above `_dash_input_armed`).

- **When the controls come back** (`set_controls_enabled(true)`), the dash is disarmed.
- **While disarmed,** each tick only waits for both dash actions to be released, and reads no press.
- **Once they are released,** the dash reads presses again.

Do the same for targeting:

1. **`targeting.gd`:**
   - Add `var _input_armed: bool = false` with a `##` doc comment in the style of `_dash_input_armed`.
   - Add a public `func require_release() -> void`, which sets it to false, with a `##` doc comment.
   - At the top of `_physics_process`, when not armed, set `_input_armed = not Input.is_action_pressed(&"lock_target") and not Input.is_action_pressed(&"next_target")`, and treat this tick's `lock_pressed` and `next_pressed` as false. The rest of the tick still runs: a current lock is still validated, and released when its target becomes invalid.
2. **`player_controller.gd`:** in `set_controls_enabled()`, in the `if enabled:` branch, next to `_dash_input_armed = false`, add `targeting.require_release()` (guard it with `if targeting != null:`). Update that function's doc comment in one clause: the resume press can reach neither the dash nor targeting.

Nothing else changes. Recenter is already event-based and safe. `fire` and `focus` are held polls, which only act while held, so they are out of scope.

## Files

- **Edits:**
  - `scripts/player/targeting.gd`: the latch and `require_release()`, as above.
  - `scripts/player/player_controller.gd`: one call in `set_controls_enabled()`, and its doc comment. No other line.
- **Docs:**
  - `docs/engineering/player-flight.md`: one bullet in the section "Targeting contract" only. F16-07 is editing that file's F16 sections, so do not touch them.
  - `docs/engineering/menus-session.md`: one line under "Open issues", after the B/`bomb` note, saying targeting is now covered (F16-09).
- **At session end:** this ticket's Outcome, its `docs/engineering/ROADMAP.md` row, and one `docs/HANDOFF_LOG.md` entry, newest first.
- **Must not touch:** anything else, and especially `game_session.gd`, `camera_rig.gd`, scenes and tests.

## Verification (no tests)

- Write no tests and no test or driver scripts.
- `tools/lane.ps1 land` is the gate: the existing suite (it has targeting contract tests; they must stay green), the boot smoke and the resource check.
- In the Outcome, record what was checked by reading. The physical check belongs to the user's F16-07 pass: remap Lock to B, pause, resume with B, and nothing gets locked.

## Definition of Done

`land` passes. The ticket is `Status: done` with an Outcome, the ROADMAP row is updated, and one handoff entry is written. One commit: `(F16-09) targeting ignores the press that resumed play`.

## Kickoff prompt

```
Model: DeepSeek V4.1 Flash. You are lane oc-a. Work only in C:\Users\Braia\Documents\touhou-3d-oc-a. First run powershell -NoProfile -ExecutionPolicy Bypass -File tools\lane.ps1 sync. Read AGENTS.md and .scratch/controls-expansion/issues/09-targeting-ignores-the-resume-press.md, then implement that ticket exactly. Strictly typed GDScript; warnings are errors (untyped declarations, unused variables or parameters, shadowing). No tests of any kind and no test or driver scripts. Finish with the ticket's Definition of Done: one commit, then powershell -NoProfile -ExecutionPolicy Bypass -File tools\lane.ps1 land. If land fails twice, stop and paste its output.
```

## Outcome

Not started.
