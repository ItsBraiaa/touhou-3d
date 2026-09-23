# F13-00 Plan the Audio feature

Status: cut (pending the user, 2026-09-23)
Type: docs
parallel-safe: no
Depends on: F3-02 (buses bound), F7-03 (events exist); can be planned earlier and implemented against temporary streams

## Goal

Write `.scratch/audio/spec.md` and the full tickets for F13.

## Planned tickets

1. `01-audio-controller-events-and-limiter`: `audio_controller.gd` on `Main/Audio`: event-to-stream mapping as an exported Dictionary Astra fills (`pickup_accepted`, `player_hit`, `shield_broken`, `bomb_used`, `graze`, `enemy_defeated`, `phase_changed`, `checkpoint_activated`, `ui_focus`, `ui_accept`), per-event rate limiting and voice cap, playback on the `SFX` bus, transition-safe stop on stage unload; temporary streams from `all-sounds/` copied into `assets/audio/` with licenses recorded.
2. `02-music-per-route-and-boss`: one track per route and one per boss on the `Music` bus with crossfade; the fan-content guideline check from PLANEJAMENTO Section 9 decides which files may ship; if no permitted recording is identified, ship without music and record the decision.

## Read first when planning

- `docs/PLANEJAMENTO.md` Section 9 (audio and the fan-content guidelines), Section 7 (interface sounds)
- `docs/ENGINEERING_BRIEF.md` Section 4.I ("limiting repetitive SFX", "transition-safe audio")
- `docs/GUIDE.md` Section 6 row `audio_controller.gd`
- `docs/ASSET_CREDITS.md`

## Definition of Done

- `spec.md` and two ticket files; roadmap rows replaced; commit `plan: write F13 audio tickets`.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/audio/issues/00-plan.md, then write the F13 spec and tickets as described. Finish with its Definition of Done and commit.
```

## Cut (2026-09-23)

Cut from the 2026-09-24 delivery by the one-pass planning session (commit `plan: write F4-F14 tickets`) to protect the Stage 1 loop. Do not pick it while cut; reinstating it is the user's call (set Status back to `todo`, then run this plan ticket as written).

Consequence while cut: the game ships silent. `Main/Audio` keeps no script, and the events that would drive it (`pickup_accepted`, `player_hit`, `shield_broken`, `bomb_used`, graze, `enemy_defeated`, `phase_changed`, `checkpoint_activated`) exist as signals with no audio consumer. The Kenney selection and the music decision under PLANEJAMENTO Section 9 are not made.
