# F1-05: Astra flight design pass

Status: blocked
Type: design
Owner: Astra

## Scope

Fly `scenes/dev/arena_harness.tscn`; tune only the authorized numeric Inspector
values on PlayerShip, CameraRig and Targeting. Preserve base speed 12, Focus 0.45,
follow distance 8.5, follow height 3.2 and all wiring. No script or test edits.

Record decisions for the rectangular Flight Volume, near-wall hull obstruction,
shrine-gate camera pop, target cycle order and tree occlusion in the module's
Open issues. Retire the obsolete scene generator without executing it. Confirm
or revert the two enemy atlas compression imports. Run `tools/test.ps1`, update
the roadmap and handoff log, and commit only this session's changes.

## Result

Design decisions are recorded in `docs/engineering/player-flight.md` under Open
issues. The generator is retired, unchanged, as a `.py.txt` archive. Both atlases
are lossless and reimported with automatic 3D compression disabled.

Inspector tuning and flight feel acceptance are blocked: Computer Use stopped on
physical Escape. After the user authorized continuation on the secondary monitor,
Godot was relaunched with `--screen 1`, but the tool still refused access with the
same stopped message. No numeric values, scenes, wiring, scripts or tests changed.
Resume the Inspector pass when Computer Use accepts a new user-authorized turn.
Human keyboard and DualSense acceptance remain pending.

## Validation

- `tools/test.ps1 -Import`: 93 passed, 0 failed, exit 0. Both atlases reimported;
  this sandboxed run also printed inaccessible Godot user-directory errors.
- `tools/test.ps1` with normal user-directory access: 93 passed, 0 failed, exit 0.
  Evidence: `docs/validation/player-flight-design-tests.log`. The three missing
  reference errors and one missing HitVolume warning are intentional negative
  tests, each followed by PASS.
- `git diff --check`: clean. Integrated scenes and scripts have no diff.
- Archive is byte-for-byte the original generator; it was never executed.
