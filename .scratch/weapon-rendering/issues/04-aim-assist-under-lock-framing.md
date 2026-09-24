# F6-04 Aim Assist under lock framing

Status: done
Type: adapter
parallel-safe: no
Depends on: F6-03, F9-02
Lane: path
Model: Claude Opus 5.5, solo

## Goal

With a Target Lock on an enemy 10 to 16 units away, locked shots stop hitting as soon as the camera's lock framing blends in. Path found this in F9-02's arena run (`docs/validation/enemies.md`, "Finding for another lane").

**Why it happens.** `PlayerWeapon._fire` builds "forward" toward the view's center ray at the target's depth, then applies the Aim Assist cone (10° for the main shot) from the shot's origin. `CameraRig`'s lock framing deliberately puts the locked target off the view center: pitch about −17°, the target about 75 px above the center. At close range that offset, seen from the Muzzle, is larger than 10°, so `assist_direction` gives up and the shots pass about 3.5 units from the Spirit. At about 30 units the offset is small enough and the lock kills the Spirit in 2.35 s.

PLANEJAMENTO Section 4 asks for Aim Assist toward the Target Lock, so a locked target in view must be hit at any range the lock allows (Targeting `max_distance` 60). Shots still fly straight, and the Projectile Field still stops them on scenery and closed Gates.

## Read first

- `scripts/combat/player_weapon.gd` (`_fire` and its doc comment), `scripts/combat/weapon_model.gd` (`assist_direction`, the tuning cones)
- `scripts/player/camera_rig.gd` (lock framing: `set_lock_target`, `lock_blend_speed`), `scripts/player/targeting.gd` (`max_distance`, `max_screen_radius`)
- `docs/validation/enemies.md` (the measurement and how it was taken), `docs/engineering/weapon-rendering.md` ("WeaponModel", "PlayerWeapon")
- `docs/PLANEJAMENTO.md` Section 4 "Shots, power, and familiars"

## Files

- **Edits:**
  - `scripts/combat/player_weapon.gd`: the fire path only.
  - `scripts/combat/weapon_model.gd`: only if the assist helper's signature must change.
  - `docs/validation/enemies.md`: re-measure, and mark the finding resolved.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md` (the F6-04 row);
  - `docs/HANDOFF_LOG.md`;
  - `docs/engineering/weapon-rendering.md` ("Aim Assist under a lock");
  - the `docs/GUIDE.md` Section 6 row `player_weapon.gd`, if an export changes.
- **Must not touch:**
  - `scripts/player/camera_rig.gd`: the lock framing is design-approved (F1-03, F1-05).
  - `scripts/player/targeting.gd`.
  - Every trunk-only file (SPRINT.md "Lanes"), including `scenes/player/player_ship.tscn`. A new export keeps its default in code; any value change is a handoff note for trunk.
- **Conflicts with:**
  - trunk F13-03, which later adds `shots_fired(count)` to `player_weapon.gd`. This ticket lands long before it. Keep the fire path in one function, as F6-03 asked.

## Deliverables

- **Locked shots:** measure the Aim Assist against the lock, not against the framed view center. Two acceptable designs; pick one and document it:
  1. With a valid Target Lock, compute the cone from the eye: compare the target's direction from the camera with the view direction, using a lock cone wide enough to cover lock framing (a new export `lock_assist_degrees`, Claude's proposal 25°, Astra tunes). Inside it, aim the shot from its origin straight at the target.
  2. With a valid Target Lock inside Targeting's range, aim every main shot from its origin straight at the target's `HitVolume` center. The lock itself is the assist; the Familiars keep their level cones.
- **Unlocked shots** behave exactly as before, with the 10° cone around the view center.
- **Familiars:** their Power Level cones apply to the lock in the same way, or keep today's behavior. Document which.
- **Unchanged:** obstacles along the travel are still enforced by the Projectile Field; nothing here bypasses it.

## Verification (no tests: SPRINT.md "No new tests")

- `tools/lane.ps1 land` passes: the existing suite and the boot smoke.
- **Re-run the F9-02 measurement** in the arena harness, windowed, with a Spirit locked at about 10, 16, 30 and 50 units, `fire` held, and the lock framing fully blended. Record hits per second and the time to defeat at each distance in `docs/validation/enemies.md`, and mark the finding resolved. The target: locked shots hit at every distance, and the kill time at 10 to 16 units is no worse than at 30.
- **Check unlocked fire** at the same distances: still the 10° cone.

## Out of scope

Camera lock framing, Targeting selection, weapon values beyond the one new export, and Familiar visuals.

## Definition of Done

`tools/lane.ps1 land` passes; the measurement is recorded; the module doc has an "Aim Assist under a lock" section; the handoff entry is written; the ticket is `Status: done` with an Outcome; the ROADMAP row is updated. One commit: `combat: aim assist follows the Target Lock under lock framing`.

## Handoff notes for Astra

If `lock_assist_degrees` is added, it is yours to tune (D-05 or D-07 Part C): report the value to trunk, who sets it in `player_ship.tscn` during F14-01's swap step.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/SPRINT.md and .scratch/weapon-rendering/issues/04-aim-assist-under-lock-framing.md, then implement that ticket solo in lane path with no tests. Verify it by re-running the arena measurement windowed. Finish with its Definition of Done, commit, and run tools/lane.ps1 land.
```

## Outcome (2026-09-23)

Delivered solo in lane path with **design 1**: under a Target Lock, `PlayerWeapon._fire` measures the lock's angle from the camera (view direction against the direction to the lock's `HitVolume`) once per tick. Each shot compares it with its own cone widened by `lock_assist_degrees − main_assist_degrees`; inside it, the shot flies from its origin straight at the target, otherwise along forward as before. New export `lock_assist_degrees` = 25.0 (a code default; `player_ship.tscn` untouched). **No tests** (sprint rule); the land gate and the windowed measurement are the checks.

- **Why design 1 and not design 2:** PLANEJAMENTO asks for Aim Assist on "visible targets near the screen center", and `CameraRig` lets the player orbit the view away from a lock. Design 2 would make the lock auto-aim even then.
- **Familiars:** their level cones widen by the same 15°, to 25° at Power Level 2 and 35° at Power Level 3, so they keep their stronger tracking under a lock.
- **Unlocked fire:** unchanged, and there is still no assist without a lock (the ticket's "10° cone around the view center" never existed for unlocked shots: the assist target was always the lock).
- **Measured, windowed** (`docs/validation/enemies.md`): locked Spirit at 10 / 16 / 30 / 50 units, defeated in 2.02 / 2.12 / 2.35 / 2.68 s, where 10 and 16 units never fell before. Power Level 3: 0.93 to 1.58 s. Unlocked: 0 hits at every distance, as before.
- **Left in place:** `WeaponModel.assist_direction` is no longer called by the weapon; `weapon_model.gd` was not edited (its signature did not need to change). A later cleanup can remove it with the core's owner.
- `CameraRig` and `Targeting` untouched.
