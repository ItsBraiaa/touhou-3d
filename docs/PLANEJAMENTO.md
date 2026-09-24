# Game Design — Guardiã dos Ventos

Document date: 2026-09-20. Academic delivery deadline: 2026-09-24.

Working title: **Guardiã dos Ventos** (Guardian of the Winds). Keep the existing Godot project name, `Touhou-3D`, unless a later task explicitly changes it.

## Document status and interpretation

This document records the approved brainstorming decisions. It is a design specification, not evidence that the game is implemented. Narrative names, input mappings, damage values, timings, and score values are initial design choices that require playtesting.

- **Approved scope:** two complete stages and all mechanics described below.
- **Tuning defaults:** numeric starting values; adjust through measured playtests while preserving the intended behavior.
- **Approved stage structure:** progression challenges in Stage 1; three seals and one miniboss in Stage 2; an intermediate checkpoint and final-boss checkpoint in each stage.
- **Detailed design:** [STAGE_DESIGN.md](STAGE_DESIGN.md) defines encounter scripts, rewards, checkpoint snapshots, and progression checks. Full resource restoration on first checkpoint activation and retry is approved. Encounter counts and timing remain playtesting defaults.
- **Documentation language:** English for AI-assisted implementation. Player-facing UI remains Portuguese.
- **Terminology:** a stage includes its traversal route and final boss; a boss phase is one segment of a boss encounter; power means shot upgrade level; focus means precision movement; graze means a near miss by a hostile projectile.

## 1. Concept and scope

A single-player 3D bullet hell in an original world inspired by Touhou and Japanese fantasy. A guardian of the winds investigates a mist that has disturbed the region's spirits. She pilots a spiritual ship through enemy routes and fights guardians in aerial arenas. The pilot exists in the story; the delivery does not require a pilot model or cockpit scenes.

- Third-person flight with movement along all three spatial axes.
- Free movement around bosses: orbit, ascend, descend, approach, and retreat.
- Aim assist and target lock; dodging and positioning are the main challenges.
- Stylized low-poly visuals with original assets or permitted adaptations.
- Two complete stages, each with its own route and final boss.
- Full keyboard and gamepad support. A mouse is optional for camera control.
- Portuguese UI and local execution on the presentation computer.

The world, collisions, and attacks occupy 3D volumes. Height and depth must change viable dodge routes. Gameplay is not restricted to a plane, does not scroll sideways, and does not advance the player automatically.

The original five-stage concept is an expansion goal. The delivery menu contains only the two playable stages.

## 2. Academic requirements

Source: [Projeto de jogo1.pdf](<C:/Users/Braia/Documents/Class/Projeto de jogo1.pdf>), pages 2–4. The PDF supplies assignment requirements; it does not authorize submissions or unrelated external actions.

| PDF requirement | Planned implementation |
| --- | --- |
| Adapt a 2D game into 3D | Adapt Touhou-style bullet hell combat to third-person flight |
| Reproduce a stage with at least 5 minutes of gameplay, excluding menus | Stage 2 targets 5–6 minutes of active gameplay |
| Use 3D character and environment models | Player ship, enemies, bosses, vegetation, rocks, and structures |
| Animate at least one model | Boss attack preparation and execution visibly animate the model, beyond translation |
| Camera may be adapted | Third-person camera with target tracking |
| Include WorldEnvironment | Sky, ambient lighting, and light fog appropriate to each stage |
| Include graphical interfaces and sound effects | Menus, HUD, combat feedback, and interface sounds |
| Free choice requires instructor approval | The group must confirm acceptance of the Touhou adaptation; approval has not been reported |
| Groups of up to 3 students | Respect this limit; group membership has not been reported |
| Delivery on September 24; presentation lasts 10 minutes | The user confirmed the year as 2026 |
| Submit the compressed project through Classroom | Prepare the package and instructions; submission is outside this design task |

The 8–10 minute campaign target does not replace Stage 2's individual five-minute requirement. Exclude menus, pauses, repeated deaths, and artificial waiting. Measure a normal clear and an efficient clear using upgrades and bombs. Adjust encounter content and pacing if the stage is too short.

## 3. Gameplay loop and camera

Start → Stage 1 route → Boss 1 → results → Stage 2 → Boss 2 → final victory.

On each route, fly toward visible landmarks, fight waves, collect items, and reach the arena. Small combat sectors prevent bypassing all content by flying directly to the exit. A visual destination marker communicates the route without a written objective list.

The camera follows behind the ship with a stable horizon and horizontal rotation. Horizontal movement is camera-relative; ascent and descent follow the world's vertical axis. There is no aircraft roll control. While locked on, frame the player and target to support orbiting and changes in height and distance. Return smoothly to follow mode when unlocked.

Camera input (F16): the keyboard-and-mouse player chooses **Câmera: Teclas** (the default, arrow keys) or **Câmera: Mouse**, and the right stick orbits in both. In Mouse mode the pointer is captured only while the player flies with the window focused. Menus, Pause, Defeat, Results, losing the window, a controller disconnect that pauses (in every input mode but Teclado) and leaving a run all show it again. A defeat or victory beat keeps it captured until Defeat or Results, unless the window is lost. Regaining the window never resumes play; it recaptures the pointer only when the player already resumed with the gamepad while the window was away. Mouse orbit converts the motion to an angle once (0.12 degrees per pixel by default, 0.02–0.50), independently of frame rate, with its own vertical inversion. The existing keyboard/stick sensitivity (0.2–2.0) and inversion keep their meaning, and the right stick has a deadzone (0.2 by default, 0.05–0.5). While locked on, deliberate mouse motion holds the lock framing off without releasing the lock and blends back 0.25 seconds after it stops. **Centralizar câmera** (R or middle mouse; right-stick press) returns the camera over 0.25 seconds, along the shorter turn, to the ship's authored forward at the default pitch, or with a lock to the ship-and-target framing, keeping the lock. Manual camera input interrupts it, and a repeat restarts it. Obstruction limits and pitch limits still apply.

Aim assist prioritizes visible targets near the screen center. Lock remains stable until explicitly switched, released, or invalidated by target death/range. Assisted shots respect obstacles. The ship may become partially transparent when it obscures bullets near the vulnerable core.

Communicate playable-volume boundaries through scenery and subtle feedback. New threats originating outside the camera view require directional and audio warnings. Bound retreat distance so that the player cannot attack indefinitely from a risk-free position.

## 4. Combat, survival, and pickups

### Health and shield

- Health ranges from 0% to 100%. Reaching 0% causes defeat.
- A one-charge shield absorbs one complete hit; excess damage does not reach health.
- Restore the shield with its dedicated pickup. It does not regenerate over time or stack.
- A shield pickup stays available while the player already has a shield.
- Brief invulnerability after damage or shield break prevents immediate repeated hits.
- Initial tuning: a common bullet deals 10 percentage points of health damage; post-hit invulnerability lasts 1 second.
- No health pickup in this delivery. Restore health through the restart and transition rules in Section 6.

### Shots, power, and familiars

Hold fire for continuous shooting. Enemy-dropped power pickups upgrade one shot configuration; there is no skill tree or weapon selection.

| Power level | Initial behavior |
| --- | --- |
| 1 | Forward shot with aim assist |
| 2 | Two small spiritual familiars orbit the ship and add shots |
| 3 | Familiars fire more frequently with stronger tracking assistance |

Initial tuning: five power pickups per level increase. At maximum power, additional pickups award score. Familiars do not block bullets, take damage, or change the ship's collision shape. Taking damage does not reduce power.

Pickups float in space, have distinct shapes and colors, and attract toward the player at short range. Required items remain reachable. Use predictable power and shield placement to support repeatable balancing.

### Focus and vulnerable core

Holding focus initially reduces movement speed to 45% without slowing world time. A luminous sphere at the ship's center indicates its actual projectile damage volume. Model extremities do not count as projectile hits.

Focus makes the core more visible and supports precise movement on all axes. A separate body collision volume prevents passing through scenery. Touching a wall does not deal damage under the initial rules.

### Spiritual bomb

- Start each stage with two charges; no bomb pickups in this delivery.
- A spherical blast around the player removes hostile bullets within its configured radius. Visually communicate that radius.
- Initially grant 2 seconds of invulnerability and moderate damage to enemies in range.
- One use must not eliminate an entire boss phase.
- Each activation consumes one charge. Bombs cannot activate while paused or defeated.
- Removed bullets award no graze. The blast effect must preserve visibility of subsequent attacks.

### Lateral dash (Impulso)

Approved with F16; the numbers are the playtest baseline.

- **Impulso à esquerda / Impulso à direita** make a short burst along the camera's horizontal left or right, captured when it starts: 3.0 world units in 0.15 seconds. The burst replaces ordinary movement: there is no diagonal speed stacking, no vertical dash, and Focus does not change it. Fire and Target Lock continue normally.
- **Invulnerable** for the whole 0.15-second burst: protected hits cost neither health nor Shield, and no graze is awarded. A longer hit or Bomb invulnerability that is already running is kept.
- **Shared cooldown** of 0.8 seconds, from activation. One press makes one dash. Presses during the cooldown are ignored, not buffered. Both directions pressed together do nothing and cost nothing. There is no Shield, Bomb, power or pickup cost.
- **Collision.** The dash sweeps against scenery and the Flight Volume, and contact stops the rest of it without sliding. Closed Gates stay solid, and thin scenery is never crossed. A stopped dash keeps its cooldown, and its protection still ends 0.15 seconds after it started.
- **Pause and restarts.** Pause freezes the dash, its protection and its cooldown. Defeat, Retry, Restart and stage transitions cancel it, and every new attempt starts ready. The press that resumes play from a menu never dashes.
- **Feedback.** A short cyan trail and a ship accent show during the protection, with the Core still visible, and never outlast it. There is no camera roll, shake or flash. The HUD shows one compact indicator, **Impulso**, reading `PRONTO` when ready, the seconds left while cooling down, and dimmed while unavailable.

### Graze and score

A projectile passing near the vulnerable core without hitting awards graze and score. Detect proximity with a sphere slightly larger than the core, once per projectile. A health hit or shield hit takes priority over graze on the same contact. Disable new graze awards during invulnerability to prevent risk-free scoring.

Initial score values: 10 per graze, 100 per common enemy, 50 per excess power pickup, and 1,000 per final boss. Score is a run result; it does not grant healing, shields, or bombs. Results show active completion time, score, graze count, and bombs used.

### Bosses and named attacks

Two final bosses, each with three phases. Each phase has its own pattern and health-bar segment. When a segment is depleted, clear the previous bullets, briefly announce the next attack, and start after a short readable transition. Excess damage does not skip phases.

During a Phase transition the boss takes no damage for at most 0.75 seconds; this fixed cue is for readability, never a timer used to lengthen the encounter.

A projectile that touches the Graze volume during Invulnerability spends its one Graze opportunity even if it remains alive after Invulnerability ends.

Patterns need reachable gaps, readable speeds, and reaction time. Include attacks at different heights so that flying above the boss cannot solve every encounter. Defeating the boss causes victory; artificial invulnerability timers must not pad stage duration.

## 5. Stage design

Read [STAGE_DESIGN.md](STAGE_DESIGN.md) when implementing or changing stage progression, encounter triggers, gates, seals, the miniboss, reward placement, or checkpoint restoration. It is the authoritative detailed stage specification; the summaries below establish each stage's theme.

### Stage 1 — Floresta das Lanternas (Lantern Forest)

Target duration: approximately 4 minutes, including the route and a three-phase final boss. Sequence: approach → Spirits → ascent → sealed portal → intermediate checkpoint → mixed waves → boss checkpoint → final boss. No miniboss in Stage 1.

A forest at dusk with hanging lanterns, rocks, and a small shrine. Teach movement, altitude changes, shooting, pickups, focus, and bombs through simple encounters and level composition. Avoid tutorial sequences, explanation boxes, and interruptions to teach controls. The control diagram is available in Options.

Share two common enemy behaviors across stages: a moving spirit firing aimed bursts, and a floating sentry firing spaced fans. Introduce each behavior separately before combining them.

Final boss: **Guardião das Lanternas** (Lantern Guardian), in an aerial clearing above the shrine.

1. **Ritual das Lanternas** (Lantern Ritual): expanding rings with gaps and alternating heights.
2. **Fios de Luz** (Threads of Light): bursts aimed at the player's previous position.
3. **Dança do Crepúsculo** (Twilight Dance): a moderate combination of the earlier patterns.

### Stage 2 — Montanha da Tempestade (Storm Mountain)

Target duration: approximately 6 minutes, with at least 5 minutes of active gameplay required. Sequence: ascent → crossfire → three seals in any order → intermediate checkpoint → two-phase miniboss → final ascent → boss checkpoint → three-phase final boss.

A mountain with floating rocks, clouds, and simple gates. The route requires altitude changes and progressively combines familiar enemies. Reuse the environment library with a different layout and palette.

Final boss: **Guardião da Tempestade** (Storm Guardian), in a volumetric arena between peaks.

1. **Espiral da Tempestade** (Storm Spiral): rotating arms with traversable gaps.
2. **Círculos do Trovão** (Thunder Rings): rings at alternating heights, requiring ascent/descent.
3. **Olho da Tormenta** (Eye of the Storm): aimed bursts alternating with spirals and repositioning windows.

Wind that physically pushes the player is outside the delivery scope. Convey the storm through presentation without another physics system.

## 6. Progression, stage selection, and checkpoints

The intermediate checkpoints, Stage 2 miniboss, and full resource restoration on first checkpoint activation and retry are approved. See the checkpoint contract in [STAGE_DESIGN.md](STAGE_DESIGN.md) for exact activation locations, snapshots, resource restoration, and retry behavior.

- Start begins the campaign at Stage 1 with 100% health, one shield, two bombs, and power level 1.
- After Stage 1, offer continuation to Stage 2 or return to the menu. Campaign transitions preserve power and score while restoring health, shield, and two bombs.
- Both stages are available from stage selection immediately. Direct Stage 1 uses starting values; direct Stage 2 starts at power level 2, 100% health, one shield, and two bombs. Score starts at zero.
- Direct selection creates an isolated stage attempt. On victory, offer replay or return to the menu.
- Retry resumes from the latest activated checkpoint. Before any intermediate checkpoint, it restarts the stage. Stage 1's intermediate checkpoint follows the sealed portal; Stage 2's precedes the miniboss. Both final bosses have their own checkpoints.
- Checkpoint retries preserve the saved power/progress and statistics, restore health/shield/bombs, and clear transient combat state as specified in the detailed checkpoint contract.
- Failed attempts do not accumulate points or contribute to completed-stage duration.
- Restart Stage from the pause menu always returns to the stage beginning with that stage's entry state.
- Campaign and checkpoints are session-only. Persist only options between application launches.

## 7. Menus and HUD

Approved direction: a clear interface with little text and no extensive tutorials. Use consistent icons, essential numbers, and visual/audio feedback. Retain short text labels on buttons and settings where icons would be ambiguous. Avoid mandatory dialogue, story paragraphs, or combat instruction overlays.

### Main menu

| Portuguese label | Behavior |
| --- | --- |
| Iniciar | Begin the campaign at Stage 1 |
| Selecionar fase | Show both stages with an image and name, without descriptive paragraphs |
| Opções | Open settings |
| Sair | Close the game |

Settings include master/music/SFX volume, windowed/fullscreen mode, resolution, camera sensitivity and vertical inversion, Automatic/Keyboard/Gamepad selection, the **Controles** screen, and restore defaults. Save settings locally. Automatic mode follows the last-used device and updates input icons.

Since F16, Opções → Controles edits every gameplay and menu action for keyboard and mouse and for the controller. It has two slots per action per profile, conflict handling (Trocar, Substituir, Cancelar), and changes held as a draft until Aplicar. A change to the menu controls must be confirmed within 10 seconds (Manter controles) or it reverts. Its Câmera tab holds the camera input mode, both sensitivities, both inversions and the stick deadzone. **Ícones do controle** (Automático, Xbox, PlayStation) chooses the controller names and glyphs. Menu hints always name the current bindings in the device in use. Restaurar padrões also restores the controls.

Pause menu: Continue, Restart Stage, Options, and Return to Menu, localized into Portuguese. Pausing freezes movement, projectiles, combat timers, and active elapsed time. Losing the application window during play pauses the game, and returning to it does not resume play. Defeat offers Retry and Main Menu, indicating whether retry starts at the boss or stage entrance. Victory shows results and actions appropriate to campaign or isolated-stage mode.

Persistent combat HUD: health bar with percentage, one shield icon, bomb icons/charges, and a compact power indicator. Targets and destinations use world-space or screen-edge markers. Show score and total graze in pause/results instead of persistent combat counters; graze uses subtle light and sound feedback. During bosses, add a segmented health bar and short boss name. Briefly display attack names during transitions. Off-screen threat warnings use simple directional indicators.

Spent Shield and Bomb icons retain 25% opacity, and completed boss Phase bars retain 30% opacity.

A two-Phase boss bar expands its two segments across the full panel width with the same margins and gap as the three-Phase bar.

Credits are accessible through a small button inside Options and on the final screen, preserving the four requested main menu entries.

Every menu supports keyboard and gamepad navigation with visible selection focus. Disconnecting a controller pauses the game and permits keyboard recovery; a mouse is not required.

## 8. Initial control mapping

| Action | Keyboard | Gamepad, Xbox naming |
| --- | --- | --- |
| Forward/back/strafe | W/A/S/D | Left stick |
| Ascend/descend | Space / Left Ctrl | RB / LB |
| Rotate camera | Arrow keys; the mouse in Câmera: Mouse | Right stick |
| Recenter camera (Centralizar câmera) | R or middle mouse | Right-stick press (RS/R3) |
| Lateral dash (Impulso à esquerda/direita) | Q / E | D-pad left / right (in play) |
| Fire | Hold J | Hold RT |
| Focus | Hold Left Shift | Hold LT |
| Lock/unlock target | K | Y |
| Next target | Tab | X |
| Bomb | L | B |
| Pause | Esc | Menu/Start |
| Menu navigation | Arrows and Enter; Esc to return | D-pad or left stick, A to confirm, B to return |

Validate simultaneous ascent/descent, firing, and focus on a physical gamepad. These are the defaults. Since F16 every action above is remappable in Opções → Controles, for keyboard and mouse and for the controller separately, with Xbox or PlayStation names and glyphs.

## 9. Art, animation, and audio

Use a coherent low-poly palette: green/amber forest and blue/violet mountain. Differentiate hostile bullets, friendly shots, and pickups by shape and color. Fog and bloom must preserve dodge-path readability.

**Player ship:** one distinctive low-poly model with a compact silhouette and luminous core. Proposed appearance: a spiritual craft with origami-inspired fins, talisman details, and magical propulsion. Build it from simple forms or adapt a permitted base. Selectable ships are outside scope. Keep animation minimal: gentle movement banking, core pulses, and propulsion effects. A complex rig is unnecessary. Banking is visual only; it does not rotate the camera or modify the vulnerable volume.

The ship model keeps its authored forward orientation when the camera yaws; camera-relative shots and Familiars aim independently, while visual banking alone tilts the model.

**Bosses:** concentrate animation effort here. Each needs hover/idle, attack anticipation, execution, and defeat, with gestures or moving parts that communicate the patterns. They may share base rigs and clips but should differ in silhouette, color, and ornaments. Their animation is more elaborate than the ship's without requiring cinematics or motion capture. At least one boss must visibly animate its model beyond movement to satisfy the assignment.

**Common enemies:** geometric spirits with simple movement, reserving art effort for the ship and bosses.

Minimum audio events: route/boss music; menu navigation/confirm/back; shots; impacts; power pickup; shield pickup/break; bomb; attack warning; victory; defeat. Route and boss tracks may be shared between stages if needed. Favor energetic instrumental fantasy music.

### Asset acquisition status

Downloaded models were found in `C:/Users/Braia/Documents/touhou-3d/All models`; the four recommended sound packs were found in `all-sounds/`, and five named music files were found in `music/`. Downloaded files still require detailed inventory, visual/audio review, animation inspection, and Godot import checks. Download status does not imply that any specific model, clip, or sound has been selected or cleared for distribution.

### Sources checked on 2026-09-20

| Asset | Source and intended use | Source-stated conditions |
| --- | --- | --- |
| Ship base | [Kenney Space Kit](https://kenney.nl/assets/space-kit): select a ship and adapt colors/spiritual details | Free, CC0; science-fiction appearance needs adaptation |
| Animated bosses | [Quaternius Ultimate Monsters](https://quaternius.com/packs/ultimatemonsters.html): select two aerial guardian candidates | CC0; page lists 50 animated monsters; inspect each selected model's clips |
| Trees and rocks | [Quaternius Ultimate Nature Pack](https://quaternius.com/packs/ultimatenature.html): shared environment base | CC0; FBX, OBJ, and Blend formats |
| Humanoid boss alternative | [Quaternius Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html): adapt a rigged guardian base | CC0; partial free edition and expanded editions; check selected download contents |
| Animation alternatives | [Quaternius catalog](https://quaternius.com/): animated packs and animation library | Inspect each pack and rig compatibility |
| Menu sounds | [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | CC0 |
| Shot candidates | [Kenney Digital Audio](https://kenney.nl/assets/digital-audio) | CC0 |
| Energy/propulsion candidates | [Kenney Sci-fi Sounds](https://kenney.nl/assets/sci-fi-sounds) | CC0 |
| Impact candidates | [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | CC0 |
| Alternative music catalog | [Incompetech](https://incompetech.com/music/): audition instrumental tracks | [Creative Commons option requires attribution](https://web.incompetech.com/music/royalty-free/licenses/) |

Prefer free resources. Touhou characters or exact architecture are unnecessary. Ship details, gates, lanterns, and orbs may use simple geometry for a consistent style. If retargeting is costly, select bosses with compatible existing animation or animate their parts directly while preserving anticipation, attack, and defeat.

Record filename, creator, source link, license, and modifications when integrating each asset. Select music through listening rather than assuming suitability from catalog descriptions.

### Music references discussed after the initial draft

These compositions from *Touhou 10: Mountain of Faith* were suggested as musical references, not verified audio files ready to redistribute:

| Moment | Suggested composition |
| --- | --- |
| Main menu | Sealed Gods |
| Stage 1 route | The Gensokyo the Gods Loved |
| Stage 1 boss | Faith Is for the Transient People |
| Stage 2 route | Fall of Fall ~ Autumnal Waterfall |
| Stage 2 boss | The Venerable Ancient Battlefield ~ Suwa Foughten Field |

Use one track per route and one per boss rather than changing music for every attack. [Official Touhou fan-content guidelines](https://touhou-project.news/guidelines_en/) restrict extracted official-game assets and require permission for other creators' fan content. Identify a permitted recording or arrangement before bundling it. Academic, noncommercial status alone was not established as authorization.

## 10. Proposed technical organization

Use the existing Godot project. Inspect `project.godot` and the installed editor when implementation starts rather than assuming engine or export compatibility from this design document.

Separate responsibilities:

- **Player:** movement, camera, focus, targeting, and firing.
- **Combat state:** health, shield, bombs, power, and invulnerability.
- **Projectiles:** movement, collision, graze, lifetime, and bomb/phase cleanup.
- **Enemies and bosses:** behavior, health, and parameterized patterns.
- **Stage director:** sectors, waves, objectives, checkpoints, and transitions.
- **Session:** campaign versus isolated-stage mode, score, and stage-entry snapshots.
- **UI and settings:** menus, HUD, audio, and persistent preferences.

Patterns share configurable ring, fan, spiral, and burst emitters. Reuse projectiles and bound their count/lifetime. Check collisions along movement paths to prevent tunneling through the core between frames. Profile before increasing density.

Damage and pickup events update state and notify HUD/audio. Defeat, pause, and transitions have explicit states that prevent late damage or shooting after the attempt ends. Invalid saved settings fall back to safe defaults.

## 11. Production sequence and scope boundaries

| Date | Target milestone |
| --- | --- |
| September 20 | Design, editor/export check, flight/camera/aim prototype, test arena |
| September 21 | Combat: damage, shield, bomb, focus, graze, familiars, first boss |
| September 22 | Both playable stages, second boss, menus, settings, checkpoints |
| September 23 | Integrated art/audio, full playtests, duration and performance tuning |
| September 24 | Package verification, presentation rehearsal, delivery |

This is a working target, not a completion guarantee. Two stages with all approved systems are an aggressive scope. AI can accelerate scripts, variations, and documentation; reserve time for integration, gameplay evaluation, and physical-controller tests.

If work slips, simplify decorative density, secondary animation, and enemy variants while preserving both stages and approved mechanics. Removing approved features requires a scope discussion with the user.

Outside delivery scope: multiplayer, open world, inventory, skill trees, multiple protagonists, shops, online rankings, replays, voice acting, selectable difficulty, and three expansion stages.

## 12. Acceptance criteria

- [ ] Campaign runs from Stage 1 to final victory.
- [ ] Both stages launch directly from the menu and can be completed.
- [ ] Stage 2 provides at least five minutes of active gameplay, including an efficient-clear check without stalling.
- [ ] All-axis movement and boss orbiting materially affect dodging.
- [ ] Gameplay and menus work completely on keyboard and gamepad.
- [ ] Combat UI contains essential information only, with no tutorial boxes, written objective lists, or mandatory dialogue.
- [ ] Shield absorbs exactly one hit; post-hit invulnerability prevents cascading damage.
- [ ] Bomb consumes one charge, clears its intended volume, and cannot generate artificial graze.
- [ ] Each bullet awards at most one graze; hit detection takes precedence over proximity rewards.
- [ ] Power and familiars evolve through pickups; direct Stage 2 starts at power level 2.
- [ ] Each final boss executes three named attacks with reachable gaps; Stage 2 also includes its two-phase miniboss and three-seal challenge.
- [ ] Checkpoints restore the specified state without duplicating items, bullets, or score.
- [ ] Pause freezes combat; options persist; controller disconnection is recoverable.
- [ ] The unique ship has simple animation and bosses have more elaborate animation; at least one boss clearly animates its model.
- [ ] 3D environments, WorldEnvironment, graphical interfaces, and audio are present.
- [ ] Complete runs have no progression blockers. Performance is measured on the presentation computer with an initial target of 60 FPS.
- [ ] The exported build runs outside the editor on the target computer; the project package includes credits and licenses.
- [ ] The group has confirmed instructor approval of the chosen adaptation.

## 13. Future expansion

Preserve the five-stage vision by later adding an abandoned village, a shrine lake, and a palace above the clouds. Revisit ordering and story after delivery. The current ending should close a small two-stage story arc without requiring nonexistent content.

## 14. Engineering handoff

Astra is Lead Game Designer and authors Godot scenes, environments, camera composition, visual presentation, and integration. Claude is Lead Code Engineer and implements production GDScript and tests, refining technical decisions with applicable mattpocock skills. Read [GUIDE.md](GUIDE.md) for script attachment contracts and scene handoff states, and [ENGINEERING_BRIEF.md](ENGINEERING_BRIEF.md) for engineering requirements. [STAGE_DESIGN.md](STAGE_DESIGN.md) remains the progression source of truth. Validate pacing through playtests and preserve stable encounter IDs when creating implementation tasks.
