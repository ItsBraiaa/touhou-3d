# Retired scene generator

`build_scene_handoff.py.txt` is an archival copy of the pre-integration generator,
retired by Astra's F1 design pass. Its contents are unchanged. It is reference text,
not a tool to run or restore into `tools/`.

The authoritative files are `scenes/player/player_ship.tscn` and
`scenes/tests/combat_arena.tscn`, edited in Godot. The old generator overwrites both
and omits the integrated PlayerShip exports, `node_paths`, `motion_mode`, CameraRig
references and Targeting references. Retirement preserves that wiring without
maintaining a second scene definition. Git history retains the original tool.
