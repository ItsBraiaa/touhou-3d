# Guardiã dos Ventos

A third-person 3D bullet hell made in Godot 4.7.2. You pilot a spirit ship through two stages, dodge dense bullet patterns in all three dimensions, and defeat the guardian at the end of each stage. The combat is inspired by the Touhou Project series, but the world, stages and bosses are original. The game's interface is in Portuguese.

This is an academic project, delivered on 2026-09-24. The Godot project and the executable still use the old working name, `Touhou-3D`.

## The game

A mist has disturbed the spirits of the region. As the Guardian of the Winds, you fly out to find where it comes from.

- **Stage 1, Floresta das Lanternas.** You learn to fly and fight on a forest route, open the way to the arena, and face the Guardião das Lanternas.
- **Stage 2, Montanha da Tempestade.** You break three seals in any order, beat the Sentinela da Tempestade (a miniboss), and fight the Guardião da Tempestade on the summit.

Each final boss has three phases. **Iniciar** plays both stages as a campaign, and **Selecionar fase** starts either stage on its own. Each stage has checkpoints: after a defeat, **Tentar novamente** resumes from the last checkpoint you reached.

## Install and run

### Play the Windows build

1. Unzip the delivery package, `Touhou-3D-<date>.zip`.
2. Run `game/Touhou-3D.exe`.

You need 64-bit Windows and a graphics card that supports Direct3D 12 or Vulkan. Settings and key bindings are saved in `%APPDATA%\Godot\app_userdata\Touhou-3D`.

### Run from source

1. Install [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/), the standard build (not .NET).
2. Open `project.godot` in Godot. It is at the root of this repository, or in `project/` inside the delivery package. The first import takes about a minute.
3. Press F5.

### Build the executable

Install the Godot 4.7.2 export templates first (Editor → Manage Export Templates). Then run these from the repository root, where `godot` is the Godot 4.7.2 console executable:

```powershell
godot --headless --path . --import
godot --headless --path . --export-release "Windows Desktop" build/Touhou-3D.exe
```

`powershell -NoProfile -ExecutionPolicy Bypass -File tools\package.ps1` then builds the delivery zip in `build/package/` and checks the extracted copy. [docs/engineering/project.md](docs/engineering/project.md#export) has the details.

## How to play

Fly freely, shoot enemies, collect pickups and survive to the boss.

- **Your hitbox is the glowing core** in the center of the ship, not the whole model. Hold **Focus** to slow down for precise dodging.
- **Health** goes from 100% to 0%. A **shield** absorbs one full hit, and a shield pickup restores it.
- **Power pickups** raise your shot from level 1 to 3. From level 2, two familiars orbit the ship and shoot with you.
- **Lock target** keeps the camera and your aim on one enemy while you circle it.
- **Bomb** clears the bullets around you and makes you briefly invulnerable. You get two per stage.
- **Impulso** is a short sidestep. You are invulnerable during it, and it recharges in under a second.
- **Graze:** a bullet that passes close to your core without hitting it gives you points.

### Controls

These are the defaults. You can change every binding in **Opções → Ver comandos**, where you can also turn the camera over to the mouse (**Câmera: Mouse**).

| Action | Keyboard and mouse | Gamepad (Xbox names) |
| --- | --- | --- |
| Move | W A S D | Left stick |
| Ascend / descend | Space / Left Ctrl | RB / LB |
| Camera | Arrow keys | Right stick |
| Recenter camera | R or middle mouse button | Right stick click |
| Fire | J | RT |
| Focus | Left Shift | LT |
| Lock target | K | Y |
| Next target | Tab | X |
| Bomb | L | B |
| Impulso left / right | Q / E | D-pad left / right |
| Pause | Esc | Start |
| Menus | Arrow keys, Enter, Esc | D-pad or left stick, A, B |

## Credits

**Development:** Braia. The code, scenes and art were produced with AI agents: Claude Code (Anthropic) for the code, OpenAI Codex (as the designer "Astra") for game design, scenes and art, and OpenCode for smaller tasks.

**Inspiration:** [Touhou Project](https://www16.big.or.jp/~zun/) by ZUN (Team Shanghai Alice). This is an unofficial fan-inspired project, not affiliated with Team Shanghai Alice. It includes no Touhou characters, art or music.

**Engine:** [Godot Engine](https://godotengine.org/) 4.7.2, MIT license. The interface uses Godot's built-in font.

**3D models**
- Player ship: Kenney, [Space Kit](https://kenney.nl/assets/space-kit), CC0.
- Enemies and bosses: Quaternius, [Ultimate Monsters](https://quaternius.com/packs/ultimatemonsters.html), CC0.

**Sound effects:** Kenney, [Interface Sounds](https://kenney.nl/assets/interface-sounds), [Digital Audio](https://kenney.nl/assets/digital-audio), [Sci-fi Sounds](https://kenney.nl/assets/sci-fi-sounds) and [Impact Sounds](https://kenney.nl/assets/impact-sounds), CC0.

**Music:** none. The game ships without music.

**Original work:** the stage environments (terrain, water, vegetation, shrines and gates), the shaders, the menu illustrations, the HUD icons, the controller glyphs and the combat effects were made for this project.

The license texts are in [assets/licenses/](assets/licenses/), and [docs/ASSET_CREDITS.md](docs/ASSET_CREDITS.md) records every file used and how it was changed.

## Documentation

[docs/PLANEJAMENTO.md](docs/PLANEJAMENTO.md) and [docs/STAGE_DESIGN.md](docs/STAGE_DESIGN.md) are the game design. [docs/engineering/README.md](docs/engineering/README.md) is the index of the engineering docs.
