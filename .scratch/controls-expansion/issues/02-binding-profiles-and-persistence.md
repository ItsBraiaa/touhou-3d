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
