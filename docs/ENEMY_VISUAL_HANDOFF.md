# Stage 1 enemy visual variants

Date: 2026-09-21. Owner: Astra. State: SCENE_READY (visuals only).

The user approved recolor/resize variants with identical health within each enemy type. These scenes contain no health values, scripts, collision objects or gameplay changes. Do not multiply combat stats by visual scale.

| File under `scenes/enemies/visuals/` | Source | Presentation | Base pose height |
| --- | --- | --- | --- |
| `spirit_lume.tscn` | Hywirl | Cool blue/teal accents; Spirit | 2.2 |
| `spirit_twilight.tscn` | Hywirl | Lilac; same Spirit | 2.64 |
| `sentry_lantern.tscn` | Goleling | Amber with one magic ring; Sentry | 1.6 |
| `sentry_seal.tscn` | Goleling | Violet with two rings; same Sentry | 2.0 |

Height normalization uses imported mesh bounds before animation. Goleling has broad wings, so its height is intentionally lower than the humanoid Spirit. Final flight-camera scale tuning remains necessary. Original vertex/atlas colors are preserved under a material tint; recoloring is not a uniform paint replacement.

## Claude integration

Instance the selected scene as the Enemy's `VisualRoot`. Keep Enemy root, HitVolume and Emitters outside the scaled imported `Model`. Both Spirit variants share the same health configuration; both Sentry variants share the same health configuration. These visual scenes do not define hit radius; retain the gameplay type's radius across variants rather than deriving it from rendered size.

Since D-08, `Model` is a plain `Node3D` holding an embedded copy of the glTF subtree, so reimporting `Hywirl.gltf` or `Goleling.gltf` no longer reaches these four scenes.

All four roots are Node3D named VisualRoot. AnimationPlayer is `Model/AnimationPlayer` relative to VisualRoot. Available clips: `Death`, `Fast_Flying`, `Flying_Idle`, `Headbutt`, `HitReact`, `No`, `Punch`, `Yes`. Flying_Idle loops and autoplays; Claude can take over playback for state transitions. No casting/contact attack is implied by an animation name. Rings are static MeshInstance3D children `MagicRing1` and, for the seal variant, `MagicRing2`.

Suggested assignment: S1-02 first wave lume and second wave twilight; S1-03 lantern sentries; S1-04 three seal sentries; S1-05 mixed spirit colors with lantern sentries. Counts and rewards stay unchanged. No models were inserted into live encounter markers: StageDirector must spawn actors once and own their cleanup.

## Verification

Godot 4.7.2 imported both source models and loaded all four scenes. Offline QA started/advanced Flying_Idle for all variants and checked that visuals have no collision components or root scripts. `docs/validation/enemy-visuals.log` records zero failures. Gallery: `scenes/tests/enemy_variants_preview.tscn` (F6), screenshot `docs/validation/enemy-variants.png`. This checks the idle pose and scene structure, not all clips or combat behavior.

Original source files remain untouched. Selected runtime copies are under `assets/models/enemies/`. Supplied CC0 license is preserved as `assets/licenses/quaternius-ultimate-monsters.txt` (its source heading says Ultimate Platformer Pack). Offline generator `tools/build_enemy_visuals.gd` rewrites only the four visual scenes; do not rerun after integration edits without reconciliation.

## Boss prefabs

### Lantern Guardian (D-03, SCENE_READY)

`scenes/enemies/lantern_guardian.tscn` is the Stage 1 S1-07 boss prefab. Its `Enemy` root is an identity `Node3D` with no script or gameplay values. `VisualRoot/Model` instances the approved `assets/models/bosses/Ghost.gltf` at scale 2.6. `VisualRoot/Lanterns/Lantern1..8` are amber emissive `MeshInstance3D` lanterns with simple caps; `VisualRoot/LanternMotion` turns the ring through a 12-second looping `orbit` clip independently of the imported model's animation player. No collision object is under `VisualRoot`.

`Enemy/HitVolume` is an `Area3D` on layer 16, mask 0, with monitoring and monitorable off; `HitVolume/Collision` is a sphere of radius 3.0 centered at `(0, 4.3, 0)` relative to `Enemy`. `Enemy/Emitters/Main` is at `(0, 5, -1.5)`. Both gameplay nodes are outside the scaled model.

| Role | Actual clip on `VisualRoot/Model/AnimationPlayer` | Design reading |
| --- | --- | --- |
| Idle | `Flying_Idle` | Loops and autoplays. |
| Step cue | `Punch` | The mid-clip arm draw reads as a spell windup at the approach camera. |
| Phase change | `Yes` | A head lift/nod; reserved for a later `phase_clip` export. |
| Defeat | `Death` | Non-looping collapse, 0.667 s. |

Godot 4.7.2 imported the Ghost and the copied atlas. The offline QA in `tools/validate_boss_scenes.gd` reported zero failures headless and windowed; `docs/validation/boss-scenes.log` records the result. [The S1-07 dusk capture](validation/lantern-guardian.png) was inspected at a 35-unit approach distance: the silhouette, eyes, amber lanterns and central gap remain distinct. The lantern ring was shifted half a step so no lantern covers the face from this angle. Trunk F12-03 attaches `boss_controller.gd` and sets its exports; the dev boss remains untouched until then.

### Stage 2 bosses (D-04, SCENE_READY)

Both prefabs use the same `Enemy` tree as Lantern Guardian: identity `Node3D` root with no script or gameplay values, `VisualRoot/Model`, `HitVolume/Collision`, and `Emitters/Main`. Both `HitVolume` nodes are `Area3D` on layer 16, mask 0, with monitoring and monitorable off. No collision object sits under either `VisualRoot`. Their model players are at `VisualRoot/Model/AnimationPlayer`.

| Scene | Model and visual scale | Hit sphere (radius; center relative to Enemy) | Emitter | Presentation |
| --- | --- | --- | --- | --- |
| `scenes/enemies/tempest_sentinel.tscn` | Goleling, `(3.1, 3.1, 3.1)` | 2.5; `(0, 6.9, 0)` | `(0, 7.1, -1.7)` | Slate body and three cyan/violet `VisualRoot/Ornaments/Ring1..3` meshes. `VisualRoot/OrnamentPlayer` loops and autoplays `storm_orbit` over 9 s, independently of the model player. |
| `scenes/enemies/storm_guardian.tscn` | Dragon_Evolved, `(5, 5, 5)` | 5.0; `(0, 8.8, 0)` | `(0, 9.5, -3.5)` | Lavender-blue body with blue and violet `VisualRoot/StormSigils/Sigil1..2` meshes. |

For each model player, idle is `Flying_Idle` (loop/autoplay), step cue is `Punch` (arm windup), Phase change gesture is `Yes` (head and wing lift, reserved for a later `phase_clip` export), and defeat is `Death` (non-looping). `Punch` is a visual cue only; the controller determines attack timing. The source glTFs are unchanged; the body colors and storm meshes live in these scenes.

The validator reported zero failures for all three boss scenes headless and windowed. [The S2-04 capture](validation/tempest-sentinel.png) at 38 units shows a larger Sentry silhouette and distinct energy orbit against the Stage 2 gate palette. [The S2-07 capture](validation/storm-guardian.png) at 52 units shows the Dragon silhouette and restrained storm sigils against the summit palette; the wings stay above the near-player projectile space. F12-06 and F12-07 attach `boss_controller.gd`, set its exports, and point `stage_02.tscn` actor scene entries at these prefabs.
