# First Scene Validation

Date: 2026-09-20. Scope: static player/camera/arena composition only.

## Environment

- Godot: `4.7.2.stable.official.ed1daf0bf`.
- Executable: `C:/Users/Braia/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`.
- Render: D3D12 Forward+, AMD Radeon RX 9070 XT, 1280 × 720, 4× MSAA.
- Godot MCP: no callable tools found in this session; plugin catalog search also returned no Godot match. Used the local Godot executable.

## Checks performed

- Editor import completed with exit code 0. Clean rerun in `import.log`. The initial restricted run could not write Godot's normal user/editor cache; validation was rerun with approved filesystem access.
- Scene instantiated in the headless QA utility, with 10 required node paths and 3 targetable nodes present.
- The selected GLB produces a real MeshInstance3D with dimensions 2 × 0.8 × 2.1. Scene-level offset centers it correctly.
- Final rendered QA run exited 0 and wrote `arena-preview.png`; `render.log` contains no scene/script errors.
- Visually inspected the final render: ship faces into the arena, all three targets are visible, altitude differences are readable, and the core is visible after its material adjustment.
- Four script attachments contain only their base class and explicit placeholder comments.

## Reproduction

From the project root, use the executable above:

```powershell
& $godotExe --headless --path . --editor --import
& $godotExe --headless --path . --script res://tools/validate_scene_handoff.gd
& $godotExe --path . --script res://tools/validate_scene_handoff.gd
```

Set `$godotExe` to the verified executable first. The third command renders and captures the preview, then exits. Opening the project and pressing F6 on `scenes/tests/combat_arena.tscn`, or F5 with the current main-scene setting, shows the static arena.

## Not yet verified or implemented

Player movement, input bindings, focus behavior, camera following/collision, target switching, weapons, damage, graze, enemy attacks, runtime boundaries/warnings, menus, controller operation, and an exported executable are not part of this handoff. This is SCENE_READY, not CODE_READY or INTEGRATED_VERIFIED.
