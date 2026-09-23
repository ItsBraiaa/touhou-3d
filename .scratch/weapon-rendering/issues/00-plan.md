# F6-00 Plan the Weapon and rendering feature

Status: done (2026-09-23)
Type: docs
parallel-safe: no
Depends on: F5-03

## Goal

Write `.scratch/weapon-rendering/spec.md` and the full tickets for F6.

## Planned tickets

1. `01-rendering-spike` (use `/mattpocock-skills:prototype`): measure `MultiMeshInstance3D` versus a pool of `MeshInstance3D` at 300, 1000, and 3000 Projectiles at 1280 × 720 on this machine; record FPS and frame time in `docs/engineering/spikes/projectile-rendering.md`; recommend one. Throwaway code under `scenes/dev/spikes/`.
2. `02-projectile-system-adapter`: `projectile_system.gd` on `ProjectileRoot`: ticks the field in `_physics_process`, implements the obstacle query with `PhysicsDirectSpaceState3D.intersect_ray` on layer 1, reads Core and Graze Volume radii from the authored shapes, renders with the chosen approach, exposes `spawn`, `clear_*`, and the player-hit and graze signals to the Session; dev bullet visuals under `scenes/dev/`.
3. `03-weapon-model-and-player-weapon`: `WeaponModel` core (cadence, per-Power-Level shot configuration, Familiar shots at Power Level 2 and 3, bomb request edge detection) and `player_weapon.gd` adapter (fire while held, Aim Assist toward the Target Lock with the field enforcing obstacles along travel, Muzzle and FamiliarAnchors, dev Familiar visuals); arena targets get a dev `target_dummy.gd` that registers a hit sphere and flashes on hit.

## Read first when planning

- `docs/adr/0004-central-projectile-field.md`
- `docs/PLANEJAMENTO.md` Section 4 "Shots, power, and familiars"
- `docs/ENGINEERING_BRIEF.md` Sections 4.D "Refinement question", 4.E
- `docs/GUIDE.md` Section 5 "Player" (Muzzle, FamiliarAnchors), Section 6 rows `player_weapon.gd`, `projectile_system.gd`
- `docs/HANDOFF_LOG.md` for any projectile visual presets Astra delivered

## Definition of Done

- `spec.md` and three ticket files; roadmap rows replaced; commit `plan: write F6 weapon and rendering tickets`.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/weapon-rendering/issues/00-plan.md, then write the F6 spec and tickets as described. Finish with its Definition of Done and commit.
```

## Outcome (2026-09-23)

The one-pass F4 to F14 planning session wrote these tickets (commit `plan: write F4-F14 tickets`): `.scratch/weapon-rendering/spec.md`, `01-rendering-spike.md`, `02-projectile-system-adapter.md` and `03-weapon-model-and-player-weapon.md`. None of them is parallel-safe.

Deviations from the planned list:

- 01 depends on F5-01 only, not on F5-03, because it needs just the field's movement. It is time-boxed to 1 h and also measures the cost of one layer-1 `intersect_ray` per Projectile.
- In 02, `GameSession.projectile_root: Node3D` becomes `projectile_system: ProjectileSystem`. `_unload_stage` calls `clear_all()` instead of freeing `ProjectileRoot`'s children. 02 also adds a dev spray to the arena harness.
- In 03, `WeaponModel` has no Bomb edge detection, because `CombatState.update_bomb_input()` (F4-01) owns it. `PlayerWeapon` feeds that method from `_unhandled_input` bomb events and has no `bomb_requested` signal.
- 03 adds a `camera_rig` export to `PlayerWeapon`, a required `weapon` export on `PlayerController` (`set_controls_enabled` cascades to it), and a dependency on F4-02, whose Session `CombatState` it needs.
