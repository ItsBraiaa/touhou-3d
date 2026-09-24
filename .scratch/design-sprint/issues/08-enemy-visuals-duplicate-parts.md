# D-08 Duplicate model parts in the enemy visual scenes

Status: done
Type: design
parallel-safe: no
Owner: Astra (GPT Sol)
Depends on: none
Lane: oc-a
Model: GPT 5.6 Luna (fallback DeepSeek V4.1 Flash)

## Goal

Trunk reported that Astra's enemy visual scenes hold their model parts twice. Each enemy then leaks them at exit, and probably draws its model twice. Trunk measured `26 ObjectDB instances were leaked` at exit, and freeing `spirit_lume.tscn` on its own leaks in the same way (`docs/validation/stage-director.md` "Not verified"; `docs/HANDOFF_LOG.md` F10-01 entry, "Action required by Astra" item 4). Astra says the double draw and the leak still need confirming. Part 1 confirms or rules out each one. Part 2 fixes the duplicate, and runs only if Part 1 confirms it. Both parts run in one session and land as one commit.

**Why it probably happens.** `tools/build_enemy_visuals.gd` instances the glTF as `Model`, then `own_nodes(visual_root, visual_root)` re-owns every node inside that instance. `PackedScene.pack` therefore saved two things:

- `Model` as an instance (`instance=ExtResource(...)`);
- its children `CharacterArmature`, `Skeleton3D`, the mesh (`Hywirl` or `Goleling`) and `AnimationPlayer`, again, as new typed nodes (`type="..."`), with their mesh, skin, materials and animation library embedded.

On load, the glTF instance builds its own set of those four nodes, and the file adds a second set with the same names. All four scenes have this, not only the two trunk named. The file's set carries the tint (`surface_material_override/0`) and the looping `Flying_Idle` (`autoplay`). The instance's set carries neither.

The loader then does one of two things, and Part 1 tells which:

- **It keeps both sets.** Two meshes draw, one of them untinted.
- **It drops one set from `Model`'s child list without freeing it.** That set never enters the tree, so it never draws, but it leaks.

## Read first

- `docs/ENEMY_VISUAL_HANDOFF.md` ("Claude integration", "Verification").
- The four scenes under `scenes/enemies/visuals/`. They are 900 to 2,100 lines of embedded mesh data, so read only the headers: `grep -n "^\[ext_resource\|^\[node\|^\[editable" <file>`.
- `tools/build_enemy_visuals.gd` (`build`, `own_nodes`) and `tools/validate_enemy_visuals.gd`, the offline QA run against `scenes/tests/enemy_variants_preview.tscn` (nodes `SpiritLume`, `SpiritTwilight`, `SentryLantern`, `SentrySeal`).
- `scenes/enemies/tempest_sentinel.tscn` headers. It is a clean instance of the same `Goleling.gltf`: override nodes with no `type=`, plus `[editable path="VisualRoot/Model"]`.
- The consumers:
  - `scenes/dev/spirit.tscn` and `sentry.tscn` instance `spirit_lume.tscn` and `sentry_lantern.tscn` as `VisualRoot`.
  - `scripts/enemies/enemy_actor.gd` reads only `visual_root` and pulses its `scale` (`_pulse_visual`).
  - `scenes/dev/arena_harness.gd` (`_spawn_missing_enemies`) spawns one of each.
  - D-05's `metadata/anticipation_clip` on each `VisualRoot`: `Yes` on the two Spirits, `Punch` on the two Sentries.

## Files

- **Creates:**
  - `docs/validation/enemy-visuals.md`: the Part 1 and Part 2 findings.
- **Edits, Part 2 only:**
  - `scenes/enemies/visuals/spirit_lume.tscn`, `spirit_twilight.tscn`, `sentry_lantern.tscn` and `sentry_seal.tscn` [shared]: two deletions per file, listed in Deliverables.
  - `tools/build_enemy_visuals.gd`: one line in `build`, and the line-2 comment.
  - `docs/ENEMY_VISUAL_HANDOFF.md`: one sentence under "Claude integration".
- **Serialized at session end:**
  - `docs/HANDOFF_LOG.md`: one entry, `— OpenCode (oc-a) — D-08 enemy visual duplicate parts [shared]`;
  - `docs/engineering/ROADMAP.md`: one dated line under "Received from Astra";
  - this ticket: Status and Outcome.
- **Must not touch:**
  - In the four scenes: every `sub_resource`, the typed node blocks under `Model`, the `Model` transform, `VisualRoot` and its `metadata/anticipation_clip`, and `MagicRing1` and `MagicRing2`.
  - `tools/build_enemy_visuals.gd`: **never run it**. It would drop D-05's metadata.
  - `tools/validate_enemy_visuals.gd`, `scenes/tests/enemy_variants_preview.tscn`, `docs/validation/enemy-variants.png` and `enemy-visuals.log`. Run the validator headless only: a windowed run rewrites the PNG.
  - `scenes/dev/**`, `scripts/**`, `tests/**`, the three boss scenes, and `docs/validation/stage-director.md` (trunk's; the handoff tells trunk).
- **Conflicts with:** nothing in any queue. Lane sol must not edit the four scenes until this lands.

## Deliverables

### Part 1: confirm

**A throwaway count script.** Write a `SceneTree` script outside the worktree, for example `%TEMP%\d08_visual_counts.gd`, and never commit it. Run it with `tools\godot.cmd --headless --path . --script <that absolute path>`.

It loads six scenes in this order:

1. `res://assets/models/enemies/Hywirl.gltf`, the control;
2. `spirit_lume.tscn`;
3. `spirit_twilight.tscn`;
4. `res://assets/models/enemies/Goleling.gltf`, the control;
5. `sentry_lantern.tscn`;
6. `sentry_seal.tscn`.

For each scene, run two cycles and report the second one, so that first-use caches do not count. Each cycle:

1. Read `Performance.get_monitor(Performance.OBJECT_COUNT)` and `Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)`.
2. `instantiate()`, then `root.add_child(...)`, then `await process_frame`.
3. Take `model`: the `Model` node, or the glTF root for a control. Print:
   - its child names;
   - the `MeshInstance3D`, `Skeleton3D` and `AnimationPlayer` counts under it (`find_children("*", "<class>", true, false)`);
   - the sum of `mesh.get_surface_count()`;
   - **detached**: the rise in the orphan-node count. These are nodes the instance made that never entered the tree.
4. On the second cycle only, call `Node.print_orphan_nodes()` to name the detached nodes.
5. `free()`, then `await process_frame`.
6. Print **left**: the rise in the object count since step 1.

Each glTF has one mesh with one primitive, so a control should read 1 mesh, 1 surface, 1 skeleton, 1 player, 0 detached and 0 left.

**Exit leaks.** Run the harness headless, and let `--quit-after` end it cleanly:

`tools\godot.cmd --headless --path . res://scenes/dev/arena_harness.tscn --quit-after 600 --verbose`

Keep every line that contains `leaked`. `--verbose` names the leaked classes.

**Verdict.** Part 1 confirms a duplicate if any scene reads more than its control on any count, or its detached or left value is above the control's, or its exit leaks name the visual's classes: `MeshInstance3D`, `Skeleton3D`, `AnimationPlayer`, `Skin`, `ArrayMesh` or `Animation`.

- **Double draw** is confirmed only if the mesh count is above 1, because a detached node never draws.
- **The leak** is confirmed by detached, left, or the exit lines.

Record the six rows, the exit lines and both verdicts in `docs/validation/enemy-visuals.md`.

### Part 2: fix (only if Part 1 confirms)

**The scenes.** Make `Model` a plain `Node3D` that owns the set already in the file. That set is the tinted, looping one. In each scene, delete exactly two things:

| Scene | Line 3 (the glTF `ext_resource`, delete it) | In the `Model` header, delete |
| --- | --- | --- |
| `spirit_lume.tscn` | `Hywirl.gltf`, id `1_56135` | ` instance=ExtResource("1_56135")` (line 1829) |
| `spirit_twilight.tscn` | `Hywirl.gltf`, id `1_8n7i1` | ` instance=ExtResource("1_8n7i1")` (line 1829) |
| `sentry_lantern.tscn` | `Goleling.gltf`, id `1_6k0y8` | ` instance=ExtResource("1_6k0y8")` (line 815) |
| `sentry_seal.tscn` | `Goleling.gltf`, id `1_hbrms` | ` instance=ExtResource("1_hbrms")` (line 822) |

Each header then reads `[node name="Model" type="Node3D" parent="." unique_id=<unchanged>]`. Keep the atlas `Texture2D` `ext_resource`: the materials use it. The paths that consumers rely on stay the same:

- `VisualRoot`;
- `Model/CharacterArmature/Skeleton3D/<mesh>`;
- `Model/AnimationPlayer`, with the clips `Death`, `Fast_Flying`, `Flying_Idle` (looping, autoplay), `Headbutt`, `HitReact`, `No`, `Punch` and `Yes`;
- `MagicRing1` and `MagicRing2`.

This form is used instead of trunk's suggestion, rewriting the typed blocks as `type`-less overrides the way `tempest_sentinel.tscn` does. It takes two deletions per file and needs no glTF node ids, which these files do not carry.

**The generator.** In `build`, right after `model.name = "Model"`, add `model.scene_file_path = ""`, with a one-line comment. The comment says that, left as an instance, `own_nodes` re-owns the instance's children and `pack` saves them a second time (D-08). A rerun then writes the form above. Extend the line-2 comment: a rerun also drops D-05's `metadata/anticipation_clip`. The land gate's compile step is the only check on this line.

**The handoff doc.** Add one sentence under "Claude integration": since D-08, `Model` is a plain `Node3D` that holds an embedded copy of the glTF subtree, so a reimport of `Hywirl.gltf` or `Goleling.gltf` no longer reaches these four scenes.

## Verification (no tests: SPRINT.md "No new tests")

- **The count script again, after Part 2.** Every scene equals its control: 1 mesh, 1 surface, 1 skeleton, 1 player, 0 detached, 0 left. Record it in `enemy-visuals.md` as a second table.
- **The harness exit again.** No `leaked` line names a visual class. List any other leak line, with its classes, as not D-08's.
- **The validator.** `tools\godot.cmd --headless --path . --script res://tools/validate_enemy_visuals.gd` prints `ENEMY_VISUAL_QA failures=0`, with `idle_playing=true` for all four.
- **A windowed arena run.** Run `tools\godot.cmd --path . res://scenes/dev/arena_harness.tscn`, first with `--headless --quit-after 300` and then windowed. The Spirit and the Sentry each show one body:
  - the Spirit tinted teal, and the Sentry amber with one ring;
  - `Flying_Idle` animating;
  - no untinted copy, no z-fighting, and the Anticipation pulse still visible.

  Close the window normally, and note what you saw in `enemy-visuals.md`.
- **`tools/lane.ps1 land` passes.** Its resource check loads all four scenes and compiles the generator.

## Out of scope

- The three boss scenes. They already use the override form, with `[editable path="VisualRoot/Model"]` and no typed copies.
- Tint, scale, rings, clips, and hit radii.
- An `anticipation_clip` export on `EnemyActor`.
- Moving the four scenes to the override form.
- Refreshing `enemy-variants.png`.
- Closing trunk's leak note.

## Definition of Done

- `docs/validation/enemy-visuals.md` holds Part 1's six rows, the exit lines and both verdicts. After a fix, it also holds the same checks after Part 2 and the windowed notes.
- If Part 2 ran:
  - the counts match the controls;
  - no visual class leaks at exit;
  - the validator reports 0 failures;
  - the windowed run shows both enemies animating.
- `tools/lane.ps1 land` passes.
- The handoff entry and the ROADMAP line are written. The ticket is `Status: done`, with an Outcome.
- One commit:
  - after a fix: `design: [shared] remove duplicate model parts from enemy visuals`;
  - if Part 1 does not confirm a duplicate: `docs: D-08 enemy visual duplicate check, not confirmed`, with only the findings, the handoff entry, the ROADMAP line and the ticket.

## Handoff notes for Astra

Review the four scenes' diff: two deletions each, and nothing else in them changed. `Model` no longer instances the glTF, so a new import of `Hywirl.gltf` or `Goleling.gltf` needs re-authoring, and never a generator rerun over these files. If the untinted copy was drawing, the enemies now show only your tint. Check it once in the arena. If you want the glTF link back, the override form of `tempest_sentinel.tscn` is the alternative, as your own later edit.

For trunk, the same entry says whether the leak in `stage-director.md` "Not verified" is gone.

## Outcome

Part 1 confirmed the duplicate in all four visual scenes: before the fix each had two meshes, surfaces, skeletons and animation players, four detached nodes and four left nodes, while each glTF control had one of each and zero detached/left. The arena harness also reported visual-class leaks (`Animation`, `Skin`, `ArrayMesh`, `MeshInstance3D`, `Skeleton3D`, `AnimationPlayer`) and `26 resources still in use at exit`. Part 2 removed exactly the four glTF instance ext_resources and four `instance=ExtResource(...)` attributes, one pair per scene. Post-fix counts for every scene match its control at 1 mesh, 1 surface, 1 skeleton, 1 player, 0 detached and 0 left. `validate_enemy_visuals.gd` passed with `ENEMY_VISUAL_QA failures=0`; a short windowed launch reached Forward+ and was closed after ten seconds. No tests were written and the generator was not run.

## Kickoff prompt

```
You are lane oc-a of docs/engineering/SPRINT.md. Read AGENTS.md, docs/engineering/SPRINT.md and docs/engineering/CONVENTIONS.md once, then .scratch/design-sprint/issues/08-enemy-visuals-duplicate-parts.md. If its Model line names a different model from the one you are running, stop and ask the user to switch. Run tools/lane.ps1 sync, then do Part 1, and Part 2 only if Part 1 confirms a duplicate. Write no tests of any kind, never run tools/build_enemy_visuals.gd, and keep the throwaway script outside the worktree. Finish the Definition of Done, commit on lane/oc-a with the ticket's commit message, run tools/lane.ps1 land, then stop and report. Run every tools script as powershell -NoProfile -ExecutionPolicy Bypass -File tools\<script>.ps1 <args>.
```
