# Audio

## Purpose

The audio module gates every sound effect through the deterministic, Node-free `AudioLimiter` Rules Core (F13-01) and plays them through the `AudioController` adapter (F13-02): a pool of `AudioStreamPlayer`s on the `SFX` bus for the event catalogue, two music players crossfading on the `Music` bus, and the coalesced menu sounds from the Viewport and the `Interface`. Bus volumes are F3-02's Options on `AudioServer`; gameplay producer wiring and the attachment to `Main/Audio` are F13-03's.

## Files

- `scripts/audio/audio_limiter.gd` (`AudioLimiter` Rules Core, CODE_READY F13-01)
- `scripts/audio/audio_controller.gd` (`AudioController` Adapter, CODE_READY F13-02; attached to `Main/Audio` and wired to the producers in F13-03)
- `scenes/main.tscn` (`Main/Audio`'s mapping) and `scripts/session/game_session.gd` (the wiring), F13-03; see "Wiring"

## AudioLimiter contract

### Signals

| Signal | Payload | Emitted when |
| --- | --- | --- |
| `voice_stolen` | `voice_id: int` | A higher-priority granted request replaces an active voice; emitted before `request()` returns. |

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `_init(max_voices: int)` | AudioController | Sets the global cap; asserts it is at least one. |
| `set_rule(event, min_interval, max_voices, priority)` | AudioController | Adds or replaces an event's interval, per-event cap and priority. |
| `request(event, duration) -> int` | AudioController | Returns a unique voice id or `REFUSED` (`0`); only a grant starts the interval. |
| `tick(delta)` | AudioController | Advances every interval and active duration; expiration is silent. |
| `clear()` | AudioController | Clears voices and intervals but keeps rules and the never-reused id sequence. |
| `is_active(voice_id) -> bool` | AudioController | Reports whether the id is still active. |
| `active_count(event = &"") -> int` | AudioController | Counts one event, or all active voices when the event is empty. |

Voice ids start at 1, increase monotonically and are not reset by `clear()`. A full per-event cap refuses without stealing. At the global cap, a request may replace the oldest voice at the lowest priority strictly below its own; equal or higher priorities cannot be displaced.

## AudioController contract

`class_name AudioController extends Node`. Attached to `Main/Audio` (`process_mode = ALWAYS`) since F13-03; nothing else instances it.

### Exports

| Export | Type | Default | Meaning |
| --- | --- | --- | --- |
| `event_streams` | `Dictionary[StringName, AudioStream]` | empty | Catalogue id to stream. Every effect must be non-looping: the limiter counts a voice for the stream's length. Keys outside `EVENTS` and null streams are reported and ignored. |
| `event_volume_db` | `Dictionary[StringName, float]` | empty | Per-event volume in dB; missing events play at 0. |
| `max_voices` | `int` | 12 | Global SFX voice cap; also the pool size. Below 1 disables the controller. `Main/Audio` sets 8 (F13-04, Astra's cap). |
| `sfx_bus` | `StringName` | `&"SFX"` | Bus of every SFX pool player. A name missing from `AudioServer` disables the controller. |
| `music_tracks` | `Dictionary[StringName, AudioStream]` | empty | Track id to stream. While empty, every music call is a silent no-op (the game ships without music unless D-01 finds a permitted track). |
| `music_bus` | `StringName` | `&"Music"` | Bus of both music players; validated like `sfx_bus`. |
| `music_crossfade_seconds` | `float` | 1.0 | Crossfade duration; 0 switches at once. |

The defaults are Claude's proposals; `Main/Audio`'s values are Astra's revised selection (see "Mapping").

### Constants

- `EVENTS: Array[StringName]` — the 17 catalogue ids of the audio spec.
- `EVENT_RULES` — per id, the limiter rule as `Vector3(min_interval, max_voices, priority)`. Intervals and voices are Astra's revised selection (`sound_effects/selection.json`, F13-04); priorities are the spec's catalogue proposals.
- `MUSIC_TRACK_IDS: Array[StringName]` — `menu`, `stage_01_route`, `stage_01_boss`, `stage_02_route`, `stage_02_boss`. Route and boss ids may share one stream.
- `MIN_VOICE_SECONDS := 0.1` — the duration used when a stream reports no length.
- `FADE_FLOOR_DB := -60.0` — where music fades start and end; effectively silent.

### Signals

| Signal | Payload | Emitted when |
| --- | --- | --- |
| `event_played` | `event: StringName` | A catalogue event started a voice (after the grant, once per played event). |

### Methods

| Method | Called by | Effect |
| --- | --- | --- |
| `setup(interface)` | F13-03, once | Connects `gui_focus_changed` (queues `ui_focus`) and `interface.action_requested` (queues `ui_accept` for every action except `back_refused`). A second call, a null interface, or a call outside the tree is a `push_error` and nothing else. |
| `play_event(event) -> bool` | F13-03 producer handlers | Requests a voice from the limiter for `max(stream.get_length(), MIN_VOICE_SECONDS)`; on a grant plays it on a free pool player at `event_volume_db`, emits `event_played`, returns true. An id outside `EVENTS` is a `push_error` and false; a catalogue id with no stream returns false silently. |
| `play_event_after(event, after)` | the Session's stage clear | Plays `event` at once when no voice of `after` is active, else from `_process` on the frame the limiter expires the last one. One event waits at a time (a later call replaces it). An id outside `EVENTS` is a `push_error`. |
| `stop_all()` | F13-03 on stage unload and Retry | Stops every SFX player, drops the waiting event and calls `limiter.clear()`. Music is left alone. |
| `silence()` | the Session's `_quit()` | Stops every SFX player and the music at once, drops the queued UI sounds and the waiting event, and disables the controller for good. |
| `play_music(track)` | F13-03 / F11 session points | Crossfades to the mapped track on the idle music player over `music_crossfade_seconds` using a `create_tween()` Tween (runs while paused). A stream already playing continues, even under another id; an unmapped id stops the music. |
| `stop_music()` | ditto | Fades the music out and stops it; `get_current_music()` is `&""` at once. |
| `get_current_music() -> StringName` | tests, session | The track in play, or `&""`. |
| `get_active_voice_count() -> int` | tests, dev readouts | The limiter's active SFX voices. |
| `missing_events() -> PackedStringArray` | F13-03's scene test | The catalogue ids with no usable stream; asserted empty there. |

### Behaviour notes

- `_ready` validates loudly (node path plus field): `max_voices < 1` or an unknown bus name disables processing, and a disabled controller's `play_event`/`play_music` do nothing. Bad `event_streams`/`music_tracks` entries are reported and ignored; the rest still work. It then builds the limiter with one rule per catalogue id, connects `voice_stolen` once, and creates `max_voices` SFX players and two music players in code.
- `_process(delta)` ticks the limiter, plays the waiting `play_event_after` event once its `after` voices expired, then plays the queued UI sound: at most one per frame, accept outranking focus, so a button that opens a screen plays its accept sound and not the new screen's focus sound too — and the sound survives the `stop_all()` the same action caused, because input handling runs before `_process`.
- A granted voice takes a pool player whose limiter voice is no longer active; the pool equals the global cap, so one always exists (asserted). `voice_stolen` stops the stolen voice's player.
- **Headless audio runs on the Dummy driver.** Verified on 2026-09-23 with a throwaway `tools/zz_audio_check.gd` (deleted after the run, per the ticket): three mapped events were granted, each emitted `event_played`, a repeat inside its interval was refused, and `missing_events()` listed exactly the unmapped ids. Never assert on `finished` or the playback position in headless runs.

## Wiring

F13-03 attaches `AudioController` to `Main/Audio` (still `process_mode = ALWAYS`) in `scenes/main.tscn`, with `event_streams` for all 17 ids. F13-04 replaced D-01's first pass with Astra's revised selection ([sound_effects/README.md](../../sound_effects/README.md), "Recommended mapping"). `music_tracks` stays empty: D-01 cleared no track, so every music call below is a silent no-op until one is added. `GameSession.audio` is typed `AudioController`.

### Mapping (F13-04)

Files are under `assets/audio/sfx/`, copied byte for byte from `sound_effects/`, all non-looping. File and gain live in `Main/Audio` (`event_streams`, `event_volume_db`); interval, voices and priority in `EVENT_RULES`. The global cap is 8 (`Main/Audio.max_voices`).

| Event | File | Gain dB | Min interval s | Voices | Priority |
| --- | --- | ---: | ---: | ---: | ---: |
| `ui_focus` | `interface/select_002.ogg` | -18 | 0.12 | 1 | 3 |
| `ui_accept` | `interface/confirmation_001.ogg` | -12 | 0.15 | 1 | 3 |
| `player_shot` | `scifi/laserSmall_000.ogg` | -20 | 0.25 | 1 | 0 |
| `enemy_hit` | `impact/impactGeneric_light_000.ogg` | -20 | 0.20 | 1 | 0 |
| `graze` | `interface/drop_001.ogg` | -26 | 0.30 | 1 | 1 |
| `shield_broken` | `scifi/forceField_000.ogg` | -10 | 0.30 | 1 | 3 |
| `player_hit` | `impact/impactSoft_heavy_000.ogg` | -7 | 0.30 | 1 | 3 |
| `bomb_used` | `scifi/explosionCrunch_000.ogg` | -9 | 0.50 | 1 | 3 |
| `player_defeated` | `scifi/lowFrequency_explosion_000.ogg` | -10 | 2.50 | 1 | 4 |
| `pickup_power` | `interface/drop_002.ogg` | -20 | 0.50 | 1 | 1 |
| `pickup_shield` | `digital/phaserUp2.ogg` | -12 | 0.60 | 1 | 2 |
| `enemy_defeated` | `impact/impactGeneric_light_003.ogg` | -16 | 0.25 | 1 | 1 |
| `checkpoint_activated` | `digital/phaseJump3.ogg` | -10 | 1.00 | 1 | 2 |
| `threat_warning` | `digital/twoTone2.ogg` | -8 | 1.50 | 1 | 2 |
| `boss_phase_changed` | `digital/phaserUp7.ogg` | -10 | 1.00 | 1 | 3 |
| `boss_defeated` | `impact/impactBell_heavy_000.ogg` | -8 | 2.00 | 1 | 4 |
| `stage_cleared` | `digital/threeTone1.ogg` | -10 | 2.00 | 1 | 4 |

### Producers (each connected once)

| Event | Producer | Connected in | Lifetime |
| --- | --- | --- | --- |
| `ui_focus`, `ui_accept` | Viewport `gui_focus_changed`, `Interface.action_requested` | `_ready` → `_connect_audio()`: `audio.setup(interface)`, after `show_home(MAIN_MENU)` so the first focus is silent | Session |
| `enemy_hit` | `ProjectileSystem.target_hit(target_id, damage)` (new) | `_connect_audio()` → `_on_target_hit` | Session |
| `shield_broken`, `player_hit` | `ProjectileSystem.player_hit` | the existing `_on_player_hit`, by `take_hit`'s `HitOutcome`: `ABSORBED` → `shield_broken`, `DAMAGED` → `player_hit`, `DEFEATED` and `REJECTED` → nothing | Session |
| `graze` | `ProjectileSystem.grazed` | the existing `_on_grazed` | Session |
| `bomb_used` | `CombatState.bomb_activated` | the existing `_on_bomb_activated`, before the radius damage | Session |
| `player_defeated` | `CombatState.defeated` | the existing `_on_player_defeated` | Session |
| `stage_cleared` | `RunState.stage_completed` | the existing `_on_stage_completed`, as `play_event_after(&"stage_cleared", &"boss_defeated")`: after the boss bell, not over it | Session |
| `pickup_power`, `pickup_shield` | `StageDirector.pickup_accepted`, by `Pickup.Kind` | `_load_stage` → `_connect_director_audio()` → `_on_pickup_accepted` | Director |
| `enemy_defeated` | `StageDirector.enemy_defeated(enemy_id, encounter_id)` (new) | same → `_on_enemy_defeated` | Director |
| `checkpoint_activated` | `StageDirector.checkpoint_activated` | same → `_on_checkpoint_activated` | Director |
| `threat_warning` | `StageDirector.threat_reported` | the existing `_on_threat_reported` | Director |
| `boss_phase_changed`, `boss_defeated` | `StageDirector.boss_phase_changed`, `boss_defeated` | the existing F12-03 handlers | Director |
| `player_shot` | `PlayerWeapon.shots_fired(count)` (new) | `_spawn_player`, after `weapon.setup` → `_on_shots_fired` | ship |

Session-lifetime producers are connected once in `_ready` and never again. The Director and the ship are freed on every unload and respawn, and their connections go with them, so Restart, Retry, Continuar and Jogar novamente cannot double a sound. Stage 2's Director gets the same connections, because the branch is `stage is StageDirector`.

### The three producer signals

- `StageDirector.enemy_defeated(enemy_id, encounter_id)`: emitted in `_on_enemy_defeated` on the first report of a live actor, after its score and before the machine hears it. A boss's defeat reaches `_on_enemy_defeated` too, right after `boss_defeated` and in the same call, so the Session's `_on_boss_defeated` sets `_boss_defeat_heard` and its `_on_enemy_defeated` consumes it and plays nothing: a boss's defeat plays only `boss_defeated` (Astra's "Trigger each ending once").
- `PlayerWeapon.shots_fired(count)`: emitted at the end of `_fire`, at most once per physics tick, with the number of shots the field accepted; a tick whose every spawn was refused emits nothing.
- `ProjectileSystem.target_hit(target_id, damage)`: emitted in `_on_field_enemy_hit` right after the registered `on_damage` call, only when that callable is valid. A Bomb's `damage_targets_in_radius` is not a hit and emits nothing. Stage 2's Seals register through `register_target` too, so a shot on a Seal plays `enemy_hit`.

### Transitions

- `_unload_stage` starts with `audio.stop_all()`. That covers Restart, Return to Menu, Continuar and Jogar novamente.
- `_retry()` from a Checkpoint calls `audio.stop_all()` right after `projectile_system.clear_all()`, then `play_music(<stage>_route)`. A Retry before any Checkpoint is a Restart.
- A successful `_load_stage` ends with `play_music(<stage>_route)`; `_return_to_menu` ends with `play_music(&"menu")`; `_ready` starts `menu`. `boss_started` plays `<stage>_boss`, and `boss_defeated` returns to `<stage>_route`. Track ids are `"%s_%s" % [stage_id, part]` (`_stage_track`).
- A stage clear plays `stage_cleared` once the `boss_defeated` bell's voice expires (1.48 s on both stages), not in the same frame; a stage cleared with no bell playing sounds at once. Leaving Results before then drops it (`stop_all()`).
- Sair, the window's close button and Alt+F4 go through the Session's `_quit()`: `audio.silence()`, then `quit()` 0.1 s later (`QUIT_SILENCE_SECONDS`), so the AudioServer has released every stopped playback. A stream still playing at `quit()` printed `resources still in use at exit`.
- Pause changes nothing: sound effects finish and the music continues.
- The accept sound of the button that caused a stop still plays: the controller plays queued UI sounds in its `_process`, after the input that ran `stop_all()`.
- An overlay raised by gameplay (Defeat, Results) takes focus, so it plays `ui_focus`; that is F13-02's UI source, not a gameplay event.

## Dependencies

The limiter uses only `RefCounted`, typed data and its own `tick(delta)` clock. The controller needs `AudioServer` (bus lookup only — it never sets a bus volume), a Viewport and the `Interface` for its UI sources (through `setup`), and D-01's imported streams under `assets/audio/sfx/` as the `event_streams` values, set by F13-03 in the Claude-owned `scenes/main.tscn`.

## Invariants and tests

| Invariant | Test |
| --- | --- |
| Unknown events, intervals, and full per-event caps refuse without mutation; only granted requests start the interval. | No new tests during the sprint (SPRINT.md). |
| A full global cap steals only the oldest voice at the lowest strictly lower priority; ids are never reused. | No new tests during the sprint (SPRINT.md). |
| `tick()` expires intervals and durations with a `1e-6` epsilon; `clear()` keeps rules and ids. | No new tests during the sprint (SPRINT.md). |
| Every playback is limiter-gated; SFX and music use their own buses (ENGINEERING_BRIEF 4.I). | No new tests during the sprint; the throwaway headless check above, and F13-03's wiring run. |
| Repetitive events stay capped (ENGINEERING_BRIEF 4.E). | Same: the headless check showed the in-interval refusal. |

## Setup for Astra

No scene attachment is required from Astra: `Main/Audio` is in Claude's `main.tscn`, and F13-04 set it from your revised selection (the "Mapping" table). Every sound effect must be non-looping — the limiter counts a voice for the stream's length. After the listening pass, send Claude a changed row: a file or gain is a one-line change in `Main/Audio`, an interval or voice count one in `EVENT_RULES`.

## Open issues

- The listening pass on Astra's revised selection is owed by the human pass (F14-02).
- Music ships silent: D-01 found no permitted track, so `music_tracks` is empty and every music call is a no-op by design. A cleared track only needs a `music_tracks` entry in `main.tscn`.
- Bursts are capped by design (ENGINEERING_BRIEF 4.E): a Wave killed in one tick or five Power Pickups magnetized together play one or two sounds, not one per emission (see [validation/audio.md](../validation/audio.md)).
- One of Astra's producer-coalescing rules is not built: a warning only for a new threat (F15-02's). Since F15-01 the kills of a Bomb's clear play no `enemy_defeated`, only its `bomb_used` (a boss it kills still rings `boss_defeated`). Each ending once and `stage_cleared` after the bell are built; see "Transitions". Since F15-01 `stage_cleared` plays when Results shows, 2.5 s after the kill, after the victory beat.
- No pitch variation, no 3D audio, no distinct Back sound (ticket out of scope).
