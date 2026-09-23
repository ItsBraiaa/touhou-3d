# F13-01 AudioLimiter core

Status: todo
Type: core
parallel-safe: yes
Depends on: F0-02
Lane: glm-a

## Goal

A Node-free `AudioLimiter` decides whether a sound event may start a voice now. It enforces three limits:

- a minimum interval per event;
- a voice cap per event and a global voice cap;
- priority when the global cap is full: a more important sound takes over the oldest, least important voice.

Its only clock is `tick(delta)`, so every decision is deterministic and tested directly. `AudioController` (F13-02) asks it before every playback. This is ENGINEERING_BRIEF 4.E's "limiting repetitive SFX" as a tested rule.

## Read first

- `.scratch/audio/spec.md` "Event catalogue" (how the rules will be used) and "Cross-feature contracts" (`AudioLimiter`)
- `docs/adr/0001-gameplay-rules-in-node-free-cores.md`
- `docs/engineering/CONVENTIONS.md` "Typing and warnings", "Style", "Architecture rules", "Time and randomness", "Tests"
- `docs/engineering/testing.md`; for the pattern, `scripts/session/run_state.gd` with `tests/unit/session/test_run_state.gd`
- `docs/ENGINEERING_BRIEF.md` Sections 4.E and 4.I

## Files

- **Creates:** `scripts/audio/audio_limiter.gd`, `tests/unit/audio/test_audio_limiter.gd`, `docs/engineering/audio.md`.
- **Edits:** none.
- **Serialized at session end:** the `docs/engineering/ROADMAP.md` F13-01 row, one `docs/HANDOFF_LOG.md` entry, and `docs/engineering/audio.md` (new, from `TEMPLATE.md`, with the `AudioLimiter` contract) plus its line in `docs/engineering/README.md`.
- **Must not touch:** `scripts/audio/audio_controller.gd` (F13-02), every scene, `project.godot`, `default_bus_layout.tres`.
- **Conflicts with:** none. `audio.md` is extended later by F13-02 and F13-03, which depend on this ticket.

## Deliverables

`class_name AudioLimiter extends RefCounted`, with no Node, SceneTree, AudioServer or RNG use.

- `const REFUSED := 0`.
- `signal voice_stolen(voice_id: int)`: emitted inside `request()`, before it returns, when a new voice takes the place of `voice_id`. The adapter stops that player.
- `_init(max_voices: int)`: the global cap, asserted `>= 1`.
- `set_rule(event: StringName, min_interval: float, max_voices: int, priority: int) -> void`: asserts `min_interval >= 0.0` and `max_voices >= 1`. A second call replaces the rule.
- `request(event: StringName, duration: float) -> int`: asserts `duration > 0.0`. Checks run in this order, and the first failure returns `REFUSED` with nothing changed:
  1. The event has a rule. An event without one is always refused.
  2. The event's interval is over. Only a granted request starts it, so a refused request never pushes the next grant back.
  3. `active_count(event) < rule.max_voices`. A full per-event cap refuses: an event never steals from itself.
  4. When `active_count() == max_voices`, the victim is the voice with the lowest priority strictly below the request's, and among those the oldest (the smallest id). Remove the victim, then emit `voice_stolen(victim_id)`. No victim means `REFUSED`, so an equal priority never churns.
  5. Grant. Take the next id (ids start at 1, grow by one and are never reused, not even after `clear()`), record the event, priority and remaining `duration`, and start the event's interval.
- `tick(delta: float) -> void`: asserts `delta >= 0.0`. Counts every interval and every voice down. A voice whose remaining time reaches 0 ends silently: it is the adapter's own clock that ran out. Compare with an epsilon of `1e-6`, so three ticks of 1/60 end a 0.05 s interval.
- `clear() -> void`: forgets every voice and every interval, and keeps the rules. No signal. This is `stop_all()`'s core half.
- `is_active(voice_id: int) -> bool` and `active_count(event: StringName = &"") -> int`, where an empty event counts all voices.
- `##` doc comments on every public member. Rule values are not stored here: F13-02 owns the table.

## Tests required

`tests/unit/audio/test_audio_limiter.gd`, which builds limiters in code and uses fixed ticks:

- `test_first_request_is_granted_with_a_positive_id`
- `test_event_without_a_rule_is_refused`
- `test_repeat_inside_min_interval_is_refused` (ENGINEERING_BRIEF 4.E, "limiting repetitive SFX"), then granted once `tick` covers the interval
- `test_refused_request_does_not_restart_the_interval`
- `test_three_ticks_of_a_sixtieth_end_a_twentieth_interval` (the epsilon)
- `test_per_event_cap_refuses_until_a_voice_ends`
- `test_voice_ends_after_its_duration_in_ticks`
- `test_full_global_cap_steals_the_oldest_lowest_priority_voice` (`voice_stolen` fires once, with the victim's id)
- `test_full_global_cap_refuses_equal_or_lower_priority`
- `test_zero_interval_allows_back_to_back_voices_up_to_the_cap`
- `test_clear_forgets_voices_and_intervals_but_keeps_rules`
- `test_voice_ids_are_never_reused`
- `test_graze_burst_is_capped`: rule 0.06 s / 2 voices / 0.3 s duration, 60 requests one per 1/60 tick. The grant count equals the one the rule implies, computed in the test from the rule values.
- `test_same_sequence_gives_the_same_decisions` (two limiters fed the same calls return identical ids and refusals)

## Out of scope

Playback, streams, buses and the event catalogue with its values (F13-02). Pitch variation, music, pausing (the adapter decides when to tick).

## Definition of Done

- `tools/test.ps1` green. Also grep its output for `SCRIPT ERROR`: a runtime error after an assertion still reports PASS.
- The 4.E test above exists. No Error-level warnings.
- `docs/engineering/audio.md` written with the contract, invariants, tests and open issues. Its README line added.
- One `docs/HANDOFF_LOG.md` entry. Ticket `Status: done` with an `## Outcome`. ROADMAP row updated.
- One commit: `audio: add AudioLimiter core`. Then the lane's land step from `docs/engineering/SPRINT.md` (`tools/lane.ps1 land`).

## Handoff notes for Astra

None for this ticket. The rule values live in F13-02's table and are Claude's proposals. After the D-01 listening pass, tell Claude which sounds feel too dense or too sparse.

## Kickoff prompt

```
In your lane worktree, read AGENTS.md, docs/engineering/SPRINT.md (your lane section), docs/engineering/ROADMAP.md and .scratch/audio/issues/01-audio-limiter-core.md. Check its dependencies with tools/lane.ps1 status F0-02, implement it test-first, run tools/test.ps1 until green with no SCRIPT ERROR, finish its Definition of Done, commit, then run tools/lane.ps1 land.
```
