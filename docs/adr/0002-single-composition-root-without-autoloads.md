---
status: accepted
date: 2026-09-20
---

# One composition root (`scenes/main.tscn`), no autoloads

Menus, HUD, the loaded stage, the projectile field, and audio all need the same run state, and the obvious Godot answer is a set of autoload singletons plus `change_scene_to_file`. We instead make `scenes/main.tscn` the project main scene, with `Main` (game session), `WorldRoot`, `ProjectileRoot`, `Interface`, and `Audio` as children. Every menu is instanced under `Interface` and shown or hidden, and collaborators are passed downward through `@export` references and `setup()` calls. The autoload list stays empty so every dependency is visible in the scene tree and in tests, pause is a single `get_tree().paused` toggle, and Retry never crosses a scene switch.

## Considered options

- Autoload `Session` with separately switched menu scenes: simpler menu files, but hidden global state and a re-wiring problem after every scene change.
- Several autoloads (session, settings, audio, event bus): the usual Godot pattern; rejected because it hides ownership and makes the invariants in ADR-0001 harder to isolate.
