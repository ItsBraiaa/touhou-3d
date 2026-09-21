---
status: accepted
date: 2026-09-20
---

# One Projectile Field owns all bullet state and collision

Dense bullet patterns must satisfy hit-before-graze, once-per-projectile graze, no graze during invulnerability, bomb and phase cleanup that awards nothing, and fast bullets that cross the Core between frames. Individual `Area3D` bullets make those rules depend on physics callback ordering and cannot be tested headless deterministically. We keep every Projectile (player and enemy) as an entry in one central field with arrays for position, velocity, owner, lifetime, and graze flag; test player-Core hits with sphere-versus-segment sweeps each physics tick; test enemy hits against hit spheres the enemies register; and apply cleanup in one place. Only the rendering side (MultiMeshInstance3D versus pooled MeshInstance3D) is left to a measured spike. The authored `DamageCore` and `GrazeVolume` areas stay as geometry sources with monitoring off.

## Scenery and Gates

Projectiles do collide with scenery and with closed Gate barriers (collision layer 1) and are removed on contact. The field core stays Node-free by receiving an obstacle query (`Callable(from: Vector3, to: Vector3) -> bool`) at setup; the adapter implements it with a physics-server segment query against layer 1, and tests inject a fake. Aim Assist is therefore checked every tick along the shot's travel, not only once at fire time: an assisted shot that meets an obstacle dies there.

## Considered options

- One `Area3D` per bullet with `body_entered` and `area_entered`: idiomatic, but hit ordering, tunneling, and graze uniqueness depend on physics callback order and cannot be unit tested.
- Physics-server queries for every bullet against every target: rejected for player-Core hits (a single sphere, cheaper as pure geometry) and kept only for scenery, where the authored collision is the source of truth.
