# Stage 2 static validation — 2026-09-21

Engine: Godot 4.7.2.stable.official.ed1daf0bf, confirmed through Godot MCP.
The earlier 4.7.1 run exposed invalid generated resource IDs and an incomplete
rotation vector. Both were fixed in the authoring utility before final validation.

## Automated

PowerShell is unavailable on this Linux host. Invoked the repository's same test
entry point directly:

```sh
/home/braiapc/Documents/Godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --log-file /tmp/stage02-engine.log --script res://tests/run_tests.gd
```

16 passed, zero failed. The Stage 2 scene contract checks seven encounters,
22 spawn markers, terrain clearance, five full-volume barriers, safe checkpoint
respawns, three seal assemblies, guard references, and matching portal lights.
A second scene test raycasts beneath every enemy spawn and checkpoint and checks
the ramp surface with backface hits disabled. The test does not simulate combat
or prove runtime progression.

## Visual

```sh
/home/braiapc/Documents/Godot/Godot_v4.7.2-stable_linux.x86_64 --path . --rendering-method gl_compatibility --script res://tools/validate_stage_02.gd
```

Six images captured successfully at 1280×720 on NVIDIA RTX 4050; no render errors.
Inspected entrance, seals, duel, summit, overview, and a player-height basin view.
All three seals remain visible from the basin entrance. Same-camera captures one
second apart differ, confirming ambient shader motion reaches the rendered image.

Revision 02 addresses the user's rejection of the monochrome blockout. The revised
scene has world-space granite/moss/gravel texture, green and amber vegetation,
vermilion gates, warm lanterns, flowing streams/waterfalls, wind-driven foliage and
cloth. Original stepped slabs are now connected by sculpted rises, with matching
collision. The duel's rise begins beyond the circular orbit platform. Closed-gate
wisps fade at the edges instead of creating rectangular sky overlays.

Checks caught and corrected inward crag normals, stream clipping on ramps, and
reversed winding on the terrain collision. The route still uses the approved
linear progression. Render checks cover Compatibility; full combat performance,
physical-controller flight, storm resolution and production renderer review remain
integration tasks. Scene loading and ambient visuals do not establish playability.

- [Entrance](stage-02-entrance.png)
- [Seal basin](stage-02-seals.png)
- [Player-height basin](stage-02-basin-player.png)
- [Duel](stage-02-duel.png)
- [Summit](stage-02-summit.png)
- [Overview](stage-02-overview.png)

Runtime acceptance remains open: all six seal orders, gate bypass attempts,
checkpoint refills/retries, input reachability, boss patterns, and efficient
uninterrupted Stage 2 duration of at least 300 active seconds.
