# F13-03 Audio event wiring

Status: done
Type: integration
parallel-safe: no
Depends on: F13-02, F12-03, F7-03, D-01
Lane: path
Model: Claude Opus 5.5, 2-agent workflow (implementer, reviewer)

## Goal

The real game is heard. `AudioController` goes on `Main/Audio`, with D-01's sounds as its mapping. The Session connects each catalogue producer once, in the place that already owns that producer's lifetime. Every unload and every Retry silences the sound effects in flight. Music follows the menu, the route and the boss when D-01 cleared tracks, and is a silent no-op otherwise. A scene test proves one sound per producer emission, also after Restart and Retry, and none after the stage is gone.

## Read first

- `.scratch/audio/spec.md` "Event catalogue" and "Cross-feature contracts"; `docs/engineering/audio.md` (F13-01, F13-02)
- D-01's `docs/HANDOFF_LOG.md` entry and `docs/validation/audio-selection.md`: the event-to-file table, the volume proposals and the music decision
- The Outcomes and module docs of F7-01 and F7-02 (`_on_player_hit`, `_on_grazed`, `_on_player_defeated`, `_on_bomb_activated` in `damage-pickups.md`), F10-01 to F10-03 (`_director`, `_on_threat_reported`, `_spawn_player`, `_retry()`, the test seams, in `stage-director.md`) and F12-03 (the Session's boss handlers, in `bosses.md`)
- `docs/engineering/menus-session.md` "Unloading"; `scripts/session/game_session.gd`; `scenes/main.tscn`

## Files

- **Creates:** `tests/scene/test_audio_wiring.gd`, `docs/validation/audio.md`.
- **Edits:**
  - `scenes/main.tscn`: attach `scripts/audio/audio_controller.gd` to `Audio`, which stays `process_mode = ALWAYS`. Set `event_streams` for all 17 ids from D-01's table, `event_volume_db` from its proposals, and `music_tracks` only with tracks D-01 cleared.
  - `scripts/session/game_session.gd`: the wiring below, and the export retyped to `audio: AudioController`.
  - `scripts/progression/stage_director.gd`: `signal enemy_defeated(enemy_id: StringName, encounter_id: StringName)`, emitted in `_on_enemy_defeated` on a first report, after scoring.
  - `scripts/combat/player_weapon.gd`: `signal shots_fired(count: int)`, emitted once per physics tick that spawned at least one shot.
  - `scripts/combat/projectile_system.gd`: `signal target_hit(target_id: int, damage: int)`, emitted beside the stored `on_damage` call.
  - `tests/scene/test_main_contract.gd`, only if the attached script breaks an assertion.
- **Serialized at session end:** the `docs/engineering/ROADMAP.md` F13-03 row and its "Requests to Astra" F13 row, one `docs/HANDOFF_LOG.md` entry, `docs/engineering/audio.md` ("Wiring" section), `docs/GUIDE.md` Section 6 rows for `audio_controller.gd`, `game_session.gd`, `stage_director.gd`, `player_weapon.gd` and `projectile_system.gd`, the Section 7 "Pickup accepted" row (its audio consumer is now real) and the Section 10 "Audio integration" row.
- **Must not touch:**
  - `audio_limiter.gd` and `audio_controller.gd`: a defect gets a minimal fix, logged in the Outcome.
  - `assets/audio/**`: a missing or looping file goes back to Astra, not re-picked.
  - `combat_state.gd`, `interface.gd`, `menu_controller.gd`, `hud.gd`, every `.tscn` except `main.tscn`, and `content/**`.
- **Conflicts with:**
  - `game_session.gd` and `main.tscn`: trunk only, F14-01 after.
  - `stage_director.gd`: F12-05 to F12-07 (sol), which add Stage 2 code to it and may land at the same time. Run `tools/lane.ps1 sync` first, and keep the edit to one declaration and one emit in `_on_enemy_defeated`, so the second to land merges trivially.
  - `player_weapon.gd`: F3-04 (trunk, before). `audio.md`: F13-02 (before).

## Deliverables

### Wiring (each producer connected once)

| Producer | Where | Plays |
| --- | --- | --- |
| UI | `_ready`, after `interface.show_home(ScreenRouter.MAIN_MENU)`: `audio.setup(interface)`, then `audio.play_music(&"menu")` | `ui_focus`, `ui_accept` |
| `projectile_system.player_hit` | F7-01's `_on_player_hit`, from the `take_hit` outcome | `ABSORBED`: `shield_broken`. `DAMAGED`: `player_hit`. `DEFEATED`: nothing here |
| `projectile_system.grazed` | `_on_grazed` | `graze` |
| `projectile_system.target_hit` | `_ready`, new `_on_target_hit` | `enemy_hit` |
| `_combat_state.bomb_activated` | `_on_bomb_activated` | `bomb_used` |
| `_combat_state.defeated` | `_on_player_defeated` | `player_defeated` |
| `_run_state.stage_completed` | `_on_stage_completed` | `stage_cleared` |
| `_director.pickup_accepted(pickup_id, kind, score)` | `_load_stage`, beside F10-01's Director connections | `pickup_power` or `pickup_shield` by `Pickup.Kind` |
| `_director.enemy_defeated` | same | `enemy_defeated` |
| `_director.checkpoint_activated` | same | `checkpoint_activated` |
| `_director.threat_reported` | `_on_threat_reported` | `threat_warning` |
| `_director.boss_started` / `boss_phase_changed` / `boss_defeated` | F12-03's handlers | `play_music(<stage>_boss)`; `boss_phase_changed`; `boss_defeated`, then `play_music(<stage>_route)` |
| `_player.weapon.shots_fired` | `_spawn_player`, beside the per-ship bindings | `player_shot` |

Where F12-03 connected a boss signal straight to a `Hud` method, route it through one Session handler that calls both, still with one connection. Session-lifetime producers never reconnect. The Director and the ship are freed on unload and respawn, so their connections go with them. Stage 2's Director (F12-05) gets the same connections, because the branch is `stage is StageDirector`.

### Transitions

- `_unload_stage` starts with `audio.stop_all()`. That covers Restart, Return to Menu and the Campaign transition.
- `_retry()` calls `audio.stop_all()` after `projectile_system.clear_all()`, then `play_music(<stage>_route)`.
- A successful `_load_stage` ends with `play_music(<stage>_route)`, and `_return_to_menu` ends with `play_music(&"menu")`.
- Pause changes nothing: sound effects finish and music continues.
- The accept sound of the button that caused the stop still plays, because UI sounds play in the controller's `_process`.

## Tests required

`tests/scene/test_audio_wiring.gd`, headless on `main.tscn`, counting `event_played` with `signal_recorder`. Rows drive producers the way the F7, F10 and F12 scene tests do (teleports, the public damage path, `get_combat_state()`, F10-03's resume seam). A row with no cheap real path emits the producer's signal on the live object, which still proves the one connection. Call `audio.stop_all()` between rows so intervals do not mask a count.

- `test_main_audio_carries_the_controller_with_every_event_mapped`: `missing_events()` is empty and every stream is non-looping.
- `test_menu_focus_and_accept_play_once`: `tree.root.push_input` with `ui_down`, then `ui_accept`.
- `test_each_gameplay_producer_plays_its_event_once`: all 15 gameplay rows, on a Direct Stage 1.
- `test_shield_hit_then_health_hit_play_their_own_sounds`: real hostile Projectiles, with 1 s of Invulnerability between them.
- `test_defeating_hit_plays_only_player_defeated`
- `test_restart_keeps_one_connection_per_producer`
- `test_retry_keeps_one_connection_per_producer`: the new ship's `shots_fired` also counts once.
- `test_unload_stops_every_voice_and_nothing_sounds_after` (ENGINEERING_BRIEF 4.I "transition-safe audio"). After `return_to_menu`, `get_active_voice_count()` is 0. Physics frames later there is still no gameplay `event_played`, and the old Director and ship are freed.
- `test_restart_accept_is_heard_after_the_stop`
- Per D-01's decision, `test_no_music_without_cleared_tracks` or `test_music_follows_menu_route_and_boss`.

## Out of scope

- New events: Gate opened, Seal destroyed, a distinct Back sound.
- Tuning the rule values (Astra, through a note).
- Options volumes (F3-02).
- A deferred Director callback that fires in its own unload frame (F10's "Unloading" rule): `stop_all` runs first, and the test pins silence once the Director is freed.

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR` in the output. The 4.I test exists. No Error-level warnings.
- `/run`, headless first, then windowed. An agent cannot hear, so it checks a temporary `event_played` print, removed before commit. From the main menu: navigate, start Stage 1, shoot, graze, take a Shield hit and a Health hit, collect Pickups, reach CP1-A, Bomb, die and Retry, Return to Menu. Each event is logged once and no error appears.
- Recorded in `docs/validation/audio.md`, with the human listening pass listed as owed for F14-02.
- Module doc, GUIDE rows, handoff log, `Status: done` with an Outcome, ROADMAP rows.
- One commit: `audio: attach AudioController and wire game events`. Then the lane's land step from `docs/engineering/SPRINT.md`.

## Handoff notes for Astra

- Your D-01 table is in `Main/Audio`'s `event_streams`, with your volume proposals in `event_volume_db`.
- To retune a sound's density, interval or priority, send a new row for the spec's catalogue. To swap a file, keep its path or send the new one.
- `StageDirector.checkpoint_activated` now also plays a sound. The arch glow is still yours.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/SPRINT.md, docs/engineering/ROADMAP.md and .scratch/audio/issues/03-audio-event-wiring.md, then implement that ticket and verify it with /run. Finish with its Definition of Done and commit.
```

## Outcome

Done 2026-09-24 by lane path (2-agent shape: implementer, then a read-only reviewer who reran the suite and found no defects).

- `Main/Audio` carries `AudioController` with all 17 D-01 streams and volumes; `music_tracks` is empty because D-01 cleared no track, so every music call is a silent no-op. `GameSession.audio` is typed `AudioController`.
- The wiring follows the Deliverables table. New Session functions: `_connect_audio()`, `_connect_director_audio()`, `_stage_track()`, and the five one-line handlers `_on_target_hit`, `_on_shots_fired`, `_on_pickup_accepted`, `_on_enemy_defeated`, `_on_checkpoint_activated`. The other events play from the handlers the Session already had.
- The three producer signals are one declaration and one emit each. `StageDirector.enemy_defeated` also fires for a boss, because `_on_boss_defeated` reports through `_on_enemy_defeated`, so a boss's death plays `boss_defeated` and then `enemy_defeated`. It was kept that way so the `stage_director.gd` merge with sol stays trivial; see audio.md "Open issues".
- No defect in `audio_limiter.gd` or `audio_controller.gd`; neither changed.
- Tests: none, by the sprint rule, so `test_audio_wiring.gd` is not created. `tests/scene/test_main_contract.gd` needed no change. The suite shows 225 passed. A throwaway driver of `main.tscn` from the main menu passed 54 checks, headless and then windowed. That driver was not committed and is described in `docs/validation/audio.md`.
- Owed: the human listening pass (F14-02).
