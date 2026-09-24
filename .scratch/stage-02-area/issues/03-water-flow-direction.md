# Stage 2 water flow direction

Status: done
Owner: Astra
Type: scene

Stage 2 water visibly flowed toward the summit and boss arena. Make the stream and waterfall motion read downhill toward the route entrance, without changing the water geometry, color, or wave motion.

## Result

Reversed the time direction of both scrolling patterns in `assets/environment/stage_02/water.gdshader`, the shared shader used by all six streams and four waterfalls. No new tests were written under the sprint rule. `tools/lane.ps1 land` is the verification gate.