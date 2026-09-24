# F16-10 spec-api-list-matches-shipped-code

Status: todo
Type: docs
Owner: OpenCode
Lane: oc-b
Model: DeepSeek V4.1 Flash
Depends on: F16-06
Parallel-safe: yes. Docs only; F16-07 (sol) and F16-09 (oc-a) do not edit `spec.md`.

## Problem

`.scratch/controls-expansion/spec.md` has a block, "Proposed APIs for the implementation tickets", written before any code existed. F16-02 to F16-06 and F16-08 shipped real APIs that differ from it in places. For example, F16-05's `DashModel` and `PlayerController` additions are missing, which F16-05 and F16-06 both recorded as a follow-up. That block is where the next reader looks, so it must match the code.

## Work

1. Read the block (from the line "Proposed APIs for the implementation tickets:" to the end of its `~~~text` fence) and the paragraph after it.
2. For every class the block names, read the real public API in the code: `class_name`, public `func` and `signal` lines, and public constants other tickets use. Skip anything that starts with `_`.

   | Class | File |
   | --- | --- |
   | `Settings` | `scripts/settings/settings.gd` |
   | `InputBindings` | `scripts/settings/input_bindings.gd` |
   | `InputBindingAdapter` | `scripts/ui/input_binding_adapter.gd` |
   | `Interface` | `scripts/ui/interface.gd` (only its F16 additions) |
   | `ControlsScreen` | `scripts/ui/controls_screen.gd` |
   | `BindingLabels` | `scripts/ui/binding_labels.gd` |
   | `InputDeviceState` | `scripts/ui/input_device_state.gd` (F16 additions) |
   | `CameraRig` | `scripts/player/camera_rig.gd` (F16 additions) |
   | `DashModel` | `scripts/player/dash_model.gd` |
   | `PlayerController` | `scripts/player/player_controller.gd` (dash signals and functions) |
   | `CombatState.grant_invulnerability` | `scripts/combat/combat_state.gd` |

   Cross-check with the F16 sections of `docs/engineering/settings.md`, `player-flight.md` and `combat-hud.md`, which the implementers wrote.
3. Rewrite the block as the shipped contract, one line per public member, in its existing form (`Class.method(args: Type) -> Return`, `Class.name(args) signal`):
   - Keep lines that are still true.
   - Correct changed signatures, add missing public members that F16 introduced, and drop members that do not exist, each with a short `# was: ...` note at the end of the line.
   - Keep F16 APIs only; do not list the pre-F16 API.
4. Change the heading line to "Shipped APIs (F16-02 to F16-08, checked against the code 2026-09-24):". Also change the paragraph right after the block: its "Claude may refine seams..." sentence becomes one sentence saying the list was reconciled with the code by F16-10.
5. Change nothing else in `spec.md`: the product rules and the layout contract are Astra's.

## Files

- **Edits:** `.scratch/controls-expansion/spec.md`, only the API block, its heading line and the paragraph after it. Astra owns the spec, so the commit is tagged `[shared]`.
- **At session end:** this ticket's Outcome, its `docs/engineering/ROADMAP.md` row, and one `docs/HANDOFF_LOG.md` entry addressed to Astra, newest first.
- **Must not touch:** any code, scene or test, and every other doc.

## Verification (no tests)

- Write no tests and no scripts.
- For each changed line, the Outcome names the file and function it was checked against.
- `tools/lane.ps1 land` is the gate.

## Definition of Done

`land` passes. The ticket is `Status: done` with an Outcome, the ROADMAP row is updated, and one handoff entry is written. One commit: `(F16-10) spec API list matches the shipped code [shared]`.

## Kickoff prompt

```
Model: DeepSeek V4.1 Flash. You are lane oc-b. Work only in C:\Users\Braia\Documents\touhou-3d-oc-b. First run powershell -NoProfile -ExecutionPolicy Bypass -File tools\lane.ps1 sync. Read AGENTS.md and .scratch/controls-expansion/issues/10-spec-api-list-matches-shipped-code.md, then do that ticket exactly: docs only, no code, scene or test changes, no tests or scripts. Finish with the ticket's Definition of Done: one commit, then powershell -NoProfile -ExecutionPolicy Bypass -File tools\lane.ps1 land. If land fails twice, stop and paste its output.
```

## Outcome

Not started.
