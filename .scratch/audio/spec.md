# F13 Audio — spec

Status: ready-for-agent
Owner: Claude (F13-01 and F13-02 on lane glm-a, F13-03 on trunk); Astra (D-01 on lane sol)
Source: PLANEJAMENTO.md Sections 2 ("graphical interfaces and sound effects"), 3 ("New threats originating outside the camera view require directional and audio warnings"), 7 (menu feedback; Graze gets "subtle light and sound feedback") and 9 (minimum audio events, the Kenney packs, music and the fan-content guidelines); STAGE_DESIGN.md "Checkpoint contract" (arches with "a brief glow and sound"); ENGINEERING_BRIEF Sections 4.E ("limiting repetitive SFX") and 4.I ("independent volume buses", "transition-safe audio"); GUIDE.md Section 5 `Main/Audio`, Section 6 `audio_controller.gd`, Section 7; ADR-0001, ADR-0002.

## Goal

After F13 the game has sound effects. Menus sound on navigation and confirm. In play, shots, impacts, Graze, hits, the Shield breaking, Bombs, Pickups, defeats, Checkpoints, off-screen threats, boss Phases, defeat and victory each play one short sound. A burst of 40 Grazes or a Bomb that kills six enemies does not become a wall of noise: `AudioLimiter` caps every event. Unloading a stage (Restart, Retry, Return to Menu, the Campaign transition) silences every sound effect that was in flight. Music plays only if D-01 finds a track the fan-content guidelines permit; otherwise the game ships without music and the decision is recorded.

## Reinstated scope (2026-09-23)

The PO reinstated F13 in reduced but real form, because the assignment requires sound effects. Reduced means: one sound per event, no pitch variation, no positional (3D) audio, no distinct Back sound (Back plays the focus sound of the screen it returns to), and music only when permitted. Real means: every other PLANEJAMENTO Section 9 minimum event is wired to a real producer and heard in the exported game.

## Tickets

1. `01-audio-limiter-core.md` (F13-01, core, glm-a): the Node-free `AudioLimiter`.
2. `02-audio-controller-adapter.md` (F13-02, adapter, glm-a): `AudioController`, tested standalone, attached to nothing.
3. `03-audio-event-wiring.md` (F13-03, integration, trunk): attaches it to `Main/Audio`, fills the mapping from D-01 and connects every producer once in the Session.
4. Design: `.scratch/design-sprint/issues/01-sfx-selection-and-import.md` (D-01, lane sol): the sound selection, imports, licenses and the music decision.

D-01 and F13-01 start at once. F13-02 follows F13-01. F13-03 waits for F13-02, D-01 and trunk's F12-03.

## Event catalogue

The contract between producers, the controller and Astra's selection. Ids are `StringName`s. The rule values (minimum interval in seconds, voices of this event, priority where higher wins) are Claude's proposals; Astra tunes them after listening, through a handoff note.

| Event | Means | Producer (connected in F13-03) | Interval | Voices | Priority |
| --- | --- | --- | --- | --- | --- |
| `ui_focus` | Menu navigation | Viewport `gui_focus_changed` (F13-02) | 0.05 | 1 | 3 |
| `ui_accept` | Menu confirm | `Interface.action_requested`, except `back_refused` (F13-02) | 0.05 | 1 | 3 |
| `player_shot` | The ship fires | `PlayerWeapon.shots_fired(count)`, new in F13-03 | 0.08 | 2 | 0 |
| `enemy_hit` | A player shot hits an enemy or boss | `ProjectileSystem.target_hit(target_id, damage)`, new in F13-03 | 0.05 | 3 | 0 |
| `graze` | A Graze | `ProjectileSystem.grazed(projectile_id)` | 0.06 | 2 | 1 |
| `shield_broken` | A hit breaks the Shield | `CombatState.take_hit` returns `ABSORBED` (F7-01's `_on_player_hit`) | 0.1 | 1 | 3 |
| `player_hit` | A hit takes Health | `take_hit` returns `DAMAGED` | 0.1 | 1 | 3 |
| `bomb_used` | A Bomb goes off | `CombatState.bomb_activated` | 0.1 | 1 | 3 |
| `player_defeated` | Defeat | `CombatState.defeated` | 0.0 | 1 | 4 |
| `pickup_power` | Power Pickup taken | `StageDirector.pickup_accepted`, kind `POWER` | 0.04 | 2 | 1 |
| `pickup_shield` | Shield Pickup taken | `StageDirector.pickup_accepted`, kind `SHIELD` | 0.0 | 1 | 2 |
| `enemy_defeated` | A common enemy dies | `StageDirector.enemy_defeated(enemy_id, encounter_id)`, new in F13-03 | 0.05 | 3 | 1 |
| `checkpoint_activated` | First Checkpoint activation | `StageDirector.checkpoint_activated(checkpoint_id)` | 0.0 | 1 | 2 |
| `threat_warning` | Off-screen attack warning | `StageDirector.threat_reported(side)` | 0.5 | 1 | 2 |
| `boss_phase_changed` | A boss Phase and its Attack begin | `StageDirector.boss_phase_changed(phase_index, attack_display_name)` | 0.0 | 1 | 3 |
| `boss_defeated` | A boss dies | `StageDirector.boss_defeated(boss_id)` | 0.0 | 1 | 4 |
| `stage_cleared` | Victory | `RunState.stage_completed(result)` | 0.0 | 1 | 4 |

Global cap: 12 sound-effect voices (proposal). CombatState has no hit or pickup signal (its signals are `health_changed`, `shield_changed`, `bombs_changed`, `power_changed`, `invulnerability_changed`, `bomb_activated`, `score_awarded` and `defeated`). So hits use the `HitOutcome` that `take_hit` already returns in the Session's one hit handler: it is exact and never fires on `start()`, `refill()` or `restore()`. A hit that defeats plays only `player_defeated`.

## Cross-feature contracts

- **`AudioLimiter`** (F13-01), `scripts/audio/audio_limiter.gd`, `class_name AudioLimiter extends RefCounted`: `_init(max_voices: int)`, `set_rule(event, min_interval, max_voices, priority)`, `request(event, duration) -> int` (a voice id, or `REFUSED` = 0), `tick(delta)`, `clear()`, `is_active(voice_id) -> bool`, `active_count(event := &"") -> int`, and the signal `voice_stolen(voice_id: int)`.
- **`AudioController`** (F13-02), `scripts/audio/audio_controller.gd`, `class_name AudioController extends Node`:
  - Exports: `event_streams: Dictionary[StringName, AudioStream]`, `event_volume_db: Dictionary[StringName, float]`, `max_voices: int = 12`, `sfx_bus: StringName = &"SFX"`, `music_tracks: Dictionary[StringName, AudioStream]`, `music_bus: StringName = &"Music"`, `music_crossfade_seconds: float = 1.0`.
  - Constants `EVENTS` (the catalogue above) and `MUSIC_TRACK_IDS`.
  - API: `setup(interface: Interface)` once, `play_event(event) -> bool`, `stop_all()`, `play_music(track)`, `stop_music()`, `get_current_music() -> StringName`, `get_active_voice_count() -> int`, `missing_events() -> PackedStringArray`, signal `event_played(event: StringName)`.
- **Session wiring** (F13-03). Every producer is connected once, by the Session, in the place that already owns that producer's lifetime:
  - Session-lifetime producers in `_ready`.
  - The Director in `_load_stage`.
  - The ship in F10-03's `_spawn_player`.
  - Where the Session already handles a signal, the `play_event` call goes into that handler, not into a second connection. `audio.stop_all()` runs in `_unload_stage` and in `_retry()`.
- **New producer signals** (F13-03, one declaration and one emit each): `StageDirector.enemy_defeated(enemy_id: StringName, encounter_id: StringName)` on a first report, `PlayerWeapon.shots_fired(count: int)` once per physics tick that fired at least one shot, and `ProjectileSystem.target_hit(target_id: int, damage: int)` beside the stored `on_damage` call.
- **Music track ids**: `menu`, `stage_01_route`, `stage_01_boss`, `stage_02_route`, `stage_02_boss`. PLANEJAMENTO allows route and boss tracks to be shared, so two ids may hold the same stream, and `play_music` does not restart a stream that is already playing.
- **Buses.** `Master`, `Music` and `SFX` stay as F0-03 made them (`tests/unit/project/test_audio_buses.gd`). The controller only picks a bus per player. Bus volumes are F3-02's Options, applied on `AudioServer`, so the controller never sets a bus volume.
- **Assets** (D-01): runtime copies under `assets/audio/sfx/<pack>/<original file name>`, with `<pack>` one of `interface`, `digital`, `scifi` or `impact`. Every sound effect is non-looping. The originals in `all-sounds/` and `Music/` are never edited (GUIDE Section 3).

## Done when

- The F13 tests pass, including the named tests for 4.E (a repeated event inside its interval is refused) and 4.I (no voice survives an unload).
- In the real main scene every catalogue event plays exactly once per producer emission, also after Restart and Retry, and nothing sounds after Return to Menu.
- `docs/engineering/audio.md` holds the limiter, controller and wiring contracts. GUIDE Section 6 `audio_controller.gd` is CODE_READY, and Section 10 "Audio integration" advances.
- `docs/ASSET_CREDITS.md` and `assets/licenses/` cover every shipped sound, and the music decision is recorded.
- A human listening pass is recorded in `docs/validation/audio.md`, or listed there as owed. An agent cannot hear, so its `/run` checks the `event_played` log.

## Out of scope

- Positional 3D audio, pitch or volume randomisation, ducking, a distinct Back sound, slider tick sounds in Options.
- Gate-opened and Seal-destroyed sounds: the Director exposes no public signal for either, so they are a follow-up.
- Applying volumes and saving them (F3-02).
- Any music not cleared by D-01's decision, and any new download. Getting a permitted track is the user's call.
