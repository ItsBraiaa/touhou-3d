# Engineering Roadmap

The single "where are we" page for the project's code work. Every coding session reads this first, then its ticket. Astra reads "Requests to Astra" and "Received from Astra".

Deadline: 2026-09-24 (academic delivery). Baseline: 2026-09-20; F4 to F14 planned 2026-09-23; the four-lane sprint started the same evening.

## How to run a session

**During the sprint, [SPRINT.md](SPRINT.md) replaces steps 1 and 2.** Each lane (trunk, path, oc-a, oc-b, sol, and rescue or terra on demand) works its own queue in its own git worktree, on its own `lane/<name>` branch, and lands each ticket with `tools/lane.ps1 land`. Nobody works in the primary tree.

1. Pick the first ticket whose Status is `todo` and whose dependencies are `done` (or a `parallel-safe: yes` ticket if another session is already running).
2. Paste its kickoff line into a fresh session. One ticket per session, never two.
3. The session ends with: `tools/test.ps1` (`tools/test.sh` on Linux) green, ticket `Status: done` (or `blocked` with the blocker written in the ticket), this page's row updated, a `docs/HANDOFF_LOG.md` entry, one commit of the session's own files.
4. The F4 to F14 tickets were written in one planning pass on 2026-09-23, and F3, F13, Stage 2 (F12-04 to F12-07) and the Astra design tickets (D-01 to D-07) followed in the sprint plan. Each feature's `spec.md` lists, under "Cross-feature contracts", the class, method and signal names that later features rely on. A session that changes one records it in its ticket's Outcome and its module doc.

Status values: `todo`, `doing`, `done`, `blocked`, `cut` (removed from this delivery by a user decision; never picked while cut). Tickets live in `.scratch/<feature>/issues/NN-slug.md`; the design sprint lives in `.scratch/design-sprint/`. Rules are in [CONVENTIONS.md](CONVENTIONS.md), vocabulary in [CONTEXT.md](../../CONTEXT.md), decisions in [docs/adr/](../adr/).

## Features and tickets

A lane edits only its own rows (SPRINT.md "Shared files").

| # | Feature | Folder | Ticket | Type | Parallel-safe | Lane | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| F0 | Foundation | `foundation` | 01 git-init-and-ignores | docs | no | — | done |
| | | | 02 godot-wrapper-and-test-runner | core | no | — | done |
| | | | 03 project-config-main-scene-buses-export | integration | no | — | done (export step blocked: no export templates on this host; 2026-09-22 review fix: gameplay roots PAUSABLE) |
| | | | 04 guide-ownership-and-protocol-docs | docs | no | — | done |
| F1 | Player flight | `player-flight` | 01 flight-model-core | core | yes | — | done |
| | | | 02 player-controller-adapter | adapter | no | — | done |
| | | | 03 camera-rig | adapter | no | — | done |
| | | | 04 target-selector-and-targeting | core+adapter | no | — | done (physical-device pass still owed, as for 02 and 03) |
| | | | 05 astra-design-pass | design | no | — | blocked (decisions recorded; Inspector flight pass interrupted by Computer Use stop) |
| F2 | Menus and Session skeleton | `menus-session` | 01 screen-router-core | core | yes | — | done |
| | | | 02 interface-and-menu-controller | adapter | no | — | done (scripted keyboard and gamepad pass; physical-device pass owed; gamepad A/B added to `ui_accept`/`ui_cancel`) |
| | | | 03 run-state-core | core | yes | — | done |
| | | | 04 game-session-start-pause-quit | integration | no | — | done (menu-to-flight flow scripted on keyboard and gamepad; physical-device pass owed; Stage 2 wired too) |
| F3 | Settings | `settings` | 00 plan | docs | no | — | done (cut, then reinstated by the sprint plan, 2026-09-23) |
| | | | 01 settings-core-and-configfile | core | yes | oc-b | todo |
| | | | 02 options-screen-binding | adapter | no | oc-b | todo |
| | | | 03 input-device-mode-and-controller-disconnect | adapter | no | oc-b | todo |
| | | | 04 settings-to-camera-wiring | integration | no | trunk (part 1: path) | todo |
| F4 | Combat state and HUD | `combat-hud` | 00 plan | docs | no | — | done (one-pass planning, 2026-09-23; 01 was written and delivered separately) |
| | | | 01 combat-state-core | core | yes | — | done |
| | | | 02 hud-binding-and-target-marker | adapter | no | trunk | done (2026-09-23: `Hud` bound to the Session's `CombatState` and each ship's `Targeting`; marker verified in the harness) |
| | | | 03 boss-panel-and-attack-cue-api | adapter | no | trunk | done (2026-09-23: boss panel, cue and threat API on `Hud`; verified by `scenes/dev/hud_harness.tscn`, no new tests per the sprint rule) |
| F5 | Projectile Field | `projectile-field` | 00 plan | docs | no | — | done (one-pass planning) |
| | | | 01 field-core-spawn-move-cull | core | yes | path | done |
| | | | 02 core-hit-sweep-and-graze-rules | core | yes (after 01, same file) | path | done (no unit tests, by the sprint rule; ruling 5 pending) |
| | | | 03 bomb-phase-clears-and-hit-spheres | core | yes (after 02, same file) | path | todo |
| | | | 04 pattern-emitter-core | core | yes | oc-a | todo |
| F6 | Weapon and rendering | `weapon-rendering` | 00 plan | docs | no | — | done (one-pass planning) |
| | | | 01 rendering-spike | spike | no | — | cut (folded into 02 by the sprint plan: MultiMesh by default, benchmark inside 02) |
| | | | 02 projectile-system-adapter | adapter | no | trunk | todo |
| | | | 03 weapon-model-and-player-weapon | core+adapter | no | trunk (part 1: oc-a) | todo |
| F7 | Damage, bomb, pickups | `damage-pickups` | 00 plan | docs | no | — | done (one-pass planning) |
| | | | 01 hit-to-combat-state-and-defeat | integration | no | trunk | todo |
| | | | 02 bomb-clear-and-invulnerability | integration | no | trunk | todo |
| | | | 03 pickup-adapter-and-rewards | adapter | no | path | todo |
| F8 | Progression cores and content | `progression-core` | 00 plan | docs | no | — | done (one-pass planning) |
| | | | 01 definition-schemas-and-content-validation | core | yes | oc-b | todo |
| | | | 02 encounter-machine-core | core | yes | oc-b | todo |
| | | | 03 snapshot-capture-restore | core | yes | oc-b | todo |
| | | | 04 stage-01-content-draft | content | yes | oc-b | todo |
| F9 | Enemies | `enemies` | 00 plan | docs | no | — | done (one-pass planning) |
| | | | 01 enemy-model-core | core | yes | oc-a | todo |
| | | | 02 dev-prefabs-and-enemy-actor | adapter | no | path | todo |
| | | | 03 seal-and-guard-rules | core+adapter | no | oc-a | todo (consumed by F12-05, Stage 2 S2-03) |
| F10 | Stage Director in Stage 1 | `stage-director` | 00 plan | docs | no | — | done (one-pass planning) |
| | | | 01 stage-director-adapter | adapter | no | trunk | todo |
| | | | 02 gate-and-checkpoint-adapters | adapter | no | trunk | todo |
| | | | 03 retry-restart-flow | integration | no | trunk | todo |
| | | | 04 stage-01-contract-smoke-test | test | yes (one new test file) | — | cut (the user's no-tests rule, 2026-09-23) |
| F11 | Run flow | `run-flow` | 00 plan | docs | no | — | done (one-pass planning) |
| | | | 01 defeat-results-retry-restart-screens | integration | no | trunk | todo |
| | | | 02 campaign-continuation-and-direct-stage | integration | no | trunk | todo |
| | | | 03 active-and-clear-time-verification | test | no | path | todo (manual protocol only; no tests) |
| F12 | Bosses and Stage 2 | `bosses` | 00 plan | docs | no | — | done (one-pass planning; Stage 2 reinstated by the sprint plan) |
| | | | 01 boss-machine-core | core | yes | path | todo |
| | | | 02 boss-controller-adapter | adapter | no | path | todo |
| | | | 03 lantern-guardian-in-s1-07 | integration | no | trunk (part 1: oc-a) | todo |
| | | | 04 stage-02-content-draft | content | yes | oc-b | todo |
| | | | 05 stage-02-director-integration | adapter | no | sol | todo |
| | | | 06 tempest-sentinel-miniboss | integration | no | sol | todo |
| | | | 07 storm-guardian | integration | no | sol | todo |
| F13 | Audio | `audio` | 00 plan | docs | no | — | done (cut, then reinstated by the sprint plan, 2026-09-23) |
| | | | 01 audio-limiter-core | core | yes | oc-a | todo |
| | | | 02 audio-controller-adapter | adapter | no | oc-a | todo |
| | | | 03 audio-event-wiring | integration | no | trunk | todo |
| F14 | Delivery | `delivery` | 00 plan | docs | no | — | done (one-pass planning) |
| | | | 01 export-and-run-outside-editor | integration | no | trunk | todo (blocks itself until the user installs the Godot 4.7.2 export templates) |
| | | | 02 package-and-acceptance-record | tooling | no | oc-b | todo |
| D | Design sprint (Astra) | `design-sprint` | 01 sfx-selection-and-import | design | — | sol | todo |
| | | | 02 combat-visuals | design | — | sol | todo |
| | | | 03 lantern-guardian-scene | design | — | sol | todo |
| | | | 04 stage-2-boss-scenes | design | — | sol | todo |
| | | | 05 stage-1-tuning-and-pacing | design | — | sol | todo |
| | | | 06 stage-2-content-review | design | — | sol | todo |
| | | | 07 shrine-lighting-and-boss-rulings | design | — | sol | todo (Part B, the rulings, lands early) |

Order rationale: Player before Menus (highest UX risk and GUIDE Section 13's assignment). Audio buses are created in F0-03 so F3 can bind Options to them. Enemies (F9) come before the Stage Director (F10) so the Director is integrated against real Waves. The sprint's lane queues, checkpoints and kickoff prompts are in [SPRINT.md](SPRINT.md).

## Risk

48 tickets are `todo` for about one day across five standing lanes (trunk 15, path 8, oc-a 6, oc-b 9, sol 10), with rescue on demand. OpenCode tickets carry a per-ticket `Model:` line (SPRINT.md "Model budgets"). The trunk lane is the critical path, because every `game_session.gd` edit is serialized there.

If a SPRINT.md checkpoint slips by more than an hour, the proposed cut order is: music, then F3-03's prompt icons, then the Storm Guardian's final art, then Stage 2 entirely, with D-05's Stage 1 pacing raised to five minutes. The user confirms each step. PLANEJAMENTO Section 11 still cuts decorative density, secondary animation and enemy variants before approved mechanics. Scope changes are raised in the ticket or at a checkpoint, never decided inside a session.

Other risks:
- **No new tests (the user's rule, 2026-09-23).** The only automated gate is `tools/lane.ps1 land`: the existing suite plus a headless boot of the main scene. Regressions in code without coverage surface only in game runs, the reviewers and the human pass.
- **Projectiles.** One physics ray per projectile per tick at 1000 to 3000 bullets. F6-02's folded benchmark measures it while other lanes run, so the numbers are pessimistic; no ticket mitigates the ray cost yet.
- **Heavy tickets.** F6-03 is the heaviest; split the WeaponModel core out if it overruns. F10-03 is a refactor: it moves the per-ship setup from F4-02, F6-02, F6-03 and F7-02 into one `_spawn_player()`.
- **Cross-lane edits.** Four files are edited by two lanes with no dependency between them (SPRINT.md "Shared files"); the second to land merges both.
- **Human steps.** F14-01 is blocked until the export templates are installed, and the listening pass, the physical-device pass and the five-minute measurement need a person.

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
| F2-02 onward | **D-02.** The focused-slider fix in `assets/ui/menu_theme.tres` described in the F2-02 row above; it matters now that F3-02 makes Options live. |
| F2-04 onward | Stage scenes: keep `PlayerStart` in every stage root (a stage without it is refused) and the Stage root at the origin. Optional: add Stage 2's `FlightBounds/Limits` marker (`min`/`max` metadata) to Stage 1 with X -45..45, Y 0..75, Z -570..35, so the scene is the single source of its flight interior instead of `Main`'s `stage_flight_bounds`. A new stage needs its id and bounds sent to Claude, who adds it to `Main`. |
| F4-02 onward | **D-07 Part B.** Review the HUD dimming values (0.25 for a spent slot, 0.3 for a finished Phase). Optional: a two-phase boss-bar layout, since with `Phase3` hidden the right third of the panel stays empty. The four Results value labels become load-bearing in F11-01. |
| F6 | **D-02 (meshes, Familiar), D-05 (values).** Projectile visual presets (radius-1 bullet meshes, one material per faction) and a final Familiar scene (Node3D root, no collision object); Claude ships `scenes/dev/` placeholders otherwise. Tune the weapon proposals in F6-03 (cadence, Familiar cadence, assist cones, shot speed, lifetime, damage) and the pattern defaults in F5-04. Solid scenery and closed Gate barriers must be layer-1 `StaticBody3D`; foliage stays off layer 1. F1 design call: the ship model never turns with the camera (the weapon compensates in code). |
| F7 | **D-02 (visuals), D-05 (values).** Pickup visuals (Power Pickup, Shield Pickup) keeping the dev prefab's root `Area3D` setup; a final Bomb blast effect, plus tuning of the Bomb radius and damage; dev placeholders otherwise. |
| F8-04 onward | **D-05.** Review and tune the Stage 1 `content/stages/stage_01/` draft that Claude transcribes from STAGE_DESIGN.md, including Portuguese place names for CP1-A and CP1-B (the Defeat screen shows the id text until then). Values are yours. |
| F9 | **D-04 (Sentinel), D-05 (tuning).** Spirit, Sentry, and Tempest Sentinel prefabs matching GUIDE Section 5 (`Enemy` root, `VisualRoot`, `HitVolume`, `Emitters`, `AnimationPlayer`). Claude ships `scenes/dev/` placeholders with the same tree until then, using your `scenes/enemies/visuals/` scenes as `VisualRoot`. Tune the dev enemy and pattern `.tres` files and the `HitVolume` radii, and choose an Anticipation clip. |
| F10 | Boss-arena retreat containment and any extra boundary presentation, using the Director's active-Encounter bounds (see `docs/STAGE_01_HANDOFF.md`). A checkpoint glow that reacts to `checkpoint_activated`. Keep the load-bearing names in `stage_01.tscn`: encounter roots and markers, `BarrierBody/Collision`, `ClosedVisual`, `Respawn`, and `Environment/PortalLinks/GuardLink1..3`. |
| F12 | **D-03, D-04, D-06, D-07.** `scenes/enemies/lantern_guardian.tscn` with the GUIDE Section 5 tree and the actual clip names for idle, step cue and defeat; the shrine-lighting `AnimationPlayer` clip (corrupted to calm) in Stage 1, with its path and clip name sent to Claude; tuning of `lantern_guardian.tres` and its patterns. Confirm or reject F12-01's reading that a boss takes no damage during a Phase transition (PLANEJAMENTO forbids "artificial invulnerability timers"). Stage 2 (reinstated): Storm Guardian and Tempest Sentinel scenes (D-04), the Stage 2 content review (D-06), and a resolved portal-light material plus the storm-resolution clip in `stage_02.tscn`, which no D ticket covers yet. |
| F13 | **D-01.** Reinstated. The event-to-sound selection from the Kenney packs, and a music decision that respects the fan-content guidelines. |
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
