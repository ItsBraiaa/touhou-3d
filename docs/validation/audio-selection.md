# D-01 audio selection

The 17 event IDs below are the F13 event catalogue. Lengths are from Godot 4.7.2 after import. All selected Ogg files are byte-for-byte Kenney copies with `loop=false`; values are proposed per-event `event_volume_db` settings for `Main/Audio`.

| Event | File (res://) | Length (s) | volume_db | Why it fits |
| --- | --- | ---: | ---: | --- |
| `ui_focus` | `res://assets/audio/sfx/interface/tick_001.ogg` | 0.023 | -12.0 | Very short navigation tick; low level for frequent focus changes. |
| `ui_accept` | `res://assets/audio/sfx/interface/confirmation_001.ogg` | 0.290 | -5.0 | Distinct confirmation cue within the menu limit. |
| `player_shot` | `res://assets/audio/sfx/scifi/laserSmall_000.ogg` | 0.239 | -18.0 | Short small-laser cue; deliberately soft under continuous fire. |
| `enemy_hit` | `res://assets/audio/sfx/impact/impactGeneric_light_000.ogg` | 0.139 | -16.0 | Light impact, brief enough for repeated hits. |
| `graze` | `res://assets/audio/sfx/interface/pluck_001.ogg` | 0.102 | -22.0 | Small pluck, quieter than shots and hits. |
| `shield_broken` | `res://assets/audio/sfx/scifi/forceField_000.ogg` | 0.954 | -4.0 | Force-field cue distinguishes a shield loss from health damage. |
| `player_hit` | `res://assets/audio/sfx/impact/impactSoft_heavy_000.ogg` | 0.505 | -3.0 | Heavier impact identifies health loss. |
| `bomb_used` | `res://assets/audio/sfx/scifi/explosionCrunch_000.ogg` | 0.777 | -1.0 | Short energy explosion for the large area clear. |
| `player_defeated` | `res://assets/audio/sfx/scifi/lowFrequency_explosion_000.ogg` | 2.000 | -2.0 | Longer low-frequency ending cue, reserved for defeat. |
| `pickup_power` | `res://assets/audio/sfx/digital/phaseJump2.ogg` | 0.392 | -9.0 | Compact rising digital cue for the frequent Power pickup. |
| `pickup_shield` | `res://assets/audio/sfx/digital/phaserUp2.ogg` | 0.418 | -6.0 | Rising energy cue, distinct from Power and shield break. |
| `enemy_defeated` | `res://assets/audio/sfx/impact/impactGeneric_light_003.ogg` | 0.138 | -13.0 | A second light impact keeps common kills brief. |
| `checkpoint_activated` | `res://assets/audio/sfx/digital/phaseJump3.ogg` | 0.444 | -4.0 | Bright digital transition supports the checkpoint glow. |
| `threat_warning` | `res://assets/audio/sfx/digital/lowThreeTone.ogg` | 1.019 | 1.0 | Three-tone warning has more presence than repeated combat cues. |
| `boss_phase_changed` | `res://assets/audio/sfx/digital/phaserUp2.ogg` | 0.418 | -3.0 | Rising energy marks the next named attack. |
| `boss_defeated` | `res://assets/audio/sfx/impact/impactBell_heavy_000.ogg` | 1.480 | 0.0 | Heavy bell impact signals the boss ending. |
| `stage_cleared` | `res://assets/audio/sfx/digital/threeTone1.ogg` | 0.827 | -2.0 | Three-tone completion cue follows the boss ending. |

## Verification and listening

`tools/validate_audio_selection.gd` loaded all 17 paths as `AudioStream`, checked nonzero length, the event-specific maximum length, and `loop=false`: `AUDIO_SELECTION failures=0 events=17`. Godot's headless import exited 0 and generated an `.import` file for each of the 16 distinct clips. The runner's sandbox profile could not write its editor cache or root certificate store; the asset import and validation still completed.

The windowed `tools/validate_menu_handoff.gd` pass reported `MENU_QA_COMPLETE failures=0` and refreshed `menu-credits.png`; visual inspection found the new sound credit legible and clear of the Back button. SHA-256 comparisons against all 16 source files reported zero mismatches.

No perceptual listening pass was possible in this agent environment: audio input is unavailable. The volume values and descriptive fit are proposals based on clip names, duration and event priority. A human should audition each event in the editor before accepting the final mix, with particular attention to the threat warning and the two end cues.
