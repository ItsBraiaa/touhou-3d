# D-04 Stage 2 boss scenes

Status: done
Type: design
Owner: Astra (GPT Sol)
Lane: sol
Model: GPT Sol (Codex)
Depends on: none

## Goal

This ticket builds two boss prefabs with the GUIDE Section 5 tree:

- **`scenes/enemies/tempest_sentinel.tscn`.** The Stage 2 miniboss reuses the Sentry look at a larger scale, with a distinct darker body, bright storm-energy accents and rotating ornaments. STAGE_DESIGN "Miniboss" and MODEL_SELECTION both call for this reuse: "one additional encounter, not a third fully animated final-boss asset".
- **`scenes/enemies/storm_guardian.tscn`.** The final boss uses the approved `Dragon_Evolved.gltf`, with blue and violet storm accents and a strong arrival silhouette.

Like D-03, both scenes carry no script and no gameplay value. F12-06 and F12-07 attach `boss_controller.gd` and set its exports.

## Read first

- `docs/GUIDE.md` Sections 3, 4 and 5 "Enemy and boss prefabs": "The miniboss reuses the Sentry appearance with enlarged scale and rotating ornaments".
- `docs/MODEL_SELECTION.md`: the approved cast table (Stage 2 rows), the verified clip names, and "Larger boss wings must not hide important projectiles near the player".
- `docs/ENEMY_VISUAL_HANDOFF.md`: the Sentry variants (`sentry_lantern.tscn`, `sentry_seal.tscn`, Goleling, `MagicRing1..2`), and D-03's "Boss prefabs" section once it has landed.
- `docs/STAGE_DESIGN.md` Stage 2 "Miniboss" and "Final boss sequence". `docs/STAGE_02_HANDOFF.md` gives the markers: `S2-04/Spawns/Wave1_Boss1` at (0, 76, -408), and `S2-07/Spawns/Wave1_Boss1` at (0, 113, -690) above the summit platform at Y 85.
- `.scratch/design-sprint/issues/03-lantern-guardian-scene.md`: the same contract, and `tools/validate_boss_scenes.gd`.

## Files

- **Creates:**
  - `scenes/enemies/tempest_sentinel.tscn`. Optionally `scenes/enemies/visuals/sentry_tempest.tscn` as its `VisualRoot`, authored directly and never through `tools/build_enemy_visuals.gd`.
  - `scenes/enemies/storm_guardian.tscn`.
  - `assets/models/bosses/Dragon_Evolved.gltf`, with its texture copy and `.import` files. The Sentinel reuses `assets/models/enemies/Goleling.gltf`.
  - `docs/validation/tempest-sentinel.png` and `docs/validation/storm-guardian.png`.
- **Edits:**
  - `tools/validate_boss_scenes.gd`: extend D-03's tool to both scenes. Create it if D-03 has not landed.
  - `docs/validation/boss-scenes.log`.
  - `docs/ENEMY_VISUAL_HANDOFF.md`: "Boss prefabs".
  - `docs/ASSET_CREDITS.md`: the `Dragon_Evolved.gltf` line.
  - `docs/engineering/ROADMAP.md`: the D-04 row and one "Received from Astra" row.
  - `docs/HANDOFF_LOG.md`.
- **Must not touch:**
  - `scripts/**`, `tests/**`, `content/**` and `scenes/dev/**`.
  - `scenes/stages/*.tscn`. Only F12-05 attaches scripts to `stage_02.tscn`, and F12-06 and F12-07 set its exports.
  - The four existing `scenes/enemies/visuals/*.tscn` and `tools/build_enemy_visuals.gd`, which must never be rerun.
  - `scenes/enemies/lantern_guardian.tscn` (D-03), and the `All models/` originals.

## Deliverable contract

Both scenes use D-03's table exactly: an `Enemy` root with an identity transform and no script; `VisualRoot/Model`; `HitVolume` on layer 16, mask 0, monitoring and monitorable off, with a `Collision` `SphereShape3D` whose radius is the gameplay hit radius; and `Emitters/Main`. `HitVolume` and `Emitters` stay outside the scaled model. The consumers read the scenes through `BossController`'s exports (F12-02).

**Tempest Sentinel**, consumed by F12-06:

- `VisualRoot` is the Goleling Sentry, enlarged well past the common Sentry's pose height of 1.6 to 2.0. The exact scale is Astra's.
- It gets a darker body with bright storm accents, distinct from both Sentry variants.
- Ornaments go at `VisualRoot/Ornaments/Ring1..N` (`MeshInstance3D`, no collision). They turn continuously through `VisualRoot/OrnamentPlayer`, an `AnimationPlayer` of their own with one looping autoplay clip whose name is reported, or through a shader. The code never drives it, so a step or defeat clip on the model's player cannot stop the spin.
- The `HitVolume` radius fits the enlarged core, not the rings.

**Storm Guardian**, consumed by F12-07:

- `VisualRoot/Model` is `Dragon_Evolved`, scaled for the summit arena.
- Its blue and violet accents stay clear of the hostile-projectile colors (D-02), so bullets stay readable against the boss.
- Its wings never cover the space around the player at the approach distance.

**Clips, for each scene.** Report the `AnimationPlayer` path and the actual names for idle (`Flying_Idle` candidate, looping), step cue (inspect first; it must read as a cast or charge, or "none"), Phase change (name it; there is no export yet, so it is recorded for a later `phase_clip`) and defeat (`Death` candidate, not looping). All eight names from MODEL_SELECTION exist in both models, but choose by motion, not by name.

No health, pattern or Phase count lives in either scene. Two and three Phases are content (F12-06, F12-07).

## Acceptance

- `tools/test.ps1` green with no `SCRIPT ERROR`.
- `tools/validate_boss_scenes.gd` runs headless and writes zero failures for all three boss scenes to `docs/validation/boss-scenes.log`. It checks:
  - the D-03 table checks for both new scenes;
  - that the Sentinel's ornament clip loops and autoplays on its own player;
  - that no collision object sits under either `VisualRoot`.
- Two renders from about the player's approach distance against the Stage 2 palette: `tempest-sentinel.png`, where the silhouette reads as a Sentry but larger and stormier, and `storm-guardian.png`. Both are inspected, and the result is recorded in the log entry.

## Handoff to Claude

One `docs/HANDOFF_LOG.md` entry, `— Astra (sol) — Stage 2 boss scenes (D-04)`, State `SCENE_READY`. For each scene it lists the file, the tree, the `AnimationPlayer` path, the four clip names, the `HitVolume` radius and center, and the scale. It also names the Sentinel's ornament clip and says "root has no script".

| Consumer (lane) | Claude-side change |
| --- | --- |
| F12-06 (sol) | Attach `boss_controller.gd` to `tempest_sentinel.tscn` and set its exports. Point `stage_02.tscn`'s `actor_scenes[&"tempest_sentinel"]` at it. |
| F12-07 (sol) | The same for `storm_guardian.tscn` and `actor_scenes[&"storm_guardian"]`. |

## Outcome

Both scenes and the Dragon_Evolved runtime copy are delivered. `tools/validate_boss_scenes.gd` checked all three boss prefabs with `BOSS_SCENES_QA failures=0` in headless and windowed runs; the existing test suite and main-scene boot passed through `tools/lane.ps1 land`. The S2-04 and S2-07 approach screenshots were inspected against the Stage 2 palette. Exact tree paths, clip choices, sphere dimensions, emitter positions and the independent Sentinel ornament clip are recorded in `docs/ENEMY_VISUAL_HANDOFF.md` and the handoff log. Controller attachment and exported values remain F12-06/F12-07 integration work.

## Kickoff prompt

```
Read AGENTS.md, docs/engineering/SPRINT.md (lane sol), docs/GUIDE.md Sections 3 and 5 and .scratch/design-sprint/issues/04-stage-2-boss-scenes.md, then deliver it in your worktree, log it in docs/HANDOFF_LOG.md, commit, and run tools/lane.ps1 land.
```
