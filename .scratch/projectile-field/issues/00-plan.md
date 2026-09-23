# F5-00 Plan the Projectile Field feature

Status: done (2026-09-23)
Type: docs
parallel-safe: no
Depends on: F4-01

## Goal

Write `.scratch/projectile-field/spec.md` and the full tickets for F5. All four are Rules Core tickets and can be marked `parallel-safe` where their files are disjoint.

## Planned tickets

1. `01-field-core-spawn-move-cull`: `ProjectileField` with packed arrays (position, velocity, owner, lifetime, radius, graze flag, alive), `spawn(request) -> int`, `tick(delta)`, culling on lifetime and Flight Volume exit, obstacle query `Callable` injected at setup (scenery and closed Gates, ADR-0004), stable ids, capacity limit with a documented policy when full.
2. `02-core-hit-sweep-and-graze-rules`: sphere-versus-segment sweep against the player Core each tick; hit before graze on the same contact; graze once per Projectile; no graze during Invulnerability; results reported as signals `player_hit(id)`, `grazed(id)`.
3. `03-bomb-phase-clears-and-hit-spheres`: `clear_hostile_in_radius(center, radius)` and `clear_hostile_all()` award nothing; owner filtering; enemies register hit spheres per tick, player-owned Projectiles report `enemy_hit(enemy_id, projectile_id)`.
4. `04-pattern-emitter-core`: `PatternEmitter` turning a `PatternDefinition` (ring, fan, spiral, burst, aimed with sampled position) into spawn requests over time with the injected RNG; Anticipation delay handled by the caller.

## Read first when planning

- `docs/adr/0004-central-projectile-field.md` (including the scenery section)
- `docs/ENGINEERING_BRIEF.md` Section 4.D and Section 8
- `docs/PLANEJAMENTO.md` Section 4 "Graze and score", "Spiritual bomb", Section 10 "Patterns share configurable ring, fan, spiral, and burst emitters"
- `docs/STAGE_DESIGN.md` boss attack descriptions (what the patterns must express)
- `CONTEXT.md` Combat terms

## Definition of Done

- `spec.md` and four ticket files; roadmap rows replaced; commit `plan: write F5 projectile field tickets`.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/projectile-field/issues/00-plan.md, then write the F5 spec and tickets as described. Finish with its Definition of Done and commit.
```

## Outcome (2026-09-23)

Tickets written in the one-pass planning session for F4 to F14 (commit `plan: write F4-F14 tickets`): `.scratch/projectile-field/spec.md`, `01-field-core-spawn-move-cull.md`, `02-core-hit-sweep-and-graze-rules.md`, `03-bomb-phase-clears-and-hit-spheres.md` and `04-pattern-emitter-core.md`, all Rules Cores and all `parallel-safe: yes`. 01 → 02 → 03 share `projectile_field.gd` and are serialized by Depends on; 04 needs only 01.

Deviations from the planned list:

- The owner array became a faction (`ProjectileSpawn.Faction { PLAYER, HOSTILE }`). The graze flag moved from 01 to 02, where its rules live.
- The full-field policy is to refuse the new request (`spawn` returns -1, `get_refused_count()` counts it) and never evict. Ids are never reused.
- Events are emitted after the tick's pass. `clear_all()` from a listener drops the tick's remaining events.
- The obstacle check comes before the Core sweep. In 02 the first `player_hit` of a tick makes the rest of the tick invulnerable. Invulnerable contact marks a Projectile graze-spent (the strict reading).
- `player_hit` also carries `damage`, `enemy_hit` carries `damage`, and 03 adds `targets_in_radius` for the Bomb. 02 adds `clear_player()`.
- `PatternDefinition` is owned by 04 (not F8-01), with its fields finalized there. AIMED samples the aim point once per run.
