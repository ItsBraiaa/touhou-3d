# D-03 Lantern Guardian scene

Status: todo
Type: design
Owner: Astra (GPT Sol)
Lane: sol
Model: GPT Sol (Codex)
Depends on: none

## Goal

`scenes/enemies/lantern_guardian.tscn` is the Stage 1 boss prefab. It uses the GUIDE Section 5 tree and is built from the approved `Ghost.gltf` (MODEL_SELECTION), with warm amber magic and a ring of floating lanterns.

It carries no script and no gameplay value. Script attachment is Claude's (GUIDE Section 3), and this ticket may land before `boss_controller.gd` exists. F12-03 (trunk) later attaches `boss_controller.gd`, sets its exports, and swaps this scene in for `scenes/dev/dev_boss.tscn`.

Astra picks the clips for idle, the step cue, the Phase change and defeat after watching them play, and reports their actual names.

## Read first

- `docs/GUIDE.md` Section 3, Section 4 (placeholder policy), Section 5 "Enemy and boss prefabs".
- `docs/MODEL_SELECTION.md`: "Approved selection", "Boss alternatives and verified animation metadata", "Visual review evidence and next checks".
- `docs/ENEMY_VISUAL_HANDOFF.md`, the pattern to follow:
  - runtime copies go under `assets/models/`;
  - `HitVolume` and `Emitters` sit outside the scaled `Model`;
  - the clips live in `Model/AnimationPlayer`.
- `docs/STAGE_DESIGN.md` Stage 1 "Final boss sequence". `docs/STAGE_01_HANDOFF.md`: `Wave1_Boss1` at (0, 43, -520) in the aerial clearing.
- `.scratch/bosses/issues/02-boss-controller-adapter.md`, "Deliverables" and "Handoff notes for Astra": the exports this scene feeds.

## Files

- **Creates:**
  - `scenes/enemies/lantern_guardian.tscn`.
  - `assets/models/bosses/Ghost.gltf`, with its texture copy and `.import` files. The source in `All models/` stays untouched.
  - `tools/validate_boss_scenes.gd`: offline QA in the style of `tools/validate_enemy_visuals.gd`. D-04 extends it.
  - `docs/validation/boss-scenes.log` and `docs/validation/lantern-guardian.png`.
- **Edits:**
  - `docs/ENEMY_VISUAL_HANDOFF.md`: a "Boss prefabs" section.
  - `docs/ASSET_CREDITS.md`: the `Ghost.gltf` line (CC0; the license is already at `assets/licenses/quaternius-ultimate-monsters.txt`).
  - `docs/engineering/ROADMAP.md`: the D-03 row and one "Received from Astra" row.
  - `docs/HANDOFF_LOG.md`.
- **Must not touch:**
  - `scripts/**`, `tests/**`, `content/**`.
  - `scenes/dev/**`: the dev boss stays until F12-03 swaps it.
  - `scenes/stages/*.tscn`: `stage_01.tscn` is trunk-only until F12-03 lands.
  - `scenes/enemies/visuals/*.tscn` and `tools/build_enemy_visuals.gd`. Never rerun the generator.
  - The `All models/` originals.

## Deliverable contract

Consumed by F12-03 through `BossController`'s exports (F12-02). Names are exact.

| Path | Type | Contract |
| --- | --- | --- |
| `Enemy` | `Node3D` root, identity transform | No script. F12-03 attaches `scripts/enemies/boss_controller.gd`. |
| `Enemy/VisualRoot` | `Node3D` | Holds the Ghost instance as `VisualRoot/Model` and the ornaments as `VisualRoot/Lanterns/Lantern1..N` (`MeshInstance3D`). No collision object anywhere below it. |
| `Enemy/HitVolume` | `Area3D` | `collision_layer` 16, `collision_mask` 0, `monitoring` and `monitorable` off. Child `Collision` (`CollisionShape3D`) holds a `SphereShape3D`. **Its radius is the gameplay hit radius** (BossController reads it). Centered on the body. Outside the scaled `Model`. |
| `Enemy/Emitters/Main` | `Marker3D` under a `Node3D` named `Emitters` | The shot origin. Each Attack step adds its `height_offset` to it. Outside the scaled `Model`. |
| The `AnimationPlayer` | The imported `VisualRoot/Model/AnimationPlayer` | Its path relative to `Enemy` goes in the handoff. |

Clips: report the actual name for each of four roles, or "none".

- **Idle** → `idle_clip`. `Flying_Idle` is the candidate. It loops, and autoplay is allowed.
- **Step cue** → `step_clip`. It plays when each Attack step's Anticipation begins, so it must read as a cast. Watch the motion first: `Punch` and `Headbutt` are allowed only if they do not read as contact attacks (MODEL_SELECTION).
- **Phase change.** Name one clip, or none. `BossController` has no export for it today, so it is recorded for a later `phase_clip`.
- **Defeat** → `defeat_clip`. `Death` is the candidate. It must not loop, because `BossController` frees the boss when it finishes.

Scale and look are Astra's choice, under these limits:

- The silhouette reads at arena distance around `Wave1_Boss1`.
- Lanterns and wings never hide projectiles near the player (MODEL_SELECTION).
- Continuous ornament motion goes on an `AnimationPlayer` of its own with a looping autoplay clip, never on the model's player, which the code drives.
- No health, pattern or speed lives in the scene.

## Acceptance

- `tools/test.ps1` green with no `SCRIPT ERROR`.
- `tools/validate_boss_scenes.gd` runs headless and writes zero failures to `docs/validation/boss-scenes.log`. It checks:
  - every path, type and flag in the table above;
  - that no collision object sits under `VisualRoot`;
  - that each named clip exists, plays once and advances;
  - that the defeat clip does not loop.
- A render from about the ship's distance at the S1-07 approach, against the Stage 1 dusk palette, in `docs/validation/lantern-guardian.png`. Inspect it for silhouette, amber magic and readable lanterns.

## Handoff to Claude

One `docs/HANDOFF_LOG.md` entry, `— Astra (sol) — Lantern Guardian scene (D-03)`, State `SCENE_READY`. It lists:

- the file;
- the tree as built;
- the `AnimationPlayer` path;
- the four clip names;
- the `HitVolume` radius and center, and the model scale;
- the statement "root has no script".

Consumer: F12-03 (trunk). It attaches `boss_controller.gd` to `Enemy`, sets `visual_root`, `hit_volume`, `emitter`, `animation_player`, `idle_clip`, `step_clip` and `defeat_clip`, and points `actor_scenes[&"lantern_guardian"]` in `stage_01.tscn` at this scene instead of `scenes/dev/dev_boss.tscn`.

## Kickoff prompt

```
Read AGENTS.md, docs/engineering/SPRINT.md (lane sol), docs/GUIDE.md Sections 3 and 5 and .scratch/design-sprint/issues/03-lantern-guardian-scene.md, then deliver it in your worktree, log it in docs/HANDOFF_LOG.md, commit, and run tools/lane.ps1 land.
```
