# Selected Runtime Asset Credits

## Stage 1 common enemy visuals

- Creator: Quaternius; downloaded Ultimate Monsters pack, Flying/glTF.
- Selected files: Hywirl.gltf and Goleling.gltf; runtime copies under `assets/models/enemies/`.
- Supplied license: CC0, preserved at `assets/licenses/quaternius-ultimate-monsters.txt`; source license heading reads Ultimate Platformer Pack.
- Changes: scene-level material tint, visual normalization, and original magic-ring meshes. Source models preserved.

## Player ship

- Creator: Kenney.
- Pack: Space Kit 2.0.
- Source: https://kenney.nl/assets/space-kit
- License: CC0; supplied license copied to `assets/licenses/kenney-space-kit.txt`.
- Original: `All models/kenney_space-kit/Models/GLTF format/craft_speederA.glb`.
- Runtime copy: `assets/models/player/craft_speederA.glb`.
- Changes: original GLB preserved byte-for-byte; scene-level position offsets center the imported ship. Additional core/engine meshes are separate authored primitives.

The test arena's geometry and materials are authored primitives. No monster models, downloaded music, or sound effects have been integrated in this handoff.

## Menu artwork

- `assets/ui/menu_forest.svg`, `menu_mountain.svg`, and `wind_emblem.svg`: original vector artwork authored for this project.
- `assets/ui/menu_theme.tres`: original Godot interface styling using Godot's bundled font and controls; no external font files copied.
- Illustrations represent the stage themes; they are not captures of completed game stages.

## HUD icons

- `assets/ui/shield.svg`, `bomb.svg`, `power.svg`, `target.svg`, and `threat.svg`: original vector icons authored for this project.
