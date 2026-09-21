# Stage 2 static mountain route

Status: done
Owner: Astra
Type: scene

## Acceptance

- Seven stable S2-01 through S2-07 encounter roots with entry/exit volumes.
- Mountain ascent, crossfire ledges, visible low/middle/high seals with two guard
  markers each, duel volume, final ascent, summit threshold, and open boss volume.
- Full-cross-section gate collision and separate safe checkpoint/arena triggers.
- Exact authored spawn and reward locations documented for Claude.
- Scene loads, contract checks pass, rendered views reviewed, existing tests pass.
- Handoff, roadmap, and own-files commit completed.

Static delivery only. Six seal orders, checkpoint restore, combat, and five-minute
active duration require runtime integration and are not verified by this ticket.

## Result

SCENE_READY_STATIC. Godot 4.7.2: 15 tests passed, zero failed; five static
previews rendered and inspected. See docs/STAGE_02_HANDOFF.md and
docs/validation/stage-02.md. Runtime acceptance remains pending integration.
