# Stage 1 night forest and boundary rails

Status: done
Owner: Astra
Type: scene

The user requested a stronger night identity for Stage 1, fewer lanterns with a warm Japanese yellow/orange glow, removal of the pink beam into the sky, and rails on both stages that make the flight boundary clear.

## Result

Stage 1 uses a deep navy sky, subdued blue moonlight, a moon, textured moss and stone, moving foliage, forest floor details and torii roof silhouettes. Only 30 of the 90 authored lanterns remain visible; their paper bodies glow orange and local lights mark the route. The full-height closed-gate collision remains, while its visible veil fades out above the gate opening and uses blue rather than pink.

Wood rails follow both side edges of all six route sections in each stage. Stage 1 rails sit on the existing bank tops; Stage 2 rails follow the mountain terraces. The already-authored FlightBounds collision walls and flight clamp remain the physical out-of-bounds protection behind the visible rails. No script attachment, collision layer or mask changed.

## Verification

Godot 4.7.2 loaded and rendered five Stage 1 views and six Stage 2 views at 1280 x 720. tools/validate_stage_01.gd reported zero failures for seven encounters, 18 spawn markers, two checkpoints and four full-span gate shapes; tools/validate_stage_02.gd reported zero failures and visible ambient motion. No tests were written, per the sprint rule. tools/lane.ps1 land is the final integration check.
