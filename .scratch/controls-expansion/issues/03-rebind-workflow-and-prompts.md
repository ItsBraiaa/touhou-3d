# F16-03 rebind-workflow-and-prompts

Status: done
Type: adapter
Owner: Claude
Lane: trunk
Depends on: F16-01, F16-02, F16-08
Parallel-safe: no

## Read first

- [Spec](../spec.md): product rules, exact widget paths, data shapes and proposed APIs.
- [Execution plan](../../../docs/engineering/controls-expansion-plan.md): ownership, task steps and review focus.
- docs/engineering/SPRINT.md in the worktree: no-new-tests rule and lane loop.

## Routing (2026-09-24, Claude)

- **Consumes F16-08:** `BindingLabels.describe()`, `glyph_id()` and `glyph_path()`, plus `InputDeviceState.set_glyph_override()`, `get_prompt_family()` and `prompt_family_changed`. Do not rebuild them. If F16-08 has not landed when this ticket starts, do its deliverables here first and record that in both Outcomes.
- **Glyph files:** `res://assets/ui/controls/glyphs/<glyph_id>.png` (F16-08's list). Fall back to text when a file is missing.
- **Docs:** fill only the pre-made sections "F16 capture workflow and prompts (F16-03)" in settings.md and the F16-03 section of `docs/validation/controls-expansion.md`.

## Goal

Make the authored screen a safe, persistent editor with truthful current-input prompts.

## Files

- scripts/ui/controls_screen.gd (new)
- scripts/ui/interface.gd
- scripts/ui/menu_controller.gd
- scripts/ui/input_device_state.gd
- scripts/ui/options_screen.gd
- scenes/ui/controls.tscn (wiring only; preserve Astra layout)
- scenes/ui/options.tscn (existing entry/camera labels only if needed)
- docs/engineering/settings.md (capture/prompt contract)
- docs/validation/controls-expansion.md (rebinding observations)

Also update this ticket's Outcome, only its own docs/engineering/ROADMAP.md row, and append a newest-first docs/HANDOFF_LOG.md entry. New production scripts/assets include their generated .uid/.import sidecars. No files outside this boundary without first coordinating the owner and recording the expansion.

## Work

- [x] Bind ControlsScreen.setup to the authored paths and catalog; implement context-aware primary/secondary/reset rows and real focus loops.
- [x] Implement wait-release, capture, candidate review, conflict decisions, timeout and modal input consumption.
- [x] Implement draft Apply, tab defaults, dirty exit, save failure, 10-second new-binding confirmation and rollback on timeout/disconnect/focus loss.
- [x] Update all menu/gameplay control hints from current bindings and glyph family; integrate existing device preference and global Defaults.

## Manual acceptance / existing gate

- Capture ordinary keys, Escape, mouse buttons, D-pad, sticks and triggers; held opener/repeat/drift never auto-binds.
- Try Trocar/Substituir/Cancelar and preserve required menu bindings.
- Navigate entirely by controller after changing confirm/back; rollback restores access without restarting.
- No fire, dash, recenter or pause leaks during listening; no hidden widget owns focus.
- Save, quit and relaunch; exact bindings and glyph override return.

Write no new tests or disposable test drivers. Run the existing tools/lane.ps1 land gate after the scoped commit. A static/headless result does not certify physical device feel. Failures belong in Outcome and the handoff; never bypass the gate.

## Outcome

Done 2026-09-24 by lane trunk, on base `4f68c44`. F16-08 had landed, so its `BindingLabels` and prompt family were consumed, not rebuilt. The contract is in `docs/engineering/settings.md`, "F16 capture workflow and prompts (F16-03)", and the record and the human walkthrough are in `docs/validation/controls-expansion.md`, "Rebinding workflow and prompts".

- **`ControlsScreen`** (`scripts/ui/controls_screen.gd`, new) binds Astra's exact paths and is created by `Interface` under the Controls root, like `OptionsScreen`; the menu scene registry is unchanged.
  - The six `Preview*` rows are replaced by a heading per category and one `binding_row.tscn` row per catalog action. Slots show `BindingLabels` glyphs when the file exists, else text; changed rows are marked and Aplicar is disabled while nothing changed.
  - Focus: tabs → Ícones → rows (Principal → Alternativo → Redefinir) → Restaurar esta aba → Aplicar → Voltar, wrapping, with up/down by column, per-tab memory, `ensure_control_visible`, ActionHelp for the focused control, and only the shown tab linked. Entry focus stays on Voltar, which the existing menu contract test pins.
  - Capture: wait for release, listen, review after release, then Usar or Cancelar. Echo, actions, mouse motion and drift are ignored; axes need centre below 0.2 then 0.6; triggers handle a −1-at-rest backend; modifiers make chords or bind alone; Escape and the live accept/cancel can be captured; the other device's `ui_cancel` and a click on Cancelar cancel; 10 s timeout. Every event is consumed through `Interface._input`, focus is trapped in the dialog and the mouse is blocked behind it.
  - Conflicts: Trocar, Substituir, Cancelar through `assign`, each enabled only when a trial succeeds. F16-02's layout limit is resolved here: `pause` versus the menu-only actions are also compared in the layout's space, and such a conflict can only be replaced.
  - Draft until Aplicar; save failure shows "Não foi possível salvar os controles." and keeps both; a changed menu binding runs the 10 s confirmation on the new bindings, reverting on timeout, Reverter, `ui_cancel`, a disconnect, focus loss or the screen hiding. Restaurar esta aba, Redefinir and the Dirty dialog (Aplicar, Descartar, Continuar editando) work on the draft.
  - The Câmera tab and Ícones do controle store and save at once with the `Settings` ranges; the camera values reach the rig in F16-06.
- **Prompts:** `MenuController.set_prompts` writes every footer from the live bindings in the prompt family (keyboard, Xbox, PlayStation), pushed by `Interface` on every family or binding change. `set_keyboard_prompts` stays, for a menu on its own. `InputDeviceState` gains `get_controller_family` and `controller_family_changed`. `Interface` now applies `controller_glyph_family` as the glyph override at boot and on every change, global Defaults included. The HUD shows no control hints, so it is unchanged.
- **`controls.tscn` [shared], wiring only:** the preview rows and their scene reference removed; `CaptureDialog/Buttons/UseButton` ("Usar") and `ConflictDialog/Buttons/ReplaceButton` ("Substituir") added; "Escolher outro" → "Cancelar" and "Manter" → "Manter controles", as the spec names them. `options.tscn` is unchanged.
- **Verification.** The existing suite passes (225), the 300-frame boot is clean and `check_resources --strict-validate` passes (85 scripts). The suite enters and leaves Controls through `main.tscn`. The capture, conflict, dialog and confirmation paths were checked by reading only; nothing was driven by synthetic input and no device was used. No tests or drivers were written.
- **Not done here:** clearing a slot to blank from the UI (only Redefinir and Restaurar esta aba reach a blank Alternativo), and physical device feel, which is F16-07's.
