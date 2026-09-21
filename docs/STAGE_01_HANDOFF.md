# Stage 1 — area and engineering handoff

Date: 2026-09-20. Owner: Astra. State: SCENE_READY_STATIC (first spatial pass).

Authoritative gameplay: [STAGE_DESIGN.md](STAGE_DESIGN.md). Shared integration rules: [GUIDE.md](GUIDE.md). Follow CONTEXT.md and accepted ADRs for engineering. This document describes actual scene paths; it does not replace the encounter rules.

## Open and integrate

- Area: `scenes/stages/stage_01.tscn`, root `Stage` (Node3D).
- F6 preview: `scenes/tests/stage_01_preview.tscn`; contains Stage and an independent static PreviewCamera.
- No Player, Menu, production scripts or project startup settings were edited in this pass. Stage has no attached script yet. Claude supplies and attaches the director after implementing its contract.
- The preview contains no Player or HUD and performs no movement. Compose the actual Player and HUD through the application's composition root after their scripts are ready.
- Authored geometry, lighting, trees, lanterns and shrine are original primitives. Ghost is not yet instantiated or animated.

## Spatial contract

Route direction is -Z; identity Stage transform is the authored reference. Use marker global transforms if instancing Stage with a transform. Flight interior spans X=-45..45 and Y up to 75. Side/end/ceiling collision is on scenery layer 1, mask 2. Ground terraces rise from Y=0 to 28. Trunks inside the route have box collision; tree crowns are decorative and intentionally non-solid. Lanterns are decorative. Flight boundaries and overhead feedback need an integrated readability pass.

| Encounter | Entry Z | Exit-volume Z | Authored spawns under `Encounters/<ID>/Spawns` |
| --- | --- | --- | --- |
| S1-01 | 20 | -57 | None; safe approach |
| S1-02 | -60 | -137 | `Wave1_Spirit1..3`, `Wave2_Spirit1..3` |
| S1-03 | -145 | -222 | `Wave1_Sentry1..2`, at different heights |
| S1-04 | -230 | -312 | `Wave1_Sentry1..3`, low/middle/high portal guards |
| S1-05 | -340 | -422 | Each of Wave1 and Wave2 has Spirit1, Spirit2, Sentry1 |
| S1-06 | -430 | -457 | None; safe sanctuary entrance |
| S1-07 | -465 | -562 | `Wave1_Boss1` at (0,43,-520) |

Each encounter has `EntryVolume/Collision`, `ExitVolume/Collision`, `Spawns`, and `RewardOrigin`. Entry/exit Areas span the route cross-section; their monitoring is disabled for static review. Enable monitoring and connect once during integration. They are traversal observations, not sufficient authority to complete an encounter. Use the exact completion conditions from STAGE_DESIGN.md; specifically, boss completion comes from final phase defeat, not its ExitVolume.

Enemy counts total 17 common enemies and one boss marker. Waves remain inactive until the director activates them. Spawn into `RuntimeActors`; never delete authored markers during cleanup. RewardOrigin is a location only: S1-02 and S1-05 each award exactly five power pickups after their final wave, while S1-03 uses its separate `ShieldPickup` marker. Other RewardOrigin nodes do not imply rewards.

Typed Encounter/Wave/Reward Resources remain to be authored against Claude's validated Resource classes (ADR 0003). Names and minimal identity metadata here are scene integration labels, not a runtime JSON configuration system.

## Gates and portal presentation

Four roots: `Gates/Gate_S1_02`, `Gate_S1_03`, `Gate_S1_04`, `Gate_S1_05`, at Z=-140, -225, -315, -425 respectively.

Each contains `BarrierBody/Collision`, `ClosedVisual`, and `Arch`. Barrier collision spans 90 × 75 units from Y=0 to 75 and meets side/ceiling bounds. All are closed in the static scene. Opening must disable BarrierBody collision and hide ClosedVisual; the arch remains scenery. Set state idempotently, including checkpoint reconstruction. Full-span geometry was checked; practical bypass resistance still requires moving-player tests.

`Environment/PortalLinks/GuardLink1..3` links the corresponding S1-04 Sentry markers to the portal. Hide each link when its guard dies, and reconstruct it from encounter state on retry. Empty endpoints currently mark future enemy placement. Arch trim material is shared across gates; duplicate material before changing only one gate's color.

The boss arena has no runtime retreat containment yet. Claude should expose active-encounter bounds and request any extra boundary presentation from Astra. Do not allow indefinite safe retreat or completion of later encounters by flying over their triggers out of order.

## Checkpoints

Both are Area3D roots under `Checkpoints`, with `Collision` and `Respawn`. They currently have monitoring disabled and no attached checkpoint script. Visible arches live separately under `Geometry/CP1-AArch` and `Geometry/CP1-BArch`.

| ID | Area center | Global Respawn | Resume |
| --- | --- | --- | --- |
| CP1-A | (0,28,-325) | (0,27,-329) | S1-05 |
| CP1-B | (0,38,-450) | (0,37,-454) | S1-07 approach |

Respawn faces -Z. Both next encounter entry volumes are 15 units beyond checkpoint centers. Checkpoint Areas are 30 × 20 × 5 around the arch. The director must require activation before arming the next combat encounter, even if a player flies outside the arch's activation volume. Guide the player back using the arch presentation, not a written objective.

Apply approved full health, one shield and two bombs on first activation and Retry; revisits do not refill. Preserve/restore power progress and statistics according to STAGE_DESIGN.md. Retry cleanup removes runtime actors, projectiles, locks and queued spawns without disturbing authored scenery.

## Claude can work now

Priority order after the requested Menu and Player work:

1. **Settings and HUD binding:** apply/persist audio, display and input settings; bind the existing HUD paths from GUIDE sections 14–15. Use test combat state until real combat arrives.
2. **Combat state and pickups:** health percentage, one-hit shield, damage invulnerability, bombs, power thresholds, pickup acceptance and once-only rewards. These rules can be tested without final meshes.
3. **Weapons, projectiles and graze:** Muzzle and FamiliarAnchors already exist. Implement cadence, assisted shots, swept hits, once-per-projectile graze, and cleanup on bomb/phase/checkpoint transitions. Use the accepted centralized projectile-field architecture.
4. **Run lifecycle and checkpoints:** Campaign/Direct Stage start values, Pause, Retry, Restart, results statistics and immutable Snapshot restore. Test restoration and duplicate callbacks in a simple fixture.
5. **Typed definitions and StageDirector:** schema validation, ordered encounter lifecycle, waves, gates and checkpoint preconditions. The scene markers above are ready; schema classes and behavioral tests can precede wiring.
6. **Common enemy and boss cores:** aimed bursts, spaced fans, phase state and defeat events can run against simple test targets. Final model references, animation names and emitter placements require Astra's enemy prefab handoff before integration.

Menu/Player first, then a working shooting-and-damage loop in the test arena, then progression. This yields an early playable slice without waiting for all scenery. Audio playback infrastructure can also be implemented against temporary streams; final event-to-file mappings and mix remain unselected.

Coordinate edits to scene files, GUIDE and project.godot before changing shared integration points. Do not run an authoring generator over Claude's scene wiring.

## Verification and remaining work

Godot 4.7.2 imported the scene successfully. Offline QA rendered five views at 1280 × 720 and reported zero failures for seven encounters, 18 spawn markers, two checkpoints and four full-span gate shapes. Captures: `docs/validation/stage-01-{entrance,ascent,portal,arena,overview}.png`. Validation utility: `tools/validate_stage_01.gd` (offline only).

This is the initial area, not a complete playable stage. Pending: actual Player traversal, enemy and Ghost prefab presentation, live gates/checkpoints, combat VFX/audio, terrain/detail refinement, active-encounter retreat limits, camera obstruction review, collision tuning, performance measurements and the four-minute Stage 1 pacing target. No academic gameplay duration has been measured.

`tools/build_stage_01.py` rewrites only the Stage 1 scene and its preview. It is an offline authoring utility. Do not rerun after integration without reconciling edits.
