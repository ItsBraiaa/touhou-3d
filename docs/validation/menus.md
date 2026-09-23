# Menu navigation validation — 2026-09-23 (F2-02)

Engine: Godot 4.7.2.stable.official.ed1daf0bf, Windows 11, D3D12 Forward+ on an AMD
Radeon RX 9070 XT. Scene under test: `scenes/main.tscn`, where `Interface` instances
Astra's eight `scenes/ui/` menus and the HUD. Contract in
[engineering/menus-session.md](../engineering/menus-session.md).

## Automated

```powershell
tools/test.ps1
```

153 passed, 0 failed. F2-02 added 15 tests in `tests/scene/test_menu_registry_contract.gd`,
11 in `tests/scene/test_interface_contract.gd`, one in `tests/unit/project/test_input_map.gd`
(the menu bindings) and one in `tests/unit/ui/test_screen_router.gd` (the focus bug below).
One `ERROR: /root/MainMenu: screen main_menu has no button at 'Layout/StartButton'` line in
the output belongs to the test that removes that button on purpose. Thirteen mutants,
listed in the module doc, each fail a named test by assertion.

## Scripted navigation pass

```powershell
tools/godot.ps1 --path . --script res://tools/validate_menus.gd
```

The tool sends key and joypad events through the root viewport, so they go through the
real `ui_*` bindings and Godot's real focus search, and checks the screen and the focused
control after each one. It printed `MENUS_OK`, headless and in a window. Until F2-04
nothing reacts to the menu actions, so the tool plays the Session's navigation part:
`open_*` opens its screen and `resume` removes Pause.

**This is not the manual pass the ticket asks for.** No person pressed a key or a pad
button, and the run printed `no joypad connected on this host`. A physical keyboard and
DualSense pass is still owed, as it is for F1.

### Every control is reachable

From each screen's initial focus, a breadth-first walk over the four arrow keys, then over
the four D-pad buttons, reached every visible focusable control: 20 of 20 cases.

| Screen | Initial focus | Controls reached (keyboard and D-pad) |
| --- | --- | --- |
| MainMenu | Iniciar | 4 of 4 |
| StageSelect | forest card | 3 of 3 |
| Options | Geral slider | 12 of 12 |
| Controls | Voltar | 1 of 1 |
| Credits | Voltar | 1 of 1 |
| PauseMenu | Continuar | 4 of 4 |
| Defeat | Tentar novamente | 2 of 2 |
| Results, Campaign Stage 1 | Continuar | 3 of 3 (Replay hidden) |
| Results, Direct Stage | Jogar novamente | 3 of 3 (Continue hidden) |
| Results, final victory | Menu principal | 2 of 2 (both hidden) |

### Walks

| Device | Steps | Result |
| --- | --- | --- |
| Keyboard | Main menu: Up, Down | on Selecionar fase; footer shown |
| Keyboard | Down, Enter on Opções | Options, on the Geral slider |
| Keyboard | Enter on Ver comandos, Escape, Escape | Controls, then Options on Ver comandos, then the main menu on Opções |
| Keyboard | Escape on the main menu | stays on Opções; `back_refused` requested |
| Keyboard | Up, Enter, Escape | StageSelect on the forest card, then the main menu on Selecionar fase |
| Gamepad | D-pad Down | on Selecionar fase; footer hidden |
| Gamepad | A, A | StageSelect with the footer still hidden; `start_direct_stage` requested |
| Gamepad | B | the main menu on Selecionar fase |
| Keyboard | Down | footer shown again |
| Keyboard | Pause over the HUD: Down, Down, Enter, Escape | Options, then Pause on Opções with the HUD under it |
| Keyboard | Escape on Pause | `resume` requested |
| Gamepad | B on Defeat | Defeat stays, on Tentar novamente; `back_refused` requested |
| Keyboard | Results (final victory): Down, Enter, Escape, Tab | Credits, then Results on Créditos with `Jornada concluída` kept; Tab goes to Menu principal, skipping the hidden buttons |

### Screenshots

| File | What it shows |
| --- | --- |
| `menus-main-keyboard.png` | Main menu after two arrow presses: gold focus on Opções, keyboard footer visible. |
| `menus-main-gamepad.png` | Main menu after the gamepad walk: focus restored on Selecionar fase, footer hidden. |
| `menus-options-entry.png` | Options on entry, focused on the Geral slider. The focus is barely visible: see finding 3. |
| `menus-pause-return.png` | Pause over the HUD after returning from Options: focus on Opções, `Pontos  4200     Graze  17`. |
| `menus-results-final.png` | Final victory: `Jornada concluída`, Continue and Replay hidden, focus on Menu principal. |

## Findings

1. **Gamepad A and B did nothing in menus.** Godot 4.7 binds the built-in `ui_accept` and
   `ui_cancel` to Enter, keypad Enter, Space and Escape only (printed from the `InputMap`).
   The first run of the tool moved focus with the D-pad but could not press a button or go
   back. Fixed in `project.godot`: A added to `ui_accept`, B to `ui_cancel`, the default
   keys kept; pinned by `test_input_map.gd`.
2. **Re-entering a screen that was already shown restored its old focus.** `show_home(MAIN_MENU)`
   from the main menu came back on the button last used instead of Iniciar, because
   `ScreenRouter` emitted `screen_hidden` after replacing its stack and the remembered focus
   landed on the new entry. The router now emits every hide before the stack changes; the
   regression test was red before the change.
3. **A focused slider is barely distinguishable.** Buttons, option buttons and the check
   button show the gold focus border; a focused `HSlider` shows only a slightly brighter
   grabber, because Godot's `Slider` never draws the theme's `HSlider/styles/focus`. Theme
   fix requested from Astra (roadmap, "Requests to Astra").
