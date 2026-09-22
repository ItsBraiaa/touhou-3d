# Player flight validation — 2026-09-22 (F1-02)

Engine: Godot 4.7.2.stable.official.ed1daf0bf, Windows 11, D3D12 Forward+ on an AMD
Radeon RX 9070 XT. Scene under test: `scenes/dev/arena_harness.tscn`, which instances
Astra's `scenes/tests/combat_arena.tscn` and adds a debug readout.

## Automated

```powershell
tools/test.ps1
```

57 passed, 0 failed. Ten of them are the new `tests/scene/test_player_ship_contract.gd`
(body wiring, exports, the loud failure on a missing reference, banking against the
combat volumes, `reset_to`, `set_controls_enabled`, `focus_changed`, and the injected
Flight Volume). One `ERROR: ... required export 'visual_root' is not set` line in the
output belongs to the test that provokes it.

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

## The harness as the running game

```powershell
tools/godot.ps1 --path . res://scenes/dev/arena_harness.tscn --quit-after 240
```

Four seconds windowed, no errors and no warnings: the harness resolves the ship, reads
the `FlightBounds` metadata (`min_corner` (-39, 0, -45), `max_corner` (39, 30, 33)), and
hands the Flight Volume to the controller. A missing metadata key would have printed the
documented warning and left the ship on collision alone.

- [Parked on the platform](player-flight-floor.png) — y 0.400, level, readout edge 0.90.
- [Held by the clamp past the rim](player-flight-clamp.png) — y 0.000 over open void at (30, 0, 25), readout edge 1.00.
- [Against the west wall](player-flight-edge.png) — x -38.0, readout edge 0.75.
- [Banked into a right strafe](player-flight-bank.png) — right wing down, nose still at -Z, the core and muzzle unmoved.

## Not verified

- **No physical input device was pressed.** Every case above was driven with
  `Input.action_press`, which ENGINEERING_BRIEF Section 8 explicitly says does not
  replace a real device. The keyboard and Xbox bindings themselves (WASD, Space, left
  Ctrl, left Shift, left stick, RB, LB, LT) are checked as data by
  `tests/unit/project/test_input_map.gd`. A human pass on keyboard and on a physical
  controller is still owed, and is the one remaining manual item of F1-02.
- Camera behavior: the rig is still Astra's static camera, so every case above was flown
  with a camera yaw of 0. Camera-relative movement is proven only in the core's unit
  tests until F1-03 turns the rig.
- Feel judgements — whether 12.0 units per second, a 25° bank and a 4-unit edge margin
  read well in motion — are Astra's, not measurements.
