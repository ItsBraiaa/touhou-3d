# Model Selection — Art Direction

Date: 2026-09-20. Status: player ship and both final-boss models approved by the user. Runtime import and animation playback remain unverified.

Design, scene authoring, and visual asset integration: Astra. Production GDScript and technical import/animation support: Claude. Follow [GUIDE.md](GUIDE.md) for collaboration boundaries. This document records approved model choices and proposed presentation details; it does not implement or import models.

## Approved selection

The user selected `All models/Ultimate Monsters/Flying/glTF/Ghost.gltf` for the Lantern Guardian, favoring a spiritual appearance over the skull variant. Preserve that identity when adapting the model. Warm amber magic and floating lantern ornaments remain the proposed presentation; no model changes have been made.

The user also approved `All models/kenney_space-kit/Models/GLTF format/craft_speederA.glb` for the player ship and `All models/Ultimate Monsters/Flying/glTF/Dragon_Evolved.gltf` for the Storm Guardian. Use these exact source files for integration. Alternatives below are reference only, not interchangeable approved selections.

## Approved cast and presentation direction

| Role | Recommended source model | Art direction | Reason |
| --- | --- | --- | --- |
| Player ship | `All models/kenney_space-kit/Models/GLTF format/craft_speederA.glb` | White hull with teal spiritual core and limited warm accents; two small orbiting familiars | Compact silhouette and recognizable twin rear engines in the supplied preview |
| Stage 1 final boss | `All models/Ultimate Monsters/Flying/glTF/Ghost.gltf` | Lantern Guardian: warm amber magic and a ring of simple floating lanterns | Spirit identity suits the forest/shrine theme; flying animation clips are present |
| Stage 2 final boss | `All models/Ultimate Monsters/Flying/glTF/Dragon_Evolved.gltf` | Storm Guardian: blue/violet attack effects and a strong arrival silhouette | Dragon identity gives a distinct final encounter; flying animation clips are present |
| Stage 2 miniboss | A reused Sentry with larger scale and rotating ornaments | Tempest Sentinel: darker body with bright storm-energy accents | Preserves the approved reuse strategy; does not require a third complex character |

Suggested recolors and accessories are art direction, not completed edits. Check model materials before choosing how to recolor them. Preserve the original downloaded files.

## Player ship alternatives

- `craft_racer.glb`: more compact/block-like; alternative if a denser body is preferred.
- `craft_speederD.glb`: broader wings and stronger aircraft silhouette; occupies more screen area behind the player.

All three are in `All models/kenney_space-kit/Models/GLTF format/`. The supplied isometric PNGs were visually inspected. `craft_speederA` is the preferred compromise between readability and screen coverage. Rear-camera readability still requires a runtime check.

### Supplied previews

Recommended — craft_speederA:

![craft_speederA](<All models/kenney_space-kit/Isometric/craft_speederA_NE.png>)

Alternative — craft_racer:

![craft_racer](<All models/kenney_space-kit/Isometric/craft_racer_NE.png>)

Alternative — craft_speederD:

![craft_speederD](<All models/kenney_space-kit/Isometric/craft_speederD_NE.png>)

## Boss alternatives and verified animation metadata

`Ghost_Skull.gltf` was considered but not selected for Stage 1; use the approved `Ghost.gltf`. `Dragon.gltf` is the simpler Stage 2 alternative. `Tribal.gltf` and `Goleling_Evolved.gltf` were also inspected as metadata alternatives, not selected.

The following animation names are present in all six inspected glTF files:

- Death
- Fast_Flying
- Flying_Idle
- Headbutt
- HitReact
- No
- Punch
- Yes

This confirms named clips in the files, not successful animation playback or suitability for every attack. In particular, a dedicated casting clip was not identified. Claude should inspect the actual motion before assigning Punch or Headbutt as an anticipation gesture; the design does not add contact-based boss attacks merely because those clips exist.

Use Flying_Idle as a hover candidate, Fast_Flying for entry/repositioning, and Death for defeat. Avoid interrupting attack readability with HitReact on every player projectile. Use the three named attack patterns from STAGE_DESIGN.md independently of imported clip names.

## Visual review evidence and next checks

Inspected locally:

- Kenney Space Kit Preview.png and the three individual ship preview PNGs.
- Ultimate Monsters Preview.jpg, showing the pack's cartoon monster art direction.
- Animation names from the six candidate glTF files.

The monster contact sheet shows the pack as a whole; isolated renders of the selected boss files have not been produced. The pack has rounded cartoon forms, while the ships have angular forms. Unify them through palette, simple materials, restrained effects, and scene lighting rather than assuming their visual styles already match perfectly.

Before final integration, inspect each chosen model from the gameplay camera and play its clips. Verify its texture/buffer dependencies, scale, forward axis, clipping, and visibility against the stage palette. Keep core collision independent of ship visuals. Larger boss wings must not hide important projectiles near the player.

Source pack licenses are supplied in their folders; record the selected files and licenses in the eventual ASSET_CREDITS.md. These assets remain downloaded source material until integration is explicitly performed.
