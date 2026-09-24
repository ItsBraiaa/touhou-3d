# Audio validation

Engine: Godot 4.7.2.stable.official.ed1daf0bf, Windows 11. Contract in
[engineering/audio.md](../engineering/audio.md) "Wiring" and "Mapping". The shipped selection
is Astra's revised one, [sound_effects/README.md](../../sound_effects/README.md) (F13-04);
D-01's first pass is in [audio-selection.md](audio-selection.md).

# Endings each once, in order, and a silent quit — 2026-09-24 (path)

Two throwaway `SceneTree` drivers (not in the repo), headless on the Dummy audio driver, no
`SCRIPT ERROR`, `ERROR:` or `WARNING:` line.

| # | Check | Measured |
| --- | --- | --- |
| 1 | Direct Stage 1 cleared through S1-07 | `boss_defeated` 1, `stage_cleared` 1, Results on top. The boss's kill tick played `boss_defeated` and Results' `ui_focus`, no `enemy_defeated` |
| 2 | `stage_cleared` after the bell | Started 1,476 ms (88 physics ticks) after `boss_defeated`; the bell is 1,480 ms. The limiter's clock is `_process` delta, so a voice started mid-frame expires up to one frame early |
| 3 | Ordinary kills still heard | 18 `enemy_defeated` emissions gave 4 sounds (the limiter's 0.25 s interval) |
| 4 | Waiting event and `stop_all()` | A `stage_cleared` waiting on a bell was not played 2 s after `stop_all()`; with no bell it played at once |
| 5 | Quit while sounds play | Before the fix, Sair with `boss_defeated`, `stage_cleared` and `player_defeated` playing (and Sair's queued `ui_accept`) printed `ERROR: 8 resources still in use at exit` and `16 ObjectDB instances were leaked` (four `AudioStreamPlaybackOggVorbis` and their streams). After it: nothing, for Sair and for a `NOTIFICATION_WM_CLOSE_REQUEST`, and 0 voices right after the press |
| 6 | F13-04's 64-check driver, rerun | 64 passed; its full-route wait lengthened from 5 to 100 ticks for the delayed `stage_cleared`. The route now hears 6 `enemy_defeated`, not 7 |

# Astra's revised selection — 2026-09-24 (F13-04)

## What changed

- Five files: `ui_focus` `interface/select_002.ogg`, `graze` `interface/drop_001.ogg`,
  `pickup_power` `interface/drop_002.ogg`, `threat_warning` `digital/twoTone2.ogg`,
  `boss_phase_changed` `digital/phaserUp7.ogg`. Each is a byte-for-byte copy of its
  `sound_effects/` original (`cmp`), imported with `loop=false`.
- Removed, no event uses them: `interface/tick_001.ogg`, `interface/pluck_001.ogg`,
  `digital/phaseJump2.ogg`, `digital/lowThreeTone.ogg`. `phaserUp2.ogg` stays for
  `pickup_shield`.
- All 17 gains, intervals and voice counts from `selection.json`; every event now has one
  voice. The global cap is 8. Priorities are unchanged. The full table is in
  [engineering/audio.md](../engineering/audio.md) "Mapping".
- `tools/validate_audio_selection.gd` points at the new files: 17 events, `failures=0`, none
  looping.

## Driven pass: `scenes/main.tscn`

This is F13-03's throwaway driver (not in the repo), adapted. It reads `selection.json` and
compares every event's stream path, `event_volume_db` and `EVENT_RULES` interval and voices
with Astra's row. On each `event_played` it looks for a playing SFX pool player that holds the
event's stream at its gain. It holds fire for 3 s, measures each Power Pickup cluster, and
ends with a cap burst. It ran headless (Dummy audio driver): 64 checks passed, no
`SCRIPT ERROR`, no `ERROR:` or `WARNING:` line.

| # | Check | Measured |
| --- | --- | --- |
| 1 | Mapping | `missing_events()` empty. 17 streams, none looping. Every stream, gain, interval and voice count matches `selection.json`. `max_voices` 8, and the pool has 8 SFX players |
| 2 | Every event plays its new file | All 17 events were heard on a playing pool player holding Astra's file at her gain, including the five new ones |
| 3 | Held fire | 3 s of `fire` gave 30 `shots_fired` emissions and 10 `player_shot`: 3.33 starts per second, 18 ticks (0.3 s) apart. The limit is 4 per second |
| 4 | Pickup clusters | S1-02 and S1-05: 5 Power Pickups each, 1 `pickup_power` each |
| 5 | Menu, graze, Shield hit, Health hit, enemy hit, CP1-A, threat, Bomb, defeating hit | Each plays its event once, as in F13-03. The Shield bullet's graze on the way in is now refused by graze's 0.3 s interval |
| 6 | Retry from CP1-A | 0 active voices right after `retry`. Tentar novamente's `ui_accept` still plays. The new ship's 6 `shots_fired` gave 2 `player_shot` |
| 7 | Restart ×2 and Return to Menu | 0 active voices right after each. Only Menu principal's `ui_accept` plays in the next 120 ticks. One connection per producer after every reload |
| 8 | Full Stage 1 route | 18 `enemy_defeated` emissions gave 7 sounds. 10 Power Pickups gave 2 `pickup_power`, and the Shield Pickup 1. `checkpoint_activated` 2, `boss_defeated` 1, `stage_cleared` 1, then Results. `boss_phase_changed` 2 for 3 Phases: the driver deals 50 damage per tick, so two Phase changes fall inside its 1.0 s interval. Real Phases last far longer |
| 9 | Global cap | All 17 events requested in one frame, from silence: at most 8 voices, 8 players. The voices kept: `ui_accept`, `shield_broken`, `player_hit`, `bomb_used`, `player_defeated`, `boss_phase_changed`, `boss_defeated` and `stage_cleared`. Every routine event was stolen or refused. `stop_all()` then leaves 0 |

## Listening pass

**Owed (F14-02, the human pass),** with Astra's "Listening check still needed" protocol in
[sound_effects/README.md](../../sound_effects/README.md). Two things in the running game are
unchanged. A boss's final defeat still plays `enemy_defeated` under `boss_defeated`. The bell
and `stage_cleared` start in the same frame.

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
