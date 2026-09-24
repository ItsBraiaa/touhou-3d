# Closed gate visual clarity in Stages 1 and 2

Status: done
Owner: Astra
Type: scene

The closed gates do not read clearly enough as blocked passages. Keep the scene collision, Encounter IDs, gate script wiring, and opening transition intact. Strengthen Stage 1's mist and give Stage 2 a storm veil that suits its mountain shrine and wind motifs. Avoid a flat rectangle across the sky.

## Result

Stage 1 closed gates now hold thicker, slowly billowing blue mist within the torii opening. Stage 2 closed gates hold a violet storm front with moving diagonal folds and glints. Each gate's veil is centered on its own arch through an authored instance shader parameter. The visual meshes have four units of depth; collision is unchanged. Existing `Gate.set_open` and `restore_open` still control the `ClosedVisual` mesh.

Godot 4.7.2 windowed preview scripts for both stages completed with zero failures. The initial full-width fog pass looked rectangular in the rendered views and was replaced with arch-local masks. No new tests were written under the sprint rule. `tools/lane.ps1 land` remains the integration gate.
