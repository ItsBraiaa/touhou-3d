# F6-01 Projectile rendering spike

Status: todo
Type: spike
parallel-safe: no (FPS must be measured with nothing else running; time-box 1 h)
Depends on: F5-01

## Goal

Answer one question with numbers from this machine: at 300, 1000 and 3000 Projectiles, 1280 × 720, which representation draws them at the higher frame rate with the lower frame time, one `MultiMeshInstance3D` per faction or a pool of `MeshInstance3D` nodes? The spike also measures what the F5 field's tick and a layer-1 `intersect_ray` per Projectile cost at the same counts, because ADR-0004's obstacle query scales with the population too. It ends with one recommendation and a capacity proposal for F6-02. The code is throwaway (ENGINEERING_BRIEF 4.D, "Do not assume an advanced rendering system is necessary").

## Read first

- `docs/adr/0004-central-projectile-field.md` (only rendering was left to this spike)
- `docs/ENGINEERING_BRIEF.md` Section 4.D "Refinement question" and Section 8 "Profile a dense final-boss encounter… Initial target is 60 FPS, not a verified result. Record resolution and observed behavior"
- `docs/engineering/projectile-field.md` (F5-01: `setup`, `spawn`, `tick`, `get_positions`, `get_radii`)
- `docs/GUIDE.md` Section 13 "Authored player values" (Forward Plus on D3D12, 1280 × 720, 4× MSAA)
- `/mattpocock-skills:prototype` (throwaway rules)

## Files

- **Creates:** `scenes/dev/spikes/projectile_render_spike.tscn`, `scenes/dev/spikes/projectile_render_spike.gd` (throwaway, committed so the numbers can be reproduced, and never loaded by `main.tscn`), `docs/engineering/spikes/projectile-rendering.md`.
- **Edits:** nothing.
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (F6-01 row), `docs/HANDOFF_LOG.md`, a line for `spikes/projectile-rendering.md` in `docs/engineering/README.md`. There is no module doc: `weapon-rendering.md` starts in F6-02.
- **Must not touch:** `scripts/combat/projectile_field.gd` (use it as it is; if a read-out is missing, that is a finding for F6-02), `scenes/main.tscn`, `project.godot` (vsync and max FPS are set at runtime inside the spike only), `scenes/tests/combat_arena.tscn`.
- **Conflicts with:** none on files. Run it alone.

## Deliverables

One self-running scene, with no input. It steps through every case, prints results and quits.

- The scene holds a `Camera3D` looking at a volume about the size of a Stage 1 Encounter (for example 60 × 40 × 60), a light, and a few `StaticBody3D` boxes on layer 1 for the ray cost.
- Movement uses a real `ProjectileField` (F5-01) with random velocities from a seeded `RandomNumberGenerator`, long lifetimes, and an immediate respawn of anything culled, so the count stays constant. Half the Projectiles are `PLAYER` and half `HOSTILE`, so both render paths are exercised.
- The mesh is a low-poly `SphereMesh` of radius 1 with an unshaded emissive `StandardMaterial3D`, and each instance is scaled by the Projectile's radius (0.25).
- Cases, each at 300, 1000 and 3000:
  - **A1** `MultiMeshInstance3D` updated with `set_instance_transform` in a GDScript loop.
  - **A2** `MultiMeshInstance3D` with `multimesh.buffer` rebuilt as one `PackedFloat32Array`.
  - **B** a pool of `MeshInstance3D` whose `position` is set.
  - **Ray cost:** only the field tick plus one `intersect_ray` per Projectile per tick, timed with `Time.get_ticks_usec()`.
- Method: `DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)` and `Engine.max_fps = 0`. Per case, warm up 2 s, then sample 5 s and record:
  - mean FPS, and mean and 95th-percentile frame time from `_process` deltas;
  - `Performance` `TIME_PROCESS` and `TIME_PHYSICS_PROCESS`;
  - render CPU and GPU time (`RenderingServer.viewport_set_measure_render_time` and `viewport_get_measured_render_time_cpu` / `_gpu`);
  - draw calls (`RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME`).
- One `SPIKE_RESULT <case> <count> ...` line per case, then `SPIKE_DONE`. The scene quits itself, and `--quit-after` guards against a hang.
- Run it headless first, which checks that the sequence completes and prints `SPIKE_DONE` (render numbers are N/A there). Then run it windowed at 1280 × 720: windowed validation can hang, and a headless pass must come first.
- `docs/engineering/spikes/projectile-rendering.md` holds:
  - the machine: `RenderingServer.get_video_adapter_name()`, `OS.get_processor_name()`, the renderer and driver, and the resolution;
  - the results table and the ray-cost table;
  - the recommendation, with the count at which each approach drops below 60 FPS;
  - a capacity proposal for `ProjectileSystem.capacity`;
  - whether F6-02 needs a buffer-shaped read-out from the field;
  - what was not measured (real boss patterns, the exported build, the presentation computer).

**Time-box: 1 hour.** At the limit, record what was measured and recommend `MultiMeshInstance3D` (A2), the approach Godot documents for many identical instances, with capacity 2048. Say that this recommendation was not fully measured.

## Tests required

None: this is a spike. The run itself is the evidence, and its `SPIKE_RESULT` lines are pasted into the record. `tools/test.ps1` must still be green: the spike adds no tests and must not break any, and its script compiles under the warnings-as-errors settings.

## Out of scope

- The production `ProjectileSystem` (F6-02).
- Physics interpolation, LOD, and GPU particles.
- Profiling real boss patterns (F12-03, F14-02).
- The exported build (F14-01).
- Tuning `project.godot` rendering settings. If one looks necessary, the record requests it; the spike does not change it.

## Definition of Done

- `tools/test.ps1` is green, and the spike script has no Error-level warnings.
- `docs/engineering/spikes/projectile-rendering.md` is written with the measured tables and one recommendation, and linked from `docs/engineering/README.md`.
- A handoff log entry, ticket `Status: done` with an Outcome that repeats the recommendation and the capacity, and the roadmap row.
- One commit: `combat: record the projectile rendering spike`.

## Handoff notes for Astra

None needed. If final Projectile art is wanted, it should be a mesh of radius 1 with one material, so it can be instanced and scaled by the Projectile's radius. The spike's numbers say how much vertex and overdraw budget such a mesh has.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/weapon-rendering/issues/01-rendering-spike.md, then implement that ticket with /mattpocock-skills:prototype. Finish with its Definition of Done and commit.
```
