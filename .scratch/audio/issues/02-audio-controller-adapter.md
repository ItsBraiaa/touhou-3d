# F13-02 AudioController adapter

Status: todo
Type: adapter
parallel-safe: no
Depends on: F13-01
Lane: glm-a

## Goal

`scripts/audio/audio_controller.gd` is the Adapter that `Main/Audio` will carry. It plays catalogue events from an exported event-to-stream mapping through a pool of `AudioStreamPlayer`s on the `SFX` bus, and every playback is gated by `AudioLimiter`. It plays menu focus and accept sounds from the viewport and the `Interface`. It stops every sound effect for a stage unload, and it can play music with a crossfade on the `Music` bus when tracks are provided. This ticket attaches it to no scene: its tests instance it standalone with generated `AudioStreamWAV` streams, and F13-03 attaches and wires it.

## Read first

- `.scratch/audio/spec.md`: the "Event catalogue" table (ids and rule values) and "Cross-feature contracts" (the exact API)
- `docs/engineering/audio.md` (F13-01's `AudioLimiter` contract)
- `docs/GUIDE.md` Section 5 "Main composition" (`Main/Audio` is a `Node` with `process_mode = ALWAYS`; buses `Master`, `Music`, `SFX`) and the Section 6 row `audio_controller.gd`
- `scripts/ui/interface.gd`: `action_requested(action, payload)`, and `back_refused` for "nothing to go back to"
- `docs/engineering/CONVENTIONS.md` "Architecture rules" (loud setup errors, one connection place) and "Tests"; `tests/unit/project/test_audio_buses.gd`

## Files

- **Creates:** `scripts/audio/audio_controller.gd`, `tests/scene/test_audio_controller.gd`.
- **Edits:** none.
- **Serialized at session end:** the `docs/engineering/ROADMAP.md` F13-02 row, one `docs/HANDOFF_LOG.md` entry, `docs/engineering/audio.md` ("AudioController contract" and "Setup for Astra" sections), and the `docs/GUIDE.md` Section 6 `audio_controller.gd` row with the exact exports, marked "CODE_READY F13-02, attached in F13-03".
- **Must not touch:**
  - `scenes/main.tscn` and `scripts/session/game_session.gd` (trunk, F13-03).
  - `scripts/ui/interface.gd` and `menu_controller.gd` (F4-02, F3-02, F3-03, F11-01).
  - `scripts/audio/audio_limiter.gd` (F13-01; a defect is a note in the Outcome).
  - `project.godot`, `default_bus_layout.tres`, `assets/**` (D-01) and every producer script.
- **Conflicts with:** none on code. `audio.md` is F13-03's next, and it depends on this ticket.

## Deliverables

`class_name AudioController extends Node`:

- **Exports.** `event_streams: Dictionary[StringName, AudioStream]`, `event_volume_db: Dictionary[StringName, float]`, `max_voices: int = 12`, `sfx_bus: StringName = &"SFX"`, `music_tracks: Dictionary[StringName, AudioStream]`, `music_bus: StringName = &"Music"`, `music_crossfade_seconds: float = 1.0`. The numbers are Claude's proposals.
- **Constants.**
  - `EVENTS: Array[StringName]`: the 17 catalogue ids.
  - The rule table: each id with its interval, voices and priority, from the spec. The representation is the implementer's.
  - `MUSIC_TRACK_IDS`: `menu`, `stage_01_route`, `stage_01_boss`, `stage_02_route`, `stage_02_boss`.
  - `MIN_VOICE_SECONDS := 0.1`: the duration used when `stream.get_length()` is 0 or less.
- **`_ready`.**
  - Reports with `push_error`, naming the node path and the field: `max_voices < 1`, and a bus name missing from `AudioServer.get_bus_index`. Either disables processing, and a disabled controller's `play_event` and `play_music` do nothing (false).
  - Also reported: an `event_streams` key outside `EVENTS`, a `music_tracks` key outside `MUSIC_TRACK_IDS`, and a null stream. That entry is ignored and the rest still work.
  - Creates the limiter with `max_voices` and calls `set_rule` for every id, connecting `voice_stolen` once.
  - Creates `max_voices` `AudioStreamPlayer` children on `sfx_bus` and two music players on `music_bus`, all in code.
- **`play_event(event: StringName) -> bool`.**
  - An id outside `EVENTS` is a `push_error` and returns false. A catalogue id with no stream returns false silently.
  - Otherwise it requests `maxf(stream.get_length(), MIN_VOICE_SECONDS)`. On a grant it takes a free player, one whose voice is no longer `is_active`: the pool equals the global cap, so one always exists, which is asserted. It sets `stream` and `volume_db = event_volume_db.get(event, 0.0)`, calls `play()`, emits `event_played(event)` and returns true.
  - `_on_voice_stolen(voice_id)` stops that voice's player.
- **`stop_all()`.** Stops every sound-effect player and calls `limiter.clear()`. Music is left alone: it changes through `play_music`.
- **`_process(delta)`.** Calls `limiter.tick(delta)`, then plays the queued UI sound. Audio is presentation, and `Main/Audio` is ALWAYS, so it ticks while paused and menu sounds work on Pause.
- **`setup(interface: Interface)`, once.** A second call, a null interface, or a call while the controller is outside the tree is a `push_error` and nothing else. It connects:
  - `get_viewport().gui_focus_changed`, which queues `ui_focus`;
  - `interface.action_requested`, which queues `ui_accept` for every action except `back_refused`.

  UI sounds are coalesced: at most one per frame, played in `_process`, with accept outranking focus. So a button that opens a screen plays its accept sound, not the new screen's focus sound too. The sound also plays after any `stop_all()` the same action caused (Restart, Return to Menu).
- **Music.**
  - `play_music(track: StringName)`:
    - The stream already playing continues, even under another id.
    - A mapped track fades in on the idle music player while the current one fades out over `music_crossfade_seconds`. Use a `Tween` from `create_tween()`, so it runs while paused. The old player stops at the end.
    - An unmapped id does `stop_music()`.
    - With `music_tracks` empty, every music call is a silent no-op.
  - `stop_music()` fades out. `get_current_music() -> StringName` returns `&""` when nothing plays.
- **Queries.** `get_active_voice_count() -> int`, and `missing_events() -> PackedStringArray`, the catalogue ids with no stream, which F13-03's scene test asserts empty.

## Tests required

`tests/scene/test_audio_controller.gd`. The controller is built with `AudioController.new()` under `tree.root`, exports set first, and freed in `after_each`. A helper makes an `AudioStreamWAV` of a given length: 8-bit, mono, 8000 Hz, zeroed data. The UI source is an `Interface.new()` that is never added to the tree, and its `action_requested` is emitted directly. Assert on `event_played`, `get_active_voice_count()`, a player's `stream`, `bus` and `volume_db`, and `is_playing()` right after `play()`. Never assert on `finished` or the playback position: headless audio runs on the Dummy driver. Check that once and record it in `audio.md`.

- `test_mapped_event_plays_on_the_sfx_bus`
- `test_sfx_and_music_use_their_own_buses` (ENGINEERING_BRIEF 4.I "independent volume buses")
- `test_repeated_event_inside_its_interval_is_refused` (4.E)
- `test_unmapped_event_is_silent_and_listed_in_missing_events`
- `test_unknown_event_is_reported` (expected `push_error`; grep `SCRIPT ERROR` separately)
- `test_full_pool_steals_for_a_higher_priority_event` (`max_voices = 2`, then `graze` and `pickup_power`, then `bomb_used`: the `graze` player now holds the Bomb stream, two voices)
- `test_stop_all_silences_every_voice_and_resets_intervals`
- `test_event_volume_is_applied`
- `test_focus_change_plays_one_focus_sound` (two `Button`s, `grab_focus`, await a process frame)
- `test_accept_outranks_focus_in_the_same_frame`
- `test_back_refused_is_silent`
- `test_second_setup_is_reported_and_does_not_double_connect`
- `test_music_crossfades_and_stops_the_old_player` (crossfade 0.2 s, await timers)
- `test_same_music_stream_is_not_restarted`
- `test_empty_music_tracks_are_a_silent_no_op`
- `test_bad_bus_and_null_stream_are_reported`

## Out of scope

Attaching to `Main/Audio`, choosing streams, and connecting gameplay producers (F13-03). Bus volumes (F3-02). A distinct Back sound, pitch variation, 3D audio.

## Definition of Done

- `tools/test.ps1` green, with no `SCRIPT ERROR` in the output. The 4.E and 4.I tests exist. No Error-level warnings.
- Verified headless: a throwaway `tools/zz_audio_check.gd` builds a controller, plays three events and prints the `event_played` log. Delete it and its `.uid` afterwards.
- `audio.md` and the GUIDE Section 6 row updated, one handoff log entry, `Status: done` with an Outcome, ROADMAP row.
- One commit: `audio: add AudioController adapter`. Then `tools/lane.ps1 land`.

## Handoff notes for Astra

- `Main/Audio` stays in Claude's `main.tscn`. Hand over the event-to-file table and any volume proposals (D-01), and Claude sets `event_streams` and `event_volume_db`.
- Every sound effect must be non-looping. The limiter counts a voice for the stream's length.

## Kickoff prompt

```
In your lane worktree, read AGENTS.md, docs/engineering/SPRINT.md (your lane section), docs/engineering/ROADMAP.md and .scratch/audio/issues/02-audio-controller-adapter.md. Check its dependencies with tools/lane.ps1 status F13-01, implement it test-first, run tools/test.ps1 until green with no SCRIPT ERROR, finish its Definition of Done, commit, then run tools/lane.ps1 land.
```
