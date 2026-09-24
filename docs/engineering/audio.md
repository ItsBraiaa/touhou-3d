# Audio

## Purpose

The audio module gates every sound effect through the deterministic, Node-free `AudioLimiter` Rules Core (F13-01) and plays them through the `AudioController` adapter (F13-02): a pool of `AudioStreamPlayer`s on the `SFX` bus for the event catalogue, two music players crossfading on the `Music` bus, and the coalesced menu sounds from the Viewport and the `Interface`. Bus volumes are F3-02's Options on `AudioServer`; gameplay producer wiring and the attachment to `Main/Audio` are F13-03's.

## Files

- `scripts/audio/audio_limiter.gd` (`AudioLimiter` Rules Core, CODE_READY F13-01)
- `scripts/audio/audio_controller.gd` (`AudioController` Adapter, CODE_READY F13-02; attached to `Main/Audio` and wired to the producers in F13-03)

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

`class_name AudioController extends Node`. F13-03 attaches it to `Main/Audio` (`process_mode = ALWAYS`); nothing instances it before then.

### Exports

| Export | Type | Default | Meaning |
| --- | --- | --- | --- |
| `event_streams` | `Dictionary[StringName, AudioStream]` | empty | Catalogue id to stream. Every effect must be non-looping: the limiter counts a voice for the stream's length. Keys outside `EVENTS` and null streams are reported and ignored. |
| `event_volume_db` | `Dictionary[StringName, float]` | empty | Per-event volume in dB; missing events play at 0. |
| `max_voices` | `int` | 12 | Global SFX voice cap; also the pool size. Below 1 disables the controller. |
| `sfx_bus` | `StringName` | `&"SFX"` | Bus of every SFX pool player. A name missing from `AudioServer` disables the controller. |
| `music_tracks` | `Dictionary[StringName, AudioStream]` | empty | Track id to stream. While empty, every music call is a silent no-op (the game ships without music unless D-01 finds a permitted track). |
| `music_bus` | `StringName` | `&"Music"` | Bus of both music players; validated like `sfx_bus`. |
| `music_crossfade_seconds` | `float` | 1.0 | Crossfade duration; 0 switches at once. |

All numbers are Claude's proposals.

### Constants

- `EVENTS: Array[StringName]` — the 17 catalogue ids of the audio spec.
- `EVENT_RULES` — per id, the limiter rule as `Vector3(min_interval, max_voices, priority)` from the spec's catalogue table (Claude's proposals; Astra tunes after the D-01 listening pass).
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
| `stop_all()` | F13-03 on stage unload and Retry | Stops every SFX player and calls `limiter.clear()`. Music is left alone. |
| `play_music(track)` | F13-03 / F11 session points | Crossfades to the mapped track on the idle music player over `music_crossfade_seconds` using a `create_tween()` Tween (runs while paused). A stream already playing continues, even under another id; an unmapped id stops the music. |
| `stop_music()` | ditto | Fades the music out and stops it; `get_current_music()` is `&""` at once. |
| `get_current_music() -> StringName` | tests, session | The track in play, or `&""`. |
| `get_active_voice_count() -> int` | tests, dev readouts | The limiter's active SFX voices. |
| `missing_events() -> PackedStringArray` | F13-03's scene test | The catalogue ids with no usable stream; asserted empty there. |

### Behaviour notes

- `_ready` validates loudly (node path plus field): `max_voices < 1` or an unknown bus name disables processing, and a disabled controller's `play_event`/`play_music` do nothing. Bad `event_streams`/`music_tracks` entries are reported and ignored; the rest still work. It then builds the limiter with one rule per catalogue id, connects `voice_stolen` once, and creates `max_voices` SFX players and two music players in code.
- `_process(delta)` ticks the limiter, then plays the queued UI sound: at most one per frame, accept outranking focus, so a button that opens a screen plays its accept sound and not the new screen's focus sound too — and the sound survives the `stop_all()` the same action caused, because input handling runs before `_process`.
- A granted voice takes a pool player whose limiter voice is no longer active; the pool equals the global cap, so one always exists (asserted). `voice_stolen` stops the stolen voice's player.
- **Headless audio runs on the Dummy driver.** Verified on 2026-09-23 with a throwaway `tools/zz_audio_check.gd` (deleted after the run, per the ticket): three mapped events were granted, each emitted `event_played`, a repeat inside its interval was refused, and `missing_events()` listed exactly the unmapped ids. Never assert on `finished` or the playback position in headless runs.

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

No scene attachment is required from Astra: `Main/Audio` is in Claude's `main.tscn` and F13-03 attaches the controller and sets `event_streams` from D-01's imported files (`assets/audio/sfx/<pack>/<file>`) plus any volume proposals. Every sound effect must be non-looping — the limiter counts a voice for the stream's length. After the D-01 listening pass, tell Claude which events feel too dense or too sparse: the intervals, caps and priorities in `EVENT_RULES` are proposals.

## Open issues

- Rule values and event volumes are provisional proposals until the D-01 listening pass.
- The controller is not attached anywhere yet; `play_event`, `stop_all` and the music API first run in the game at F13-03.
- Music ships silent unless D-01 finds a permitted track: with `music_tracks` empty every music call is a no-op by design.
- No pitch variation, no 3D audio, no distinct Back sound (ticket out of scope).
