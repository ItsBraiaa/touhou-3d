# Stage 1 area — scene authoring plan

Status: ready-for-human

Approved source: docs/STAGE_DESIGN.md, S1-01 through S1-07. User authorized starting the area while Claude implements Menu and Player.

Build a static, fully three-dimensional lantern forest route from Z=30 to Z=-565, with broad combat spaces and rising scenery. Keep all seven Encounter IDs, separate safe checkpoints CP1-A/CP1-B from subsequent combat triggers, and provide full-volume gate collision. Include authored spawn markers, not enemy runtime implementations. Use original low-poly geometry and lighting; the selected Ghost boss will be integrated separately.

Files owned by this pass: scenes/stages/stage_01.tscn, scenes/tests/stage_01_preview.tscn, tools/build_stage_01.py, tools/validate_stage_01.gd, docs/STAGE_01_HANDOFF.md, validation outputs. Do not modify Player, Menu, project startup or Claude's scripts. No runtime scripts are needed for a static scene; stage-director attachment awaits Claude's implemented contract.

- [x] Author route geometry, collision boundaries, decorative forest and lantern guidance.
- [x] Place seven Encounter entry/exit volumes, spawn markers, gates and two checkpoint arches.
- [x] Import and validate resource loading, markers, gate coverage and checkpoint spacing.
- [x] Render entrance, ascent, portal and boss-arena views; inspect them.
- [x] Document concrete paths and Claude's independent work queue.

Typed encounter Resources are Claude's schema responsibility under ADR 0003. Scene metadata only identifies authored markers; it is not a second runtime data format. Gameplay timing, bypass resistance during movement, encounter transitions and checkpoints require later integrated playtesting.
