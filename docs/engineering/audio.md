# Audio

## Purpose

The audio module limits repeated sound-effect playback through a deterministic, Node-free `AudioLimiter` Rules Core. The later `AudioController` owns playback, streams, buses, event rules and music; this core only decides whether a voice may start and when its interval and duration expire.

## Files

- `scripts/audio/audio_limiter.gd` (`AudioLimiter` Rules Core)
- `scripts/audio/audio_controller.gd` (`AudioController` Adapter; planned in F13-02)

## Public contract

### Exports (Adapter)

Not applicable to the Rules Core.

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

## Dependencies

The core uses only `RefCounted`, typed data and its own `tick(delta)` clock. It holds no Node, SceneTree, AudioServer or RNG references. The AudioController supplies rules and translates grants and `voice_stolen` into playback operations.

## Invariants and tests

| Invariant | Test |
| --- | --- |
| Unknown events, intervals, and full per-event caps refuse without mutation; only granted requests start the interval. | No new tests during the sprint (SPRINT.md). |
| A full global cap steals only the oldest voice at the lowest strictly lower priority; ids are never reused. | No new tests during the sprint (SPRINT.md). |
| `tick()` expires intervals and durations with a `1e-6` epsilon; `clear()` keeps rules and ids. | No new tests during the sprint (SPRINT.md). |

## Setup for Astra

No scene attachment is required. F13-02's `AudioController` constructs the core with the configured global voice cap, installs the event catalogue as rules, ticks it from the adapter, stops a stolen player's playback on `voice_stolen`, and calls `clear()` when stopping all effects.

## Open issues

Rule values are provisional proposals. Astra can tune event intervals, caps and priorities after the D-01 listening pass; playback behavior and music remain in F13-02.
