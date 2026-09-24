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
| | | | 01 settings-core-and-configfile | core | yes | oc-b | done (2026-09-23: `Settings` core and explicit ConfigFile persistence landed; no tests per sprint rule) |
| | | | 02 options-screen-binding | adapter | no | path | done (2026-09-23: `Interface` owns the one `Settings`; `OptionsScreen` binds the eight widgets, applies buses and window, saves on change and Defaults; no new tests, by the sprint rule; windowed display pass owed to F3-04 part 1) |
| | | | 03 input-device-mode-and-controller-disconnect | adapter | no | path | done (2026-09-23: one `InputDeviceState` in `Interface` drives every menu footer; a controller unplugged over the HUD pauses through `pause`; no new tests, by the sprint rule; physical unplug owed to the human pass) |
| | | | 04 settings-to-camera-wiring | integration | no | path | done (2026-09-24: part 1 the windowed F3 pass; part 2 the Session applies camera sensitivity and invert at every spawn and on change, also from Pause; verified headless and in a short windowed run, no new tests per the sprint rule; physical-device pass owed) |
| F4 | Combat state and HUD | `combat-hud` | 00 plan | docs | no | — | done (one-pass planning, 2026-09-23; 01 was written and delivered separately) |
| | | | 01 combat-state-core | core | yes | — | done |
| | | | 02 hud-binding-and-target-marker | adapter | no | trunk | done (2026-09-23: `Hud` bound to the Session's `CombatState` and each ship's `Targeting`; marker verified in the harness) |
| | | | 03 boss-panel-and-attack-cue-api | adapter | no | trunk | done (2026-09-23: boss panel, cue and threat API on `Hud`; verified by `scenes/dev/hud_harness.tscn`, no new tests per the sprint rule) |
| F5 | Projectile Field | `projectile-field` | 00 plan | docs | no | — | done (one-pass planning) |
| | | | 01 field-core-spawn-move-cull | core | yes | path | done |
| | | | 02 core-hit-sweep-and-graze-rules | core | yes (after 01, same file) | path | done (no unit tests, by the sprint rule; ruling 5 confirmed strict by D-07 Part B) |
| | | | 03 bomb-phase-clears-and-hit-spheres | core | yes (after 02, same file) | path | done (no unit tests, by the sprint rule) |
| | | | 04 pattern-emitter-core | core | yes | oc-a | done (no new tests, by the sprint rule) |
| F6 | Weapon and rendering | `weapon-rendering` | 00 plan | docs | no | — | done (one-pass planning) |
| | | | 01 rendering-spike | spike | no | — | cut (folded into 02 by the sprint plan: MultiMesh by default, benchmark inside 02) |
| | | | 02 projectile-system-adapter | adapter | no | trunk | done (2026-09-23: MultiMesh ProjectileSystem on ProjectileRoot, capacity 2048; 3000 Projectiles at 1118 FPS with other lanes running; D-02 meshes swapped in by F14-01) |
| | | | 03 weapon-model-and-player-weapon | core+adapter | no | trunk (part 1: oc-a) | done (2026-09-23: WeaponModel by oc-a, PlayerWeapon, dev Familiars and target dummies by trunk; D-02 Familiar swapped in by F14-01) |
| | | | 04 aim-assist-under-lock-framing | adapter | no | path | done (2026-09-23: under a lock the Aim Assist cone is measured from the camera, `lock_assist_degrees` 25; a locked Spirit falls in 2.0 to 2.7 s from 10 to 50 units; no new tests, by the sprint rule) |
| F7 | Damage, bomb, pickups | `damage-pickups` | 00 plan | docs | no | — | done (one-pass planning) |
| | | | 01 hit-to-combat-state-and-defeat | integration | no | trunk | done (2026-09-23: hits, Graze, Invulnerability blink and Defeat wired in GameSession; `tools/validate_combat.gd` COMBAT_OK; Retry restarts the stage until F10-03) |
| | | | 02 bomb-clear-and-invulnerability | integration | no | trunk | done (2026-09-23: Bomb clear, radius damage, bombs used and dev blast; `validate_combat.gd` checks 14-21 COMBAT_OK; D-02 blast swapped in by F14-01) |
| | | | 03 pickup-adapter-and-rewards | adapter | no | trunk | done (2026-09-23: `Pickup` adapter and dev Power and Shield prefabs with D-02's visuals; arena harness row verified headless and windowed, no new tests per the sprint rule) |
| F8 | Progression cores and content | `progression-core` | 00 plan | docs | no | — | done (one-pass planning) |
| | | | 01 definition-schemas-and-content-validation | core | yes | oc-b | done (typed schemas and validators landed 2026-09-23; no tests per sprint rule) |
| | | | 02 encounter-machine-core | core | yes | oc-b | done (2026-09-23: `EncounterMachine` Rules Core landed; no tests per sprint rule) |
| | | | 03 snapshot-capture-restore | core | yes | oc-b | done (2026-09-24: `Snapshot` value object and `CheckpointStore` Rules Core landed; no tests per sprint rule) |
| | | | 04 stage-01-content-draft | content | yes | oc-b | done (2026-09-23: dev draft of `content/stages/stage_01/` landed, validates; Astra tunes values) |
| F9 | Enemies | `enemies` | 00 plan | docs | no | — | done (one-pass planning) |
| | | | 01 enemy-model-core | core | yes | oc-a | done (no new tests, by the sprint rule) |
| | | | 02 dev-prefabs-and-enemy-actor | adapter | no | path | done (2026-09-23: `EnemyActor` and dev Spirit and Sentry fight in the arena harness; no new tests, by the sprint rule; locked-shot miss at close range logged for trunk) |
| | | | 03 seal-and-guard-rules | core+adapter | no | oc-a | todo (consumed by F12-05, Stage 2 S2-03) |
| F10 | Stage Director in Stage 1 | `stage-director` | 00 plan | docs | no | — | done (one-pass planning) |
| | | | 01 stage-director-adapter | adapter | no | trunk | done (2026-09-23: `StageDirector` on Stage 1; S1-01 to S1-03 Encounters, defeats scored once, rewards and stage clear verified in the running game, no new tests per the sprint rule; fixed `EncounterMachine`'s compile error) |
| | | | 02 gate-and-checkpoint-adapters | adapter | no | trunk | done (2026-09-23: `Gate` and `Checkpoint` on Stage 1; the whole route flown from the menu, Gates open as Encounters clear, CP1-A and CP1-B refill once; no new tests per the sprint rule) |
| | | | 03 retry-restart-flow | integration | no | trunk | done (2026-09-23: Retry resumes in place from the latest Checkpoint, Restart reloads, Defeat names the Checkpoint; verified in the running game, no new tests per the sprint rule) |
| | | | 04 stage-01-contract-smoke-test | test | yes (one new test file) | — | cut (the user's no-tests rule, 2026-09-23) |
| | | | 05 retry-restores-checkpoint-pickups | adapter | no | path | done (2026-09-24: a Retry restores the Pickups live at its Checkpoint's activation, at their spawn points; collected-before stays collected, spawned-after is removed and returns with its Encounter; four cases and the CP1-B extra driven headless, capture windowed; no new tests per the sprint rule) |
| | | | 06 stage-validators-accept-the-director | tooling | yes | oc-a | done (2026-09-24: Stage 1 validator accepts no root script or the StageDirector script; all three validators passed headless, no new tests per sprint rule) |
| F11 | Run flow | `run-flow` | 00 plan | docs | no | — | done (one-pass planning) |
| | | | 01 defeat-results-retry-restart-screens | integration | no | trunk | done (2026-09-24: a stage clear freezes under Results with the real values and the Run Mode's layout, a final stage ends the Run with one victory, `STAGE_RESULT` line; every Defeat, Results and Pause button verified in the running game; no new tests per the sprint rule) |
| | | | 02 campaign-continuation-and-direct-stage | integration | no | trunk | done (2026-09-24: Continuar loads Campaign Stage 2 with Power and score carried and resources restored, Jogar novamente starts a fresh Direct Stage Run; the Campaign's Stage 2 clear shows the final victory once; verified in the running game, no new tests per the sprint rule) |
| | | | 03 active-and-clear-time-verification | test | no | trunk | done (2026-09-24: Active Time and Clear Time verified through the real Session by a headless driver, no defect and no code change; protocol and record in `docs/validation/clear-time.md`; both stages flown end to end, the Campaign final victory reached through play; the played Stage 1 and Stage 2 clear times are owed by the human pass; no new tests per the sprint rule) |
| F12 | Bosses and Stage 2 | `bosses` | 00 plan | docs | no | — | done (one-pass planning; Stage 2 reinstated by the sprint plan) |
| | | | 01 boss-machine-core | core | yes | path | done (no unit tests, by the sprint rule; transition cap 0.75 s from D-07 ruling 1) |
| | | | 02 boss-controller-adapter | adapter | no | path | done (2026-09-23: `BossController` and the dev boss run three Phases, clears and the HUD panel in the arena harness; no new tests, by the sprint rule; `lantern_guardian.tres` load failure reported for F12-03) |
| | | | 03 lantern-guardian-in-s1-07 | integration | no | trunk (part 1: oc-a) | done (2026-09-24: the Lantern Guardian fights in S1-07 through `boss_definitions`, with the HUD panel and cues, +1000 and one stage clear from its final Phase; D-03's prefab attached; verified in the running game, no new tests per the sprint rule; Phase health about 2.7× the pacing target, noted for D-07 Part C) |
| | | | 04 stage-02-content-draft | content | yes | oc-b | done (2026-09-23: dev draft of `content/stages/stage_02/` landed, validates and matches the scene; Astra tunes values in D-06) |
| | | | 05 stage-02-director-integration | adapter | no | sol | done (2026-09-24: Stage 2 Director, Seals, Guards, Gates and checkpoint fallback; both route orders and retries observed) |
| | | | 06 tempest-sentinel-miniboss | integration | no | sol (part 1: oc-a) | done (2026-09-24: two-Phase boss in S2-04; HUD uses D-07 full-width two-bar layout) |
| | | | 07 storm-guardian | integration | no | sol (part 1: oc-a) | done (2026-09-24: three-Phase Storm Guardian replaces the S2-07 stand-in and reaches the existing final-victory path) |
| F13 | Audio | `audio` | 00 plan | docs | no | — | done (cut, then reinstated by the sprint plan, 2026-09-23) |
| | | | 01 audio-limiter-core | core | yes | oc-a | done |
| | | | 02 audio-controller-adapter | adapter | no | oc-a | done (no new tests, by the sprint rule; headless Dummy-driver check recorded in audio.md) |
| | | | 03 audio-event-wiring | integration | no | path | done (2026-09-24: `AudioController` on `Main/Audio` with D-01's 17 effects and volumes, no music; every producer connected once where the Session owns it, `stop_all()` on unload and Retry; driven from the menu through Retry, two Restarts, the Lantern Guardian and Return to Menu, headless and windowed; no new tests per the sprint rule; listening pass owed) |
| | | | 04 apply-astras-revised-sfx-selection | integration | no | path | done (2026-09-24: Astra's revised selection is the shipped mix: five new files, the four unused removed, all 17 gains, intervals and voices from `selection.json`, one voice per event, global cap 8; headless driver 64 checks: every event heard on its new file, held fire 3.33 starts/s, 5-Pickup clusters 1 sound each, silence after Retry, Restart and Return to Menu) |
| F14 | Delivery | `delivery` | 00 plan | docs | no | — | done (one-pass planning) |
| | | | 01 export-and-run-outside-editor | integration | no | trunk | done (2026-09-24: swap step applied D-02 meshes, Familiar and blast and D-07 shrine exports; release build of `8061d77` exported and run outside the repo: D3D12 Forward+, RX 9070 XT, no fallback, 1280 × 720, V-Sync 60; Storm Guardian and Lantern Guardian 59–60 FPS, over 1,100 uncapped; no ERROR or WARNING; `validation/export.md`. Presentation computer not verified) |
| | | | 02 package-and-acceptance-record | tooling | no | oc-b | done (2026-09-24: `tools/package.ps1` builds `build/package/Touhou-3D-<yyyyMMdd>.zip` and verifies the extracted copy — project import, the suite, and a 300-frame boot — `PACKAGE_OK`; fixed the part-1 archive root so the zip carries its `Touhou-3D/` folder; re-exported byte-identical to F14-01; `validation/acceptance.md` fills all 32 checks with no fails and the human-pass items marked owed; three credit gaps requested from Astra; no tests per the sprint rule) |
| D | Design sprint (Astra) | `design-sprint` | 01 sfx-selection-and-import | design | — | sol | done (listening pass owed by the human pass) |
| | | | 02 combat-visuals | design | — | sol | done (2026-09-23: six visuals and focused-slider fix verified) |
| | | | 03 lantern-guardian-scene | design | — | sol | done (2026-09-23: Ghost prefab, clips and dusk render verified) |
| | | | 04 stage-2-boss-scenes | design | — | sol | done (2026-09-23: Tempest Sentinel and Storm Guardian prefabs, clips and Stage 2 renders verified) |
| | | | 05 stage-1-tuning-and-pacing | design | — | sol | done (2026-09-23: content values, names, clip candidates and provisional 221 s estimate) |
| | | | 06 stage-2-content-review | design | — | sol | done (2026-09-24: rewards and Seals reviewed, bosses tuned to 20/30 and 40/40/50 s; 336 s efficient estimate, measured clear pending) |
| | | | 07 shrine-lighting-and-boss-rulings | design | — | sol | done (2026-09-24: 2.4 s shrine clip, five rulings, Lantern Guardian health 550/550/775; trunk export swap pending) |
| | | | 08 enemy-visuals-duplicate-parts | design | — | oc-a | done (2026-09-24: Part 1 confirmed duplicate glTF and embedded model parts in all four visuals; Part 2 removed the instance links, post-fix counts and validator clean) |

Order rationale: Player before Menus (highest UX risk and GUIDE Section 13's assignment). Audio buses are created in F0-03 so F3 can bind Options to them. Enemies (F9) come before the Stage Director (F10) so the Director is integrated against real Waves. The sprint's lane queues, checkpoints and kickoff prompts are in [SPRINT.md](SPRINT.md).

## Risk

48 tickets are `todo` for about one day across five standing lanes (trunk 15, path 8, oc-a 6, oc-b 9, sol 10), with rescue on demand. OpenCode tickets carry a per-ticket `Model:` line (SPRINT.md "Model budgets"). The trunk lane is the critical path, because every `game_session.gd` edit is serialized there.

If a SPRINT.md checkpoint slips by more than an hour, the proposed cut order is: music, then F3-03's prompt icons, then the Storm Guardian's final art, then Stage 2 entirely, with D-05's Stage 1 pacing raised to five minutes. The user confirms each step. PLANEJAMENTO Section 11 still cuts decorative density, secondary animation and enemy variants before approved mechanics. Scope changes are raised in the ticket or at a checkpoint, never decided inside a session.

Other risks:
- **No new tests (the user's rule, 2026-09-23).** The only automated gate is `tools/lane.ps1 land`: the existing suite plus a headless boot of the main scene. Regressions in code without coverage surface only in game runs, the reviewers and the human pass.
- **Projectiles.** One physics ray per projectile per tick at 1000 to 3000 bullets. F6-02's folded benchmark measures it while other lanes run, so the numbers are pessimistic; no ticket mitigates the ray cost yet.
- **Heavy tickets.** F6-03 is the heaviest; split the WeaponModel core out if it overruns. F10-03 is a refactor: it moves the per-ship setup from F4-02, F6-02, F6-03 and F7-02 into one `_spawn_player()`.
- **Cross-lane edits.** Four files are edited by two lanes with no dependency between them (SPRINT.md "Shared files"); the second to land merges both.
- **Human steps.** The listening pass, the physical-device pass, the five-minute measurement and the presentation-computer run of the exported build (`validation/export.md`) need a person.

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
| F7 | **D-02 (visuals), D-05 (values).** Pickup visuals are in: `scenes/dev/power_pickup.tscn` and `shield_pickup.tscn` instance them as `Visual`. For final Pickup scenes keep the root contract in [damage-pickups.md "Pickup contract"](damage-pickups.md#pickup-contract) (`Area3D` with `pickup.gd`, `kind`, layer 0, mask 2, monitoring on, a `CollisionShape3D`), and tune `attraction_range` (6.0) and `attraction_speed` (14.0) there. A final Bomb blast effect, plus tuning of the Bomb radius and damage; dev placeholders otherwise. |
| F8-04 onward | **D-05.** Review and tune the Stage 1 `content/stages/stage_01/` draft that Claude transcribes from STAGE_DESIGN.md, including Portuguese place names for CP1-A and CP1-B (the Defeat screen shows the id text until then). Values are yours. |
| F9 | **D-04 (Sentinel), D-05 (tuning).** Spirit, Sentry, and Tempest Sentinel prefabs matching GUIDE Section 5 (`Enemy` root, `VisualRoot`, `HitVolume`, `Emitters`, `AnimationPlayer`). Claude ships `scenes/dev/` placeholders with the same tree until then, using your `scenes/enemies/visuals/` scenes as `VisualRoot`. Tune the dev enemy and pattern `.tres` files and the `HitVolume` radii, and choose an Anticipation clip. |
| F10 | Boss-arena retreat containment and any extra boundary presentation, using the Director's active-Encounter bounds (see `docs/STAGE_01_HANDOFF.md`). A checkpoint glow that reacts to `checkpoint_activated`. Keep the load-bearing names in `stage_01.tscn`: encounter roots and markers, `BarrierBody/Collision`, `ClosedVisual`, `Respawn`, and `Environment/PortalLinks/GuardLink1..3`. |
| F12 | **D-03, D-04, D-06, D-07.** `scenes/enemies/lantern_guardian.tscn` with the GUIDE Section 5 tree and the actual clip names for idle, step cue and defeat; the shrine-lighting `AnimationPlayer` clip (corrupted to calm) in Stage 1, with its path and clip name sent to Claude; tuning of `lantern_guardian.tres` and its patterns. Confirm or reject F12-01's reading that a boss takes no damage during a Phase transition (PLANEJAMENTO forbids "artificial invulnerability timers"). Stage 2 (reinstated): Storm Guardian and Tempest Sentinel scenes (D-04), the Stage 2 content review (D-06), and a resolved portal-light material plus the storm-resolution clip in `stage_02.tscn`, which no D ticket covers yet. |
| F13 | **D-01** delivered; since F13-04 your revised selection (`sound_effects/README.md`) is the shipped mix, from `Main/Audio` (`event_streams`, `event_volume_db`, `max_voices` 8 in `scenes/main.tscn`) and `EVENT_RULES`, and no music ships. Open: the listening pass (human pass, F14-02). To retune a sound's interval, voices, priority or volume, or swap a file, send Claude a new catalogue row; `checkpoint_activated` now also plays a sound (the arch glow is still yours). |
| F14 | Credits and licenses cover the integrated assets; F14-02's three credit gaps were closed by Astra. |
| F14-02 | **Credits gaps closed by Astra (sol).** `ASSET_CREDITS.md` now names the five original D-02 materials in `assets/combat/` and the original Stage 1 gate veil shader; the in-game Créditos screen names Quaternius's Ultimate Monsters enemy and boss models. See [validation/acceptance.md](../validation/acceptance.md) "Credits coverage". |

## Received from Astra

2026-09-24: D-08 confirmed duplicate embedded and instanced enemy model parts in all four Stage 1 visual scenes, then removed the duplicate instance links. Post-fix counts are one mesh/surface/skeleton/player with zero detached or left nodes; `validate_enemy_visuals.gd` passed. See [enemy-visuals.md](../validation/enemy-visuals.md).

2026-09-23: D-05 reviewed Stage 1 content and shared Spirit/Sentry values, named both checkpoints and selected candidate Anticipation clips. [stage-01-pacing.md](../validation/stage-01-pacing.md) estimates an efficient clear at about 221 s against the 240 s design target; it is not a measured result. Trunk owns clip playback and any PlayerShip value follow-up; D-06 must recompute its Stage 2 estimate from the revised shared enemy health.

2026-09-23: D-06 pass 1 reviewed F12-04's Stage 2 content and named CP2-A/CP2-B; [stage-02-pacing.md](../validation/stage-02-pacing.md) records the exact reward audit and conditional ~319 s efficient / ~392 s normal estimates. The ≥300 s requirement still needs a measured clear; Seal and boss tuning remain for passes 2 and 3.

2026-09-23: D-02 combat visuals are SCENE_READY under `scenes/combat/visuals/`; exact mesh, scene, animation and consumer swap paths are in [combat-visuals.md](../validation/combat-visuals.md). The Options slider focus fill is gold and visually verified.

2026-09-23: D-04 Tempest Sentinel and Storm Guardian prefabs are SCENE_READY at `scenes/enemies/tempest_sentinel.tscn` and `scenes/enemies/storm_guardian.tscn`; tree, clips, hit spheres, emitters and render notes are in [ENEMY_VISUAL_HANDOFF.md](../ENEMY_VISUAL_HANDOFF.md). Sol F12-06 and F12-07 own controller attachment and Stage 2 actor scene wiring.

2026-09-23: D-03 Lantern Guardian prefab is SCENE_READY at `scenes/enemies/lantern_guardian.tscn`; tree, clip names, hit sphere and emitter are in [ENEMY_VISUAL_HANDOFF.md](../ENEMY_VISUAL_HANDOFF.md). Trunk F12-03 owns the script attachment and scene export wiring.

2026-09-24: D-07 is complete. The five Part B rulings are in [PLANEJAMENTO.md](../PLANEJAMENTO.md); F12-06 applied the two-Phase HUD offsets. Part A authored `Environment/ShrineLighting` and the `corrupted_to_calm` clip in Stage 1; trunk F14-01 sets the Stage exports. Part C tuned Lantern Guardian health to 550/550/775 and reviewed its patterns. Captures and reset checks are in [stage-01-shrine.md](../validation/stage-01-shrine.md).

2026-09-24: D-06 is complete as a content review. Tempest Sentinel health is 440/660; Storm Guardian health is 885/885/1105, with six rather than eight spiral projectiles per volley. [stage-02-pacing.md](../validation/stage-02-pacing.md) estimates about 336 s efficient and 426 s normal. A no-death strong-play Results Clear Time is still required before the ≥300 s acceptance line can be verified.

Stage 1 night and both-stage boundary rails: .scratch/stage-night-rails/issues/01-night-forest-and-boundary-rails.md — **done** (night palette, warm lanterns, low gate veil, textured forest detail, visible rails along existing flight walls).

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

2026-09-24: D-06 pass 2 explicitly authors Seal health 10 on all three Seals (unchanged from the verified default). Updated conditional Stage 2 estimates with D-05 enemy health: ~336 s efficient / ~414 s normal; boss review and measured clear remain pending.
