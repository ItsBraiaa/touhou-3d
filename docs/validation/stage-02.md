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

15 passed, zero failed. The Stage 2 scene contract checks seven encounters,
22 spawn markers, terrain clearance, five full-volume barriers, safe checkpoint
respawns, three seal assemblies, guard references, and matching portal lights.
The test does not simulate combat or prove runtime progression.

## Visual

```sh
/home/braiapc/Documents/Godot/Godot_v4.7.2-stable_linux.x86_64 --path . --rendering-method gl_compatibility --script res://tools/validate_stage_02.gd
```

Five images captured successfully at 1280×720 on NVIDIA RTX 4050; no render errors.
Inspected entrance, seals, duel, summit, and overview. All three seals appear in
the entrance view of the basin. Platforms leave open aerial orbit space. Cyan
route markers and violet gate accents distinguish travel from blocked passages.
This is a primitive spatial pass; the route remains straight and decorative peak
silhouettes repeat. Final art, moving-camera composition, and boundary feedback
need a later integrated pass. Only Compatibility rendering is verified here.

- [Entrance](stage-02-entrance.png)
- [Seal basin](stage-02-seals.png)
- [Duel](stage-02-duel.png)
- [Summit](stage-02-summit.png)
- [Overview](stage-02-overview.png)

Runtime acceptance remains open: all six seal orders, gate bypass attempts,
checkpoint refills/retries, input reachability, boss patterns, and efficient
uninterrupted Stage 2 duration of at least 300 active seconds.
