# Engineering Roadmap

The single "where are we" page for Claude's GDScript work. Every coding session reads this first, then its ticket. Astra reads "Requests to Astra" and "Received from Astra".

Deadline: 2026-09-24 (academic delivery). Baseline: 2026-09-20; F4 to F14 planned 2026-09-23.

## How to run a session

1. Pick the first ticket whose Status is `todo` and whose dependencies are `done` (or a `parallel-safe: yes` ticket if another session is already running).
2. Paste its kickoff line into a fresh session. One ticket per session, never two.
3. The session ends with: `tools/test.ps1` (`tools/test.sh` on Linux) green, ticket `Status: done` (or `blocked` with the blocker written in the ticket), this page's row updated, a `docs/HANDOFF_LOG.md` entry, one commit of the session's own files.
4. The F4 to F14 tickets were all written in one planning pass on 2026-09-23. Each feature's `spec.md` lists, under "Cross-feature contracts", the class, method and signal names that later features rely on; a session that changes one records it in its ticket's Outcome and its module doc. F3, F13 and F12-04 are cut pending the user.

Status values: `todo`, `doing`, `done`, `blocked`, `cut` (removed from this delivery pending the user's decision; never picked while cut). Tickets live in `.scratch/<feature>/issues/NN-slug.md`. Rules are in [CONVENTIONS.md](CONVENTIONS.md), vocabulary in [CONTEXT.md](../../CONTEXT.md), decisions in [docs/adr/](../adr/).

## Features and tickets

| # | Feature | Folder | Ticket | Type | Parallel-safe | Status |
| --- | --- | --- | --- | --- | --- | --- |
| F0 | Foundation | `foundation` | 01 git-init-and-ignores | docs | no | done |
| | | | 02 godot-wrapper-and-test-runner | core | no | done |
| | | | 03 project-config-main-scene-buses-export | integration | no | done (export step blocked: no export templates on this host; 2026-09-22 review fix: gameplay roots PAUSABLE) |
| | | | 04 guide-ownership-and-protocol-docs | docs | no | done |
| F1 | Player flight | `player-flight` | 01 flight-model-core | core | yes | done |
| | | | 02 player-controller-adapter | adapter | no | done |
| | | | 03 camera-rig | adapter | no | done |
| | | | 04 target-selector-and-targeting | core+adapter | no | done (physical-device pass still owed, as for 02 and 03) |
| | | | 05 astra-design-pass | design | no | blocked (decisions recorded; Inspector flight pass interrupted by Computer Use stop) |
| F2 | Menus and Session skeleton | `menus-session` | 01 screen-router-core | core | yes | done |
| | | | 02 interface-and-menu-controller | adapter | no | done (scripted keyboard and gamepad pass; physical-device pass owed; gamepad A/B added to `ui_accept`/`ui_cancel`) |
| | | | 03 run-state-core | core | yes | done |
| | | | 04 game-session-start-pause-quit | integration | no | done (menu-to-flight flow scripted on keyboard and gamepad; physical-device pass owed; Stage 2 wired too) |
| F3 | Settings | `settings` | 00 plan | docs | no | cut (pending the user, 2026-09-23: Options apply nothing, no `settings.cfg`, no disconnect pause) |
| F4 | Combat state and HUD | `combat-hud` | 00 plan | docs | no | done (one-pass planning, 2026-09-23; 01 was written and delivered separately) |
| | | | 01 combat-state-core | core | yes | done |
| | | | 02 hud-binding-and-target-marker | adapter | no | todo |
| | | | 03 boss-panel-and-attack-cue-api | adapter | no | todo |
| F5 | Projectile Field | `projectile-field` | 00 plan | docs | no | done (one-pass planning) |
| | | | 01 field-core-spawn-move-cull | core | yes | todo |
| | | | 02 core-hit-sweep-and-graze-rules | core | yes (after 01, same file) | todo |
| | | | 03 bomb-phase-clears-and-hit-spheres | core | yes (after 02, same file) | todo |
| | | | 04 pattern-emitter-core | core | yes | todo |
| F6 | Weapon and rendering | `weapon-rendering` | 00 plan | docs | no | done (one-pass planning) |
| | | | 01 rendering-spike | spike | no (FPS measured alone; 1 h time-box) | todo |
| | | | 02 projectile-system-adapter | adapter | no | todo |
| | | | 03 weapon-model-and-player-weapon | core+adapter | no | todo |
| F7 | Damage, bomb, pickups | `damage-pickups` | 00 plan | docs | no | done (one-pass planning) |
| | | | 01 hit-to-combat-state-and-defeat | integration | no | todo |
| | | | 02 bomb-clear-and-invulnerability | integration | no | todo |
| | | | 03 pickup-adapter-and-rewards | adapter | no | todo |
| F8 | Progression cores and content | `progression-core` | 00 plan | docs | no | done (one-pass planning) |
| | | | 01 definition-schemas-and-content-validation | core | yes | todo |
| | | | 02 encounter-machine-core | core | yes | todo |
| | | | 03 snapshot-capture-restore | core | yes | todo |
| | | | 04 stage-01-content-draft | content | yes | todo |
| F9 | Enemies | `enemies` | 00 plan | docs | no | done (one-pass planning) |
| | | | 01 enemy-model-core | core | yes | todo |
| | | | 02 dev-prefabs-and-enemy-actor | adapter | no | todo |
| | | | 03 seal-and-guard-rules | core+adapter | no | todo (lowest priority: its only consumer, Stage 2 S2-03, is cut with F12-04) |
| F10 | Stage Director in Stage 1 | `stage-director` | 00 plan | docs | no | done (one-pass planning) |
| | | | 01 stage-director-adapter | adapter | no | todo |
| | | | 02 gate-and-checkpoint-adapters | adapter | no | todo |
| | | | 03 retry-restart-flow | integration | no | todo |
| | | | 04 stage-01-contract-smoke-test | test | yes (one new test file) | todo |
| F11 | Run flow | `run-flow` | 00 plan | docs | no | done (one-pass planning) |
| | | | 01 defeat-results-retry-restart-screens | integration | no | todo |
| | | | 02 campaign-continuation-and-direct-stage | integration | no | todo |
| | | | 03 active-and-clear-time-verification | test | no | todo |
| F12 | Bosses | `bosses` | 00 plan | docs | no | done (one-pass planning) |
| | | | 01 boss-machine-core | core | yes | todo |
| | | | 02 boss-controller-adapter | adapter | no | todo |
| | | | 03 lantern-guardian-in-s1-07 | integration | no | todo |
| | | | 04 tempest-sentinel-and-storm-guardian | integration | no | cut (pending the user, 2026-09-23; carries Stage 2 gameplay integration too) |
| F13 | Audio | `audio` | 00 plan | docs | no | cut (pending the user, 2026-09-23: the game ships silent) |
| F14 | Delivery | `delivery` | 00 plan | docs | no | done (one-pass planning) |
| | | | 01 export-and-run-outside-editor | integration | no | todo (blocks itself until the user installs the Godot 4.7.2 export templates) |
| | | | 02 package-and-acceptance-record | tooling | no | todo |

Order rationale: Player before Menus (highest UX risk and GUIDE Section 13's assignment). Audio buses are created in F0-03 so F3 can bind Options to them. Enemies (F9) come before the Stage Director (F10) so the Director is integrated against real Waves. Codex's own priority list in `docs/STAGE_01_HANDOFF.md` is compatible with this order.

## Order to 2026-09-24

31 tickets are `todo`. The `Depends on` line in each ticket is authoritative; this is the order that keeps both lanes busy.

- **Integration lane.** One session at a time, in this order: F4-02 → F4-03 → F6-01 → F6-02 → F6-03 → F7-01 → F7-02 → F7-03 → F9-02 → F12-02 → F10-01 → F10-02 → F10-03 → F11-01 → F11-02 → F12-03 → F11-03 → F14-01 → F14-02.
  - Every one of these edits `scripts/session/game_session.gd` or a scene. Never run two together, even where their `Depends on` lines would allow it (F6-03 with F7-01, F7-02 with F10-01, F11-01, F11-02 and F12-03).
- **Core lane.** Parallel-safe tickets that run beside the integration lane: F5-01 → F5-02 → F5-03 → F5-04 → F9-01 → F8-01 → F8-02 → F8-04 → F8-03 → F12-01 → F10-04.
  - F5-01 to F5-03 gate F6-01 and F6-02, so start them at once.
  - F5-04 and F9-01 feed F9-02; F12-01 feeds F12-02; F8 feeds F10.
- **F6-01 runs alone.** Its FPS measurement is invalid while another session runs.
- **Last and optional: F9-03.** No scheduled scene hosts a Seal; cutting it is the user's call.
- **Human steps:**
  - Install the Godot 4.7.2 export templates (about 1 GB) before F14-01; F0-03 found none on this host.
  - A person plays the physical keyboard and DualSense pass and the clear-time measurement (F11-03, F14).

## Risk

31 tickets remain for one day, most of them on a single serialized integration lane, so the deadline is at risk even with the cuts.

**Cut pending the user on 2026-09-23** to protect the Stage 1 loop. Two of the three cuts each break a requirement of the assignment (PLANEJAMENTO Section 2):
- **F3 Settings.** The Options screen applies nothing.
- **F13 Audio.** The game ships silent, but the assignment requires "graphical interfaces and sound effects".
- **F12-04.** Stage 2 has no gameplay, so the Campaign's final victory is unreachable in play, and the stage chosen for the assignment's five-minute requirement (Stage 2, 5–6 min) cannot be measured. Stage 1's target is about four minutes.

Reinstating any cut is the user's call. The cheapest ways to keep both requirements are a reduced F13 that plays a few SFX on existing events, and Stage 1 pacing tuned to at least five minutes.

Other risks:
- **Projectiles.** The F6-01 rendering spike, and one physics ray per projectile per tick at 1000–3000 bullets (no ticket mitigates the ray cost yet).
- **F6-03 is the heaviest ticket.** Split the WeaponModel core out if it overruns.
- **F10-03 is a refactor.** It moves the per-ship setup that F4-02, F6-02, F6-03 and F7-02 added into one `_spawn_player()`.
- **F14-01 is blocked** until the export templates are installed.

If the schedule slips further, PLANEJAMENTO Section 11 cuts decorative density, secondary animation and enemy variants first; approved mechanics are not cut. Scope changes are raised in the ticket, not decided in a session.

## Requests to Astra

Dependencies Claude has on scene and content work. These are needs by Feature, not confirmed dates.

| Needed by | Request |
| --- | --- |
| F0-03 | None. Claude takes ownership of `project.godot`, `export_presets.cfg`, `default_bus_layout.tres`, `scenes/main.tscn` and `scenes/dev/`, plus script attachment, exported values, collision layers, masks, monitoring flags and the instancing of Claude's prefabs inside any `.tscn`. Do not edit them afterwards without a log entry. See GUIDE Section 3. |
| F0-03 onward | `build_scene_handoff.py` is retired to `docs/archive/build_scene_handoff.py.txt` (reference only). Do not rerun `build_menu_handoff.py` or `build_stage_01.py` over integrated scenes without reconciling first. |
| F0-03 onward | Every `.gd` compiles with `untyped_declaration`, `unused_variable`, `unused_parameter`, `shadowed_variable` as errors: type `for` iterators over untyped arrays (`for path: String in paths`). Claude typed the ones in `tools/validate_*.gd` on 2026-09-21; behavior unchanged. |
| F1-02 onward | F1-05: Inspector tuning blocked by stopped Computer Use; all numeric proposals and pinned values unchanged. Accept rectangular open corners for the dev harness only. Generator retired. See player-flight.md Open issues. |
| F1-03 onward | F1-05: camera tuning blocked. Choose proximity-driven ship transparency; reject the 6.5-unit gate pop as final production presentation. Claude to investigate obstruction transition; implementation and motion acceptance pending. See player-flight.md Open issues. |
| F1-03 onward | A human pass on a physical keyboard and on the DualSense pad this host has: the six movement axes, Focus, the arrow keys and right stick for the camera, `K`/`Y` to lock and `Tab`/`X` to cycle in the harness. Everything measured so far is simulated input, which ENGINEERING_BRIEF Section 8 says is not the same thing. |
| F1-04 onward | F1-05: keep left-to-right wrap as the design rule; feel/range/radius tuning still pending. Stage solid trunks/branches should occlude with fitted layer-1 collision; foliage should not. Collision authoring is a follow-up. Every lockable prefab remains a Node3D in targetable with a HitVolume child and its own volumes off layer 1. |
| F2-02 onward | Make a focused slider visible in `assets/ui/menu_theme.tres`: Godot 4.7's `Slider` never draws `HSlider/styles/focus`, and `grabber_area_highlight` is the same `SliderFill` as `grabber_area`, so a focused slider only has a slightly brighter grabber (`docs/validation/menus-options-entry.png`). A gold `HSlider/icons/grabber_highlight` or a distinct `grabber_area_highlight` would do. Optional: move Menu principal and Créditos up when Results hides both Continue and Replay (`menus-results-final.png`). |
| F2-04 onward | Stage scenes: keep `PlayerStart` in every stage root (a stage without it is refused) and the Stage root at the origin. Optional: add Stage 2's `FlightBounds/Limits` marker (`min`/`max` metadata) to Stage 1 with X -45..45, Y 0..75, Z -570..35, so the scene is the single source of its flight interior instead of `Main`'s `stage_flight_bounds`. A new stage needs its id and bounds sent to Claude, who adds it to `Main`. |
| F4-02 onward | Review the HUD dimming values (0.25 for a spent slot, 0.3 for a finished Phase). Optional: a two-phase boss-bar layout, since with `Phase3` hidden the right third of the panel stays empty. The four Results value labels become load-bearing in F11-01. |
| F6 | Projectile visual presets (radius-1 bullet meshes, one material per faction) and a final Familiar scene (Node3D root, no collision object); Claude ships `scenes/dev/` placeholders otherwise. Tune the weapon proposals in F6-03 (cadence, Familiar cadence, assist cones, shot speed, lifetime, damage) and the pattern defaults in F5-04. Solid scenery and closed Gate barriers must be layer-1 `StaticBody3D`; foliage stays off layer 1. F1 design call: the ship model never turns with the camera (the weapon compensates in code). |
| F7 | Pickup visuals (Power Pickup, Shield Pickup) keeping the dev prefab's root `Area3D` setup; a final Bomb blast effect, plus tuning of the Bomb radius and damage; dev placeholders otherwise. |
| F8-04 onward | Review and tune the Stage 1 `content/stages/stage_01/` draft that Claude transcribes from STAGE_DESIGN.md, including Portuguese place names for CP1-A and CP1-B (the Defeat screen shows the id text until then). Values are yours. |
| F9 | Spirit, Sentry, and Tempest Sentinel prefabs matching GUIDE Section 5 (`Enemy` root, `VisualRoot`, `HitVolume`, `Emitters`, `AnimationPlayer`). Claude ships `scenes/dev/` placeholders with the same tree until then, using your `scenes/enemies/visuals/` scenes as `VisualRoot`. Tune the dev enemy and pattern `.tres` files and the `HitVolume` radii, and choose an Anticipation clip. |
| F10 | Boss-arena retreat containment and any extra boundary presentation, using the Director's active-Encounter bounds (see `docs/STAGE_01_HANDOFF.md`). A checkpoint glow that reacts to `checkpoint_activated`. Keep the load-bearing names in `stage_01.tscn`: encounter roots and markers, `BarrierBody/Collision`, `ClosedVisual`, `Respawn`, and `Environment/PortalLinks/GuardLink1..3`. |
| F12 | `scenes/enemies/lantern_guardian.tscn` with the GUIDE Section 5 tree and the actual clip names for idle, step cue and defeat; the shrine-lighting `AnimationPlayer` clip (corrupted to calm) in Stage 1, with its path and clip name sent to Claude; tuning of `lantern_guardian.tres` and its patterns. Confirm or reject F12-01's reading that a boss takes no damage during a Phase transition (PLANEJAMENTO forbids "artificial invulnerability timers"). F12-04, cut pending the user: Storm Guardian and Tempest Sentinel scenes, Stage 2 gameplay markers, seal and portal-light states. |
| F13 | Cut pending the user. If reinstated: the event-to-sound selection from the Kenney packs, and a music decision that respects the fan-content guidelines. |
| F14 | Nothing new; credits and licenses must already cover every integrated asset. F14-02 lists any gaps it finds. |

## Received from Astra

Stage 2 art revision: `.scratch/stage-02-area/issues/02-mountain-art-pass.md` — **done** (textures, terrain, vegetation and ambient visual motion; gameplay pending).

Stage 2 scene ticket: `.scratch/stage-02-area/issues/01-mountain-route.md` — **done** (static scene only).

2026-09-21: Four Stage 1 visual variants are ready in `scenes/enemies/visuals/`; see [ENEMY_VISUAL_HANDOFF.md](../ENEMY_VISUAL_HANDOFF.md). These are visual components for F9, not complete enemy adapters/prefabs. No health changes; animation references and proposed wave assignment are documented.

| Date | Deliverable | Where | State |
| --- | --- | --- | --- |
| 2026-09-22 | F1 design decisions, retired generator, lossless enemy atlas imports; Inspector flight tuning blocked by stopped Computer Use | `.scratch/player-flight/issues/05-astra-design-pass.md`, `docs/engineering/player-flight.md` Open issues | PARTIAL / BLOCKED |
| 2026-09-21 | Stage 2 textured mountain route, vegetation, ambient motion, seven encounters, seals and checkpoints | `scenes/stages/stage_02.tscn`, `docs/STAGE_02_HANDOFF.md` | SCENE_READY_STATIC |
| 2026-09-20 | Player ship and static arena | `scenes/player/player_ship.tscn`, `scenes/tests/combat_arena.tscn`, GUIDE Section 13 | SCENE_READY |
| 2026-09-20 | Eight menu scenes and theme | `scenes/ui/*.tscn`, GUIDE Section 14 | SCENE_READY |
| 2026-09-20 | Combat HUD | `scenes/ui/hud.tscn`, GUIDE Section 15 | SCENE_READY |
| 2026-09-20 | Stage 1 area with encounters, gates, checkpoints, spawn markers | `scenes/stages/stage_01.tscn`, `docs/STAGE_01_HANDOFF.md` | SCENE_READY_STATIC |
| 2026-09-20 | Approved models and art direction | `docs/MODEL_SELECTION.md` | reference |

## Decision log

Architecture and style decisions are not repeated here. See `docs/adr/` and `CONVENTIONS.md`. Gameplay rules stay in `docs/PLANEJAMENTO.md` and `docs/STAGE_DESIGN.md`.
