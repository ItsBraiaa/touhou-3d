# Selected Runtime Asset Credits

## Stage 1 common enemy visuals

- Creator: Quaternius; downloaded Ultimate Monsters pack, Flying/glTF.
- Selected files: Hywirl.gltf and Goleling.gltf; runtime copies under `assets/models/enemies/`.
- Supplied license: CC0, preserved at `assets/licenses/quaternius-ultimate-monsters.txt`; source license heading reads Ultimate Platformer Pack.
- Changes: scene-level material tint, visual normalization, and original magic-ring meshes. Source models preserved.

## Boss models

- Creator: Quaternius; Ultimate Monsters, Flying/glTF. Source: https://quaternius.com/packs/ultimatemonsters.html.
- Stage 1 Lantern Guardian: approved `All models/Ultimate Monsters/Flying/glTF/Ghost.gltf`, copied byte-for-byte to `assets/models/bosses/Ghost.gltf`. Its atlas is embedded in the glTF; an unchanged source atlas copy is preserved at `assets/models/bosses/Ghost_Atlas_Monsters.png`.
- Stage 2 Storm Guardian: approved `All models/Ultimate Monsters/Flying/glTF/Dragon_Evolved.gltf`, copied byte-for-byte to `assets/models/bosses/Dragon_Evolved.gltf`. Its atlas is embedded in the glTF; an unchanged source atlas copy is preserved at `assets/models/bosses/Dragon_Evolved_Atlas_Monsters.png`.
- Stage 2 Tempest Sentinel reuses the Goleling runtime copy credited above; no additional model source is introduced.
- License: CC0, preserved at `assets/licenses/quaternius-ultimate-monsters.txt` (the supplied file's heading says Ultimate Platformer Pack).
- Changes: imported model scale 2.6 and original amber lantern meshes/orbit are authored in `scenes/enemies/lantern_guardian.tscn`; the source glTF and atlas are unchanged.
- Stage 2 changes: scene-level slate and lavender-blue materials, scales, and original storm rings and sigils are authored in `scenes/enemies/tempest_sentinel.tscn` and `scenes/enemies/storm_guardian.tscn`; the source glTFs and atlases are unchanged.

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

## Combat materials

- `assets/combat/player_shot.tres`, `hostile_shot.tres`, `bomb_ring.tres`, `power_gold.tres`, and `shield_blue.tres`: original Godot materials authored for the D-02 projectile, Bomb and Pickup visuals. No external material or texture was used.

## Stage 1 gate veil

- `assets/environment/stage_01/gate_veil.gdshader`: original shader authored for the Stage 1 gate veil. No external shader or texture was used.

## Sound effects

Creator: Kenney. The 17 selected Ogg Vorbis files under `assets/audio/sfx/` are unchanged byte-for-byte; there are no trims or conversions. Each selected pack is CC0 and its supplied license is preserved:

| Pack | Source | Runtime folder | Supplied license |
| --- | --- | --- | --- |
| Interface Sounds | https://kenney.nl/assets/interface-sounds | `assets/audio/sfx/interface/` | `assets/licenses/kenney-interface-sounds.txt` |
| Digital Audio | https://kenney.nl/assets/digital-audio | `assets/audio/sfx/digital/` | `assets/licenses/kenney-digital-audio.txt` |
| Sci-fi Sounds | https://kenney.nl/assets/sci-fi-sounds | `assets/audio/sfx/scifi/` | `assets/licenses/kenney-sci-fi-sounds.txt` |
| Impact Sounds | https://kenney.nl/assets/impact-sounds | `assets/audio/sfx/impact/` | `assets/licenses/kenney-impact-sounds.txt` |

The [event-to-file table](engineering/audio.md#mapping-f13-04) records every shipped filename and its use: Astra's revised selection (`sound_effects/README.md`, applied by F13-04). D-01's first pass is in [validation/audio-selection.md](validation/audio-selection.md).

## Music

No music ships in this delivery. The five files in the ignored `music/` source folder have *Touhou 10* composition titles, but their source and redistribution permission are not documented. They remain references only and were not copied to runtime assets. A new permitted track requires a separate selection and credit decision.

## Stage 2 mountain environment

- `assets/environment/stage_02/`: original terrain, stream and crag OBJ meshes
  generated by `tools/build_stage_02.py`; original visual shaders for world-space
  noise texture, foliage/cloth wind, water flow and gate wisps.
- Terrain texture uses Godot FastNoiseLite and NoiseTexture2D. No external texture,
  vegetation pack, image-generation output or new licensed download was integrated.
- Trees, shrubs, flowers, shrine structures and waterfalls are original mesh
  compositions in `scenes/stages/stage_02.tscn`.

## F16 controls and dash visuals

- `assets/ui/controls/glyphs/`: 36 original 64×64 PNG controller glyphs drawn for this project; no external source.
- `scenes/player/visuals/dash_visual.tscn`: original translucent cyan mesh composition; no external source.
