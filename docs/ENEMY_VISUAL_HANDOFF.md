# Stage 1 enemy visual variants

Date: 2026-09-21. Owner: Astra. State: SCENE_READY (visuals only).

The user approved recolor/resize variants with identical health within each enemy type. These scenes contain no health values, scripts, collision objects or gameplay changes. Do not multiply combat stats by visual scale.

| File under `scenes/enemies/visuals/` | Source | Presentation | Base pose height |
| --- | --- | --- | --- |
| `spirit_lume.tscn` | Hywirl | Cool blue/teal accents; Spirit | 2.2 |
| `spirit_twilight.tscn` | Hywirl | Lilac; same Spirit | 2.64 |
| `sentry_lantern.tscn` | Goleling | Amber with one magic ring; Sentry | 1.6 |
| `sentry_seal.tscn` | Goleling | Violet with two rings; same Sentry | 2.0 |

Height normalization uses imported mesh bounds before animation. Goleling has broad wings, so its height is intentionally lower than the humanoid Spirit. Final flight-camera scale tuning remains necessary. Original vertex/atlas colors are preserved under a material tint; recoloring is not a uniform paint replacement.

## Claude integration

Instance the selected scene as the Enemy's `VisualRoot`. Keep Enemy root, HitVolume and Emitters outside the scaled imported `Model`. Both Spirit variants share the same health configuration; both Sentry variants share the same health configuration. These visual scenes do not define hit radius; retain the gameplay type's radius across variants rather than deriving it from rendered size.

All four roots are Node3D named VisualRoot. AnimationPlayer is `Model/AnimationPlayer` relative to VisualRoot. Available clips: `Death`, `Fast_Flying`, `Flying_Idle`, `Headbutt`, `HitReact`, `No`, `Punch`, `Yes`. Flying_Idle loops and autoplays; Claude can take over playback for state transitions. No casting/contact attack is implied by an animation name. Rings are static MeshInstance3D children `MagicRing1` and, for the seal variant, `MagicRing2`.

Suggested assignment: S1-02 first wave lume and second wave twilight; S1-03 lantern sentries; S1-04 three seal sentries; S1-05 mixed spirit colors with lantern sentries. Counts and rewards stay unchanged. No models were inserted into live encounter markers: StageDirector must spawn actors once and own their cleanup.

## Verification

Godot 4.7.2 imported both source models and loaded all four scenes. Offline QA started/advanced Flying_Idle for all variants and checked that visuals have no collision components or root scripts. `docs/validation/enemy-visuals.log` records zero failures. Gallery: `scenes/tests/enemy_variants_preview.tscn` (F6), screenshot `docs/validation/enemy-variants.png`. This checks the idle pose and scene structure, not all clips or combat behavior.

Original source files remain untouched. Selected runtime copies are under `assets/models/enemies/`. Supplied CC0 license is preserved as `assets/licenses/quaternius-ultimate-monsters.txt` (its source heading says Ultimate Platformer Pack). Offline generator `tools/build_enemy_visuals.gd` rewrites only the four visual scenes; do not rerun after integration edits without reconciliation.
