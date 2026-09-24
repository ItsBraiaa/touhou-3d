# Stage 2 — mountain route handoff

Date: 2026-09-21. Owner: Astra. State: SCENE_READY_STATIC.

Open `scenes/tests/stage_02_preview.tscn` with F6 for a static view.
The reusable scene is `scenes/stages/stage_02.tscn`, root `Stage`.
There is no player, runtime director, enemy actor, or boss prefab in this pass.
Gameplay remains defined by [STAGE_DESIGN.md](STAGE_DESIGN.md).

## Spatial contract

Forward is -Z, up is +Y. The Stage transform is identity; use global transforms
when instancing it elsewhere. The flight interior is X=-55..55, Y=0..160,
Z=-760..40, also recorded on `FlightBounds/Limits` as min/max metadata.
Base floor elevations rise from 0 to 14, 25, 48, 65, and 83 at the original
terrace boundaries. The last 28 units of each section now form a smooth rise to
the next level; the duel exit uses a shorter 6-unit rise to preserve its orbit
platform. Edge relief adds up to five units outside the central lane. Read actual
terrain collision when clamping flight; the original step-height table is no longer
an exact floor query. Each foundation has Surface and SurfaceBody/Collision nodes.
Concave terrain collision is generated from the same triangles as its visible mesh.
The duel and summit platforms still top out at Y=50 and 85.

The art revision replaces identical blue peaks with three original irregular crag
meshes, textured granite/moss/gravel, broad terrain surfaces, green and amber tree
canopies, shrubs, grass and flowers. Vermilion gate wood, slate roofs, warm lanterns
and bronze inlays distinguish shrine structures. All tree trunks and major crags
remain outside the flight walls; low plants decorate the margins. Cyan fragments
remain route guidance. Four waterfalls and a shallow stream provide moving accents.

Visual materials live in `assets/environment/stage_02/`. Native FastNoiseLite /
NoiseTexture2D feeds world-space terrain texturing; no downloaded textures are used.
Four shaders handle terrain, wind on foliage/cloth, flowing water, and edge-faded
closed-gate wisps. These use shader time and do not attach production GDScript.
Ambient motion does not imply working enemy, seal, checkpoint, or gate behavior.
Water is cosmetic; the ground underneath provides collision. Clouds remain static.

All common Stage roots from GUIDE Section 5 exist, plus `Gates` and
`FlightBounds`. Static scenery uses layer 1, mask 2. Entry, exit, checkpoint,
and approach Areas use layer 0, mask 2, with monitoring disabled for review.
No scripts or signal connections are attached. Enable observation during setup.
Identity metadata is not a parallel runtime configuration format.

## Encounters and markers

Paths below are relative to `Encounters/<ID>`. Every root contains
`EntryVolume/Collision`, `ExitVolume/Collision`, `Spawns`, and `RewardOrigin`.
All spawn positions are stage-local because Encounter roots have identity transforms.

| ID | Entry Z | Exit Z | Spawns | Completion and reward |
| --- | --- | --- | --- | --- |
| S2-01 | 25 | -86 | Wave1_Spirit1..2 | Both defeated and ledge reached; no reward |
| S2-02 | -98 | -191 | Wave1/2_Spirit1..2 and Wave1/2_Sentry1 | Sequential mixed waves; 2 power items, ShieldPickup |
| S2-03 | -203 | -326 | Seal1/2/3_Sentry1..2 | Three seals destroyed in any order; 1 power item per seal |
| S2-04 | -376 | -446 | Wave1_Boss1 at (0,76,-408) | Two-phase Tempest Sentinel; 500 score, ShieldPickup |
| S2-05 | -458 | -566 | Wave1/2_Spirit1..2 and Wave1/2_Sentry1 | Sequential mixed waves; 2 power items |
| S2-06 | -578 | -606 | None | Safe traversal and CP2-B activation |
| S2-07 | -620 | -745 | Wave1_Boss1 at (0,113,-690) | Three-phase Storm Guardian; victory on final defeat |

Totals: 20 common-enemy markers and two boss markers. Spawn actors only under
`RuntimeActors`, preserving authored geometry and markers during retry cleanup.
RewardOrigin alone does not authorize a reward. S2-02 and S2-04 have separate
ShieldPickup markers. S2-03 uses each Seal's local RewardOrigin, not the
Encounter's generic marker. The stage provides seven power items in total.
Typed Definitions await Claude's schema; use the approved timing targets without
automatic timer completion. Neither boss is completed by its ExitVolume.

## Seals and gate

`Encounters/S2-03/Seals/Seal1..3` have stable metadata IDs `S2-03-Seal1..3`.
Positions are (-29,43,-256), (0,65,-285), and (29,86,-267).
Each contains Core, ShieldVisual, OrbitRing, HitVolume/Collision,
ApproachVolume/Collision, RewardOrigin, and GuardLinks/Guard1..2.
HitVolume has sphere radius 1.7, layer 16, mask 0, monitoring/monitorable off;
it supplies geometry to the Projectile Field after integration.

Each guard link's `guard_spawn` metadata is a NodePath relative to S2-03,
for example `Spawns/Seal1_Sentry1`. Resolve against the Encounter, then associate
with the spawned actor. Hide the corresponding link on guard defeat. Remove the
shield only after both linked guards die; allow target selection/damage then.
Each approach box is 24×22×30, centered ten units toward the entrance from its
seal. Activate that pair once on approach or shooting a guard. Multiple pairs may
remain active. Guard activation, six destruction orders, bomb handling, and
one-time reward delivery require implementation and gameplay tests.

`Gates/Gate_S2_03/PortalLights/Seal1..3` are three separate ring meshes. They
are static cyan samples; runtime must distinguish unresolved and resolved lights.
The third resolved seal opens the gate. Shield/link visuals are also static.

## Gates and checkpoints

Five Gate roots: `Gates/Gate_S2_01..05`, at Z=-90, -195, -330, -450, -570.
Each has BarrierBody/Collision (110×160×1, center Y=80), ClosedVisual, Arch,
and hidden OpenVisual/ClearBeacon. Opening disables the barrier and hides the
closed veil while showing the clear beacon. Arch geometry stays intact.
Full cross-section barriers geometrically cover the floor/ceiling and side walls;
movement-based bypass resistance still needs player integration testing.

| Checkpoint | Center | Respawn | Resume |
| --- | --- | --- | --- |
| Checkpoints/CP2-A | (0,62,-354) | child Respawn at local (0,0,-4) | S2-04 |
| Checkpoints/CP2-B | (0,98,-596) | child Respawn at local (0,0,-4) | S2-07 |

Both respawns face -Z, are above their floors and precede the next combat trigger
by 18 and 20 units. Checkpoint Areas are 38×26×6; matching arches are under
Geometry. The director must validate prerequisite completion and commit the
checkpoint before starting the next fight, including players crossing outside the
central arch. Whole-section EntryVolumes alone must never bypass a checkpoint.
First activation/refill, saved power/statistics, retry, and cancellation of queued
spawns follow STAGE_DESIGN. CP2-A retries repeat the duel and final ascent.

## Validation and remaining work

Godot MCP confirmed version 4.7.2 and project access. The Linux executable ran
`tests/run_tests.gd`: 16 tests passed, zero failures, including the new scene
contract. PowerShell is unavailable here, so the same runner was invoked directly.
`tools/validate_stage_02.gd` rendered six inspected views and checked ambient frame changes using Compatibility on
NVIDIA RTX 4050. See [validation/stage-02.md](validation/stage-02.md).

Claude: attach the validated director, author typed encounter resources, connect
waves/seals/checkpoints, instance enemy and boss prefabs, and integrate the player.
Boss retreat containment, boundary feedback, animated seal/gate states, storm
resolution, input reachability, and the five-minute efficient clear remain open.
No active duration or playability is claimed by the static scene.

`tools/build_stage_02.py` rewrites Stage 2, its preview, and the original OBJ
terrain/stream/crag meshes in `assets/environment/stage_02/`. Reconcile any
integration edits before running it again. No Stage 1 generator was executed.

## Boundary rail pass (2026-09-23)

Environment/BoundaryRails now follows both sides of the six mountain terraces, with posts, two beams and bronze caps. These visual rails indicate the edge enforced by the existing FlightBounds/West and East layer-1 walls and the player flight clamp. No gameplay markers, terrain collision, script wiring, collision layers or masks changed. Six 1280 x 720 review captures in docs/validation/stage-02-*.png show the rails in the route views.
