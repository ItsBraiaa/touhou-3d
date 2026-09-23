# Player flight validation — 2026-09-22 (F1-02, F1-03, F1-04)

Engine: Godot 4.7.2.stable.official.ed1daf0bf, Windows 11, D3D12 Forward+ on an AMD
Radeon RX 9070 XT. Scene under test: `scenes/dev/arena_harness.tscn`, which instances
Astra's `scenes/tests/combat_arena.tscn` and adds a debug readout.

The flight sections are F1-02's and were re-run unchanged against the F1-03 and F1-04
code; the camera sections are F1-03's; the targeting section at the bottom is F1-04's.

## Automated

```powershell
tools/test.ps1
```

F1-04: 93 passed, 0 failed — the 69 below plus 14 in
`tests/unit/player/test_target_selector.gd` and 10 in
`tests/scene/test_targeting_contract.gd`. Mutation checks for those are listed in
[engineering/player-flight.md](../engineering/player-flight.md) "Invariants and tests".

F1-03: 69 passed, 0 failed. Eleven of them are `tests/scene/test_player_ship_contract.gd` (body
wiring, exports, the loud failure on a missing reference, banking against the combat
volumes, `reset_to`, `set_controls_enabled`, `focus_changed`, the injected Flight Volume,
and the camera-yaw round trip) and eleven the new
`tests/scene/test_camera_rig_contract.gd` (rest pose, published yaw, orbit, inverted
vertical axis, lock framing, release, the level horizon in every state, position-without-
rotation following, obstruction, and the loud failure on a missing camera). Two
`ERROR: ... required export ... is not set` lines in the output belong to the two tests
that provoke them.

Two mutations were used to check that the new assertions bite:

| Mutation | Caught by |
| --- | --- |
| `PlayerController._camera_yaw()` returns `0.0` — the silent failure the F1-03 ticket describes | `test_forward_input_follows_the_camera_yaw_instead_of_the_world_axis`, and nothing else (10 of 11 ship tests still passed) |
| the obstruction ray runs on mask 0, so it never hits | `test_scenery_between_the_ship_and_the_camera_shortens_the_rig`, with 9.08 against the expected 3.63 |

The clamp assertion was checked by mutation: commenting out
`global_position = _model.clamp_position(global_position)` fails
`test_the_injected_flight_volume_clamps_the_ship_and_reports_the_edge` with
`expected 1.0 ... got 50.0`.

## Measured flight

```powershell
tools/godot.ps1 --path . --script res://tools/validate_player_flight.gd
```

The utility drives the harness with simulated input actions, measures 30 physics ticks
(0.5 s) of travel per case from a fixed start, and writes the screenshots below. It
exits non-zero on any miss; this run printed `FLIGHT_OK`.

| Case | Measured | Expected | Source of the expectation |
| --- | --- | --- | --- |
| `move_forward` | travel (0, 0, -6.000), speed 12.000 | 12.0 along -Z | GUIDE 13 `base_speed`, nose at -Z |
| `move_back` | travel (0, 0, +6.000), speed 12.000 | 12.0 along +Z | same |
| `move_right` | travel (+6.000, 0, 0), speed 12.000 | 12.0 along +X | same |
| `move_left` | travel (-6.000, 0, 0), speed 12.000 | 12.0 along -X | same |
| `ascend` | travel (0, +6.000, 0), speed 12.000 | 12.0 along +Y, world-vertical | PLANEJAMENTO 3 |
| `descend` | travel (0, -6.000, 0), speed 12.000 | 12.0 along -Y | PLANEJAMENTO 3 |
| three-axis diagonal | travel (3.000, 4.243, -3.000), speed 12.000 | speed 12.0, every pressed axis moving | ENGINEERING_BRIEF 4.B; unbounded would have travelled 10.392 units instead of 6.0 |
| focus diagonal | travel (1.350, 1.909, -1.350), speed 5.400 | 12.0 × 0.45 | PLANEJAMENTO 4 |
| platform stop | y 0.400 | body half-height above the y 0 surface | arena floor cylinder, `BodyShape` 2 × 0.8 × 2.1 |
| Flight Volume floor | y 0.000, readout edge 1.00 | the clamp, past the platform rim | GUIDE 13 FlightBounds min y 0 |
| west wall stop | x -38.000, readout edge 0.75 | one body half-width inside the x -39 wall face; 1 - 1/4 of `edge_margin` | arena `BoundaryShape`, `edge_margin` 4.0 |
| bank strafing right | -0.428 rad (-24.5°) | -0.436 rad after 0.5 s of eased roll toward the 25° maximum | `max_bank_angle_degrees`, `bank_smoothing` 8.0 |

Resting positions are exact and stable, so `move_and_slide` plus the position clamp do
not fight each other at a surface. The `speed` line of the readout is the commanded
velocity: floating mode leaves `velocity` alone when a slide is blocked, which is why a
ship parked on the platform still reads 12.00.

## Measured camera — F1-03

Same command, same run: the utility drives the `camera_*`, `lock_target` and
`next_target` actions and measures the rig. Every case also reads the rendered camera's
roll, which is the invariant that must not move. The numbers below are reproducible: two
consecutive runs printed the same values.

| Case | Measured | Expected | Source of the expectation |
| --- | --- | --- | --- |
| camera rest offset | (0.033, 4.490, 7.895) | (0, 4.490, 7.895) | GUIDE 13 camera (0, 3.2, 8.5) rotated by the -9° rest pitch; the 0.033 is the tail of the ease after the ship was teleported |
| camera rest pitch | -9.000° | -9.0° | `default_pitch_degrees`, the export form of GUIDE 13's -0.16 rad |
| camera rest roll | 0.000° | 0 | PLANEJAMENTO 3 "stable horizon" |
| orbit yaw, `camera_right` held 30 ticks | -60.000° | -60° | `orbit_speed_degrees` 120 × 0.5 s, negative because looking right is a negative rotation around world Y |
| orbit pitch, `camera_up` held 15 ticks | +30.000° | +30° | the same rate on the vertical axis; `camera_up` raises the view |
| orbit roll | 0.000° | 0 | turning the view may not tilt it |
| orbit returns | yaw 0.000°, pitch -9.000° | the rest pose | opposite actions held for the same ticks undo each other exactly |
| pitch ceiling / floor | +35.000° / -60.000° | `pitch_limits_degrees` | held far past the limit; the clamp is what stops it, and the roll stays 0 at both ends |
| quarter turn | 90.000° | 120°/s × 45 ticks | `camera_left` |
| camera-relative forward | travel (-6.000, 0, 0), speed 12.000 | -X, because the camera now faces -X | PLANEJAMENTO 3 "horizontal movement is camera-relative". World -Z would be the failure |
| lock Low / Middle / High, aim | 0.017° / 0.007° / 0.007° off the ship-to-target line | 0 | PLANEJAMENTO 3 "frame the player and target" |
| lock Low / Middle / High, framing | ship and target both inside the 68° vertical FOV, roll 0.000° | both in view | the three arena targets are at y 5, 9 and 15 (GUIDE 13), which is the "different heights" the brief asks for |
| release | heading held to -0.001° | unchanged | PLANEJAMENTO 3 "return smoothly to follow mode": the rig lets go where it was, it does not snap behind the ship |
| camera distance against the west wall | 0.753 | 0.753 | the ship parked at x -38, camera turned into the x -39 wall: hit distance minus `obstruction_margin` 0.4 |
| camera stays inside the wall | x ≥ -39 | inside | the shortening must not put the view outside the arena |
| shrine gate pass | shortest distance 3.533 of 9.08, roll 0.000° through the whole pass | shortens | the beam at y 10.5, z -27 crosses the camera line once the ship is a few units past it |
| shrine gate, largest single-frame change | 6.522 | — | reported, not asserted. This is the snap into an obstruction: the rig shortens immediately by design, because easing in would put the camera inside the beam. Easing back out is smooth |

- [Orbited to yaw -60, pitch +21](player-flight-camera-orbit.png) — roll 0.00, horizon level, distance 8.94 of 9.1.
- [Locked on the High target](player-flight-camera-lock.png) — `lock High` on the readout, ship and target both framed, roll 0.00.
- [Turned into the west wall](player-flight-camera-obstruction.png) — yaw -90, distance 0.75 of 9.1, the hull filling the frame; the extreme end of the obstruction rule, recorded as an open issue.
- [Past the shrine gate](player-flight-camera-gate.png) — parked at z -31 with the beam between ship and camera: distance 3.53 of 9.1, yaw 0, horizon still level.

## Measured targeting — F1-04

Same command. Since F1-04 `lock_target` and `next_target` go through the ship's real
`Targeting` adapter, and the lock reaches the rig through the ship's own connection; the
harness's F1-03 stand-in is gone, so the three `lock Low / Middle / High` camera rows above
were re-measured through real selection in this run (aim 0.010° / 0.000° / 0.005°, both
ends in view, roll 0.000°). The ticket's manual checks are the rows below, flown with
simulated actions. Two runs: one headless, one in a real window that also wrote the
screenshots; both printed `FLIGHT_OK`, and every targeting number below matched between them
to the digits shown except where noted.

| Case | Measured | Expected | Source of the expectation |
| --- | --- | --- | --- |
| lock from the open-air start | Middle | Middle | Worked by hand from GUIDE 13's positions and the rest camera: Middle is 0.13 from the screen center in the core's normalized units, Low 0.24, High 0.42. PLANEJAMENTO 3 "near the screen center" |
| cycle | Middle → High → Low, then back to Middle | all three once, then wrap | left to right on screen, with the camera turning to frame each new lock in between (60 ticks per step) |
| each lock reaches the rig and the readout | Middle, High, Low | the locked name | the readout's `lock <name> at <d> of 60.0` line |
| release | readout `lock none`, heading held to -0.001° | released, no snap | PLANEJAMENTO 3 "return smoothly to follow mode" |
| fly out of range | released at 60.047; last tick still held at 59.980 | 60.0 ± one tick of travel (0.25) | `max_distance` 60. Flown with `move_back` + `move_right` + `ascend` while locked on Middle, which the camera-relative controls turn into flying away; released with the ship at (21.97, 29.60, 31.95), near the far corner |
| lock behind scenery | held on Middle; Middle's candidate `visible` false | held | PLANEJAMENTO 3 "stable until explicitly switched, released, or invalidated by target death/range"; ENGINEERING_BRIEF 4.B "scenery occlusion". Ship at (0, 6.5, -31), past the shrine gate: the lock turns the camera back through the gate, to (-0.06, 12.53, -37.79) at -21.1° pitch, and its line to Middle hits `BeamBody` at y 10.55 on the beam's z -27.8 face |
| fresh lock from behind the gate | High (windowed), nothing (headless) | anything but Middle | a hidden target cannot be freshly locked. Low is behind the beam too; High clears it, and sits close enough to the 0.85 radius that the few hundredths of camera difference between the two runs decide whether it qualifies |

The arena's trees have no collision — they are meshes in `Environment/Backdrop` — so the
ticket's "put a tree between camera and target" cannot hide anything in this scene: the
occlusion ray only sees layer 1 bodies. The shrine gate's beam is the only collidable
scenery that can come between the camera and a target, which is why the case uses it.

- [Locked on Middle behind the shrine gate](player-flight-targeting-occluded.png) — readout
  `lock Middle at 11.3 of 60.0`, the orb hidden behind the beam while its ring still shows
  above and below it: occlusion is one ray to the center, recorded as an open issue.
- [Locked on High](player-flight-camera-lock.png) — re-captured through real selection;
  readout `lock High at 32.7 of 60.0`.

The first windowed attempt of this session hung in the first screenshot readback
(`player-flight-floor.png`, before any targeting code ran) with the window "Not Responding";
it was killed after five minutes. The headless run and the second windowed run went
through. The flight and camera screenshots that run rewrote were restored to the committed
F1-02/F1-03 captures, since nothing in them changed.

## The harness as the running game

```powershell
tools/godot.ps1 --path . res://scenes/dev/arena_harness.tscn --quit-after 240
```

Four seconds windowed, no errors and no warnings, re-run on the F1-04 code: the harness
resolves the ship, its rig and its targeting, reads the `FlightBounds` metadata
(`min_corner` (-39, 0, -45), `max_corner` (39, 30, 33)), and hands the Flight Volume to the
controller. A missing metadata key would have printed the documented warning and left the
ship on collision alone. Since F1-04 the harness no longer collects targets itself: the
ship's `Targeting` finds the `targetable` group on its own, and an arena without targets
simply has nothing to lock.

- [Parked on the platform](player-flight-floor.png) — y 0.400, level, readout edge 0.90.
- [Held by the clamp past the rim](player-flight-clamp.png) — y 0.000 over open void at (30, 0, 25), readout edge 1.00.
- [Against the west wall](player-flight-edge.png) — x -38.0, readout edge 0.75.
- [Banked into a right strafe](player-flight-bank.png) — right wing down, nose still at -Z, the core and muzzle unmoved.

## Not verified

- **No physical input device was pressed, in F1-02, F1-03 or F1-04.** Every case above was
  driven with `Input.action_press`, which ENGINEERING_BRIEF Section 8 explicitly says
  does not replace a real device. What was actually pressed in this session: nothing —
  the sessions that produced this page ran the utility and the test suite from the
  command line, and no key or button was touched by a human. The keyboard and Xbox
  bindings themselves (WASD, Space, left Ctrl, left Shift, arrow keys, K, Tab, left
  stick, right stick, RB, LB, LT) are checked as data by
  `tests/unit/project/test_input_map.gd`.
- **The pad exists.** The F1-03 run printed
  `joypads connected: 0:DualSense Wireless Controller (standard mapping: true)`, so this
  host does have a controller and Godot has a standard mapping for it, which is what
  makes the Xbox-named bindings land on the right buttons. That is a device inventory,
  not a device test. Both F1-04 runs printed `no joypad connected on this host`: the pad
  was not plugged in this time. The human pass still owed is: fly the six movement axes
  and Focus on the keyboard and on that pad, orbit with the arrow keys and with the right
  stick, lock and release with `K` and with `Y`, switch through the three targets with
  `Tab` and with `X`, fly out of range until the readout drops the lock, park behind the
  shrine gate with a lock held, and say whether the camera and the switch order read well
  in motion.
- Target Lock feel — whether 60 units of range and the 0.85 acquisition radius read well,
  and whether switching left to right, wrapping to the far left, is what a player expects
  from `Tab` / `X` — is Astra's and the user's judgement, not a measurement.
- Feel judgements — whether 12.0 units per second, a 25° bank, a 4-unit edge margin,
  120°/s of orbit, the -60 to +35 pitch range and the three damping rates read well in
  motion — are Astra's, not measurements.
- The obstruction snap under the shrine gate (6.5 units in one frame) is measured but not
  judged: whether it reads as a pop in motion needs eyes, and the remedies are in the
  engineering page's open issues.
