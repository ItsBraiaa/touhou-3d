# Game sound selection — 24 September 2026

Status: recommended selection, packaged for review; not applied to the game. No perceptual listening pass was possible in this environment. Measurements cannot establish whether a sound is pleasant or warnings are reliably audible.

## Coverage

All 365 individual Ogg effects decoded successfully: Digital Audio 62, Impact Sounds 130, Interface Sounds 100, Sci-fi Sounds 73. The additional Preview.ogg is a pack demonstration rather than an individual effect. Music is outside this SFX selection. All 17 selected originals are copied byte for byte under the pack folders/. Supplied pack licenses are under licenses/.

## Recommended mapping

Gains are per-event starting values, assuming unity SFX and Master buses. Intervals and voice counts are proposed settings, not current runtime behavior.

| Event | File | Seconds | Gain dB | Minimum interval s | Voices | Reason |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| ui_focus | [select_002.ogg](kenney_interface-sounds/select_002.ogg) | 0.043 | -18 | 0.12 | 1 | Replaces tick_001: 1.39% energy above 4 kHz versus 78.35%; short navigation cue. |
| ui_accept | [confirmation_001.ogg](kenney_interface-sounds/confirmation_001.ogg) | 0.290 | -12 | 0.15 | 1 | Keep the brief confirmation; lower gain for frequent menu use. |
| player_shot | [laserSmall_000.ogg](kenney_sci-fi-sounds/laserSmall_000.ogg) | 0.239 | -20 | 0.25 | 1 | Keep: short and relatively little high-frequency energy; one cue per burst, never per projectile. |
| enemy_hit | [impactGeneric_light_000.ogg](kenney_impact-sounds/impactGeneric_light_000.ogg) | 0.139 | -20 | 0.20 | 1 | Keep the short impact; at most five feedback cues per second across all enemies. |
| graze | [drop_001.ogg](kenney_interface-sounds/drop_001.ogg) | 0.110 | -26 | 0.30 | 1 | Replaces pluck_001: 1.12% energy above 4 kHz versus 36.12%; quietest recurring cue. |
| shield_broken | [forceField_000.ogg](kenney_sci-fi-sounds/forceField_000.ogg) | 0.954 | -10 | 0.30 | 1 | Keep the longer energy cue for actual shield loss only. |
| player_hit | [impactSoft_heavy_000.ogg](kenney_impact-sounds/impactSoft_heavy_000.ogg) | 0.505 | -7 | 0.30 | 1 | Keep the impact distinct from routine enemy hits; audition on small speakers because energy is bass-heavy. |
| bomb_used | [explosionCrunch_000.ogg](kenney_sci-fi-sounds/explosionCrunch_000.ogg) | 0.777 | -9 | 0.50 | 1 | Keep the explosion, lower level substantially to avoid a startling jump. |
| player_defeated | [lowFrequency_explosion_000.ogg](kenney_sci-fi-sounds/lowFrequency_explosion_000.ogg) | 2.000 | -10 | 2.50 | 1 | Keep the ending cue once per defeat; do not stack damage cues over it. |
| pickup_power | [drop_002.ogg](kenney_interface-sounds/drop_002.ogg) | 0.191 | -20 | 0.50 | 1 | Replaces phaseJump2 with a 0.191-second cue; one sound for a pickup cluster. |
| pickup_shield | [phaserUp2.ogg](kenney_digital-audio/phaserUp2.ogg) | 0.418 | -12 | 0.60 | 1 | Keep an energy cue for the less frequent shield reward. |
| enemy_defeated | [impactGeneric_light_003.ogg](kenney_impact-sounds/impactGeneric_light_003.ogg) | 0.138 | -16 | 0.25 | 1 | Keep a brief impact, slightly above ordinary hit feedback; group mass kills. |
| checkpoint_activated | [phaseJump3.ogg](kenney_digital-audio/phaseJump3.ogg) | 0.444 | -10 | 1.00 | 1 | Keep the short checkpoint cue; play only on first activation. |
| threat_warning | [twoTone2.ogg](kenney_digital-audio/twoTone2.ogg) | 0.731 | -8 | 1.50 | 1 | Replaces lowThreeTone: spectral energy centre 441 Hz instead of 90 Hz, a candidate for better small-speaker audibility; once per new threat. |
| boss_phase_changed | [phaserUp7.ogg](kenney_digital-audio/phaserUp7.ogg) | 0.366 | -10 | 1.00 | 1 | Distinct source from shield pickup; short energy transition, audition the distinction. |
| boss_defeated | [impactBell_heavy_000.ogg](kenney_impact-sounds/impactBell_heavy_000.ogg) | 1.480 | -8 | 2.00 | 1 | Keep the bell reserved for boss defeat, with room for its decay. |
| stage_cleared | [threeTone1.ogg](kenney_digital-audio/threeTone1.ogg) | 0.827 | -10 | 2.00 | 1 | Keep the completion phrase; delay until the boss bell finishes if both trigger together. |

## Rules to keep repetition unobtrusive

- Keep a global cap of 8 SFX voices; reserve priority for player damage, new threats and endings. Reject excess routine effects rather than queueing them for later.
- Shots: one voice, at most 4 starts/second. Hits: 5/second. Graze: about 3/second. Power pickups: 2/second, grouped globally across the cluster.
- A warning must describe a new threat, not repeat continuously while that threat remains alive. Cooldown alone does not ensure this.
- Avoid a separate hit and defeat effect for the same fatal hit. Suppress ordinary enemy-death sounds during a Bomb clear.
- Let the boss bell finish before the stage-complete cue. Trigger each ending once.
- No continuous engine layer, footsteps, random bleeps, or constant low-health alarm in this palette.
- Use existing SFX volume options. Check the actual game mix for summed peaks: individual-file peak measurements do not guarantee the combined mix cannot clip.

## What changed from D-01

Five replacements: ui_focus tick_001 → select_002; graze pluck_001 → drop_001; pickup_power phaseJump2 → drop_002; threat_warning lowThreeTone → twoTone2; boss_phase_changed phaserUp2 → phaserUp7. Other sources retained. Recurring effects use lower gains, longer cooldowns and one voice each.

## Listening check still needed

Play 60 seconds of held fire with hits, graze and clustered pickups at ordinary volume, then trigger shield loss and a threat. Check both headphones and laptop speakers. Repeated cues should recede into the background; threat and damage cues must remain identifiable. Repeat with SFX set low. Confirm the new graze and pickup sounds are distinguishable, and the warning communicates urgency without startling. Lower recurring cues before raising warnings. The source measurements cannot substitute for this check.

## Integration handoff

Astra selection only. The D-01 boundary excludes scripts/audio/audio_controller.gd and scenes/main.tscn. The owner of audio wiring should copy selected sources into assets/audio/sfx with loop disabled, apply the event mapping/gains in Main/Audio and interval/voice values in EVENT_RULES, and handle event coalescing at producers. The audit does not change runtime audio wiring. Selected originals now live in sound_effects/.

## Measurement method and full inventory

Files decoded with libsndfile via SoundFile. Peak and RMS are sample-domain dBFS over all channels, not LUFS or true peak. High-frequency fraction and spectral energy centre use the FFT power spectrum of the mono average over the complete clip; stereo cancellation can affect those figures. High-frequency energy is a screening aid, not a measure of annoyance. Whole-clip RMS includes tails and silence. A Vorbis decoded sample above 0 dBFS is possible and is not by itself proof of audible clipping.

| Source | Seconds | Peak dBFS | RMS dBFS | Energy >=4 kHz % | Energy centre Hz | Selected event |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| all-sounds/kenney_digital-audio/Audio/highDown.ogg | 0.5224 | -0.84 | -11.03 | 0.01 | 1287 | — |
| all-sounds/kenney_digital-audio/Audio/highUp.ogg | 0.5486 | -0.06 | -11.77 | 0.01 | 846 | — |
| all-sounds/kenney_digital-audio/Audio/laser1.ogg | 1.1004 | -0.78 | -15.07 | 0.04 | 168 | — |
| all-sounds/kenney_digital-audio/Audio/laser2.ogg | 1.0910 | -0.9 | -16.01 | 0.09 | 239 | — |
| all-sounds/kenney_digital-audio/Audio/laser3.ogg | 0.9845 | -0.83 | -16.79 | 0.04 | 164 | — |
| all-sounds/kenney_digital-audio/Audio/laser4.ogg | 1.1319 | -0.84 | -16.47 | 0.3 | 391 | — |
| all-sounds/kenney_digital-audio/Audio/laser5.ogg | 1.0137 | -1.0 | -19.83 | 2.44 | 1052 | — |
| all-sounds/kenney_digital-audio/Audio/laser6.ogg | 0.9714 | -1.11 | -18.2 | 3.16 | 1246 | — |
| all-sounds/kenney_digital-audio/Audio/laser7.ogg | 0.9329 | -0.63 | -20.04 | 8.33 | 2063 | — |
| all-sounds/kenney_digital-audio/Audio/laser8.ogg | 0.9868 | -0.1 | -20.41 | 9.32 | 2959 | — |
| all-sounds/kenney_digital-audio/Audio/laser9.ogg | 1.0094 | -1.09 | -18.79 | 2.8 | 1197 | — |
| all-sounds/kenney_digital-audio/Audio/lowDown.ogg | 0.7837 | -0.63 | -10.09 | 0.0 | 81 | — |
| all-sounds/kenney_digital-audio/Audio/lowRandom.ogg | 0.5486 | -1.01 | -10.81 | 0.0 | 124 | — |
| all-sounds/kenney_digital-audio/Audio/lowThreeTone.ogg | 1.0188 | -0.54 | -10.86 | 0.0 | 90 | — |
| all-sounds/kenney_digital-audio/Audio/pepSound1.ogg | 0.5224 | -1.01 | -12.81 | 0.0 | 289 | — |
| all-sounds/kenney_digital-audio/Audio/pepSound2.ogg | 0.5486 | -1.1 | -13.79 | 0.0 | 271 | — |
| all-sounds/kenney_digital-audio/Audio/pepSound3.ogg | 0.4441 | -0.9 | -11.24 | 0.0 | 435 | — |
| all-sounds/kenney_digital-audio/Audio/pepSound4.ogg | 0.6269 | -0.82 | -11.12 | 0.0 | 301 | — |
| all-sounds/kenney_digital-audio/Audio/pepSound5.ogg | 0.6269 | -0.96 | -13.79 | 0.0 | 666 | — |
| all-sounds/kenney_digital-audio/Audio/phaseJump1.ogg | 0.4702 | -1.25 | -15.69 | 0.0 | 358 | — |
| all-sounds/kenney_digital-audio/Audio/phaseJump2.ogg | 0.3918 | -0.79 | -13.86 | 0.0 | 513 | — |
| all-sounds/kenney_digital-audio/Audio/phaseJump3.ogg | 0.4441 | -0.49 | -17.92 | 0.0 | 554 | checkpoint_activated |
| all-sounds/kenney_digital-audio/Audio/phaseJump4.ogg | 0.4702 | -0.84 | -18.52 | 0.08 | 867 | — |
| all-sounds/kenney_digital-audio/Audio/phaseJump5.ogg | 0.4180 | 0.48 | -17.15 | 1.17 | 1388 | — |
| all-sounds/kenney_digital-audio/Audio/phaserDown1.ogg | 0.4702 | -1.04 | -15.0 | 0.14 | 752 | — |
| all-sounds/kenney_digital-audio/Audio/phaserDown2.ogg | 0.3135 | -1.31 | -18.51 | 0.01 | 586 | — |
| all-sounds/kenney_digital-audio/Audio/phaserDown3.ogg | 0.4963 | -1.06 | -15.93 | 0.02 | 546 | — |
| all-sounds/kenney_digital-audio/Audio/phaserUp1.ogg | 0.4963 | -1.25 | -17.27 | 0.0 | 473 | — |
| all-sounds/kenney_digital-audio/Audio/phaserUp2.ogg | 0.4180 | -1.29 | -17.84 | 0.02 | 618 | pickup_shield |
| all-sounds/kenney_digital-audio/Audio/phaserUp3.ogg | 0.5224 | -1.08 | -17.8 | 0.02 | 626 | — |
| all-sounds/kenney_digital-audio/Audio/phaserUp4.ogg | 0.3657 | -1.58 | -18.94 | 0.03 | 634 | — |
| all-sounds/kenney_digital-audio/Audio/phaserUp5.ogg | 0.3135 | -1.18 | -19.77 | 0.01 | 473 | — |
| all-sounds/kenney_digital-audio/Audio/phaserUp6.ogg | 0.3396 | -1.43 | -17.84 | 0.03 | 632 | — |
| all-sounds/kenney_digital-audio/Audio/phaserUp7.ogg | 0.3657 | -1.07 | -15.94 | 0.05 | 860 | boss_phase_changed |
| all-sounds/kenney_digital-audio/Audio/powerUp1.ogg | 1.2016 | -0.63 | -14.38 | 39.33 | 2535 | — |
| all-sounds/kenney_digital-audio/Audio/powerUp10.ogg | 0.6531 | -1.08 | -14.39 | 22.4 | 3552 | — |
| all-sounds/kenney_digital-audio/Audio/powerUp11.ogg | 0.6792 | -0.68 | -13.66 | 30.73 | 3009 | — |
| all-sounds/kenney_digital-audio/Audio/powerUp12.ogg | 0.8620 | -0.5 | -13.84 | 0.57 | 2147 | — |
| all-sounds/kenney_digital-audio/Audio/powerUp2.ogg | 0.4702 | -0.77 | -17.74 | 36.71 | 2618 | — |
| all-sounds/kenney_digital-audio/Audio/powerUp3.ogg | 1.1494 | -2.13 | -16.99 | 26.56 | 3251 | — |
| all-sounds/kenney_digital-audio/Audio/powerUp4.ogg | 0.5486 | -1.8 | -16.57 | 27.42 | 3314 | — |
| all-sounds/kenney_digital-audio/Audio/powerUp5.ogg | 0.4441 | -1.63 | -16.82 | 27.11 | 4063 | — |
| all-sounds/kenney_digital-audio/Audio/powerUp6.ogg | 0.4441 | -0.45 | -15.08 | 30.12 | 3098 | — |
| all-sounds/kenney_digital-audio/Audio/powerUp7.ogg | 0.5224 | -0.42 | -14.79 | 28.14 | 3247 | — |
| all-sounds/kenney_digital-audio/Audio/powerUp8.ogg | 0.5747 | -0.9 | -15.72 | 27.17 | 3231 | — |
| all-sounds/kenney_digital-audio/Audio/powerUp9.ogg | 0.5486 | -1.08 | -16.15 | 32.37 | 3432 | — |
| all-sounds/kenney_digital-audio/Audio/spaceTrash1.ogg | 1.4513 | -1.22 | -20.88 | 11.76 | 1692 | — |
| all-sounds/kenney_digital-audio/Audio/spaceTrash2.ogg | 1.4748 | -0.81 | -21.16 | 9.49 | 1365 | — |
| all-sounds/kenney_digital-audio/Audio/spaceTrash3.ogg | 1.5350 | -1.52 | -21.17 | 12.69 | 1815 | — |
| all-sounds/kenney_digital-audio/Audio/spaceTrash4.ogg | 1.4773 | -0.68 | -21.51 | 19.36 | 2247 | — |
| all-sounds/kenney_digital-audio/Audio/spaceTrash5.ogg | 1.4257 | -0.94 | -22.15 | 13.42 | 1818 | — |
| all-sounds/kenney_digital-audio/Audio/threeTone1.ogg | 0.8271 | -1.02 | -12.01 | 0.0 | 290 | stage_cleared |
| all-sounds/kenney_digital-audio/Audio/threeTone2.ogg | 0.8658 | -1.36 | -14.48 | 0.3 | 556 | — |
| all-sounds/kenney_digital-audio/Audio/tone1.ogg | 0.6607 | -1.07 | -17.22 | 0.02 | 373 | — |
| all-sounds/kenney_digital-audio/Audio/twoTone1.ogg | 0.7238 | -1.08 | -14.51 | 0.02 | 376 | — |
| all-sounds/kenney_digital-audio/Audio/twoTone2.ogg | 0.7312 | -1.66 | -15.05 | 0.24 | 441 | threat_warning |
| all-sounds/kenney_digital-audio/Audio/zap1.ogg | 1.0188 | 0.13 | -12.19 | 0.28 | 506 | — |
| all-sounds/kenney_digital-audio/Audio/zap2.ogg | 1.2278 | -0.48 | -10.61 | 0.12 | 326 | — |
| all-sounds/kenney_digital-audio/Audio/zapThreeToneDown.ogg | 1.3322 | -0.37 | -9.02 | 0.09 | 305 | — |
| all-sounds/kenney_digital-audio/Audio/zapThreeToneUp.ogg | 1.2016 | -0.06 | -10.13 | 0.11 | 345 | — |
| all-sounds/kenney_digital-audio/Audio/zapTwoTone.ogg | 1.3061 | -0.57 | -10.16 | 0.15 | 363 | — |
| all-sounds/kenney_digital-audio/Audio/zapTwoTone2.ogg | 1.2016 | -0.62 | -11.81 | 0.45 | 565 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_carpet_000.ogg | 0.1448 | -1.09 | -23.05 | 0.28 | 321 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_carpet_001.ogg | 0.1448 | -1.12 | -19.71 | 1.14 | 423 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_carpet_002.ogg | 0.1448 | -1.12 | -19.71 | 1.14 | 423 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_carpet_003.ogg | 0.1448 | -1.15 | -22.94 | 0.15 | 284 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_carpet_004.ogg | 0.1448 | -1.15 | -22.94 | 0.15 | 284 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_concrete_000.ogg | 0.1059 | -0.93 | -20.97 | 0.0 | 208 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_concrete_001.ogg | 0.1076 | -1.21 | -22.48 | 0.3 | 248 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_concrete_002.ogg | 0.1128 | -0.99 | -22.78 | 0.24 | 263 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_concrete_003.ogg | 0.1105 | -1.08 | -21.77 | 0.02 | 219 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_concrete_004.ogg | 0.1144 | -1.0 | -21.27 | 0.0 | 220 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_grass_000.ogg | 0.7776 | -1.06 | -29.88 | 0.09 | 245 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_grass_001.ogg | 0.6736 | -1.19 | -28.83 | 0.91 | 428 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_grass_002.ogg | 0.6924 | -1.05 | -29.49 | 0.7 | 402 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_grass_003.ogg | 0.6693 | -0.93 | -29.46 | 0.08 | 237 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_grass_004.ogg | 0.5902 | -1.09 | -28.53 | 0.1 | 243 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_snow_000.ogg | 0.3742 | -0.88 | -22.35 | 0.81 | 502 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_snow_001.ogg | 0.3742 | -1.01 | -18.71 | 0.23 | 301 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_snow_002.ogg | 0.3742 | -0.96 | -18.8 | 0.16 | 253 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_snow_003.ogg | 0.3742 | -0.91 | -23.06 | 0.22 | 284 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_snow_004.ogg | 0.3742 | -1.05 | -21.89 | 0.21 | 236 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_wood_000.ogg | 0.2496 | -0.92 | -20.79 | 0.0 | 102 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_wood_001.ogg | 0.2516 | -1.0 | -20.08 | 0.0 | 108 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_wood_002.ogg | 0.2514 | -0.9 | -19.47 | 0.0 | 95 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_wood_003.ogg | 0.2515 | -1.08 | -21.53 | 0.0 | 103 | — |
| all-sounds/kenney_impact-sounds/Audio/footstep_wood_004.ogg | 0.2479 | -0.96 | -19.57 | 0.0 | 87 | — |
| all-sounds/kenney_impact-sounds/Audio/impactBell_heavy_000.ogg | 1.4802 | -1.14 | -26.26 | 0.01 | 448 | boss_defeated |
| all-sounds/kenney_impact-sounds/Audio/impactBell_heavy_001.ogg | 1.7409 | -1.16 | -24.57 | 0.01 | 330 | — |
| all-sounds/kenney_impact-sounds/Audio/impactBell_heavy_002.ogg | 0.6973 | -0.79 | -23.82 | 0.01 | 310 | — |
| all-sounds/kenney_impact-sounds/Audio/impactBell_heavy_003.ogg | 0.6536 | -1.01 | -24.57 | 0.02 | 405 | — |
| all-sounds/kenney_impact-sounds/Audio/impactBell_heavy_004.ogg | 0.3015 | -1.14 | -22.29 | 0.01 | 231 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGeneric_light_000.ogg | 0.1387 | -1.24 | -20.33 | 0.06 | 439 | enemy_hit |
| all-sounds/kenney_impact-sounds/Audio/impactGeneric_light_001.ogg | 0.1175 | -1.0 | -20.1 | 0.07 | 325 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGeneric_light_002.ogg | 0.1396 | -0.97 | -20.58 | 0.1 | 417 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGeneric_light_003.ogg | 0.1380 | -1.13 | -20.71 | 0.07 | 346 | enemy_defeated |
| all-sounds/kenney_impact-sounds/Audio/impactGeneric_light_004.ogg | 0.1403 | -0.94 | -20.56 | 0.08 | 366 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGlass_heavy_000.ogg | 0.2412 | -1.08 | -22.44 | 0.01 | 253 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGlass_heavy_001.ogg | 0.4290 | -0.96 | -25.27 | 0.01 | 268 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGlass_heavy_002.ogg | 0.2472 | -0.92 | -23.16 | 0.01 | 224 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGlass_heavy_003.ogg | 0.1715 | -0.93 | -19.62 | 0.01 | 354 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGlass_heavy_004.ogg | 0.3992 | -1.24 | -24.15 | 0.01 | 221 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGlass_light_000.ogg | 0.2096 | -1.56 | -21.36 | 0.14 | 1490 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGlass_light_001.ogg | 0.2096 | -0.9 | -21.36 | 0.06 | 1693 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGlass_light_002.ogg | 0.2096 | -1.18 | -19.99 | 0.75 | 1526 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGlass_light_003.ogg | 0.2096 | -1.08 | -21.07 | 0.11 | 1470 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGlass_light_004.ogg | 0.2096 | -0.82 | -20.53 | 0.2 | 1308 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGlass_medium_000.ogg | 0.5434 | -1.16 | -25.45 | 0.04 | 494 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGlass_medium_001.ogg | 0.5434 | -0.91 | -25.27 | 0.12 | 581 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGlass_medium_002.ogg | 0.5434 | -1.01 | -25.65 | 0.03 | 421 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGlass_medium_003.ogg | 0.5434 | -1.26 | -25.57 | 0.11 | 603 | — |
| all-sounds/kenney_impact-sounds/Audio/impactGlass_medium_004.ogg | 0.5434 | -1.38 | -24.56 | 0.03 | 757 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMetal_heavy_000.ogg | 0.1677 | -0.93 | -20.5 | 2.77 | 322 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMetal_heavy_001.ogg | 0.3593 | -1.09 | -23.62 | 3.53 | 372 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMetal_heavy_002.ogg | 0.1173 | -1.19 | -18.74 | 0.19 | 346 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMetal_heavy_003.ogg | 0.2069 | -0.98 | -21.28 | 0.09 | 356 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMetal_heavy_004.ogg | 0.1338 | -1.28 | -19.51 | 0.05 | 290 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMetal_light_000.ogg | 0.3515 | -0.96 | -20.81 | 10.63 | 2625 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMetal_light_001.ogg | 0.2518 | -0.95 | -20.04 | 0.24 | 2333 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMetal_light_002.ogg | 0.2358 | -1.38 | -20.61 | 30.6 | 2894 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMetal_light_003.ogg | 0.4820 | -1.48 | -20.74 | 31.27 | 2940 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMetal_light_004.ogg | 0.2134 | -1.29 | -20.67 | 0.24 | 2371 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMetal_medium_000.ogg | 0.2718 | -1.16 | -21.6 | 0.32 | 1090 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMetal_medium_001.ogg | 0.1434 | -1.22 | -19.61 | 0.15 | 897 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMetal_medium_002.ogg | 0.1191 | -1.09 | -21.2 | 0.03 | 791 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMetal_medium_003.ogg | 0.2540 | -1.45 | -21.78 | 7.5 | 1171 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMetal_medium_004.ogg | 0.1094 | -1.03 | -20.52 | 0.1 | 874 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMining_000.ogg | 0.9374 | -1.06 | -20.59 | 0.16 | 128 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMining_001.ogg | 0.8694 | -1.0 | -21.06 | 0.29 | 166 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMining_002.ogg | 0.8047 | -1.19 | -22.91 | 0.19 | 171 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMining_003.ogg | 0.9917 | -1.02 | -23.41 | 0.18 | 174 | — |
| all-sounds/kenney_impact-sounds/Audio/impactMining_004.ogg | 0.8303 | -0.91 | -19.76 | 0.15 | 107 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlank_medium_000.ogg | 0.7790 | -1.22 | -23.88 | 0.16 | 199 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlank_medium_001.ogg | 0.7790 | -1.01 | -20.63 | 0.06 | 156 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlank_medium_002.ogg | 0.7790 | -0.97 | -20.99 | 0.09 | 165 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlank_medium_003.ogg | 0.7790 | -1.0 | -21.66 | 0.07 | 172 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlank_medium_004.ogg | 0.7790 | -0.95 | -25.22 | 0.4 | 267 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlate_heavy_000.ogg | 0.4887 | -0.97 | -22.63 | 2.38 | 464 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlate_heavy_001.ogg | 0.3523 | -0.88 | -17.42 | 0.77 | 163 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlate_heavy_002.ogg | 0.4942 | -1.44 | -21.79 | 2.09 | 442 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlate_heavy_003.ogg | 0.3466 | -1.15 | -17.85 | 0.69 | 172 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlate_heavy_004.ogg | 0.5591 | -0.6 | -21.66 | 1.63 | 299 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlate_light_000.ogg | 0.5424 | -1.0 | -25.46 | 6.31 | 978 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlate_light_001.ogg | 0.6547 | -1.32 | -27.37 | 8.85 | 1308 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlate_light_002.ogg | 0.4888 | -0.93 | -25.25 | 7.23 | 1194 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlate_light_003.ogg | 0.5276 | -1.16 | -24.45 | 7.18 | 1258 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlate_light_004.ogg | 0.6566 | -1.32 | -26.33 | 8.53 | 1301 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlate_medium_000.ogg | 0.6093 | -1.35 | -25.59 | 3.43 | 659 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlate_medium_001.ogg | 0.6162 | -1.08 | -24.41 | 3.65 | 728 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlate_medium_002.ogg | 0.5152 | -1.09 | -24.2 | 2.46 | 591 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlate_medium_003.ogg | 0.6537 | -1.22 | -22.26 | 2.01 | 395 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPlate_medium_004.ogg | 0.5343 | -1.03 | -21.71 | 1.67 | 401 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPunch_heavy_000.ogg | 0.6490 | -0.97 | -17.98 | 0.0 | 121 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPunch_heavy_001.ogg | 0.5359 | -1.18 | -17.48 | 0.01 | 140 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPunch_heavy_002.ogg | 0.4575 | -0.97 | -16.59 | 0.0 | 122 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPunch_heavy_003.ogg | 0.4738 | -0.89 | -17.16 | 0.01 | 142 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPunch_heavy_004.ogg | 0.5363 | -0.97 | -17.37 | 0.0 | 131 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPunch_medium_000.ogg | 0.4305 | -1.11 | -17.18 | 0.0 | 173 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPunch_medium_001.ogg | 0.4046 | -1.14 | -16.9 | 0.0 | 188 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPunch_medium_002.ogg | 0.5414 | -0.85 | -18.72 | 0.04 | 204 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPunch_medium_003.ogg | 0.4553 | -0.94 | -18.22 | 0.01 | 206 | — |
| all-sounds/kenney_impact-sounds/Audio/impactPunch_medium_004.ogg | 0.5429 | -1.0 | -18.57 | 0.0 | 187 | — |
| all-sounds/kenney_impact-sounds/Audio/impactSoft_heavy_000.ogg | 0.5051 | -0.92 | -17.23 | 0.0 | 84 | player_hit |
| all-sounds/kenney_impact-sounds/Audio/impactSoft_heavy_001.ogg | 0.5720 | -0.97 | -17.45 | 0.0 | 78 | — |
| all-sounds/kenney_impact-sounds/Audio/impactSoft_heavy_002.ogg | 0.5723 | -0.88 | -17.16 | 0.0 | 78 | — |
| all-sounds/kenney_impact-sounds/Audio/impactSoft_heavy_003.ogg | 0.5442 | -1.01 | -16.58 | 0.0 | 61 | — |
| all-sounds/kenney_impact-sounds/Audio/impactSoft_heavy_004.ogg | 0.5010 | -1.0 | -16.84 | 0.0 | 75 | — |
| all-sounds/kenney_impact-sounds/Audio/impactSoft_medium_000.ogg | 0.1180 | -0.96 | -14.33 | 0.0 | 87 | — |
| all-sounds/kenney_impact-sounds/Audio/impactSoft_medium_001.ogg | 0.1833 | -0.93 | -14.92 | 0.0 | 72 | — |
| all-sounds/kenney_impact-sounds/Audio/impactSoft_medium_002.ogg | 0.1352 | -0.99 | -14.21 | 0.0 | 73 | — |
| all-sounds/kenney_impact-sounds/Audio/impactSoft_medium_003.ogg | 0.1402 | -0.95 | -14.33 | 0.0 | 74 | — |
| all-sounds/kenney_impact-sounds/Audio/impactSoft_medium_004.ogg | 0.1471 | -0.96 | -14.52 | 0.0 | 78 | — |
| all-sounds/kenney_impact-sounds/Audio/impactTin_medium_000.ogg | 0.1587 | -0.96 | -20.93 | 0.12 | 409 | — |
| all-sounds/kenney_impact-sounds/Audio/impactTin_medium_001.ogg | 0.1743 | -1.49 | -22.59 | 0.14 | 467 | — |
| all-sounds/kenney_impact-sounds/Audio/impactTin_medium_002.ogg | 0.1338 | -1.11 | -21.58 | 0.18 | 447 | — |
| all-sounds/kenney_impact-sounds/Audio/impactTin_medium_003.ogg | 0.2146 | -1.1 | -23.19 | 0.14 | 473 | — |
| all-sounds/kenney_impact-sounds/Audio/impactTin_medium_004.ogg | 0.1785 | -1.21 | -22.56 | 0.15 | 502 | — |
| all-sounds/kenney_impact-sounds/Audio/impactWood_heavy_000.ogg | 0.3130 | -0.94 | -19.64 | 0.0 | 90 | — |
| all-sounds/kenney_impact-sounds/Audio/impactWood_heavy_001.ogg | 0.3130 | -0.93 | -19.75 | 0.0 | 96 | — |
| all-sounds/kenney_impact-sounds/Audio/impactWood_heavy_002.ogg | 0.3130 | -0.97 | -18.95 | 0.0 | 71 | — |
| all-sounds/kenney_impact-sounds/Audio/impactWood_heavy_003.ogg | 0.3130 | -0.92 | -20.43 | 0.0 | 113 | — |
| all-sounds/kenney_impact-sounds/Audio/impactWood_heavy_004.ogg | 0.3130 | -0.96 | -20.15 | 0.0 | 106 | — |
| all-sounds/kenney_impact-sounds/Audio/impactWood_light_000.ogg | 0.2656 | -1.12 | -22.31 | 0.02 | 330 | — |
| all-sounds/kenney_impact-sounds/Audio/impactWood_light_001.ogg | 0.2656 | -0.94 | -24.06 | 0.0 | 272 | — |
| all-sounds/kenney_impact-sounds/Audio/impactWood_light_002.ogg | 0.2656 | -1.12 | -22.09 | 0.02 | 308 | — |
| all-sounds/kenney_impact-sounds/Audio/impactWood_light_003.ogg | 0.2656 | -0.93 | -23.75 | 0.0 | 243 | — |
| all-sounds/kenney_impact-sounds/Audio/impactWood_light_004.ogg | 0.2656 | -1.19 | -24.72 | 0.0 | 331 | — |
| all-sounds/kenney_impact-sounds/Audio/impactWood_medium_000.ogg | 0.3327 | -1.03 | -22.6 | 0.0 | 188 | — |
| all-sounds/kenney_impact-sounds/Audio/impactWood_medium_001.ogg | 0.3327 | -1.05 | -22.55 | 0.0 | 180 | — |
| all-sounds/kenney_impact-sounds/Audio/impactWood_medium_002.ogg | 0.3327 | -1.08 | -22.62 | 0.01 | 231 | — |
| all-sounds/kenney_impact-sounds/Audio/impactWood_medium_003.ogg | 0.3327 | -1.04 | -22.74 | 0.0 | 206 | — |
| all-sounds/kenney_impact-sounds/Audio/impactWood_medium_004.ogg | 0.3327 | -1.13 | -22.16 | 0.01 | 195 | — |
| all-sounds/kenney_interface-sounds/Audio/back_001.ogg | 0.0639 | -0.96 | -21.45 | 4.73 | 1525 | — |
| all-sounds/kenney_interface-sounds/Audio/back_002.ogg | 0.0698 | -0.96 | -15.85 | 0.1 | 381 | — |
| all-sounds/kenney_interface-sounds/Audio/back_003.ogg | 0.0929 | -0.9 | -19.74 | 6.59 | 1301 | — |
| all-sounds/kenney_interface-sounds/Audio/back_004.ogg | 0.0730 | -0.94 | -16.67 | 0.12 | 461 | — |
| all-sounds/kenney_interface-sounds/Audio/bong_001.ogg | 0.1228 | -0.89 | -16.31 | 0.0 | 208 | — |
| all-sounds/kenney_interface-sounds/Audio/click_001.ogg | 0.1000 | -1.35 | -26.52 | 11.5 | 1604 | — |
| all-sounds/kenney_interface-sounds/Audio/click_002.ogg | 0.0100 | -0.85 | -15.52 | 0.9 | 1961 | — |
| all-sounds/kenney_interface-sounds/Audio/click_003.ogg | 0.0100 | -1.36 | -16.02 | 0.61 | 2161 | — |
| all-sounds/kenney_interface-sounds/Audio/click_004.ogg | 0.0100 | -1.23 | -15.26 | 58.65 | 8310 | — |
| all-sounds/kenney_interface-sounds/Audio/click_005.ogg | 0.0100 | -1.22 | -12.96 | 1.07 | 496 | — |
| all-sounds/kenney_interface-sounds/Audio/close_001.ogg | 0.1478 | -0.92 | -14.77 | 96.76 | 12785 | — |
| all-sounds/kenney_interface-sounds/Audio/close_002.ogg | 0.3138 | -1.03 | -16.36 | 79.11 | 8747 | — |
| all-sounds/kenney_interface-sounds/Audio/close_003.ogg | 0.3138 | -0.92 | -15.15 | 87.06 | 10984 | — |
| all-sounds/kenney_interface-sounds/Audio/close_004.ogg | 0.3229 | -1.01 | -17.36 | 90.85 | 13070 | — |
| all-sounds/kenney_interface-sounds/Audio/confirmation_001.ogg | 0.2898 | -0.93 | -11.31 | 0.0 | 502 | ui_accept |
| all-sounds/kenney_interface-sounds/Audio/confirmation_002.ogg | 0.5390 | -0.96 | -14.88 | 4.17 | 1847 | — |
| all-sounds/kenney_interface-sounds/Audio/confirmation_003.ogg | 0.3220 | -0.98 | -15.22 | 5.46 | 2549 | — |
| all-sounds/kenney_interface-sounds/Audio/confirmation_004.ogg | 0.4904 | -0.91 | -11.78 | 0.0 | 1201 | — |
| all-sounds/kenney_interface-sounds/Audio/drop_001.ogg | 0.1098 | -0.89 | -20.38 | 1.12 | 1551 | graze |
| all-sounds/kenney_interface-sounds/Audio/drop_002.ogg | 0.1911 | -1.06 | -19.83 | 0.0 | 713 | pickup_power |
| all-sounds/kenney_interface-sounds/Audio/drop_003.ogg | 0.1911 | -1.11 | -19.67 | 0.0 | 690 | — |
| all-sounds/kenney_interface-sounds/Audio/drop_004.ogg | 0.2867 | -0.86 | -20.7 | 0.0 | 642 | — |
| all-sounds/kenney_interface-sounds/Audio/error_001.ogg | 0.1646 | -0.8 | -19.07 | 32.41 | 4554 | — |
| all-sounds/kenney_interface-sounds/Audio/error_002.ogg | 0.1646 | 0.58 | -17.52 | 51.68 | 6643 | — |
| all-sounds/kenney_interface-sounds/Audio/error_003.ogg | 0.5335 | -0.5 | -20.04 | 18.28 | 2666 | — |
| all-sounds/kenney_interface-sounds/Audio/error_004.ogg | 0.1027 | -1.25 | -16.3 | 4.46 | 996 | — |
| all-sounds/kenney_interface-sounds/Audio/error_005.ogg | 0.5000 | -0.96 | -18.74 | 0.04 | 102 | — |
| all-sounds/kenney_interface-sounds/Audio/error_006.ogg | 0.5000 | -0.78 | -18.0 | 0.13 | 179 | — |
| all-sounds/kenney_interface-sounds/Audio/error_007.ogg | 0.1920 | -0.89 | -13.09 | 2.19 | 570 | — |
| all-sounds/kenney_interface-sounds/Audio/error_008.ogg | 0.1393 | -0.96 | -20.55 | 0.69 | 408 | — |
| all-sounds/kenney_interface-sounds/Audio/glass_001.ogg | 0.2784 | -1.03 | -20.09 | 0.03 | 1889 | — |
| all-sounds/kenney_interface-sounds/Audio/glass_002.ogg | 0.1253 | -1.04 | -19.04 | 0.05 | 1953 | — |
| all-sounds/kenney_interface-sounds/Audio/glass_003.ogg | 0.1237 | -0.95 | -16.36 | 0.07 | 1811 | — |
| all-sounds/kenney_interface-sounds/Audio/glass_004.ogg | 0.6923 | -1.12 | -17.97 | 99.93 | 7336 | — |
| all-sounds/kenney_interface-sounds/Audio/glass_005.ogg | 0.1108 | -0.93 | -19.81 | 13.81 | 2518 | — |
| all-sounds/kenney_interface-sounds/Audio/glass_006.ogg | 0.1108 | -0.98 | -18.65 | 0.08 | 1594 | — |
| all-sounds/kenney_interface-sounds/Audio/glitch_001.ogg | 0.0200 | -0.99 | -10.08 | 2.54 | 434 | — |
| all-sounds/kenney_interface-sounds/Audio/glitch_002.ogg | 0.0300 | -1.16 | -13.98 | 17.37 | 1388 | — |
| all-sounds/kenney_interface-sounds/Audio/glitch_003.ogg | 0.0100 | -0.5 | -11.62 | 36.61 | 3960 | — |
| all-sounds/kenney_interface-sounds/Audio/glitch_004.ogg | 0.0229 | -0.93 | -16.16 | 66.05 | 4104 | — |
| all-sounds/kenney_interface-sounds/Audio/maximize_001.ogg | 0.2584 | -0.97 | -13.01 | 69.87 | 4614 | — |
| all-sounds/kenney_interface-sounds/Audio/maximize_002.ogg | 0.2583 | -0.92 | -10.29 | 70.98 | 5288 | — |
| all-sounds/kenney_interface-sounds/Audio/maximize_003.ogg | 0.2119 | -0.95 | -20.26 | 78.95 | 6010 | — |
| all-sounds/kenney_interface-sounds/Audio/maximize_004.ogg | 0.4180 | -0.94 | -15.15 | 78.87 | 10173 | — |
| all-sounds/kenney_interface-sounds/Audio/maximize_005.ogg | 0.5264 | -0.91 | -16.55 | 91.97 | 7126 | — |
| all-sounds/kenney_interface-sounds/Audio/maximize_006.ogg | 0.3800 | -0.93 | -14.2 | 0.0 | 343 | — |
| all-sounds/kenney_interface-sounds/Audio/maximize_007.ogg | 0.1858 | -0.98 | -13.64 | 0.02 | 2228 | — |
| all-sounds/kenney_interface-sounds/Audio/maximize_008.ogg | 0.2254 | -0.91 | -12.71 | 0.0 | 344 | — |
| all-sounds/kenney_interface-sounds/Audio/maximize_009.ogg | 0.2248 | -0.93 | -10.62 | 0.0 | 1250 | — |
| all-sounds/kenney_interface-sounds/Audio/minimize_001.ogg | 0.2584 | -0.93 | -13.01 | 69.88 | 4614 | — |
| all-sounds/kenney_interface-sounds/Audio/minimize_002.ogg | 0.2583 | -0.9 | -10.3 | 71.15 | 5292 | — |
| all-sounds/kenney_interface-sounds/Audio/minimize_003.ogg | 0.2119 | -1.0 | -20.26 | 78.93 | 6013 | — |
| all-sounds/kenney_interface-sounds/Audio/minimize_004.ogg | 0.4180 | -0.94 | -15.15 | 78.8 | 10169 | — |
| all-sounds/kenney_interface-sounds/Audio/minimize_005.ogg | 0.5264 | -0.82 | -16.55 | 91.98 | 7127 | — |
| all-sounds/kenney_interface-sounds/Audio/minimize_006.ogg | 0.3800 | -0.96 | -14.18 | 0.0 | 344 | — |
| all-sounds/kenney_interface-sounds/Audio/minimize_007.ogg | 0.1858 | -0.95 | -13.64 | 0.02 | 2228 | — |
| all-sounds/kenney_interface-sounds/Audio/minimize_008.ogg | 0.2254 | -0.94 | -12.73 | 0.0 | 344 | — |
| all-sounds/kenney_interface-sounds/Audio/minimize_009.ogg | 0.2248 | -0.93 | -10.63 | 0.0 | 1250 | — |
| all-sounds/kenney_interface-sounds/Audio/open_001.ogg | 0.1478 | -0.86 | -14.78 | 96.76 | 12784 | — |
| all-sounds/kenney_interface-sounds/Audio/open_002.ogg | 0.3138 | -0.92 | -16.36 | 79.03 | 8743 | — |
| all-sounds/kenney_interface-sounds/Audio/open_003.ogg | 0.3138 | -0.97 | -15.16 | 87.06 | 10979 | — |
| all-sounds/kenney_interface-sounds/Audio/open_004.ogg | 0.3229 | -0.95 | -17.37 | 90.86 | 13066 | — |
| all-sounds/kenney_interface-sounds/Audio/pluck_001.ogg | 0.1024 | 0.43 | -20.56 | 36.12 | 4888 | — |
| all-sounds/kenney_interface-sounds/Audio/pluck_002.ogg | 0.1646 | -0.46 | -21.82 | 35.73 | 5054 | — |
| all-sounds/kenney_interface-sounds/Audio/question_001.ogg | 0.4907 | -0.9 | -11.77 | 0.0 | 1479 | — |
| all-sounds/kenney_interface-sounds/Audio/question_002.ogg | 0.3325 | -0.91 | -10.02 | 0.0 | 751 | — |
| all-sounds/kenney_interface-sounds/Audio/question_003.ogg | 0.3325 | -0.94 | -10.05 | 0.0 | 2151 | — |
| all-sounds/kenney_interface-sounds/Audio/question_004.ogg | 0.3325 | -0.94 | -10.05 | 0.0 | 492 | — |
| all-sounds/kenney_interface-sounds/Audio/scratch_001.ogg | 0.1393 | -0.92 | -12.29 | 36.17 | 4750 | — |
| all-sounds/kenney_interface-sounds/Audio/scratch_002.ogg | 0.1393 | -1.01 | -11.66 | 80.44 | 6097 | — |
| all-sounds/kenney_interface-sounds/Audio/scratch_003.ogg | 0.1234 | -0.98 | -18.1 | 80.73 | 12911 | — |
| all-sounds/kenney_interface-sounds/Audio/scratch_004.ogg | 0.3251 | -0.96 | -20.48 | 41.59 | 4596 | — |
| all-sounds/kenney_interface-sounds/Audio/scratch_005.ogg | 0.3251 | -0.99 | -15.38 | 54.02 | 4894 | — |
| all-sounds/kenney_interface-sounds/Audio/scroll_001.ogg | 1.0000 | -0.86 | -21.23 | 70.36 | 9603 | — |
| all-sounds/kenney_interface-sounds/Audio/scroll_002.ogg | 1.0000 | -0.92 | -21.97 | 0.13 | 527 | — |
| all-sounds/kenney_interface-sounds/Audio/scroll_003.ogg | 1.0000 | -0.93 | -21.89 | 2.23 | 1450 | — |
| all-sounds/kenney_interface-sounds/Audio/scroll_004.ogg | 1.0000 | -0.9 | -20.11 | 34.14 | 4004 | — |
| all-sounds/kenney_interface-sounds/Audio/scroll_005.ogg | 1.0000 | -0.92 | -18.03 | 20.06 | 2951 | — |
| all-sounds/kenney_interface-sounds/Audio/select_001.ogg | 0.0433 | -1.13 | -17.63 | 2.45 | 2440 | — |
| all-sounds/kenney_interface-sounds/Audio/select_002.ogg | 0.0433 | -0.97 | -16.18 | 1.39 | 1229 | ui_focus |
| all-sounds/kenney_interface-sounds/Audio/select_003.ogg | 0.3828 | -0.82 | -18.8 | 20.15 | 3098 | — |
| all-sounds/kenney_interface-sounds/Audio/select_004.ogg | 0.3828 | -0.73 | -19.23 | 0.93 | 2031 | — |
| all-sounds/kenney_interface-sounds/Audio/select_005.ogg | 0.3828 | -1.32 | -18.72 | 0.35 | 1290 | — |
| all-sounds/kenney_interface-sounds/Audio/select_006.ogg | 1.9439 | -0.77 | -22.48 | 0.01 | 533 | — |
| all-sounds/kenney_interface-sounds/Audio/select_007.ogg | 0.0469 | -0.96 | -13.63 | 30.3 | 3468 | — |
| all-sounds/kenney_interface-sounds/Audio/select_008.ogg | 0.0469 | -1.0 | -19.14 | 90.61 | 9349 | — |
| all-sounds/kenney_interface-sounds/Audio/switch_001.ogg | 0.6177 | -0.95 | -27.35 | 84.75 | 4402 | — |
| all-sounds/kenney_interface-sounds/Audio/switch_002.ogg | 0.6110 | -0.95 | -25.06 | 0.89 | 1008 | — |
| all-sounds/kenney_interface-sounds/Audio/switch_003.ogg | 0.5000 | -0.91 | -15.3 | 0.57 | 234 | — |
| all-sounds/kenney_interface-sounds/Audio/switch_004.ogg | 0.5000 | -0.96 | -23.88 | 10.76 | 1153 | — |
| all-sounds/kenney_interface-sounds/Audio/switch_005.ogg | 0.6119 | -0.91 | -22.63 | 0.61 | 135 | — |
| all-sounds/kenney_interface-sounds/Audio/switch_006.ogg | 0.6105 | -0.92 | -24.6 | 1.01 | 286 | — |
| all-sounds/kenney_interface-sounds/Audio/switch_007.ogg | 0.6144 | -0.95 | -25.02 | 0.3 | 754 | — |
| all-sounds/kenney_interface-sounds/Audio/tick_001.ogg | 0.0232 | -0.8 | -18.61 | 78.35 | 10844 | — |
| all-sounds/kenney_interface-sounds/Audio/tick_002.ogg | 0.0232 | -1.21 | -17.22 | 73.83 | 9068 | — |
| all-sounds/kenney_interface-sounds/Audio/tick_004.ogg | 0.0548 | -0.85 | -15.84 | 3.0 | 3450 | — |
| all-sounds/kenney_interface-sounds/Audio/toggle_001.ogg | 0.1393 | -0.91 | -14.11 | 8.13 | 2003 | — |
| all-sounds/kenney_interface-sounds/Audio/toggle_002.ogg | 0.1393 | -0.95 | -12.18 | 14.1 | 2534 | — |
| all-sounds/kenney_interface-sounds/Audio/toggle_003.ogg | 0.1393 | -0.94 | -14.32 | 57.2 | 6501 | — |
| all-sounds/kenney_interface-sounds/Audio/toggle_004.ogg | 0.0662 | -0.94 | -16.46 | 15.4 | 2885 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/computerNoise_000.ogg | 5.0000 | -0.99 | -7.65 | 0.06 | 1117 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/computerNoise_001.ogg | 5.0000 | -0.95 | -8.89 | 0.07 | 1056 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/computerNoise_002.ogg | 5.0000 | -0.93 | -11.45 | 0.29 | 882 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/computerNoise_003.ogg | 5.0000 | -0.98 | -11.27 | 0.3 | 876 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/doorClose_000.ogg | 0.5316 | -0.86 | -17.6 | 96.56 | 13119 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/doorClose_001.ogg | 0.5286 | -0.92 | -15.41 | 97.0 | 13536 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/doorClose_002.ogg | 0.5326 | -0.97 | -15.95 | 92.71 | 13136 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/doorOpen_000.ogg | 0.5316 | -0.93 | -17.6 | 96.56 | 13114 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/doorOpen_001.ogg | 0.5286 | -0.95 | -15.41 | 97.01 | 13543 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/doorOpen_002.ogg | 0.5326 | -0.97 | -15.96 | 92.68 | 13126 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/engineCircular_000.ogg | 5.0000 | -0.96 | -14.7 | 10.09 | 923 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/engineCircular_001.ogg | 5.0000 | -0.94 | -13.25 | 4.58 | 596 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/engineCircular_002.ogg | 5.0000 | -0.97 | -12.18 | 2.23 | 540 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/engineCircular_003.ogg | 5.0000 | -0.95 | -14.78 | 12.02 | 1228 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/engineCircular_004.ogg | 5.0000 | -0.93 | -15.08 | 16.7 | 1579 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/explosionCrunch_000.ogg | 0.7775 | -0.96 | -13.76 | 0.8 | 236 | bomb_used |
| all-sounds/kenney_sci-fi-sounds/Audio/explosionCrunch_001.ogg | 1.3568 | -0.97 | -11.99 | 0.93 | 259 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/explosionCrunch_002.ogg | 1.2558 | -0.95 | -16.38 | 1.16 | 728 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/explosionCrunch_003.ogg | 1.5534 | -0.98 | -13.93 | 1.53 | 255 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/explosionCrunch_004.ogg | 1.9801 | -0.98 | -14.71 | 0.23 | 79 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/forceField_000.ogg | 0.9540 | -0.89 | -11.53 | 0.0 | 218 | shield_broken |
| all-sounds/kenney_sci-fi-sounds/Audio/forceField_001.ogg | 0.9534 | -0.91 | -11.59 | 0.0 | 158 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/forceField_002.ogg | 0.9551 | -0.94 | -11.6 | 0.01 | 273 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/forceField_003.ogg | 0.9559 | -0.92 | -11.57 | 0.0 | 184 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/forceField_004.ogg | 0.9544 | -0.91 | -11.59 | 0.0 | 218 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/impactMetal_000.ogg | 0.6349 | -0.94 | -22.07 | 0.0 | 179 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/impactMetal_001.ogg | 0.6876 | -0.9 | -19.85 | 0.0 | 46 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/impactMetal_002.ogg | 0.4711 | -0.92 | -20.42 | 0.0 | 95 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/impactMetal_003.ogg | 0.7768 | -0.92 | -21.56 | 0.0 | 180 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/impactMetal_004.ogg | 0.3895 | -0.94 | -21.25 | 0.0 | 206 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/laserLarge_000.ogg | 0.6766 | -0.94 | -17.18 | 13.98 | 1263 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/laserLarge_001.ogg | 0.7210 | -0.95 | -16.58 | 6.93 | 727 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/laserLarge_002.ogg | 0.7436 | -0.84 | -16.48 | 13.46 | 1906 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/laserLarge_003.ogg | 0.7158 | -0.94 | -17.93 | 15.19 | 1431 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/laserLarge_004.ogg | 0.6932 | -0.93 | -17.0 | 15.31 | 1720 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/laserRetro_000.ogg | 0.2354 | -0.87 | -7.48 | 6.13 | 1379 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/laserRetro_001.ogg | 0.2355 | -0.92 | -7.43 | 2.83 | 775 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/laserRetro_002.ogg | 0.2551 | -0.93 | -13.58 | 14.59 | 2184 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/laserRetro_003.ogg | 0.2548 | -0.85 | -7.59 | 15.2 | 3114 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/laserRetro_004.ogg | 0.2786 | -0.94 | -11.51 | 3.06 | 1594 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/laserSmall_000.ogg | 0.2392 | -5.65 | -21.62 | 1.57 | 739 | player_shot |
| all-sounds/kenney_sci-fi-sounds/Audio/laserSmall_001.ogg | 0.2473 | -2.54 | -21.92 | 68.81 | 7308 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/laserSmall_002.ogg | 0.3443 | -5.7 | -22.63 | 40.75 | 4060 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/laserSmall_003.ogg | 0.3004 | -7.68 | -22.17 | 4.13 | 1467 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/laserSmall_004.ogg | 0.4143 | -3.17 | -15.59 | 0.36 | 88 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/lowFrequency_explosion_000.ogg | 2.0000 | -0.9 | -17.99 | 0.0 | 77 | player_defeated |
| all-sounds/kenney_sci-fi-sounds/Audio/lowFrequency_explosion_001.ogg | 1.0000 | -0.83 | -15.62 | 0.0 | 90 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/slime_000.ogg | 0.5000 | -0.95 | -26.37 | 18.51 | 3220 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/slime_001.ogg | 4.7098 | -0.95 | -23.7 | 0.86 | 1648 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngine_000.ogg | 5.0000 | -1.0 | -9.66 | 0.01 | 59 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngine_001.ogg | 5.0000 | -0.96 | -8.41 | 0.01 | 65 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngine_002.ogg | 5.0000 | -0.93 | -13.8 | 0.02 | 114 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngine_003.ogg | 5.0000 | -0.87 | -12.06 | 0.0 | 173 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngineLarge_000.ogg | 5.0000 | -0.91 | -5.3 | 0.31 | 109 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngineLarge_001.ogg | 5.0000 | -0.92 | -6.14 | 4.14 | 536 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngineLarge_002.ogg | 5.0000 | -0.91 | -8.08 | 3.59 | 601 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngineLarge_003.ogg | 5.0000 | -0.94 | -6.8 | 5.37 | 835 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngineLarge_004.ogg | 5.0000 | -0.93 | -8.52 | 3.9 | 559 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngineLow_000.ogg | 5.0000 | -0.98 | -7.65 | 0.0 | 158 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngineLow_001.ogg | 5.0000 | -0.92 | -7.62 | 0.0 | 134 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngineLow_002.ogg | 5.0000 | -0.89 | -8.14 | 0.0 | 55 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngineLow_003.ogg | 5.0000 | -0.97 | -7.37 | 0.0 | 86 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngineLow_004.ogg | 5.0000 | -0.96 | -7.68 | 0.0 | 110 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngineSmall_000.ogg | 5.0000 | -0.91 | -10.22 | 0.0 | 136 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngineSmall_001.ogg | 5.0000 | -1.01 | -17.41 | 0.02 | 315 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngineSmall_002.ogg | 5.0000 | -1.06 | -14.33 | 0.01 | 229 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngineSmall_003.ogg | 5.0000 | -0.93 | -16.28 | 0.02 | 254 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/spaceEngineSmall_004.ogg | 5.0000 | -0.98 | -13.81 | 0.01 | 283 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/thrusterFire_000.ogg | 5.0000 | -1.0 | -18.82 | 7.54 | 1233 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/thrusterFire_001.ogg | 5.0000 | -0.89 | -17.45 | 4.9 | 813 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/thrusterFire_002.ogg | 5.0000 | -0.96 | -18.81 | 10.43 | 1616 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/thrusterFire_003.ogg | 5.0000 | -0.95 | -16.61 | 1.76 | 332 | — |
| all-sounds/kenney_sci-fi-sounds/Audio/thrusterFire_004.ogg | 5.0000 | -0.94 | -19.05 | 16.76 | 2445 | — |
