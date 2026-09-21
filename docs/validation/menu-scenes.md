# Menu Scene Validation

Date: 2026-09-20. Scope: scene composition and visual handoff.

Godot MCP is now available. Its version/project calls succeeded, create_scene created the initial main-menu root, and run_project opened the completed authored main menu. Engine: 4.7.2.stable.official.ed1daf0bf.

Local Godot imported the shared theme, three SVGs, placeholder controller, and eight scenes. Rendered QA used D3D12 Forward+ at 1280 × 720 on AMD Radeon RX 9070 XT. Both import and QA runs exited 0.

Validated scenes: main_menu, stage_select, options, controls, pause_menu, defeat, results, credits. All loaded; authored focus-next/previous targets resolve; basic label-size checks passed. All eight screenshots were visually inspected for layout, legibility, and clipping.

Evidence: `menu-import.log`, `menu-render.log`, and `menu-<scene>.png`. Final QA reported `MENU_QA_COMPLETE failures=0`.

Reproduction: run the available Godot executable with `--path <project> --script res://tools/validate_menu_handoff.gd`. Add `--headless` for resource/contract checks without screenshots. This QA helper is not part of game logic.

Not verified or implemented: initial focus, application navigation, starting a stage, exiting via button, settings application/persistence, pause behavior, controller disconnect recovery, actual gamepad operation, alternate aspect ratios, and runtime result binding. These remain Claude's script tasks under GUIDE.md Section 14. Menu scenes are SCENE_READY only.
