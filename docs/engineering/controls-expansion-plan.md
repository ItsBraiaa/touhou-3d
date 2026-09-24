# F16 Controls, Camera and Dash Implementation Plan

> For agentic workers: Claude orchestrates the named lanes and one ticket per session. Codex implementers use superpowers:executing-plans; the user's no-new-tests rule overrides TDD instructions. Read the spec and your ticket before implementation.

**Goal:** Deliver editable keyboard/mouse and Xbox/PlayStation controls, mouse orbit, camera recentering and a short invulnerable lateral dash.
**Architecture:** One settings owner and one InputMap adapter in Interface; Node-free binding and dash rules; CameraRig/PlayerController adapters; existing CombatState owns all protection. Astra authors UI and VFX components, Claude owns wiring and behavior.
**Tech stack:** Godot 4.7.2, typed GDScript, .tscn/.tres, ConfigFile.
**Spec:** [F16 spec](../../.scratch/controls-expansion/spec.md).
**Status:** Planning deliverable; implementation not started.
**Orchestrator kickoff:** [CLAUDE_KICKOFF.md](../../.scratch/controls-expansion/CLAUDE_KICKOFF.md).

## Global constraints

- No new tests of any kind, including disposable test scripts; run the existing lane gate and manual game checks.
- Never edit the primary tree; sol authors design/layout, trunk owns project.godot, player_ship.tscn, main.tscn and Session, path owns the assigned standalone camera ticket.
- Engineering docs/identifiers English; player-facing UI Portuguese.
- Keep base_speed 12.0, focus_multiplier 0.45, follow_distance 8.5 and follow_height 3.2.
- Dash 3.0 units / 0.15 s, shared 0.8 s cooldown from activation, 0.15 s invulnerability; no Graze or wall phasing.
- One ticket, handoff and scoped commit per implementation session. No remote push, history rewrite or blanket staging.
- Lane assignments below are this new feature's proposal, not permission to interrupt unrelated in-progress tickets. Claude dispatches only into an available lane.

## Ownership and execution order

| Ticket | Owner/lane | Deliverable | Dependencies |
| --- | --- | --- | --- |
| F16-00 | Astra / sol | This design, plan, tickets and kickoff | F3-04, F7-02 |
| F16-01 | Astra / sol | Controls layout, modal/row templates, cooldown and dash visual components | F16-00 |
| F16-02 | Claude / trunk | Catalog, profiles, persistence/migration and InputMap adapter | F16-00 |
| F16-03 | Claude / trunk | Functional rebinding UI, conflict/capture flow and dynamic prompts | F16-01, F16-02 |
| F16-04 | Claude / path | Mouse orbit and free/locked recenter behavior | F16-00 (routing below) |
| F16-05 | Claude / rescue | Dash timing/movement, combat protection, cooldown and VFX integration | part 1 F16-00; part 2 F16-01 (routing below) |
| F16-06 | Claude / trunk | Camera settings/input lifecycle integration and complete return flows | F16-03, F16-04, F16-05 |
| F16-07 | Astra / sol; Claude coordinates engineering fixes | Visual/device acceptance and final record | F16-06 |
| F16-08 | OpenCode / oc-a | Binding labels, glyph ids and controller-family detection (carved out of F16-03) | F16-00 |

**Routing (2026-09-24, Claude, as orchestrator):**

- **F16-02 part 1:** lane plan landed the three new action defaults first, so no other lane waits on `project.godot`.
- **F16-04** starts at once, because CameraRig reads no Settings.
- **F16-05** moves to a third Claude lane, `rescue`. Part 1 (mechanics and protection) starts at once; part 2 (Astra's components) follows F16-01. Its files are disjoint from trunk's 02 and 03, and trunk gets Session and `player_ship.tscn` back for F16-06.
- **F16-08 (OpenCode):** takes the labels and prompt-family work out of F16-03.

Shared docs have one pre-made section per ticket. Earlier text: F16-01 and F16-02 can run concurrently on disjoint files. After F16-02 lands, F16-04 can run alongside trunk's F16-03 then F16-05; it does not touch Session, Interface, settings schema or player_ship.tscn. F16-06 is the serialized convergence. F16-07 follows the integrated result, not a static mockup.

No new agent is launched by this planning ticket. Claude uses the kickoff to dispatch implementation only when requested. If sol/path is occupied, wait or execute the ticket later in its named lane; never share a worktree.

## File and interface boundaries

New paths are planned; existing paths below were inspected at planning time.

| Unit | Files | Responsibility |
| --- | --- | --- |
| Binding rules | scripts/settings/input_bindings.gd (new) | Catalog, contexts, descriptors, conflicts, required-action validation, defaults |
| Saved settings | scripts/settings/settings.gd | Extend current ConfigFile storage and migrate old eight-value settings without loss |
| Input adapter | scripts/ui/input_binding_adapter.gd (new), scripts/ui/interface.gd | Convert real events, install both device profiles once, preserve unowned actions |
| Controls UI | scenes/ui/controls.tscn, scenes/ui/components/binding_row.tscn (new), scripts/ui/controls_screen.gd (new) | Astra layout; Claude draft/capture/apply behavior |
| Existing menus | scripts/ui/menu_controller.gd, input_device_state.gd, options_screen.gd | Dynamic bindings/glyphs, actual tab focus loop, integration with global Defaults |
| Camera | scripts/player/camera_rig.gd | Mouse and recenter; retain existing apply_settings compatibility |
| Dash | scripts/player/dash_model.gd (new), player_controller.gd | Timing rules and collision-driven lateral burst |
| Combat integration | scripts/combat/combat_state.gd, scripts/session/game_session.gd | Grant and propagate protection before sweep, signal lifetime, spawn/reset cleanup |
| Presentation integration | scripts/ui/hud.gd, scenes/ui/hud.tscn, scenes/player/player_ship.tscn | Attach/drive Astra's components without changing Core or Graze geometry |
| Configuration | project.godot | New actions and default bindings, trunk only |

All concrete widget paths, proposed method signatures and data shapes are in the spec. Each ticket names only its own subset. Read current code after sync; do not use line numbers or assumed historical state as an edit target.

## Task steps

### F16-01: Astra scene pass
- [ ] Build the authored screen and reusable components at the spec's exact paths, preserving the existing root script, BackButton and NavigationHint.
- [ ] Lay out all visual states and Portuguese text; keep the list scrollable and footer fixed, with controller-visible focus.
- [ ] Create original Xbox/PlayStation glyphs with text fallback and a non-obscuring cyan dash visual; list external asset sources if any.
- [ ] Inspect at 1280×720, 1600×900 and 1920×1080; record screenshots and the widget inventory in docs/validation/controls-expansion.md. Static inspection does not certify runtime remapping.
- [ ] Land before Claude binds the screen. Subsequent scene changes preserve its paths/wiring.

### F16-02: Claude input/persistence foundation
- [ ] Inventory every action consumed by scripts and menu focus; create the catalog and the spec's descriptor methods.
- [ ] Preserve analog magnitude, two slots, context-aware conflicts and independent device profiles; validate required menu/gameplay actions.
- [ ] Extend Settings persistence with a versioned controls section, migration and atomic save; old audio/display/camera values remain intact.
- [ ] Install profiles once through the new Interface-owned adapter before interactive menu input; add the three new action defaults in project.godot. Preserve unrelated engine actions.
- [ ] Manually verify restart persistence, old-file migration, malformed-binding fallback and controller-index changes. Land contracts before consumers start.

### F16-03: Claude controls workflow
- [ ] Attach ControlsScreen through Interface, consuming F16-01 paths and F16-02 bindings; no menu scene registry replacement.
- [ ] Implement wait-release/listen/candidate/conflict/confirm state transitions; consume all events during capture and retain focus origin.
- [ ] Bind Apply/restore-tab/dirty-exit/save-failure/rollback flows, with no gameplay actions under menus.
- [ ] Render current binding prompts for keyboard/Xbox/PlayStation everywhere. Preserve automatic device and disconnect behavior, including profile confirmation rollback.
- [ ] Walk remapped menu navigation, conflict swap, invalid replacement, Escape assignment, held trigger/drift and no-input timeout. Land before trunk's dash ticket.

### F16-04: Claude camera adapter
- [ ] Implement request_recenter and apply_control_settings from the spec while preserving existing settings API and collision/roll contracts.
- [ ] Accumulate relative mouse displacement only when explicitly active; apply once without delta multiplication. Keyboard/stick remain rate-based.
- [ ] Implement lock-look override and inactivity return; free/locked shortest-path recenter, interruption and no queued repeat.
- [ ] Expose lifecycle methods for F16-06: set_mouse_capture_active(active: bool) and clear_pending_look() to gate collection/reset deltas. Session/Interface, not the rig alone, decide whether gameplay is active.
- [ ] Inspect the adapter in the existing arena scene with its exported mode values; final pause/settings-device integration remains F16-06. Do not add a test driver or edit a trunk scene to bypass the boundary.

### F16-05: Claude invulnerable dash
- [ ] Implement DashModel acceptance/timers; integrate replacement lateral velocity and captured direction in PlayerController.
- [ ] Use collision-aware motion with no remaining tangent slide on impact; stop at closed Gates/Flight Volume edges. Clamp the final movement step to remaining active time.
- [ ] Add CombatState.grant_invulnerability with max(existing, duration). Connect dash_started synchronously in the owning Session before any field sweep can hit or Graze that activation tick.
- [ ] Confirm actual physics ordering of Session timer tick → player activation/motion → projectile sweep. Document the first and last protected ticks; avoid one frame of vulnerability on activation or one extra frame on expiry.
- [ ] Wire dash visuals/HUD and lifecycle cleanup. Reuse the existing protection signal to the field; preserve Bomb/hit overlap. No new damage path.
- [ ] Manually cross a projectile pattern and walls, check Shield/health/Graze, cooldown spam, simultaneous directions, pause/Retry and Bomb overlap. Land with measured observations.

### F16-06: Claude integrated controls
- [ ] Route all new camera settings at spawn, from paused Options and after Retry/Restart; clear stale deltas/actions on transitions.
- [ ] Drive cursor capture from gameplay/menu/focus state. Losing focus pauses an active Run; returning does not resume it.
- [ ] Wire recenter input without letting the capture dialog trigger it; resolve lock/manual orbit and multi-device behavior.
- [ ] Integrate Options → Controls → caller with defaults, confirmation rollback, disconnect recovery and no duplicate signal connections.
- [ ] Land after playing both stages and returning through main-menu and pause callers; update GUIDE contracts and controls/module docs.

### F16-07: Astra acceptance with Claude fixes
- [ ] Judge scene readability, focused-row scrolling, modal states, true dynamic glyphs, cooldown and dash VFX in the integrated game.
- [ ] Run the ticket's device/manual matrix. Record unavailable hardware as not verified, not passed.
- [ ] Tune only approved content/presentation values; send any player_ship.tscn or code-value requests to trunk with exact requested numbers and reasons.
- [ ] Claude fixes engine/input/combat findings in scoped follow-up commits in the owning lane; rerun affected checks, then the existing landing gate.
- [ ] Record accepted dash/camera values, remaining limitations and the integrated commit. A new export/package is a separate explicit release step; do not claim the old packaged executable includes F16.

## Review focus

1. Losing confirm/back while rebinding: F16-02 validates the final profile; F16-03 offers timed rollback and F16-07 walks keyboard/controller recovery.
2. Trigger drift or opener accidentally becoming a binding: F16-03 requires neutral/release and candidate review; F16-07 exercises real devices.
3. Cursor/camera motion leaking through Pause, focus loss or mode changes: F16-04 gates/reset deltas; F16-06 owns lifecycle; F16-07 repeats transitions.
4. Dash protection arriving after a projectile sweep or awarding Graze: F16-05 owns physics ordering and shared CombatState propagation; F16-07 crosses live patterns.
5. Conflicting writes to Interface, Session, project.godot or player_ship.tscn: serialize trunk tickets; path's camera ticket is confined to CameraRig; sol hands over components before wiring.

## Landing protocol

From the ticket's named lane, never the primary tree:
~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/lane.ps1 sync
powershell -NoProfile -ExecutionPolicy Bypass -File tools/lane.ps1 status .scratch/controls-expansion/issues/02-binding-profiles-and-persistence.md
# Implement only that ticket; perform its manual acceptance; update docs and Outcome.
git add -- scripts/settings/input_bindings.gd scripts/settings/input_bindings.gd.uid scripts/settings/settings.gd scripts/ui/input_binding_adapter.gd scripts/ui/input_binding_adapter.gd.uid scripts/ui/interface.gd project.godot docs/engineering/settings.md .scratch/controls-expansion/issues/02-binding-profiles-and-persistence.md docs/engineering/ROADMAP.md docs/HANDOFF_LOG.md
git commit -m "controls: add binding profiles and persistence (F16-02) [shared]"
powershell -NoProfile -ExecutionPolicy Bypass -File tools/lane.ps1 land
~~~

The commands above are the concrete F16-02 example; other tickets use their own filename and exact Files list. The land gate runs the existing suite, boot and resource check. Do not add tests or bypass a failure. The orchestrator records gate failures against the responsible ticket, including unrelated integration blockers.

## Planning self-review

Coverage: all requested binding families and menu actions → 01/02/03/07; mouse and recenter → 04/06/07; dash and invulnerability → 05/07; persistence, focus and rollback → 02/03/06/07. File overlaps are serialized; proposed interfaces are listed once in the spec, with the camera lifecycle additions explicit in 04. No new tests are requested. No gameplay implementation is claimed by this plan.
