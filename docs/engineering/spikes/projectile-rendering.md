# Projectile rendering measurement

The F6-01 spike, folded into F6-02 by the sprint plan (2026-09-23): MultiMesh was built directly, and this page records one measurement of the result. Measured 2026-09-23 with `ProjectileSystem` as shipped. **Other lanes were running on the same machine** (Godot test runs and editor imports in other worktrees), so every number here is pessimistic and a single run.

## Machine

| Item | Value |
| --- | --- |
| GPU | AMD Radeon RX 9070 XT |
| CPU | AMD Ryzen 7 5800X3D 8-Core Processor |
| Renderer | Forward+ on D3D12 |
| Engine | Godot 4.7.2.stable.official.ed1daf0bf |
| Resolution | 1280 × 720 window, vsync off, `Engine.max_fps = 0` |
| Physics | 60 ticks per second (project default), Jolt |

## Method

A throwaway `SceneTree` script (deleted after the run) loaded `scenes/dev/arena_harness.tscn` with `ProjectileSystem.capacity` raised to 4096, stopped the `DevSpray` timer, and topped the field up every frame: half the count as hostile rings through `DevSpray.spawn_ring()`, half as player rings of the same shape. Rings of 24 at speed 6 from (0, 6, 0) fly until the arena walls stop them, so every Projectile casts its obstacle ray every tick and the hostile half is swept against the ship at (0, 6, 18). Per count: 2 s warm-up, then 5 s of samples.

- Frame time from consecutive `process_frame` timestamps; FPS is frames over the sample time.
- "System step" is the wall time of `ProjectileSystem._physics_process` (set the player, tick the field with its rays, refresh both renderers), bracketed by two probe nodes at physics priorities 99 and 101.
- Rays and the renderer refresh were timed apart, once per count after sampling: one layer-1 `intersect_ray` of 0.1 units per alive Projectile, and both `_refresh_renderer` calls.
- Render CPU and GPU times from `RenderingServer.viewport_get_measured_render_time_cpu/_gpu`; draw calls from `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`.

## Results (windowed)

| Projectiles (alive) | FPS | Frame mean | Frame p95 | Physics step (all nodes) | System step | Render CPU | Render GPU | Draw calls | Refused |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 300 (329) | 1827 | 0.55 ms | 0.74 ms | 0.96 ms | 0.47 ms | 0.18 ms | 0.34 ms | 157 | 0 |
| 1000 (1019) | 1519 | 0.66 ms | 1.01 ms | 1.99 ms | 1.34 ms | 0.18 ms | 0.40 ms | 157 | 0 |
| 3000 (3020) | 1118 | 0.89 ms | 4.53 ms | 4.53 ms | 3.84 ms | 0.18 ms | 0.48 ms | 157 | 0 |

The physics step runs on about one frame in twenty at these frame rates, which is why the mean frame time sits far below the physics cost and the p95 at 3000 (4.53 ms) is the frames that carry a physics step.

| Projectiles | Rays | Ray time | Per ray | Renderer refresh (both factions) |
| --- | --- | --- | --- | --- |
| 300 | 305 | 0.09 ms | 0.30 µs | 0.14 ms |
| 1000 | 1023 | 0.38 ms | 0.37 µs | 0.42 ms |
| 3000 | 3046 | 0.89 ms | 0.29 µs | 1.15 ms |

At 3000 the 3.84 ms system step is therefore about 0.9 ms of rays, 1.2 ms of renderer refresh and 1.8 ms of the field's own pass (lifetimes, sweeps, moves). A headless pass of the same script completed first (physics step 1.06, 2.55 and 6.41 ms), with no render numbers.

## Recommendation

- **MultiMesh stays.** One `MultiMeshInstance3D` per faction draws 3000 Projectiles with the draw-call count unchanged (157 is the arena itself) and under 0.5 ms of GPU time. No count here drops below 60 FPS, or anywhere near it.
- **Capacity 2048 stays** as the default: PLANEJAMENTO's densest pattern needs far less, and a raised capacity costs only memory (the per-tick work scales with the alive count). Raise it on `Main/ProjectileRoot` if a boss pattern ever reports refusals.
- **No buffer read-out is needed from the field.** The refresh through `get_positions` and `get_radii` plus a GDScript write into a persistent buffer costs 1.15 ms at 3000; a field-side buffer would save part of that, and nothing asks for it.
- **The ray per Projectile per tick is affordable** at 0.3 µs a ray: under 1 ms at 3000. No mitigation is proposed.

## Not measured

- Real boss patterns (F12-03, the F14-02 acceptance record), the exported build (F14-01) and the presentation computer.
- A machine with nothing else running.
- Case B of F6-01 (a `MeshInstance3D` pool) and case A1 (`set_instance_transform` per instance): MultiMesh with a buffer was built directly, as the sprint plan decided.
