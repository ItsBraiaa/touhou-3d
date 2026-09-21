# GUIDE — Godot Scene and Script Integration

**Owners:** Astra — Lead Game Designer and Godot scene author. Claude — Lead Code Engineer and GDScript author.
**Language:** English documentation and code identifiers; Portuguese player-facing UI.
**Status:** Integration contract, version 4. The player/test arena, eight menu layouts, and combat HUD are SCENE_READY. Gameplay, menu, and HUD scripts remain explicit placeholders for Claude. See Sections 13–15 for actual files, node paths, and validation limits.

## 1. Working agreement

Astra builds the game's presentation and Godot composition: stages, geometry, model placement, collision shapes, camera rig, lighting, environment, effects, animation setup, interface layouts, audio placement, encounter markers, and Inspector configuration. Astra also creates script placeholders when a scene needs a future attachment and documents their purpose here.

Claude refines engineering details and writes the production GDScript: movement behavior, camera behavior, input processing, targeting, combat, projectiles, enemy AI, progression, checkpoint restoration, menus, settings, audio behavior, and tests. Godot is the engine; Claude is the code lead working in it.

Astra owns what the game looks and feels like and how scenes are assembled. Claude owns how the runtime logic works. Camera placement/framing defaults belong to Astra; following, target lock, collision avoidance, and interpolation logic belong to Claude. Collision shape placement belongs to Astra; collision rules and damage ordering belong to Claude.

This guide is the shared scene-to-code contract. Claude may improve internal architecture with mattpocock skills while preserving the documented scene interface. If a public node name, script path, signal, or Inspector field needs to change, update the contract and coordinate the scene adjustment with Astra rather than silently breaking the scene.

## 2. Reference documents and precedence

- [PLANEJAMENTO.md](PLANEJAMENTO.md): approved product rules and scope.
- [STAGE_DESIGN.md](STAGE_DESIGN.md): encounter progression, rewards, and checkpoint behavior.
- [MODEL_SELECTION.md](MODEL_SELECTION.md): approved models and visual direction.
- [ENGINEERING_BRIEF.md](ENGINEERING_BRIEF.md): engineering risks, invariants, and refinement work.
- This guide: ownership, attachment points, exported configuration, runtime messages, and handoff state.

The old Superpowers implementation draft is non-authoritative. Prefer the current design documents and this guide over its candidate paths/signatures. Gameplay decisions remain owned by Astra and the user; technical refinements remain owned by Claude.

## 3. File ownership

| Area | Primary owner | Collaboration rule |
| --- | --- | --- |
| `scenes/`, scene-owned visual resources, layout and marker data | Astra | Claude requests structural changes or makes an explicitly coordinated integration fix |
| `scripts/`, code-defined resources, tests | Claude | Astra creates a placeholder only before code ownership starts; never overwrites implementation |
| `assets/` selection, materials, VFX, animation presentation | Astra | Claude verifies import/runtime compatibility |
| Stage encounter values and balance | Astra | Claude supplies validation and interprets the data |
| `project.godot`, autoload registration, input actions, export presets | Shared | Assign one editor at a time and report exact changes |
| `GUIDE.md` | Shared | Update attachment contracts with every intentional interface change |
| Game design documents | Astra | Claude proposes gameplay changes with technical rationale |
| Engineering/test documentation | Claude | Link results and unresolved issues back to this guide |

Preserve original downloads in `All models/`, `all-sounds/`, and `Music/`. Runtime assets should use selected copies with their texture/buffer dependencies. Never edit the same shared file concurrently.

## 4. Placeholder policy

A placeholder is an explicitly unfinished attachment point, not a fake implementation.

- Astra may create a minimal `.gd` with the correct base class and a comment referring to this guide. Add no empty behavior methods that pretend a system works.
- Attach a placeholder only when the scene remains valid and its purpose is listed here. Otherwise leave the node without a script and document the intended path.
- Once Claude begins a script, Claude owns its contents. Astra edits scene values and presentation instead of replacing script files.
- Do not connect scene signals to missing methods. Claude implements the contract first; then the designated owner wires it.
- Mark each handoff as `PLANNED`, `SCENE_READY`, `CODE_READY`, or `INTEGRATED_VERIFIED` in the table below. These are project delivery states, not game runtime states.

## 5. Scene composition targets

These node names form the initial integration vocabulary. Finalize each tree when its scene is built and update this guide to match the actual tree.

### Main composition

`scenes/main.tscn` is the project main scene and Claude-owned since F0-03. Actual tree:

- `Main` — Node, `process_mode = ALWAYS`; `scripts/session/game_session.gd` (`GameSession`) attached, its four exports pointing at the children below.
- `Main/WorldRoot` — Node3D; holds the loaded stage instance.
- `Main/ProjectileRoot` — Node3D; will hold `scripts/combat/projectile_system.gd`.
- `Main/Interface` — CanvasLayer, `process_mode = ALWAYS`; holds menus and the in-game HUD. `GameSession` instances `scenes/ui/main_menu.tscn` here at startup; screen navigation arrives with F2.
- `Main/Audio` — Node, `process_mode = ALWAYS`; will hold `scripts/audio/audio_controller.gd`.

Systems are connected through Inspector references and composition-time injection; the autoload list stays empty (ADR-0002). Contract test: `tests/scene/test_main_contract.gd`. Audio buses `Master`, `Music`, `SFX` live in `default_bus_layout.tres`; the sixteen gameplay input actions live in `project.godot` (CONVENTIONS "Input actions").

### Player

`scenes/player/player_ship.tscn`:

- `PlayerShip` — CharacterBody3D; attach `scripts/player/player_controller.gd`.
- `PlayerShip/BodyCollision` — CollisionShape3D for scenery collision.
- `PlayerShip/VisualRoot` — Node3D for the imported ship, visual banking, and cosmetic effects.
- `PlayerShip/DamageCore` — Area3D with CollisionShape3D; projectile damage volume.
- `PlayerShip/GrazeVolume` — Area3D with CollisionShape3D; larger proximity volume.
- `PlayerShip/Muzzle` — Marker3D outside the visual banking hierarchy.
- `PlayerShip/FamiliarAnchors` — Node3D with `Left` and `Right` Marker3D children.
- `PlayerShip/Weapon` — Node; attach `scripts/combat/player_weapon.gd`.
- `PlayerShip/Targeting` — Node; attach `scripts/player/targeting.gd`.
- `PlayerShip/CameraRig` — Node3D; attach `scripts/player/camera_rig.gd`; child Camera3D named `Camera3D`.

Astra authors the rig and collision volumes. Claude decides whether the projectile engine uses the Area3D volumes directly or reads their shape geometry for swept collision. The visible core and actual collision must agree. Visual banking must not move the core.

### Stages

`scenes/stages/stage_01.tscn` and `scenes/stages/stage_02.tscn` share this layout:

- `Stage` — Node3D; attach `scripts/progression/stage_director.gd`.
- `Stage/Environment` — sky, lighting, WorldEnvironment, and decoration.
- `Stage/Geometry` — navigable scenery and authored static collisions.
- `Stage/PlayerStart` — Marker3D.
- `Stage/Encounters` — Node3D containing encounter roots named by stable IDs, such as `S1-01`.
- `Stage/Checkpoints` — checkpoint scene instances with stable checkpoint IDs.
- `Stage/RuntimeActors` — Node3D for active spawned enemies and pickups.

Each encounter root holds entry/exit volumes and named spawn markers. These are authored scene elements. Runtime actors must be spawned under `RuntimeActors`, so cleanup cannot delete the authored layout.

### Enemy and boss prefabs

`scenes/enemies/spirit.tscn`, `sentry.tscn`, `tempest_sentinel.tscn`, `lantern_guardian.tscn`, and `storm_guardian.tscn`:

- Root `Enemy` — Node3D; attach `scripts/enemies/enemy_actor.gd` for common enemies or `scripts/enemies/boss_controller.gd` for segmented bosses.
- Child `VisualRoot` — imported model and presentation effects.
- Child `HitVolume` — Area3D and collision shape.
- Child `Emitters` — Node3D with Marker3D children identifying shot origins.
- Child `AnimationPlayer` or an explicitly assigned imported animation reference.

The miniboss reuses the Sentry appearance with enlarged scale and rotating ornaments. It uses two health segments; final bosses use three. Imported clips are selected by actual names, not assumed universal names.

## 6. Script attachment and configuration registry

All fields below are public configuration intentions. Claude chooses safe GDScript types and defaults, then records the final exported fields here before Astra wires a scene. Inject runtime collaborators instead of forcing each script to search the whole scene tree.

| Script path | Attach to | Astra configures | Claude implements |
| --- | --- | --- | --- |
| `scripts/session/game_session.gd` | Main | Nothing yet: `world_root: Node3D`, `projectile_root: Node3D`, `interface: CanvasLayer`, `audio: Node` are set in the Claude-owned `scenes/main.tscn`; stage scene references come with F2/F11 | Validates the four exports and instances the main menu (F0-03); campaign/direct-stage lifecycle, results and transitions (F2, F11) |
| `scripts/player/player_controller.gd` | PlayerShip | Movement speed, focus multiplier, visual root, combat-volume references | Input, movement, scenery collision, reset and control enable/disable |
| `scripts/player/camera_rig.gd` | CameraRig | Camera reference, follow distance/height, FOV, damping defaults | Follow/orbit, lock framing, camera obstruction response |
| `scripts/player/targeting.gd` | Targeting | Targeting range/cone and camera reference | Visibility filtering, acquire/switch/release, invalid target recovery |
| `scripts/combat/player_weapon.gd` | Weapon | Muzzle/familiar references, shot settings, bomb radius and VFX references | Cadence, assisted shots, familiar fire, bomb requests |
| `scripts/combat/projectile_system.gd` | ProjectileRoot | Projectile visual presets, capacity/lifetime defaults | Projectile lifecycle, swept collision, graze, bomb/phase cleanup |
| `scripts/combat/pickup.gd` | Pickup prefab root Area3D | Kind, amount, attraction range, visual/audio feedback | Accepted collection and exactly-once reward delivery |
| `scripts/enemies/enemy_actor.gd` | Common enemy root | Health, movement bounds, emission markers, pattern configuration | Enemy movement/attacks, damage and defeat reporting |
| `scripts/enemies/boss_controller.gd` | Final boss/miniboss root | Phase configuration, attack names, animation and emitter references | Segmented health, phase lifecycle, attacks, one-time defeat |
| `scripts/progression/stage_director.gd` | Stage | Stage ID, encounter definitions, markers and gate/checkpoint references | Waves, objective flags, completion, reconstruction and progression |
| `scripts/progression/checkpoint.gd` | Checkpoint prefab root Area3D | Checkpoint ID, resume encounter ID, safe spawn and visual/audio cues | Activation request once; delegate resource/snapshot changes to director |
| `scripts/progression/gate.gd` | Gate prefab root Node3D | Barrier collision and open/closed visuals | Apply opened state consistently and idempotently |
| `scripts/progression/seal.gd` | Seal prefab root Node3D | Seal ID, guard links, shield/target visuals | Guard-dependent vulnerability and one-time destroyed event |
| `scripts/ui/menu_controller.gd` | Menu scene root Control | Button references, focus order, panel references | Navigation and session/settings action requests |
| `scripts/ui/hud.gd` | HUD scene root Control | Bar/icon/label references and transient cue presentation | Render observed gameplay state without owning combat values |
| `scripts/audio/audio_controller.gd` | Audio | Event-to-stream mapping, music tracks and audio buses | Sound limits, playback, transitions and volume application |

Code-only helpers such as combat state, checkpoint storage, encounter resource schemas, and settings persistence are owned by Claude and do not need empty scene-attached scripts. Describe their contracts in engineering documentation and expose only the values needed by Astra in the Inspector.

## 7. Runtime messages and ownership

Use these semantic event contracts; Claude records final typed signal signatures during implementation. Payload IDs must remain stable across retries.

| Event | Producer → consumer | Minimum payload | Required handling |
| --- | --- | --- | --- |
| Combat state changed | Player combat logic → HUD | Health %, shield, bombs, power and partial progress | Display only; HUD does not mutate resources |
| Target changed | Targeting → camera/HUD/weapon | Valid target reference or null | Clear all consumers when target disappears |
| Enemy defeated | Enemy → stage director | Encounter ID, unique enemy ID | Count once, even if damage callbacks repeat |
| Boss phase changed | Boss → presentation/HUD | Phase index, attack display name | Clear old phase threats and show a brief cue |
| Seal destroyed | Seal → stage director | Seal ID | Resolve objective once, update linked portal lights |
| Checkpoint entered | Checkpoint → stage director | Checkpoint ID, resume encounter ID | Validate preceding completion; first activation refills and snapshots |
| Pickup accepted | Pickup/combat logic → session/audio | Pickup ID, kind, resulting reward | Remove only on acceptance and prevent duplicate credit |
| Player defeated | Player → session | Active stage and attempt context | Stop combat and show Retry/Main Menu |
| Stage completed | Stage director → session | Stage ID and committed result | Campaign continuation or isolated-stage results |
| Pause requested | Input/menu → session | Desired pause state | Freeze world/timers, preserve menu processing |

Connect each event once. Choose either authored connections or runtime wiring for each connection; do not use both. After restore, reconnect only reconstructed actors and clear references to freed targets.

## 8. Stage data and checkpoint integration

Astra supplies content matching STAGE_DESIGN.md. Claude supplies a validated resource/schema to express it. Required encounter data:

- Stable encounter ID and next encounter ID.
- Activation volume and spawn-marker references.
- Waves with enemy type/count, activation rule, and emitter configuration.
- Completion condition: traversal, all required enemies, or specified objectives.
- One-time power/shield rewards and reachable drop locations.
- Gate references and optional checkpoint/resume ID.

Duration is a balancing target, not a timer that automatically completes an encounter.

Required checkpoint markers: CP1-A, CP1-B, CP2-A, CP2-B. Keep checkpoint activation physically separate from the next combat trigger. The director owns the snapshot and resource restoration; the checkpoint scene provides a location and feedback.

Astra must provide open 3D space around each boss, clear limits, visible depth references, and safe checkpoint spawns. Claude must restore the correct actors/flags, cancel queued spawns, and preserve committed statistics. Use the detailed retry matrix in STAGE_DESIGN.md.

## 9. Per-scene handoff procedure

1. Astra assembles a scene and records its actual node tree, referenced assets, placeholder paths, intended behavior, and editable parameters.
2. Astra marks the scene `SCENE_READY` only if it opens with valid resources and no dangling script/signal references. A static scene is not marked playable.
3. Claude reads this guide and the applicable design section, refines internal engineering, and writes the scripts and behavioral tests.
4. Claude records public exported fields, signals, methods, setup prerequisites, and test results. Mark `CODE_READY` only after the code checks pass.
5. Astra attaches scripts, assigns Inspector references, configures content values, and performs visual/playability review. Claude resolves code defects discovered during integration.
6. Mark `INTEGRATED_VERIFIED` only after the actual scene runs with the intended behavior. Record manual checks separately from automated ones.

For shared scenes or project settings, announce the files being edited to the collaborator before starting. Do not create separate tasks or dispatch agents automatically as a consequence of this document.

## 10. Handoff tracking

| Deliverable | Scene owner | Code owner | State | Evidence |
| --- | --- | --- | --- | --- |
| Main composition and session | Claude (`scenes/main.tscn`, F0-03) | Claude | CODE_READY | Composition root instanced headless by `tests/scene/test_main_contract.gd`; main menu shown at startup; navigation pending (F2) |
| Player/camera test arena | Astra | Claude | SCENE_READY | Both scenes load and render in Godot 4.7.2; static camera only; Section 13 |
| Player combat and projectiles | Astra: presentation | Claude | PLANNED | Product rules documented |
| Common enemies and miniboss | Astra | Claude | PLANNED | Behavior and reuse strategy documented |
| Lantern Guardian | Astra | Claude | PLANNED | Ghost selected; animation metadata inspected |
| Storm Guardian | Astra | Claude | PLANNED | Dragon_Evolved selected; animation metadata inspected |
| Stage 1 progression | Astra | Claude | SCENE_READY | Initial area, markers and collision authored; runtime progression pending; see [STAGE_01_HANDOFF.md](STAGE_01_HANDOFF.md) |
| Stage 2 progression | Astra | Claude | SCENE_READY_STATIC | Seven encounters, three guarded seals, two checkpoints; [STAGE_02_HANDOFF.md](STAGE_02_HANDOFF.md) |
| Checkpoints/gates/seals | Astra | Claude | PLANNED | Restore and objective rules specified |
| Menus/options | Astra | Claude | SCENE_READY | Eight menu scenes rendered and checked; Section 14; navigation logic pending |
| Combat HUD | Astra | Claude | SCENE_READY | Normal and synthetic boss states rendered at 1280 × 720; Section 15; gameplay binding pending |
| Audio integration | Astra: selection/mix | Claude: runtime | PLANNED | Sound packs found; event mapping not selected |

## 11. Completion checks for collaboration

- Every attached script has the expected base type and a documented purpose.
- Required Inspector references are assigned; missing references produce a useful setup error instead of silent failure.
- Scene node names and script expectations agree; scene-owned references are not hidden in arbitrary absolute node paths.
- Models/materials retain valid dependencies; effects do not obscure the player core or dodge gaps.
- Camera rig placement and code framing are tested together on keyboard and gamepad.
- Signal connections do not duplicate after retry or stage changes.
- Scene cleanup removes transient gameplay objects while preserving authored geometry and markers.
- Both source specs' acceptance criteria remain the final product tests.

## 12. Prompt for Claude

> Act as Lead Code Engineer for this Godot project. Astra is Lead Game Designer and owns the authored scenes, environments, camera composition, models, effects, UI layout, and Inspector content. Read GUIDE.md first, then the linked game/stage specifications and ENGINEERING_BRIEF.md. Use applicable mattpocock skills to refine internal engineering and implement production GDScript. Preserve the documented scene interfaces or coordinate any necessary contract changes in GUIDE.md before changing them. Implement only the scene/script handoff currently assigned to you, with behavioral tests and exact setup instructions for Astra. Do not rebuild the visual design or overwrite scene work without coordination. Keep engineering documentation in English and player-facing text in Portuguese.

## 13. First scene handoff — player and static arena

### Delivered files

- `scenes/player/player_ship.tscn`: reusable player scene matching the player tree in Section 5.
- `scenes/tests/combat_arena.tscn`: directly runnable static scene. The main scene is now `scenes/ui/main_menu.tscn`; open the arena directly for scene testing. `scenes/main.tscn` remains planned.
- `assets/models/player/craft_speederA.glb`: selected copy of the approved ship, with embedded materials.
- `scripts/player/player_controller.gd`, `camera_rig.gd`, `targeting.gd`, and `scripts/combat/player_weapon.gd`: base type and handoff comments only. No movement, aiming, firing, combat, or camera-follow logic is implemented.
- `ASSET_CREDITS.md` and `assets/licenses/kenney-space-kit.txt`: selected asset provenance.
- `docs/validation/first-scene.md`, logs, and `arena-preview.png`: verification evidence.

The arena is a functional scene blockout for later gameplay integration, not either finished stage. It contains a circular stone platform, depth grid, shrine gate, perimeter lanterns, geometric trees/mountains, and targets at three heights. No tutorial text or fake HUD is displayed.

### Actual arena tree

`CombatArena` contains `Environment`, `Geometry`, `FlightBounds`, `Targets`, `PlayerStart`, the instantiated `PlayerShip`, `RuntimeActors`, and `ProjectileRoot`.

`Targets/Low`, `Targets/Middle`, and `Targets/High` are Node3D members of the `targetable` group. Each contains `Orb`, `Ring`, and `HitVolume/Collision`. Their world positions are (-10, 5, -8), (0, 9, -20), and (11, 15, -10). They are static targeting references, not damageable enemies. Target IDs are stored as metadata.

`PlayerStart` and the initial ship position are (0, 6, 18). World up is +Y; forward is -Z. The platform is centered at (0, 0, -6) with radius 39. FlightBounds metadata proposes min (-39, 0, -45) and max (39, 30, 33), with perimeter and ceiling collision surfaces. The circle does not fill the corners of those rectangular bounds; Claude must implement a readable playable-volume limit before free-flight testing near the edge. Collision alone is not the final boundary warning behavior.

### Authored player values

| Item | Current value / wiring |
| --- | --- |
| Body collision | Box 2 × 0.8 × 2.1, centered on PlayerShip |
| Damage core | Sphere radius 0.18; visible sphere matches this radius |
| Graze volume | Sphere radius 0.55 |
| Imported model offset | VisualRoot/Model position (-2, -0.4, -1.5), compensating embedded model translation |
| Visual orientation | Nose faces -Z; bank VisualRoot only |
| Muzzle | (0, 0, -1.25), separate from banked visuals |
| Familiar anchors | (-1.6, 0.25, 0.1) and (1.6, 0.25, 0.1); no familiar gameplay/meshes yet |
| Camera | CameraRig/Camera3D at (0, 3.2, 8.5), X rotation -0.16 radians, FOV 68°, near 0.1, far 500 |
| Movement defaults | PlayerShip metadata: base_speed 12.0 and focus_multiplier 0.45 |
| Rendering | Existing Forward Plus/D3D12 retained; viewport 1280 × 720, 4× MSAA |

Metadata is a design handoff, not a working exported script property. Claude must define the actual exports and update this registry before expecting Inspector values to drive behavior.

Collision layer allocation: scenery 1; player body 2; damage core 3; graze 4; target hit volume 5. Corresponding bit values are 1, 2, 4, 8, 16. Player body mask is scenery only. Area monitoring is intentionally disabled until Claude selects the projectile/collision strategy; Claude must configure masks/monitoring for the chosen implementation.

The core's unshaded material disables depth testing to make it visible through the ship in this static review. Revisit this presentation during gameplay integration if it incorrectly draws through unrelated geometry. Two teal engine meshes are static visual accents; there is no propulsion animation yet.

### Tools and integration boundaries

`tools/build_scene_handoff.py` is an offline scene-authoring utility. It writes both scene files from scratch. Do not rerun it after manual or Claude integration changes without updating the generator; it would overwrite scene wiring. It is not runtime game logic.

`tools/validate_scene_handoff.gd` is an offline QA script that loads the scene, checks required nodes and imported mesh presence, and captures a rendered preview when a graphics display is available. It is not attached to gameplay nodes and does not implement player behavior.

Source-download folders have `.gdignore` files so Godot imports selected assets instead of every duplicate format. To use another downloaded asset, copy its required dependencies under `assets/` first. The downloaded MP3s are not integrated.

### Next assignment for Claude

Implement flight, focus movement, camera follow/orbit, and stable target acquisition/switch/release against the three static targets. Begin with the three player scripts; leave weapon behavior for the combat handoff. Preserve the authored scene and document required input actions and final exported references. Validate normalized three-axis speed, core independence from banking, keyboard-only controls, physical-gamepad ergonomics, and target loss. The current scene is not evidence that any of those behaviors already work.

## 14. Menu scene handoff

### State and verification

All eight menu scenes are SCENE_READY and share `assets/ui/menu_theme.tres`. Godot MCP successfully reported the engine/project, created the initial main-menu scene, and ran the authored main menu. Local Godot rendering validated all eight screens and their explicit focus paths with zero reported failures. Screenshots are in `docs/validation/menu-*.png`.

`scripts/ui/menu_controller.gd` contains only `extends Control` and handoff comments. Buttons have no application action connections. Native slider/dropdown/toggle widgets can change their displayed values, but no setting is applied or persisted. No initial focus, automatic device prompt changes, screen transitions, session starts, pause logic, retry, or application exit has been implemented. These are Claude's next menu engineering tasks.

The project main scene is `scenes/ui/main_menu.tscn`. Running it currently previews that layout. Use F6 on another menu scene to inspect it independently. Menu art is original SVG composition, not a screenshot promising that the playable stages are finished.

### Scene and action registry

All paths below are relative to the named scene root. Every scene has a `Layout` Control; the following button paths are stable.

| Scene / root | Button or control path | Intended action |
| --- | --- | --- |
| `main_menu.tscn` / MainMenu | `Layout/StartButton` | Start campaign at Stage 1 |
| MainMenu | `Layout/StageSelectButton` | Open StageSelect |
| MainMenu | `Layout/OptionsButton` | Open Options, preserving return destination |
| MainMenu | `Layout/QuitButton` | Exit application |
| `stage_select.tscn` / StageSelect | `Layout/ForestCard/SelectButton` | Start isolated Stage 1 |
| StageSelect | `Layout/MountainCard/SelectButton` | Start isolated Stage 2 with specified starting power/resources |
| StageSelect | `Layout/BackButton` | Main menu |
| `options.tscn` / Options | `Layout/Controls/BindingsButton` | Open Controls |
| Options | `Layout/DefaultsButton` | Restore validated default settings and refresh widgets |
| Options | `Layout/CreditsButton` | Open Credits |
| Options | `Layout/BackButton` | Return to caller; retain pause if caller is PauseMenu |
| `controls.tscn` / Controls | `Layout/BackButton` | Return to Options |
| `pause_menu.tscn` / PauseMenu | `Layout/ResumeButton` | Resume the same attempt |
| PauseMenu | `Layout/RestartButton` | Restart stage from stage-entry state |
| PauseMenu | `Layout/OptionsButton` | Open Options without unpausing combat |
| PauseMenu | `Layout/MenuButton` | End run and return to main menu |
| `defeat.tscn` / Defeat | `Layout/RetryButton` | Retry latest checkpoint or stage entry |
| Defeat | `Layout/MenuButton` | End run and return to main menu |
| `results.tscn` / Results | `Layout/ContinueButton` | Continue to Stage 2 after campaign Stage 1; hide for final victory and isolated runs |
| Results | `Layout/ReplayButton` | Replay isolated stage; shares ContinueButton position and is hidden by default |
| Results | `Layout/MenuButton` | Return to main menu |
| Results | `Layout/CreditsButton` | Open Credits while preserving results as return destination |
| `credits.tscn` / Credits | `Layout/BackButton` | Return to caller |

Pause, defeat, and result scenes have a translucent dim layer and central panel, with no embedded gameplay background. Instance them under a CanvasLayer above the current game. Full-screen main/select/options/controls/credits scenes include the authored forest artwork.

### Options values and fields

| Node path in Options | Type | Current display defaults | Runtime responsibility |
| --- | --- | --- | --- |
| `Layout/Audio/MasterVolume` | HSlider | 80, range 0–100, step 1 | Apply Master bus volume; map zero to mute |
| `Layout/Audio/MusicVolume` | HSlider | 65, range 0–100, step 1 | Apply Music bus volume |
| `Layout/Audio/SfxVolume` | HSlider | 80, range 0–100, step 1 | Apply SFX bus volume |
| `Layout/Display/WindowMode` | OptionButton | 0: Janela; 1: Tela cheia | Apply validated window mode |
| `Layout/Display/Resolution` | OptionButton | 0: 1280 × 720; 1: 1600 × 900; 2: 1920 × 1080 | Apply supported size and preserve usable layout |
| `Layout/Controls/InputDevice` | OptionButton | 0: Automático; 1: Teclado; 2: Controle | Switch device preference/prompts with keyboard recovery |
| `Layout/Controls/Sensitivity` | HSlider | 1.0, range 0.2–2.0, step 0.05 | Apply camera sensitivity multiplier |
| `Layout/Controls/InvertVertical` | CheckButton | false | Invert camera vertical input only |

Load validated saved settings into the widgets before accepting change callbacks. Default values are authored starting points. Avoid applying each intermediate widget update as if it were a fresh user edit during load/reset.

### Focus and responsive layout

Every visible action uses real Button/OptionButton/HSlider/CheckButton nodes with keyboard focus enabled, plus explicit focus-next/previous paths for authored widgets. Claude must assign initial focus on screen entry, preserve focus on return, and verify directional gamepad navigation. Hidden ReplayButton must be excluded from the effective result-screen navigation path; rebuild that path for each run mode.

Use the existing `ui_accept`/`ui_cancel` and UI directional actions or document intentional input changes. The theme provides hover, pressed, and gold focus borders. The static footer is a keyboard hint; update or hide it when gamepad is active. Do not add tutorial paragraphs.

Layout is authored on a centered 1280 × 720 canvas with a full-viewport background and shared typography. The existing project stretch configuration is retained. Validate alternate resolutions and aspect ratios during functional integration; only the 1280 × 720 visual composition is verified in this handoff.

### Runtime text and presentation

- Defeat: `Layout/RetryLocation` must say `Início da fase` when no checkpoint exists, or identify the latest checkpoint concisely.
- Pause: `Layout/Score` displays committed/current attempt score and graze supplied by session state.
- Results: populate `Layout/TimeValue`, `ScoreValue`, `GrazeValue`, and `BombsValue`. Em dashes in the authored scene indicate data not yet bound, not zero results.
- For final campaign victory, change `Layout/Heading` to `Jornada concluída`, hide both ContinueButton and ReplayButton, and focus MenuButton or CreditsButton.
- Credits currently cover only integrated resources (Kenney ship and original project art). Extend credits when models/audio are integrated rather than claiming unused assets are present.

### Editing and QA tools

`tools/build_menu_handoff.py` is an offline authoring utility, not runtime code. It rewrites all eight menu scenes and shared visual resources. Do not rerun it over Claude's scene integration without reconciling changes first.

`tools/validate_menu_handoff.gd` is an offline QA renderer. It loads scenes, validates focus references and basic label dimensions, and captures screenshots when graphics are available. It does not wire or simulate menu actions and does not prove functional navigation or settings persistence.

## 15. Combat HUD scene handoff

`scenes/ui/hud.tscn` has a Control root named `HUD`, attached to the placeholder `scripts/ui/hud.gd`. Instance it under the gameplay CanvasLayer. `scenes/tests/hud_preview.tscn` composes the static combat arena and HUD for F6 inspection; it is not a playable encounter. The project startup scene remains the main menu.

All HUD controls ignore mouse input. The player panel anchors to the bottom-left; boss presentation anchors to the top-center. The center remains clear for flight and projectile reading. Only 1280 × 720 composition has been visually verified.

| Path relative to HUD | Authored state | Claude's binding responsibility |
| --- | --- | --- |
| `PlayerStatus/HealthBar` | 100, range 0–100 | Display current health percentage |
| `PlayerStatus/HealthValue` | `100%` | Match health bar; clamp and format consistently |
| `PlayerStatus/Shield` | Shield icon visible | Show filled/bright for one available shield hit, dim when absent |
| `PlayerStatus/Bomb1`, `Bomb2` | Two bright icons | Reflect actual available bombs; dim spent slots |
| `PlayerStatus/PowerValue` | `1` | Display current power level |
| `PlayerStatus/PowerProgress` | 0, range 0–5 | Display partial collectible progress; handle maximum power according to design |
| `BossStatus` | Hidden | Show only during active boss/miniboss encounter |
| `BossStatus/BossName` | `Guardião das Lanternas` | Replace with encounter name |
| `BossStatus/Phase1`, `Phase2`, `Phase3` | Each 100, range 0–100 | Bind phase health; dim/empty completed phases; adjust count/layout for the two-phase sentry |
| `AttackName` | Hidden; `Ritual das Lanternas` | Brief attack cue, cleared after transition rather than persistent tutorial text |
| `TargetMarker` | Hidden | Project valid target to screen; hide on lost/behind-camera target; center icon on projected point |
| `ThreatLeft`, `ThreatRight` | Hidden | Side-warning visual samples; compute actual direction/visibility from threat data |

Threat samples are not a complete 3D warning system. Vertical/offscreen coverage, timing and priority remain to be integrated. Do not turn the target marker on at its default origin: no projected target position exists yet. Health, bomb and power values are authored visual examples, not saved session state. UI observes combat state; it must not own or change resource values.

`tools/validate_hud_handoff.gd` is an offline presentation check. It validates 13 required node paths and non-interactive controls, then renders the normal HUD and a synthetic boss example. The latter uses 70% health, a spent shield/bomb, power 2 with partial progress 3, and reduced phase-one health to inspect visual states. These changes exist only in the QA process. Both screenshots were inspected successfully; import and render logs are in `docs/validation/`. No gameplay bindings, animation timing or physical-gamepad behavior have been verified.
