# Audio validation

Engine: Godot 4.7.2.stable.official.ed1daf0bf, Windows 11. Contract in
[engineering/audio.md](../engineering/audio.md) "Wiring"; the selection is in
[audio-selection.md](audio-selection.md).

# Event wiring — 2026-09-24 (F13-03)

## Automated

`tools/test.ps1`: 225 passed, 0 failed, no `SCRIPT ERROR`. No existing test needed a change,
and no test is added (the sprint's no-new-tests rule, so the ticket's `test_audio_wiring.gd`
is void). `tools/lane.ps1 land` adds the boot smoke of `scenes/main.tscn` and
`tools/check_resources.gd`.

## Driven pass: `scenes/main.tscn`

An agent cannot hear, so a throwaway `SceneTree` script (not in the repo) counted
`AudioController.event_played` with its own connection, which stood in for the ticket's
temporary print. It drove the real game from the main menu: menu keys through
`push_input`, `fire` held through `Input.action_press`, the Bomb as a pushed `bomb` action,
hostile and player Projectiles spawned through the real `ProjectileSystem`, the ship moved
with `reset_to()`, enemies and the boss killed with `take_damage`, and Retry, Restart and
Return to Menu as the Session's actions. It ran headless (Dummy audio driver), then once in
a 1280 × 720 window (D3D12, the real audio driver), with the same results: 54 checks
passed, no `SCRIPT ERROR`, no `ERROR:` or `WARNING:` line.

| # | Check | Measured |
| --- | --- | --- |
| 1 | Mapping | `missing_events()` empty; 17 `AudioStreamOggVorbis` streams, none looping; no music (`get_current_music()` `""` at boot and at the end) |
| 2 | Menu navigation | Down on the main menu: `ui_focus` once. Enter on Selecionar fase: `ui_accept` once, Stage Select open. Enter on the forest card: `ui_accept` once, Stage 1 in play. Nothing at boot |
| 3 | One connection per producer | After the first load, after Retry and after each of two Restarts: exactly one Session connection on `target_hit`, `player_hit`, `grazed`, `bomb_activated`, `defeated`, `stage_completed`, the Director's `pickup_accepted`, `enemy_defeated`, `checkpoint_activated`, `threat_reported`, `boss_started`, `boss_phase_changed`, `boss_defeated`, and the ship's `shots_fired` |
| 4 | Shoot | 60 ticks of `fire`: 10 `shots_fired` emissions, 7 `player_shot` (2 voices of 0.239 s at a 0.1 s cadence: the limiter refuses every third) |
| 5 | Graze | One pass 0.6 from the Core: one `graze`, Graze 1 |
| 6 | Shield hit, then Health hit | First bullet into the Core: `shield_broken` once, no `player_hit`. After the Invulnerability: `player_hit` once, no `shield_broken`, Health 90. Each bullet also grazed on its way in, which plays its own `graze` |
| 7 | Enemy hit | A player Projectile on a Spirit in S1-02: `enemy_hit` once |
| 8 | Route S1-01 to S1-04 | 11 `enemy_defeated` emissions, 4 sounds; 5 Power and 1 Shield Pickup accepted, `pickup_power` 1 and `pickup_shield` 1. The driver kills a whole Wave in one tick and the five Pickups magnetize together, so the limiter (0.05 s and 3 voices; 0.04 s and 2 voices) caps each burst |
| 9 | CP1-A | `checkpoint_activated` once |
| 10 | Threat | One `threat_reported(-1)` on the live Director: `threat_warning` once |
| 11 | Bomb | One pushed `bomb` press: `bomb_used` once |
| 12 | Defeating hit | At 10 Health with no Shield, a real bullet: `player_defeated` once, no `player_hit` or `shield_broken`; Defeat on top (its focus plays `ui_focus`) |
| 13 | Retry from CP1-A | 0 active voices right after `retry` (the 2 s defeat sound stopped); Tentar novamente's `ui_accept` still plays on the next frame; the old ship freed; the new ship's 6 `shots_fired` gave 4 `player_shot` |
| 14 | Restart ×2 | 0 active voices right after each; the old Director freed |
| 15 | Full Stage 1 route to the Lantern Guardian | `checkpoint_activated` 2 (CP1-A, CP1-B), `boss_phase_changed` 3 for 3 Phases, `boss_defeated` 1, `stage_cleared` 1, Results on top. 18 `enemy_defeated` emissions (the boss's included) gave 7 sounds; 10 Power Pickups gave 2 `pickup_power`, 1 Shield Pickup 1 `pickup_shield` |
| 16 | Return to Menu | 0 active voices right after; in the next 120 physics ticks only Menu principal's `ui_accept`, no gameplay event; the last Director and ship freed |

## Listening pass

**Owed (F14-02, the human pass).** Nobody has listened to the wiring in the running game.
Check each event's level against the mix, especially `threat_warning` (+1 dB),
`player_defeated`, `boss_defeated` and `stage_cleared`, and whether `player_shot` at
-18 dB is audible under the Familiars' fire. When the boss is the stage's last Encounter,
`boss_defeated`, `enemy_defeated` and `stage_cleared` start in the same frame, so the bell
and the three-tone overlap instead of following each other. Retune the intervals, voices and priorities
through a handoff note (the spec's catalogue).
