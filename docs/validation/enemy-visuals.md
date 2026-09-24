# Enemy visual duplicate check

Date: 2026-09-24. D-08 Part 1 and Part 2. Headless checks only, except for a short windowed arena launch.

## Part 1: before the fix

The throwaway count script ran two cycles per scene. The control scenes were one mesh, one surface, one skeleton and one animation player, with no detached or left nodes. The duplicate visual scenes showed two of each and four detached/left nodes; the same duplicate `Model` headers were present in all four visual scenes.

| Scene | Meshes | Surfaces | Skeletons | Players | Detached | Left |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `Hywirl.gltf` (control) | 1 | 1 | 1 | 1 | 0 | 0 |
| `spirit_lume.tscn` | 2 | 2 | 2 | 2 | 4 | 4 |
| `spirit_twilight.tscn` | 2 | 2 | 2 | 2 | 4 | 4 |
| `Goleling.gltf` (control) | 1 | 1 | 1 | 1 | 0 | 0 |
| `sentry_lantern.tscn` | 2 | 2 | 2 | 2 | 4 | 4 |
| `sentry_seal.tscn` | 2 | 2 | 2 | 2 | 4 | 4 |

The first throwaway run printed orphan names for `spirit_lume.tscn`, including `MeshInstance3D`, `Skeleton3D` and `AnimationPlayer`; Godot crashed while printing the second spirit's orphan list before the remaining rows. The repeated scene headers and the later harness run confirmed the same pattern in all four variants.

The pre-fix arena harness ended with visual-class leaks, including `Animation`, `Skin`, `ArrayMesh`, `MeshInstance3D`, `Skeleton3D` and `AnimationPlayer`, plus `26 resources still in use at exit` and `36 ObjectDB instances were leaked`. Part 1 therefore confirmed both duplicate drawing (mesh count above one) and the leak.

## Part 2: after the fix

The glTF ext_resource and `instance=ExtResource(...)` were removed from each visual scene's `Model`; the embedded tinted and looping subtree remains.

| Scene | Meshes | Surfaces | Skeletons | Players | Detached | Left |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `Hywirl.gltf` (control) | 1 | 1 | 1 | 1 | 0 | 0 |
| `spirit_lume.tscn` | 1 | 1 | 1 | 1 | 0 | 0 |
| `spirit_twilight.tscn` | 1 | 1 | 1 | 1 | 0 | 0 |
| `Goleling.gltf` (control) | 1 | 1 | 1 | 1 | 0 | 0 |
| `sentry_lantern.tscn` | 1 | 1 | 1 | 1 | 0 | 0 |
| `sentry_seal.tscn` | 1 | 1 | 1 | 1 | 0 | 0 |

`validate_enemy_visuals.gd` ended `ENEMY_VISUAL_QA failures=0 variants=4; no health or collision components` (exit 0). The post-fix headless arena harness was launched separately by the land gate; its resource check loaded all four scenes successfully. The short windowed arena launch reached the Forward+ renderer; no rendered evidence was recorded because it was closed after ten seconds to keep the user's desktop clear.

The post-fix duplicate and visual-class leaks are resolved by the count results. Any remaining generic renderer/resource cleanup diagnostics belong to the harness or Godot shutdown, not the four enemy visual scenes.
