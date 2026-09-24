# Combat visuals (D-02)

Godot 4.7.2 loaded all six resources. `tools/validate_combat_visuals.gd` reported `COMBAT_VISUALS_QA failures=0` in headless and windowed runs. It checked scene roots, scripts, collision, mesh surfaces, vertex radii and budgets, visual bounds, and animation clips. [The 1280 × 720 gallery](combat-visuals.png) was inspected against PLANEJAMENTO Section 9: player shots are cyan diamonds, hostile shots are coral spheres, Power is a gold crystal, Shield is a blue orb, and the Familiar is a smaller cyan star with a gold orbit. Their shapes remain different when color is less apparent. The Bomb is two thin cyan rings; the hostile ring remains visible through it at mid-clip. The gallery includes the ship model beside the Familiar.

| Visual | File under `scenes/combat/visuals/` | Geometry and motion |
| --- | --- | --- |
| Player Projectile | `projectile_player_mesh.tres` | Unit octahedron, 6 vertices; cyan unshaded opaque surface material. |
| Hostile Projectile | `projectile_hostile_mesh.tres` | Unit low-poly sphere, 54 vertices; coral unshaded opaque surface material. |
| Familiar | `familiar.tscn` | Radius 0.58; `VisualPivot` spins by looping, autoplay `AnimationPlayer/hover`. Root stays under weapon position control. |
| Power Pickup | `power_pickup_visual.tscn` | Radius 0.78; gold crystal and cyan halo; looping, autoplay `AnimationPlayer/float`. |
| Shield Pickup | `shield_pickup_visual.tscn` | Radius 0.76; blue orb and cyan rim; looping, autoplay `AnimationPlayer/float`. |
| Bomb | `bomb_blast_visual.tscn` | Outer radius 1.0; see-through additive rings; non-looping, autoplay `AnimationPlayer/blast` lasts 0.4 s, fades to fully hidden, with scene-local material. |

Both Projectile meshes fit the Field's spherical radius and stay below the dev sphere's 104 vertices. The five materials are original scene art in `assets/combat/`; no external asset credit is needed. These are presentation resources only, with no damage, collision, movement rule, or health value.

The focused Options slider now uses a gold `grabber_area_highlight` distinct from its unfocused teal fill. `tools/validate_menu_handoff.gd` reported zero failures, and [the recaptured Options screen](menus-options-entry.png) was inspected with the Geral slider focused: its gold fill is visible while the other three sliders stay teal.

## Integration handoff

| Consumer | Swap |
| --- | --- |
| Trunk F6-02 | Set `Main/ProjectileRoot.player_projectile_mesh` and `.hostile_projectile_mesh` to the two `.tres` meshes. |
| Trunk F6-03 | Set `PlayerShip/Weapon.familiar_scene` to `familiar.tscn`. |
| Trunk F7-02 | Instance `bomb_blast_visual.tscn` within the Bomb wrapper; scale it by `bomb_radius` and free it when `blast` finishes. |
| Path F7-03 | Instance each pickup visual as `Visual` under its existing `Pickup` root, whose collision and script remain unchanged. |
