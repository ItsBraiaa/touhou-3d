# F16-02 binding-profiles-and-persistence

Status: todo
Type: core+adapter
Owner: Claude
Lane: trunk
Depends on: F16-00
Parallel-safe: yes, only within the orchestration plan's disjoint file boundaries

## Read first

- [Spec](../spec.md): product rules, exact widget paths, data shapes and proposed APIs.
- [Execution plan](../../../docs/engineering/controls-expansion-plan.md): ownership, task steps and review focus.
- docs/engineering/SPRINT.md in the worktree: no-new-tests rule and lane loop.

## Parts (routing, 2026-09-24, Claude)

- **Part 1 (landed by lane plan, commit "(F16-02 part 1)"):** the three new `project.godot` action defaults, so path's F16-04 and rescue's F16-05 could start at once:
  - `camera_recenter`: R (physical), Mouse 3 (middle) and RS/R3 (joypad button 8);
  - `dash_left`: Q (physical) and D-pad left (13);
  - `dash_right`: E (physical) and D-pad right (14).

  None was bound before; no script hardcodes a key.
- **Part 2 (lane trunk):** everything else in this ticket. Edit `project.godot` only to correct these defaults.
- **Must not touch while part 2 runs:** these belong to the parallel F16 lanes: `game_session.gd`, `player_controller.gd`, `combat_state.gd`, `hud.*` and `player_ship.tscn` (rescue F16-05); `camera_rig.gd` (path F16-04); `input_device_state.gd` and `binding_labels.gd` (oc-a F16-08).
- **Docs:** fill only the pre-made settings.md section "F16 binding profiles and persistence (F16-02)" and the F16-02 section of `docs/validation/controls-expansion.md`.

## Goal

Provide validated editable action profiles and robust local persistence before UI/camera consumers start.

## Files

- scripts/settings/input_bindings.gd (new)
- scripts/settings/settings.gd
- scripts/ui/input_binding_adapter.gd (new)
- scripts/ui/interface.gd (settings/adapter creation and application only)
- project.godot (new action defaults only)
- docs/engineering/settings.md (F16 data contracts)

Also update this ticket's Outcome, only its own docs/engineering/ROADMAP.md row, and append a newest-first docs/HANDOFF_LOG.md entry. New production scripts/assets include their generated .uid/.import sidecars. No files outside this boundary without first coordinating the owner and recording the expansion.

## Work

- [ ] Create the catalog and all proposed InputBindings/InputBindingAdapter APIs in the spec.
- [ ] Support primitive descriptors, two slots, context-aware conflicts and analog magnitude; required menu controls cannot disappear.
- [ ] Migrate existing settings without changing saved audio/display/camera values. Add schema version, validated fallback, temporary save/replace and pending-confirmation recovery.
- [ ] Create one Interface-owned adapter and apply profiles before menus accept input. Add camera_recenter, dash_left, dash_right defaults.

## Manual acceptance / existing gate

- Read old settings and restart: old values survive; new actions get defaults.
- Malformed/unknown binding data falls back per action without invalidating unrelated settings.
- Swapping menu actions succeeds as a complete transaction; invalid required-action removal is rejected.
- Disconnect/reconnect with a different device index retains the profile. A crash during unconfirmed application rolls back on next launch.

Write no new tests or disposable test drivers. Run the existing tools/lane.ps1 land gate after the scoped commit. A static/headless result does not certify physical device feel. Failures belong in Outcome and the handoff; never bypass the gate.

## Outcome

Not started. Produces the spec's binding APIs and saved schema; does not modify CameraRig or the controls scene.
