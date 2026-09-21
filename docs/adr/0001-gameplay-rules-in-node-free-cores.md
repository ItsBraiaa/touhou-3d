---
status: accepted
date: 2026-09-20
---

# Gameplay rules live in Node-free Rules Cores; scene scripts are Adapters

The brief lists invariants (shield before health, hit before graze, once-per-projectile graze, idempotent encounter completion, deep snapshots) that must be tested without a running scene, and scene wiring is owned by another agent and arrives late. We keep every gameplay rule in plain `RefCounted` classes with an explicit `tick(delta)` and no Node, SceneTree, or physics dependency (combat state, projectile field, encounter machine, snapshot, settings). The scripts registered in GUIDE.md are thin Adapters that read input and scene state, drive a Rules Core, and render its result. Tests construct cores directly with fixed seeds and never instance a `.tscn`.

## Consequences

- Cores communicate outward through signals only; Adapters call cores directly. Cores never hold a Node reference.
- A behavior that needs engine services (raycasts, audio, animation) is requested by the core through a signal or a returned value and performed by the Adapter.
- Scene-instancing tests exist only as smoke tests of the scene contract, not of gameplay rules.
