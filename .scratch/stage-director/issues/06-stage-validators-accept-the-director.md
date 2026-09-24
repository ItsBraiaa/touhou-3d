# F10-06 Stage validators accept the Director

Status: todo
Type: tooling
parallel-safe: yes
Depends on: F10-01
Lane: oc-a
Model: GPT 5.6 Luna (fallback DeepSeek V4.1 Flash)

## Goal

`tools/validate_stage_01.gd` now fails its line 39 check, `check(stage.get_script() == null, "Static stage unexpectedly contains runtime script")`. Trunk reported it in the F10-01 handoff entry, and Astra confirmed it. The check is wrong now: since F10-01, Stage 1's `Stage` root carries `scripts/progression/stage_director.gd` (`class_name StageDirector`) by design. Astra ruled that the validator must accept the Director. Stage 2 gets its Director in sol's F12-05, so the rule has to hold for both stages.

**What the tools actually check** (read on 2026-09-24):
- **`tools/validate_stage_01.gd`:** line 39 is the only check that involves scripts. No check asserts that `monitoring` is off on an Encounter volume or a Checkpoint. No check asserts that `Gates/*` or `Checkpoints/*` have no script. The Gate loop (lines 36 to 38) reads only `BarrierBody/Collision`'s `BoxShape3D` size, and the Checkpoint loop (lines 31 to 35) reads only positions and `Respawn`. So `gate.gd` and `checkpoint.gd` pass these checks unchanged, and only line 39 needs relaxing.
- **`tools/validate_stage_02.gd`:** it has no script check. Headless, it only requires `Stage/Encounters` and `PreviewCamera`, prints `STAGE_02_PREVIEW_LOAD_OK` and exits 0. F12-05's Director does not trip it, so it needs no edit.
- **`tools/validate_scene_handoff.gd`:** it loads `scenes/tests/combat_arena.tscn`, not a stage, and makes no script assumption. It needs no edit.

## Read first

- `tools/validate_stage_01.gd` (all 57 lines), `tools/validate_stage_02.gd` (lines 7 to 22, the headless branch), `tools/validate_scene_handoff.gd`.
- `scripts/progression/stage_director.gd`, the header and `check_setup()`. It has no `_ready`, so without `setup()` the preview only instances it, and nothing spawns.
- `_ready` in `scripts/progression/gate.gd` and `scripts/progression/checkpoint.gd`. Each only looks up its children, and `push_error`s if one is missing.
- `docs/HANDOFF_LOG.md`, the entry "2026-09-23 22:40 — Claude (trunk) — F10-01", item 1 of "Action required by Astra".
- `docs/engineering/CONVENTIONS.md`: "Typing and warnings", "Git" (the `[shared]` tag) and "Shared-file protocol".

## Files

- **Edits:**
  - `tools/validate_stage_01.gd` [shared]: line 39 only, plus one new constant near the top.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F10-06 row, directly under the F10 rows (add it if it is missing). If an adjacent row conflicts, keep both texts.
  - `docs/HANDOFF_LOG.md`: one `— OpenCode (oc-a) —` entry.
  - This ticket: `Status: done` and an Outcome.
- **Must not touch:**
  - `tools/validate_stage_02.gd` and `tools/validate_scene_handoff.gd`. Read and run them only.
  - `tools/build_stage_01.py`, `tools/build_stage_02.py`: never rerun them.
  - `scenes/stages/stage_01.tscn`, `stage_02.tscn`, `scenes/tests/stage_0*_preview.tscn`, `scripts/**`, `tests/**`, `docs/STAGE_01_HANDOFF.md`.
  - `docs/engineering/stage-director.md`: trunk's file (SPRINT "Shared files"), and F12-03 part 2 is editing it now. Its "Open issues" bullet about this check stays in place; the handoff entry asks trunk to drop it.
  - `docs/validation/stage-01-*.png`: a windowed run rewrites these captures, so run the validators headless only.
- **Conflicts with:**
  - sol's D-07 Part A, which adds a shrine step to `tools/validate_stage_01.gd` after F12-03. Whoever lands second keeps both hunks.
  - sol's F12-05 shares no file with this ticket. It only decides which Stage 2 verification line below applies.

## Deliverables

Replace line 39 with a check that accepts no script or the Director's script, and nothing else. Add the constant after `var failures := 0`:

```gdscript
## The only script a Stage root may carry: the StageDirector (F10-01 on Stage 1, F12-05 on Stage 2).
const DIRECTOR_SCRIPT_PATH := "res://scripts/progression/stage_director.gd"
```

Put this at line 39, in place of the old check:

```gdscript
	var stage_script: Script = stage.get_script() as Script
	check(stage_script == null or stage_script.resource_path == DIRECTOR_SCRIPT_PATH, "Stage root carries a script other than the StageDirector")
```

- Compare the path. Do not test `is StageDirector`, so the tool needs nothing from the class cache.
- Change no other line: the counts, bounds, Gate span, Checkpoint spacing, the windowed screenshot branch and the final `STAGE_01_QA_COMPLETE` line all stay.
- Make no edit to the Stage 2 or scene-handoff validators (see Goal).

## Verification (no tests: SPRINT.md "No new tests")

- `tools/lane.ps1 land` passes: the existing suite, the boot smoke, and `tools/check_resources.gd`, which compiles every `.gd` under `tools/` with warnings as errors.
- Run each validator headless, from the worktree root. Record the last output line and the exit code (`$LASTEXITCODE`) in the Outcome:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 --headless --path . --script res://tools/validate_stage_01.gd`. The last line is `STAGE_01_QA_COMPLETE failures=0 encounters=7 spawns=18 checkpoints=2 gates=4`, with exit 0 and no `Static stage` or `StageDirector` error line.
  - The same command with `validate_stage_02.gd` gives `STAGE_02_PREVIEW_LOAD_OK (no rendered evidence in headless mode)` and exit 0. Check first with `git log dev-01 --oneline --grep "F12-05"`, and say in the Outcome whether the run had F12-05's Director or no Stage 2 script.
  - The same command with `validate_scene_handoff.gd` gives `SCENE_CONTRACT_OK: 10 required nodes; …` and exit 0.
- If any other check fails, record the message in the Outcome and the handoff entry for Astra, and leave the check unchanged. A spawn count or Gate size mismatch is a scene issue, not this ticket.

## Out of scope

- Any new validator check, including D-07 Part A's shrine step.
- Stage 2 checks of Seals or F12-05 wiring.
- The Director's runtime `check_setup()`.
- The duplicate glTF children in `spirit_lume.tscn` and `sentry_lantern.tscn`, which stay Astra's open item.
- Updating `docs/engineering/stage-director.md`.

## Definition of Done

- `tools/lane.ps1 land` passes.
- The three headless runs are recorded in the Outcome.
- The handoff entry is written.
- This ticket is `Status: done` with an Outcome.
- The ROADMAP row is updated.
- One commit: `tools: [shared] stage validators accept the StageDirector`.

## Handoff notes for Astra

Handoff entry, `State: dev`, `Files:` `tools/validate_stage_01.gd`.
- **For Astra:** the Stage 1 validator now accepts exactly two root scripts: none, or `res://scripts/progression/stage_director.gd`. Any other script still fails it. `validate_stage_02.gd` needed no change and stays valid after F12-05. When D-07 Part A adds its shrine step, sync first and keep the new line 39.
- **For trunk:** the "now fails" bullet in `docs/engineering/stage-director.md` "Open issues" is resolved. Drop it in your next doc pass.

## Kickoff prompt

```
You are lane oc-a of docs/engineering/SPRINT.md. Read AGENTS.md, docs/engineering/SPRINT.md and .scratch/stage-director/issues/06-stage-validators-accept-the-director.md. The Model line is GPT 5.6 Luna (fallback DeepSeek V4.1 Flash): if you run a different model, stop and ask the user to switch. tools/lane.ps1 sync; tools/lane.ps1 status F10-06; implement the ticket inside its Files boundary with strict static typing and NO tests of any kind; run the three validators headless as its Verification says; finish its Definition of Done; commit on lane/oc-a with "tools: [shared] stage validators accept the StageDirector"; tools/lane.ps1 land. Run every tools script as powershell -NoProfile -ExecutionPolicy Bypass -File tools\<script>.ps1 <args>.
```
