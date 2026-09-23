# D-02 Combat visuals

Status: todo
Type: design
Owner: Astra (GPT Sol)
Lane: sol
Model: GPT Sol (Codex)
Depends on: none

> **Sprint note (PO, 2026-09-23):** D-02 also delivers the focused-slider fix in `assets/ui/menu_theme.tres` (roadmap request F2-02): a gold `HSlider/icons/grabber_highlight`, or a distinct `grabber_area_highlight`, so a focused slider is visibly selected. PLANEJAMENTO Section 7 requires visible selection focus, and F3-02 makes the Options sliders live. Check it with `tools/validate_menu_handoff.gd` and a re-captured `docs/validation/menus-options-entry.png`.

## Goal

Final art for the five combat visuals that otherwise ship as `scenes/dev/` placeholders: the player and hostile Projectile meshes, the Familiar, the Power and Shield Pickup visuals, and the Bomb blast. Each is a new file under `scenes/combat/visuals/`. Claude's prefabs instance them, or Claude's exports point at them; no integrated scene is edited here. PLANEJAMENTO Section 9 is the art rule: hostile bullets, friendly shots and pickups differ by shape and color, and fog and bloom preserve dodge-path readability.

## Read first

- `docs/PLANEJAMENTO.md` Section 4 "Shots, power, and familiars" and "Spiritual bomb" ("Visually communicate that radius"; "The blast effect must preserve visibility of subsequent attacks"), Section 9 (palette and readability).
- `docs/GUIDE.md` Section 3; Section 5 "Player"; Section 13 "Authored player values" (Familiar anchors at (∓1.6, 0.25, 0.1), Core radius 0.18, Graze radius 0.55).
- `docs/adr/0004-central-projectile-field.md`: a Projectile is a sphere of its `radius`.
- The "Handoff notes for Astra" and the dev placeholder of each consumer:
  - `.scratch/weapon-rendering/issues/02-projectile-system-adapter.md`, including its sprint note (one `MultiMeshInstance3D` per faction, capacity 2048);
  - `.scratch/weapon-rendering/issues/03-weapon-model-and-player-weapon.md`;
  - `.scratch/damage-pickups/issues/02-bomb-clear-and-invulnerability.md`;
  - `.scratch/damage-pickups/issues/03-pickup-adapter-and-rewards.md`.
- If F6-02 has landed: `docs/engineering/weapon-rendering.md` and `docs/engineering/spikes/projectile-rendering.md` (the measured budget).

## Files

- **Creates:**
  - `scenes/combat/visuals/projectile_player_mesh.tres` and `projectile_hostile_mesh.tres` (`Mesh` resources);
  - `scenes/combat/visuals/familiar.tscn`;
  - `scenes/combat/visuals/power_pickup_visual.tscn` and `shield_pickup_visual.tscn`;
  - `scenes/combat/visuals/bomb_blast_visual.tscn`;
  - the materials, shaders or textures they use, under `assets/combat/`;
  - `tools/validate_combat_visuals.gd` (offline QA, like `tools/validate_enemy_visuals.gd`);
  - `docs/validation/combat-visuals.md`, `combat-visuals.png`, `combat-visuals.log`.
- **Edits:** `docs/ASSET_CREDITS.md` only if a non-original asset is used; `docs/engineering/ROADMAP.md` (the D-02 row and one "Received from Astra" row); `docs/HANDOFF_LOG.md`.
- **Must not touch:**
  - `scenes/dev/**`: Claude's placeholders, which Claude swaps;
  - `scenes/main.tscn` and `scenes/player/player_ship.tscn` (trunk only);
  - `scripts/**`, `tests/**`, `content/**`, `scenes/stages/*.tscn`, `scenes/ui/hud.tscn`.

## Deliverable contract

### Projectile meshes, for F6-02 (trunk)

`ProjectileSystem` exports `player_projectile_mesh: Mesh` and `hostile_projectile_mesh: Mesh` on `Main/ProjectileRoot`. It draws each faction with one `MultiMeshInstance3D` built in code, and scales each instance by the Projectile's `radius` (player shots are 0.15, F6-03).

- **Resource.** A `Mesh` `.tres` (`PrimitiveMesh` or `ArrayMesh`) with one surface, and the material set on that surface. The MultiMesh draws the mesh's own surface material; nothing sets an override.
- **Size.** Every vertex lies within 1.0 of the origin, and the silhouette reads as that sphere. The Field hits and grazes with a sphere of the Projectile's radius, so the edge the player sees is the edge that counts.
- **Orientation-free.** It reads the same from every direction: instances are placed and scaled, not turned toward their velocity, unless `weapon-rendering.md` says otherwise.
- **Material.** Unshaded, with transparency disabled or additive blending. Alpha blending is out: one MultiMesh is not depth-sorted per instance, so alpha-blended bullets flicker in dense patterns.
- **Budget.** At most the vertex count of the dev `scenes/dev/projectile_*_mesh.tres` (a default `SphereMesh`). Fewer is better, because F6-02 benchmarks 3000 instances.
- **Distinct.** The two factions differ in shape and color, and neither reads as a Pickup or a Familiar.

### Familiar, for F6-03 (trunk)

`PlayerWeapon.familiar_scene: PackedScene` sits on `PlayerShip/Weapon`. The weapon makes two `top_level` instances under `FamiliarAnchors/Left` and `Right`. Every `_process` it writes their root position: the yaw-rotated anchor plus an orbit of 0.3, one turn per second.

- **Root.** A `Node3D` with an identity transform, and the visual centered on its origin.
- **No collision, no script.** No `CollisionObject3D` or `CollisionShape3D` anywhere in the tree. F6-03's `test_power_level_2_shows_two_familiars_with_no_collision_object` (ENGINEERING_BRIEF 4.E) runs against whatever scene the export names.
- **Motion on children only.** Use an `AnimationPlayer` with a looping clip set to autoplay. No track keys the root transform, which code owns.
- **Size.** Visible radius under 0.75: the anchor's 1.6, minus the 0.3 orbit, minus the 0.55 Graze Volume. A Familiar then never covers the Core's surroundings.

### Power and Shield Pickup visuals, for F7-03 (glm-b)

F7-03's `scenes/dev/power_pickup.tscn` and `shield_pickup.tscn` keep their root contract:

- the root `Pickup`: an `Area3D` with `pickup.gd`, `kind` set, `collision_layer` 0, `collision_mask` 2, `monitoring` on, `monitorable` off;
- its `Collision`: a `CollisionShape3D` sphere of radius 0.9.

Claude replaces their `Visual` `MeshInstance3D` with an instance of your scene, also named `Visual`. The root contract stays in Claude's prefab.

- **Root.** A `Node3D` named `Visual`, with no collision object and no script.
- **Size.** It fits inside the 0.9 contact sphere, centered on the root origin.
- **Distinct.** Power and Shield differ in shape and color (PLANEJAMENTO Section 4). The dev cue is a gold cube and a cyan torus. Neither reads as a bullet.
- **Motion on children only.** Idle motion goes on a child `AnimationPlayer`. `Pickup` moves its own root while attracting and may spin `Visual`, so no track keys the root.

### Bomb blast, for F7-02 (trunk)

`PlayerWeapon.bomb_visual_scene: PackedScene` sits on `PlayerShip/Weapon`. The Session instances it under `WorldRoot` at the Core's center and calls `setup(radius)` with `bomb_radius` (10.0, Claude's proposal). The dev `scenes/dev/bomb_blast.tscn` is a translucent sphere: its `bomb_blast.gd` scales it to the radius, fades it over 0.4 s and frees it. Claude keeps that wrapper, which owns `setup(radius)`, and instances your scene inside it.

- **Root.** A `Node3D` authored at radius 1, with its outer edge at 1.0. The wrapper scales it by `bomb_radius`, which puts the visible edge on the clear radius.
- **Clip.** A child `AnimationPlayer` named `AnimationPlayer` holds a clip `blast` in the default library:
  - it autoplays and does not loop;
  - its length is the effect's lifetime (report it; the dev fade is 0.4 s);
  - its last keys leave nothing visible.

  The wrapper frees the node when `blast` finishes.
- **See-through.** Unshaded, additive or low alpha; no opaque fill and no shadow-casting light. The next attack must stay readable through it.
- **Local resources.** Any material the clip animates has `resource_local_to_scene = true`, so two Bombs close together fade independently.
- **No collision, no script.**

## Acceptance

- `tools/validate_combat_visuals.gd` loads the six files and checks every bullet above that a script can check:
  - resource and root types, and root names;
  - zero `CollisionObject3D`, `CollisionShape3D` and scripts;
  - mesh vertices within radius 1, a surface material that is not alpha-blended, and the vertex count against the dev mesh when it exists;
  - AABBs: Familiar under 0.75, Pickups inside 0.9, Bomb outer edge at 1.0;
  - the `blast` clip exists, does not loop, autoplays, and has no root-transform track.

  It writes zero failures to `docs/validation/combat-visuals.log`. Every `.gd` compiles with warnings as errors.
- The same tool renders one 1280 × 720 gallery, headless import first, then windowed, to `docs/validation/combat-visuals.png`. It shows:
  - both Projectiles at radius 0.15 and 1.0, over a hostile ring;
  - a Familiar beside the ship, and both Pickups;
  - a Bomb at mid-clip over hostile Projectiles.

  Inspect it against the Section 9 readability rule and record the result in `combat-visuals.md`.
- `tools/test.ps1` green with no `SCRIPT ERROR` (the land step runs it again).

## Handoff to Claude

One `docs/HANDOFF_LOG.md` entry, `— Astra (sol) — Combat visuals (D-02)`, State `SCENE_READY`. It lists the colors, the vertex counts, the `blast` length, and this swap table:

| Consumer (lane) | Claude-side change |
| --- | --- |
| F6-02 (trunk) | `Main/ProjectileRoot` `player_projectile_mesh` and `hostile_projectile_mesh` → the two meshes |
| F6-03 (trunk) | `PlayerShip/Weapon` `familiar_scene` → `familiar.tscn` |
| F7-02 (trunk) | `scenes/dev/bomb_blast.tscn` instances `bomb_blast_visual.tscn`; `bomb_blast.gd` frees the node when `blast` finishes |
| F7-03 (glm-b) | `power_pickup.tscn` and `shield_pickup.tscn` instance the visuals as `Visual`, held by `pickup.gd` as a `Node3D` |

A consumer that starts after this lands uses the final file directly. For one that already landed, the late-swap rule in `.scratch/design-sprint/spec.md` applies.

## Kickoff prompt

```
Read AGENTS.md, docs/engineering/SPRINT.md (lane sol), docs/GUIDE.md Sections 3 and 5 and .scratch/design-sprint/issues/02-combat-visuals.md, then deliver it in your worktree, log it in docs/HANDOFF_LOG.md, commit, and run tools/lane.ps1 land.
```
