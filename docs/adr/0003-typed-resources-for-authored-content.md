---
status: accepted
date: 2026-09-20
---

# Authored content is typed `Resource` Definitions, not JSON

Stage encounters, waves, patterns, boss attacks, and reward bundles are authored by the designer agent and must match STAGE_DESIGN.md exactly. We define one `Resource` subclass per concept (`EncounterDefinition`, `WaveDefinition`, `PatternDefinition`, `AttackDefinition`, and so on) with `@export` fields and a `validate()` method, saved as `.tres` files that the Inspector edits and that tests construct in code. JSON was rejected because it loses Inspector editing, type checking, and resource references (markers, scenes) and would need a parallel loader and validator.
