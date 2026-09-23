# Engineering Roadmap

The single "where are we" page for Claude's GDScript work. Every coding session reads this first, then its ticket. Astra reads "Requests to Astra" and "Received from Astra".

Deadline: 2026-09-24 (academic delivery). Today's baseline: 2026-09-20.

## How to run a session

1. Pick the first ticket whose Status is `todo` and whose dependencies are `done` (or a `parallel-safe: yes` ticket if another session is already running).
2. Paste its kickoff line into a fresh session. One ticket per session, never two.
3. The session ends with: `tools/test.ps1` (`tools/test.sh` on Linux) green, ticket `Status: done` (or `blocked` with the blocker written in the ticket), this page's row updated, a `docs/HANDOFF_LOG.md` entry, one commit of the session's own files.
4. Features F3 to F14 start with a `00-plan` ticket that writes `spec.md` and the real tickets, using what Codex has delivered by then.

Status values: `todo`, `doing`, `done`, `blocked`. Tickets live in `.scratch/<feature>/issues/NN-slug.md`. Rules are in [CONVENTIONS.md](CONVENTIONS.md), vocabulary in [CONTEXT.md](../../CONTEXT.md), decisions in [docs/adr/](../adr/).

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
| | | | 02 interface-and-menu-controller | adapter | no | todo |
| | | | 03 run-state-core | core | yes | todo |
| | | | 04 game-session-start-pause-quit | integration | no | todo |
| F3 | Settings | `settings` | 00 plan | docs | no | todo |
| F4 | Combat state and HUD | `combat-hud` | 00 plan | docs | no | todo |
| F5 | Projectile Field | `projectile-field` | 00 plan | docs | no | todo |
| F6 | Weapon and rendering | `weapon-rendering` | 00 plan | docs | no | todo |
| F7 | Damage, bomb, pickups | `damage-pickups` | 00 plan | docs | no | todo |
| F8 | Progression cores and content | `progression-core` | 00 plan | docs | no | todo |
| F9 | Enemies | `enemies` | 00 plan | docs | no | todo |
| F10 | Stage Director in Stage 1 | `stage-director` | 00 plan | docs | no | todo |
| F11 | Run flow | `run-flow` | 00 plan | docs | no | todo |
| F12 | Bosses | `bosses` | 00 plan | docs | no | todo |
| F13 | Audio | `audio` | 00 plan | docs | no | todo |
| F14 | Delivery | `delivery` | 00 plan | docs | no | todo |

Order rationale: Player before Menus (highest UX risk and GUIDE Section 13's assignment). Audio buses are created in F0-03 so F3 can bind Options to them. Enemies (F9) come before the Stage Director (F10) so the Director is integrated against real Waves. Codex's own priority list in `docs/STAGE_01_HANDOFF.md` is compatible with this order.

## Planned tickets for F3 to F14

Titles only; the `00-plan` session writes the bodies.

- **F3 Settings**: 01 settings-core-and-configfile; 02 options-screen-binding (audio buses, window mode, resolution); 03 input-device-mode-and-controller-disconnect.
- **F4 Combat state and HUD**: 01 combat-state-core; 02 hud-binding-and-target-marker; 03 boss-panel-and-attack-cue-api.
- **F5 Projectile Field**: 01 field-core-spawn-move-cull; 02 core-hit-sweep-and-graze-rules; 03 bomb-phase-clears-and-hit-spheres; 04 pattern-emitter-core.
- **F6 Weapon and rendering**: 01 rendering-spike (prototype skill, measured); 02 projectile-system-adapter (obstacle query, rendering); 03 weapon-model-and-player-weapon (fire, Aim Assist, Familiars, bomb request).
- **F7 Damage, bomb, pickups**: 01 hit-to-combat-state-and-defeat; 02 bomb-clear-and-invulnerability; 03 pickup-adapter-and-rewards.
- **F8 Progression cores and content**: 01 definition-schemas-and-content-validation; 02 encounter-machine-core; 03 snapshot-capture-restore; 04 stage-01-content-draft (dev, transcribed from STAGE_DESIGN).
- **F9 Enemies**: 01 enemy-model-core; 02 dev-prefabs-and-enemy-actor (Spirit, Sentry, threat feed); 03 seal-and-guard-rules.
- **F10 Stage Director in Stage 1**: 01 stage-director-adapter; 02 gate-and-checkpoint-adapters (PortalLinks too); 03 retry-restart-flow; 04 stage-01-contract-smoke-test.
- **F11 Run flow**: 01 defeat-results-retry-restart-screens; 02 campaign-continuation-and-direct-stage; 03 active-and-clear-time-verification.
- **F12 Bosses**: 01 boss-machine-core; 02 boss-controller-adapter; 03 lantern-guardian-in-s1-07; 04 tempest-sentinel-and-storm-guardian.
- **F13 Audio**: 01 audio-controller-events-and-limiter; 02 music-per-route-and-boss.
- **F14 Delivery**: 01 export-and-run-outside-editor; 02 package-and-acceptance-record.

## Risk

About 48 tickets against four days is aggressive. If the schedule slips, PLANEJAMENTO Section 11 says decorative density, secondary animation, and enemy variants are cut first; approved mechanics are not. Features most at risk: F12-04 (depends on Stage 2 and two boss scenes), F13 (depends on audio selection), and everything after F10 if the projectile rendering spike (F6-01) is slow. Scope changes are the user's call and are raised in the ticket, not decided in a session.

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
| F6 | Projectile visual presets (bullet meshes and materials for player and enemy shots) if final art is wanted; Claude ships `scenes/dev/` placeholders otherwise. |
| F7 | Pickup visuals (Power Pickup, Shield Pickup) following the `pickup.gd` root `Area3D` contract; dev placeholders otherwise. |
| F8-04 onward | Review and tune the Stage 1 `content/*.tres` draft that Claude transcribes from STAGE_DESIGN.md. Values are yours. |
| F9 | Spirit, Sentry, and Tempest Sentinel prefabs matching GUIDE Section 5 (`Enemy` root, `VisualRoot`, `HitVolume`, `Emitters`, `AnimationPlayer`). Claude ships `scenes/dev/` placeholders with the same tree until then. |
| F10 | Boss-arena retreat containment and any extra boundary presentation once Claude exposes active-Encounter bounds (see `docs/STAGE_01_HANDOFF.md`). |
| F12 | Lantern Guardian and Storm Guardian scenes with actual animation clip names; Stage 2 scene with `S2-01` to `S2-07`, `CP2-A`, `CP2-B`, seals, and guard links. |
| F13 | Event-to-sound selection from the Kenney packs and a music decision that respects the fan-content guidelines. |
| F14 | Nothing new; credits and licenses must already cover every integrated asset. |

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
