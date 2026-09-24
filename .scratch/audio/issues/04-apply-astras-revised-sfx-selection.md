# F13-04 Apply Astra's revised SFX selection

Status: todo
Type: integration
parallel-safe: no
Depends on: F13-03
Lane: path
Model: Claude Opus 5.5, solo

## Goal

The user chose Astra's revised sound selection (`sound_effects/README.md` and `sound_effects/selection.json`, 2026-09-24) over D-01's first pass, which F13-03 wired. Apply it so the delivered build plays Astra's mix.

- **Five files change:** ui_focus, graze, pickup_power, threat_warning and boss_phase_changed.
- **Every event gets a new gain, minimum interval and voice count,** and the global cap drops to 8 voices.

This must land before trunk's F14-01 export; aim for 13:30.

## Read first

- `sound_effects/README.md`: "Recommended mapping", "Rules to keep repetition unobtrusive" and "What changed from D-01".
- `sound_effects/selection.json`: exact paths, `gain_db`, `min_interval_seconds` and `max_voices` for all 17 events.
- `scripts/audio/audio_controller.gd` (`EVENT_RULES` and the `event_streams`, `event_volume_db` and `max_voices` exports) and `scripts/audio/audio_limiter.gd`.
- `scenes/main.tscn`, node `Main/Audio`, as F13-03 set it.
- `docs/validation/audio.md`, from F13-03's run.

## Files

- **Creates:** the five new runtime copies, byte for byte from `sound_effects/`:
  - `assets/audio/sfx/interface/select_002.ogg`
  - `assets/audio/sfx/interface/drop_001.ogg`
  - `assets/audio/sfx/interface/drop_002.ogg`
  - `assets/audio/sfx/digital/twoTone2.ogg`
  - `assets/audio/sfx/digital/phaserUp7.ogg`

  Each gets a `.import` with loop disabled, matching the existing sfx imports.
- **Edits:**
  - `scenes/main.tscn` (the `Main/Audio` exports only; the delivery-day exception to "trunk only"): `event_streams` for the five events, `event_volume_db` for all 17 from `gain_db`, and `max_voices` = 8.
  - `scripts/audio/audio_controller.gd`: the per-event `EVENT_RULES` (interval and voices from `selection.json`).
  - `docs/validation/audio.md`: the new mapping, and a re-run.
  - `docs/ASSET_CREDITS.md` ("Sound effects"): only if it lists individual files. The packs are unchanged: interface and digital were already used.
- **Deletes:** the four runtime copies no event uses any more, and their `.import` files: `interface/tick_001.ogg`, `interface/pluck_001.ogg`, `digital/phaseJump2.ogg` and `digital/lowThreeTone.ogg`. `phaserUp2.ogg` stays, for pickup_shield.
- **Serialized at session end:** `docs/engineering/ROADMAP.md` (the F13-04 row), `docs/HANDOFF_LOG.md` (a `[shared]` entry), and `docs/engineering/audio.md` (mapping table).
- **Must not touch:**
  - `sound_effects/**`: Astra's review package stays as delivered.
  - `all-sounds/**`.
  - Any other `main.tscn` node.
  - The files trunk's F14-01 swap step edits today: `player_ship.tscn` and `stage_01.tscn`.
- **Conflicts with:** trunk's F14-01, which starts its export after this lands. Sync right before starting.

## Deliverables

- The 17 events play Astra's files, with her gains and her interval and voice rules. There is a global cap of 8 voices.
- **Optional, only if it is one small change in a producer:** a boss's final defeat no longer also plays `enemy_defeated` under `boss_defeated` (path noticed this in F13-03). Astra's rule is "Trigger each ending once". Anything larger is logged, not built.

## Verification (no tests: SPRINT.md "No new tests")

- `tools/lane.ps1 land` passes.
- Re-run F13-03's headless driver of `main.tscn`, adapted to the new files and limits. Every event plays its new file. The limiter holds held fire to at most about 4 starts per second, and a pickup cluster to one or two sounds. Retry and Restart still stop every sound. Record the results in `docs/validation/audio.md`.
- The listening pass stays with the human pass (F14-02).

## Out of scope

Music (D-01 cleared none), the other producer-coalescing rules in the README (logged for later), and new sounds.

## Definition of Done

`land` passes, the run is recorded, the handoff entry is written, the ticket is `Status: done` with an Outcome, and the ROADMAP row is updated. One commit: `audio: [shared] apply Astra's revised SFX selection`.

## Handoff notes for Astra

Your revised selection is now the shipped mix. The listening pass on headphones and laptop speakers is still owed. A sound you reject after it is a one-line change in `Main/Audio`.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/SPRINT.md and .scratch/audio/issues/04-apply-astras-revised-sfx-selection.md, then implement that ticket solo in lane path with no tests. Verify it by re-running the headless audio driver. Finish with its Definition of Done, commit, and run tools/lane.ps1 land.
```
