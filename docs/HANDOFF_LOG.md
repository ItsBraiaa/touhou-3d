# Handoff Log

## 2026-09-24 — Claude (path) — F15-03: boss feedback [shared]
State: INTEGRATED_VERIFIED
Files: `scripts/enemies/boss_controller.gd`; `scenes/enemies/storm_guardian.tscn` [shared] (one line on the `Enemy` root: `ring_cue = true`); `docs/engineering/bosses.md` (new "Presentation (F15-03)", export and wiring rows, Setup for Astra); `docs/engineering/enemies.md` (F15-02's Retry sentence corrected for F15-10's defeat beat); `docs/GUIDE.md` (the `boss_controller.gd` row); `docs/engineering/ROADMAP.md` (the F15-03 row).
Change:
- **Facing.** Every boss turns `VisualRoot` toward the player. The turn is yaw only, eased at rate 4 per second, and snapped at spawn. `Emitters/Main` and `HitVolume` do not turn. The Lantern and Storm rotation tracks animate `VisualRoot`'s children, not `VisualRoot`, so nothing fights the turn.
- **Ring cue.** A new `ring_cue` export (group Cues, default off) is set only on the Storm Guardian. With it on, `spawn_setup` builds a hidden `RingCue` under the boss root, so it is freed with the boss. The cue is a flat torus, 1.5 × the hit radius (7.5), additive, unshaded, fog-free, and casts no shadow. Before each step whose Pattern is a RING at a fixed height, the cue appears at `Emitters/Main` + `height_offset` and grows from 0.3 to full size over the Anticipation. It hides when the rings fire, on the next step, and on a Phase's depletion. On the Storm Guardian only Círculos do Trovão qualifies, with cues at +8 and -8.
Verification: a headless throwaway driver through `main.tscn`, run after syncing F15-01 and F15-10. Every check passed:
- The yaw hits its target and eases.
- No cue appears in Phases 0 and 2.
- The high cue sits at emitter + 8 and the low cue at emitter - 8.
- The cue grows from 0.33 to 0.92, stays frozen under Pause, and hides as the rings fire and at once on a mid-cue depletion.
- The boss and its cue are freed with the stage after the victory, and by a Retry during a cue.
- The Lantern Guardian faces the ship and has no cue.
- Both stages clear.
F15-02's driver was rerun on the same tree and passed: `retry_from_checkpoint` called while three enemies were mid-Death removed them at once. No tests (sprint rule).
Action required by Astra: none required. `storm_guardian.tscn` gained only `ring_cue = true`. Set it on another boss to give its fixed-height rings the same cue. The cue's size, colour and growth and both turn rates are Claude's proposals; send Claude values to change them.
Action required by trunk: none.

## 2026-09-24 13:45 — Claude (trunk) — F15-10: defeat beat before the Defeat overlay
State: INTEGRATED_VERIFIED
Files: `scripts/session/game_session.gd` (`DEFEAT_BEAT_SECONDS`, `_on_player_defeated`, new `_show_defeat`, the `_on_stage_completed` doc); `docs/engineering/ROADMAP.md` (the F15-10 row; the F15-01 row moved beside the other lanes' F15 rows, in their format).
Change:
- **Defeat beat.** The defeating hit plays `player_defeated` and starts a 1.0 s beat through F15-01's `_begin_beat`. The tree keeps running, and the ship's controls, the CombatState and Active Time are frozen. Hostile fire is cleared (safe inside the field's step, which reports its events after its sweep), and Pause is refused. Then the tree pauses under the Defeat overlay, as before.
- **A clear during the beat.** A stage clear during the beat starts the victory beat, which cancels the defeat beat's finish, so Results follows and never Defeat. Before, a Defeat raised in the step of the last kill already gave way to Results.
Verification: a headless `main.tscn` driver (throwaway, not in the repo).
- Defeat showed 1.02 s after the hit. The tree was never paused and the controls were never on before it, and Clear Time did not move.
- Pause pressed in the beat was refused.
- Retry returned to the HUD with the tree running and the controls on.
- A clear 10 ticks into the beat showed Results after the 2.5 s victory beat, and Defeat never appeared.
- The F15-01 S1-07 scenario passed again on the same build, with path's F15-02 merged.
No tests (sprint rule).
Action required by Astra: none. 1.0 s is Claude's proposal; tune `DEFEAT_BEAT_SECONDS`.

## 2026-09-24 13:45 — Claude (trunk) — F15-01: victory beat, and a silent Bomb clear
State: INTEGRATED_VERIFIED
Files: `scripts/session/game_session.gd` (`VICTORY_BEAT_SECONDS`, `_begin_beat`, `_cancel_beat`, `_show_results`, `_in_beat`, `_beat_serial`, `_bomb_clearing`); `tests/scene/test_game_session_flow.gd` (`test_a_completed_stage_shows_results` now waits out the beat before its three unchanged asserts: the sprint rule's minimal adjustment of a test the ticket broke on purpose); `docs/engineering/audio.md` (Open issues); `docs/engineering/ROADMAP.md` (the F15-01 row).
Change:
- **Victory beat.** A stage clear still completes the stage at once, so Clear Time stops at the kill. Then, for 2.5 s, the tree keeps running:
  - the ship's controls and fire are off, and the CombatState is paused, so no hit, Bomb or Pickup is taken;
  - hostile fire is cleared, and Grazes are ignored;
  - Pause is refused.
  After the beat the tree pauses and Results shows, with `stage_cleared` and the `STAGE_RESULT` line as before. A Defeat raised in the physics step of the last kill still gets Results at once, with no beat.
- **Reuse.** `_begin_beat(seconds, finish)` and `_cancel_beat()` are the mechanism F15-10 reuses. An unload (Restart, Menu, Continuar, Jogar novamente) or a Retry cancels a beat in progress.
- **Bomb clear.** Enemies killed by a Bomb's damage play no `enemy_defeated`; its `bomb_used` covers them. A boss it kills still rings `boss_defeated` once.
Verification: implementer and reviewer agents, then a headless `main.tscn` driver through the real Stage 1 route to S1-07 (throwaway, not in the repo):
- Results came 2.52 s (151 ticks) after the Lantern Guardian's defeat. The tree was never paused, the screen stayed on the HUD, controls were off and the CombatState paused on every tick, and Clear Time was frozen at the kill.
- Pause pressed 1 s into the beat was refused.
- The boss `Death` clip (0.67 s) and the shrine's `corrupted_to_calm` (2.4 s) both played to the end before Results.
- A Bomb kill in S1-05 left 0 `enemy_defeated` voices and 1 `bomb_used`; an ordinary kill right after still sounded.
No tests (sprint rule).
Action required by Astra: none. 2.5 s is Claude's proposal (the shrine clip is 2.4 s); retune `VICTORY_BEAT_SECONDS` if F15-04's storm calm is longer.
Action required by path: in F15-02, keep `EnemyActor`'s `defeated` report inside its damage call, before the Death clip ("report `defeated` at once"). The Bomb-clear flag is only set during that call.
## 2026-09-24 — Claude (path) — F15-02: enemy feedback
State: INTEGRATED_VERIFIED
Files: `scripts/enemies/enemy_actor.gd`; `docs/engineering/enemies.md` (new "Presentation (F15-02)", signal and export rows, Setup for Astra, Open issues); `docs/GUIDE.md` (the `enemy_actor.gd` row); `docs/engineering/ROADMAP.md` (the F15-02 row).
Change:
- **Anticipation clip.** Each Anticipation plays the clip named by `VisualRoot`'s `metadata/anticipation_clip` (`Yes` for Spirits, `Punch` for Sentries) on `VisualRoot/Model/AnimationPlayer`, stretched to the Anticipation (1.167 s clip over 1.0 s, speed 1.167), then returns to `Flying_Idle`. The dev scale pulse is gone.
- **Hit flash.** Each accepted hit flashes the meshes under `VisualRoot`. The flash is an additive, unshaded, fog-free overlay that fades from 0.85 grey to black in 0.12 s and is then removed. Each actor has its own material, so no other enemy lights up. `HitReact` is not used, because held fire would restart it on every shot.
- **Death.** `defeated` still fires at once on the lethal hit. The actor leaves `targetable` and stops registering its hit sphere, and the Director scores and the Encounter advances. Then `Death` plays for 0.667 s, and the actor frees itself.
- **Facing.** `VisualRoot` turns toward the player (yaw only, eased at rate 6 per second, snapped at spawn).
- **Threats.** An Enemy warns once, on its first off-screen Anticipation. This is Astra's "new threat" rule.
- A visual that lacks the player or a named clip gets one `push_warning`, and that cue is skipped.
Verification: a headless throwaway driver (not in the repo), run after syncing F15-08's twilight and seal prefabs. Every check passed:
- Arena harness: the clips and their speeds, the flash rising and then removed while the other enemy stays dark, the yaw target and the eased turn, one warning from three off-screen Anticipations, and a lethal hit. After that hit, `defeated` fired once at once, the actor was out of `targetable`, a Bomb at its center found 0 targets, it was still dying at 0.53 s and was freed by 0.73 s.
- Retry: Stage 1 from CP1-A. Three S1-05 enemies were killed and died mid-Death; the score rose at once. A Defeat followed, all three were still dying under the pause, and after Retry none was left in the tree. The stage then cleared.
- A Direct Stage 2 clear.
- No `SCRIPT ERROR` and no clip warning.
No tests (sprint rule).
Action required by Astra: none required. To change the Anticipation gesture, edit `metadata/anticipation_clip` on a visual. The flash colour and length and the turn rate are Claude's proposals; send Claude values to change them.
Action required by trunk: none. F15-01's victory beat will show a common enemy's `Death` too, since the actor now outlives its report by 0.667 s.

## 2026-09-24 — OpenCode (oc-a) — F15-09 HUD edge cues
State: DELIVERED
Files: `scripts/ui/hud.gd`, `tests/scene/test_hud_contract.gd` (obsolete expectation only), `docs/engineering/ROADMAP.md`.
Change: The locked target marker now remains visible when its projection is off-screen or behind the camera, clamped inside the screen edge and rotated toward the target. Hud builds a subtle full-screen boundary vignette in code and connects the bound ship's `edge_proximity_changed` through `Targeting`'s parent, with a short fade tween. No `hud.tscn` or Session edit.
Verification: The existing HUD contract expectation for behind-camera hiding was minimally updated because F15-09 intentionally replaces it with an edge marker; no new test was added. `tools/lane.ps1 land` is the gate.
Action required by trunk: the pre-existing behind-camera marker expectation is superseded by F15-09 behavior if an acceptance test still asserts hiding it.
## 2026-09-24 — Astra (sol) — F15-08 enemy colour variants [shared]
State: DELIVERED
Files: `scenes/dev/spirit_twilight.tscn`, `scenes/dev/sentry_seal.tscn`, `scenes/stages/stage_01.tscn`, `scenes/stages/stage_02.tscn`, `content/stages/stage_01/s1_02.tres`, `s1_04.tres`, `s1_05.tres`, `content/stages/stage_02/s2_01.tres`, `s2_02.tres`, `s2_03.tres`, `s2_05.tres`, `docs/engineering/ROADMAP.md`.
Change: New actor prefabs instance Astra's Twilight Spirit and seal Sentry visual roots with the original actor script, HitVolume radius, and emitter. Stage 1 assigns Lume to S1-02 wave 1, Twilight to wave 2, seal Sentries to S1-04, and mixed Spirit colors with lantern Sentries to S1-05. Stage 2's ordinary Spirit/Sentry waves use the violet pair. Each new kind maps to the same Spirit or Sentry EnemyDefinition resource, so health, score, pattern, collision and rewards remain unchanged. No tests added (sprint rule).
Action required by Claude: none; scene wiring is declared here because it is Claude-owned under GUIDE Section 3.


## 2026-09-24 — OpenCode (oc-a) — F15-06 checkpoint glow and Gate fade
State: DELIVERED
Files: `scripts/progression/checkpoint.gd`, `scripts/progression/gate.gd`, `scripts/progression/stage_director.gd`, `docs/engineering/ROADMAP.md`.
Change: Checkpoints create an activation OmniLight3D and bloom it on first activation; `_apply_progress()` restores each glow immediately from the machine state for Retry and Restart. Gates now tween `ClosedVisual` transparency when opening, while `restore_open()` cancels presentation tweens and restores collision, visibility and transparency immediately and idempotently. Stage Director call sites remain in small private presentation/restore functions for the shared-file merge.
Verification: `tools/lane.ps1 land` and the short headless boot are the gate; no tests added (sprint rule).
Action required by sol: merge the small F15-06 additions in `stage_director.gd` when landing F15-04.
## 2026-09-24 — Astra (sol) — F15-04 storm resolution [shared]
State: DELIVERED
Files: `scenes/stages/stage_02.tscn`, `scenes/stages/stage_01.tscn` (one export), `scripts/progression/stage_director.gd`, `docs/engineering/ROADMAP.md`.
Change: Stage 2's `Environment/StormResolution` plays `storm_to_calm` for 2.4 s with `process_mode = 3`, easing fog density 0.0012 → 0.00025, sky background energy 1.0 → 1.45, and StormLight energy 1.0 → 0.62. The Director plays a defeat presentation only for `defeat_presentation_boss_id`: `storm_guardian` in Stage 2 and `lantern_guardian` in Stage 1. Retry rewinds the presentation to its storm or corrupted state. Tempest Sentinel defeat leaves Stage 2 weather untouched. No tests added (sprint rule).
Action required by oc-a: keep F15-06's checkpoint and Gate call sites in their own functions when merging `stage_director.gd`; retain the keyed presentation and Retry rewind.


## 2026-09-24 — Astra (sol) — F15-05 UI truth [shared]
State: DELIVERED
Files: `scenes/ui/controls.tscn`, `scenes/ui/results.tscn`, `docs/engineering/ROADMAP.md`.
Change: The camera binding now says "Setas". Results places Menu principal and Créditos in the first two button slots, so final victory shows no empty slot when Continue and Replay are hidden. Continue or Replay remains available in the third slot in other modes. No tests added (sprint rule).
Action required by Claude: none.

## 2026-09-24 — Claude (path) — Audio endings: boss and stage endings each play once, in order
State: INTEGRATED_VERIFIED
Files: `scripts/audio/audio_controller.gd` (`play_event_after`, `silence`, `stop_all` drops the waiting event); `scripts/session/game_session.gd` (`_boss_defeat_heard`, `_quit`, `_notification`, `QUIT_SILENCE_SECONDS`, `auto_accept_quit` off); `docs/engineering/audio.md`, `menus-session.md` (the `quit` row), `project.md` (open issue closed), `ROADMAP.md` (F13 row 05); `docs/validation/audio.md`.
Change:
- **Each ending once.** A boss's defeat plays only `boss_defeated`. The Director's `enemy_defeated` for the same kill, which follows in the same call, plays nothing.
- **In order.** `stage_cleared` starts when the bell's voice expires: 1,476 ms after it on S1-07; the bell is 1,480 ms. It used to start in the same frame. Leaving Results before then drops it.
- **Silent quit.** Sair, the window's close button and Alt+F4 now stop every sound and the music, then quit 0.1 s later. Headless, quitting with four sounds playing printed `ERROR: 8 resources still in use at exit` before the fix. After it, both paths printed nothing.
Verification: a headless S1-07 clear driver, a headless quit driver and F13-04's 64-check audio driver (all throwaway, not in the repo) passed. Record: `docs/validation/audio.md`. No tests (sprint rule).
Action required by Astra: none; no file of yours changed. The listening pass (F14-02) can drop the two known overlaps from its list.
Action required by trunk: none. The `game_session.gd` additions are private functions and one flag.
## 2026-09-24 — Astra (sol) — F14-02 credits gaps closed [shared]

State: DELIVERED

Files: `docs/ASSET_CREDITS.md`; `scenes/ui/credits.tscn`; `docs/validation/acceptance.md` (F14-02 "Credits coverage"); `docs/engineering/ROADMAP.md` (F14 and F14-02 request rows).

Change: Credited the five original D-02 combat materials and the original Stage 1 gate veil shader in the asset record. The in-game Créditos screen now names Quaternius · Ultimate Monsters · inimigos e chefes · CC0 beneath the existing Kenney ship credit, using the same label style. Updated F14-02's acceptance and roadmap notes to record the gaps as closed. No asset, script, or test changed.

Action required by Claude: none. The `docs/validation/acceptance.md` and `docs/engineering/ROADMAP.md` edits are shared-file updates for this handoff.

## 2026-09-24 — OpenCode (oc-b) — F14-02 part 2: the package, credits and acceptance record
State: DELIVERED
Files: `tools/package.ps1` (the archive root fixed); `docs/validation/acceptance.md` (all 32 checks filled); `docs/validation/export.md` (new "Package" section); `docs/engineering/ROADMAP.md` (the F14-02 row and one "Requests to Astra" row); `docs/engineering/project.md` ("Export" now points at the package script); F14-02 ticket (`Status: done`).
Change:
- **Re-export.** After `tools/lane.ps1 sync`, F14-01's command was rerun from the synced tree: `tools/test.ps1` green (225/0), `--import` once, `--export-release "Windows Desktop" build/Touhou-3D.exe` — exit 0, no `ERROR:` or `WARNING:`, 129,258,616 bytes and 91,136 bytes, byte-identical to F14-01's build. A fresh worktree must create `build/` first, or the export aborts with "the export path does not exist".
- **Fix.** Part 1 archived `build/package/Touhou-3D/*`, so the zip had no `Touhou-3D/` root and the verify step failed with `Invalid project path specified`. It now archives the `Touhou-3D` folder itself.
- **Package.** On a clean tree it printed `PACKAGE_ARCHIVE … : build/package/Touhou-3D-<yyyyMMdd>.zip`, 743 staged files, then `PACKAGE_OK`: the extracted project imported, its suite passed, and `game/Touhou-3D.console.exe --headless --quit-after 300` booted with no `ERROR:` line. Refusals: a missing executable exits 2, a dirty tree exits 3.
- **Acceptance.** `acceptance.md` covers all 32 checks: no fail; P3/S13 (the five-minute Stage 2 clear) and P18 (instructor approval) are not verified; every physical, listening, played-time and presentation-computer item is marked owed by the human pass. Nothing is cut (SPRINT reinstates F3, F13 and Stage 2). No tests (SPRINT rule).
Action required by Astra: add `ASSET_CREDITS.md` entries for the five original D-02 materials in `assets/combat/` and for the original `assets/environment/stage_01/gate_veil.gdshader`, and add the Quaternius enemy/boss models to the in-game Créditos text (`scenes/ui/credits.tscn`), which credits the ship and the sound effects but not the models. The files need no change.
Action required by trunk: none. No trunk-only file changed.

## 2026-09-24 12:30 — Claude (trunk) — F14-01: the Windows build exported and run outside the editor
State: INTEGRATED_VERIFIED
Files: `export_presets.cfg`; `docs/validation/export.md` (new); `docs/engineering/project.md` (header, Files, new "Export" section, Open issues); `docs/GUIDE.md` (Section 10 "Foundation and conventions"); `docs/engineering/ROADMAP.md` (the F14-01 row, "Human steps"); F14-01 ticket.
Change:
- **Export.** The release build of `dev-01` `8061d77`, which includes F13-04 and the swap step below, exported with exit 0 and no `ERROR:` or `WARNING:` line. `build/Touhou-3D.exe` is 129,258,616 bytes. `export_presets.cfg` `debug/export_console_wrapper` went from 1 to 2, so a release export also writes `build/Touhou-3D.console.exe`. No other key changed.
- **Runs outside the repository.** D3D12 12_0 Forward+ on the RX 9070 XT, no fallback, 1280 × 720 windowed, V-Sync capped at 60.
  - A keyboard-event walk passed the ticket's walk, and Sair quit the game with exit 0.
  - FPS held 59 to 60 in S1-01, in S1-02's Waves, and in every Phase of the Lantern Guardian (106 hostile at peak) and the Storm Guardian (93). With V-Sync off, the Storm Guardian never fell below 1,171 FPS.
  - No run printed `ERROR:`, `SCRIPT ERROR` or `WARNING:`.
- **Export-only failures:** none.
- **Details.** Full record and the presentation-computer protocol: `docs/validation/export.md`. The command and environment: `project.md` "Export".

Why: F14-01, the last trunk ticket before delivery.
Action required by oc-b (F14-02 part 2): re-export with `project.md` "Export":
1. `tools/test.ps1`;
2. `--import` once;
3. `--export-release`.

Package both exes. The release build ignores `--script`. A scratch autoload named in an `override.cfg` beside the exe can drive it, but never ship an `override.cfg`. The acceptance rows for 60 FPS and "exported build runs outside the editor" can cite `export.md`: verified on the development PC, not on the presentation computer.
Action required by Astra: none. No asset of yours failed in the export.

## 2026-09-24 — Claude (path) — F13-04 Astra's revised SFX selection applied [shared]
State: CODE_READY
Files: `assets/audio/sfx/interface/select_002.ogg`, `drop_001.ogg`, `drop_002.ogg`, `assets/audio/sfx/digital/twoTone2.ogg`, `phaserUp7.ogg` and their `.import` files (new); `interface/tick_001.ogg`, `interface/pluck_001.ogg`, `digital/phaseJump2.ogg`, `digital/lowThreeTone.ogg` and their `.import` files (deleted); `scenes/main.tscn` (`Main/Audio` only); `scripts/audio/audio_controller.gd` (`EVENT_RULES`); `tools/validate_audio_selection.gd`; `docs/engineering/audio.md`; `docs/validation/audio.md`; `docs/ASSET_CREDITS.md`; `docs/GUIDE.md` (audio row); `docs/engineering/ROADMAP.md`; F13-04 ticket.

Change: your revised selection is the shipped mix. The five replacements are byte-for-byte copies of `sound_effects/`, with loop off. All 17 gains are in `Main/Audio.event_volume_db`, and all 17 intervals and voice counts are in `EVENT_RULES`, so every event has one voice. The global cap is 8. Priorities are unchanged. The four runtime copies no event uses are deleted. `sound_effects/**` and `all-sounds/**` are untouched. Shared-file edits: `ASSET_CREDITS.md` "Sound effects" counted 16 files and linked D-01's table; it now counts 17 and links the new mapping table in `engineering/audio.md`. D-01's `tools/validate_audio_selection.gd` named the deleted files, and now names the new ones. `docs/validation/audio-selection.md` stays as D-01's historical record.
Verification: F13-03's driver, adapted and run headless on `main.tscn`, passed 64 checks with no `SCRIPT ERROR`, `ERROR:` or `WARNING:`. Every stream, gain, interval and voice count matched `selection.json`. All 17 events were heard on a playing pool player holding your file at your gain. Held fire gave 3.33 starts per second. Each 5-Pickup cluster gave 1 sound. The full Stage 1 route ended in one `boss_defeated` and one `stage_cleared`. There was silence right after Retry, Restart and Return to Menu. A 17-event burst peaked at 8 voices and kept the endings and player damage. `validate_audio_selection.gd`: `failures=0`. No tests (sprint rule).
Action required by Astra: the listening pass (human, F14-02), using your README protocol. Not built, and logged in `engineering/audio.md` "Open issues": a boss's final defeat still plays `enemy_defeated` under `boss_defeated`, because the fix needs a flag across two Session handlers. The bell and `stage_cleared` still start in the same frame. The new-threat-only warning and silent deaths during a Bomb clear are not built either. A sound you reject is a one-line change in `Main/Audio`.
Action required by trunk: `main.tscn` changed only in `Main/Audio` (four ext_resource paths, one new ext_resource `35_boss_phase_changed`, `load_steps=36`, the volumes and `max_voices = 8`). Sync before F14-01's export.
## 2026-09-24 11:55 — Claude (trunk) — F14-01 swap step: D-02 and D-07 applied [shared]
State: CODE_READY
Files: `scenes/stages/stage_01.tscn` **[shared]** (the `Stage` node's exports only); `scenes/main.tscn`; `scenes/player/player_ship.tscn`; `scenes/dev/bomb_blast.gd` and `.tscn`; `scripts/combat/player_weapon.gd` (one doc line); `docs/engineering/ROADMAP.md` (the F6-02, F6-03, F7-02 and F14-01 rows).
Change: every pending swap and every value Astra asked trunk to set, before the export:
- **D-07 Part A.** On Stage 1's `Stage`: `defeat_presentation = NodePath("Environment/ShrineLighting")` and `defeat_animation = &"corrupted_to_calm"` (the node line gained `node_paths`). No node, light, geometry or marker changed. `check_setup()` returns no message, and the clip is found.
- **D-02 Projectiles.** `Main/ProjectileRoot` now uses `scenes/combat/visuals/projectile_player_mesh.tres` (the octahedron) and `projectile_hostile_mesh.tres`. The dev meshes in `scenes/dev/` are no longer referenced.
- **D-02 Familiar.** `PlayerShip/Weapon.familiar_scene` → `scenes/combat/visuals/familiar.tscn`.
- **D-02 Bomb blast.** `scenes/dev/bomb_blast.tscn` is now a `BombBlast` root around an instance of `bomb_blast_visual.tscn` (`Visual`). `setup(radius)` scales the unit rings to `bomb_radius`, and the node frees itself when `blast` finishes. The dev sphere and its fade code are gone.
- **D-05.** It asked for no weapon or Bomb change, so `player_ship.tscn` keeps the code defaults: lock assist 25°, Bomb radius 10, damage 20.
- The D-02 Pickup visuals (F7-03) and D-03/D-04 boss scenes (F12-03, F12-06, F12-07) were already in place.

Verification: `validate_combat.gd` headless ends `COMBAT_OK`, including check 18 "the blast visual appeared and freed itself within 0.4 s". `validate_stage_01.gd` reports `failures=0`. A scratch check read the four swapped values back. No tests (sprint rule).
Action required by Astra: none. The shrine clip now plays on the Lantern Guardian's defeat; the build will show it.

## 2026-09-24 — Claude (path) — F10-05 Retry restores the checkpoint's pickups
State: CODE_READY
Files: `scripts/progression/stage_director.gd`; `docs/engineering/stage-director.md`; `docs/validation/stage-director.md`; `docs/validation/stage-director-retry-pickups.png` (new); `docs/validation/stage-01-progression.md`; `docs/GUIDE.md`; `docs/engineering/ROADMAP.md`; F10-05 ticket.

Change: Astra's decision is implemented as written. The Director records every Pickup it spawns (`_live_pickups`: prefab and spawn point) and drops it on `accepted`. It copies the record when a Checkpoint activates (`_record_checkpoint_pickups`, after `CheckpointStore.activate` returned true), and on Retry spawns the copy again at the spawn points, bound to the new ship (`_restore_checkpoint_pickups`). So Pickups collected before the Checkpoint stay collected, those live at it come back even when the failed Attempt took them, and those spawned after it are removed and return with their replayed Encounters. `_spawn_pickup` refuses an id that is already live. The Session's `_retry` order is unchanged. Stage 2's entry fallback and Seal rewards already go through the two functions touched, so CP2-A records its Seal Pickups.
Verification: driven headless on `main.tscn`, 70 checks passed. The five S1-02 Pickups came back on their 1.5 ring, twice. One taken before CP1-A stayed taken. One taken after came back, with Power reset to the Snapshot's and +1 Progress when taken again. S1-05's five were removed on Retry and dropped once more on replay. All ten Power Pickups came back from CP1-B. The guard never fired and there was no `SCRIPT ERROR`. Windowed capture `stage-director-retry-pickups.png`. No new tests (sprint rule). `stage-director.md`'s open-issue line "No Checkpoint glow or sound yet" became "No Checkpoint glow yet" (F13-03 added the sound).
Action required by Astra: none. Restored Pickups reappear at their spawn point (the ring around `RewardOrigin`, or the `ShieldPickup` marker), not where they had drifted; say so if you want otherwise.
Action required by sol: `stage_director.gd` gained two members after `_live_enemies`, three private functions after `_spawn_pickup`, a guard and two lines in `_spawn_pickup`, and one call line each in `_on_checkpoint_entered` and `retry_from_checkpoint`. Keep them when you merge F12-06/F12-07 part 2.

## 2026-09-24 11:36 — Claude (trunk) — F11-03 follow-up: Stage 2 flown end to end
State: docs
Files: `docs/validation/clear-time.md`; `docs/engineering/run-flow.md` ("Time accounting evidence", Open issues); `docs/engineering/ROADMAP.md` (F11-03 row); F11-03 ticket Outcome.
Change: This supersedes the entry below on Stage 2. F12-06 and F12-07 part 2 landed while F11-03 was in flight, so the driver gained two Stage 2 scenarios. It reran in full on `lane/trunk` `6284db6`, the merge with `dev-01` `1c3f4bf`, and passed: `TA_OK`, 33 checks, no `ERROR:` or `WARNING:`. Results:
- **Direct Stage 2.** An uninterrupted clear through the real route (Waves, Guards, three Seals, the Tempest Sentinel's two Phases and the Storm Guardian's three) shows `attempt=1`, with Clear Time exactly its 390 counted ticks.
- **Campaign.** Stage 1 cleared, then Continuar, then Stage 2. A defeat after the miniboss and a Retry returned to CP2-A's committed time and score, and the miniboss had to be fought again. The final clear showed `Jornada concluída`, with one `run_ended(true)`.

Stage 2's five-minute clear is still not measured; a person must play it. `clear-time.md` step 5 is ready for F14-02's human pass.
Why: the ticket's sprint note says to measure Stage 2 once F12-07 has landed. The rules are now checked on both real routes; the played duration still needs a person.
Action required by Astra: none. Sol's `docs/validation/bosses.md` says a controlled fight through both Stage 2 bosses is owed. This scripted pass fought both through all their Phases, via the Director, by direct damage. That is not a feel or difficulty check.
## 2026-09-24 — Claude (path) — F13-03 audio event wiring
State: CODE_READY
Files: `scenes/main.tscn`; `scripts/session/game_session.gd`; `scripts/progression/stage_director.gd`; `scripts/combat/player_weapon.gd`; `scripts/combat/projectile_system.gd`; `docs/engineering/audio.md`; `docs/validation/audio.md` (new); `docs/GUIDE.md`; `docs/engineering/ROADMAP.md`; F13-03 ticket.

Change: `Main/Audio` carries `AudioController` with D-01's 17 non-looping effects in `event_streams` and its volume proposals in `event_volume_db`; `music_tracks` stays empty (no cleared track). `GameSession.audio` is typed `AudioController`. The game session and `main.tscn` were edited by lane path as the delivery-day exception the user granted; trunk's F14-01 and later edits merge on top. Every producer is connected once where the Session owns it: `audio.setup(interface)` and `ProjectileSystem.target_hit` in `_ready`; the Director's `pickup_accepted`, `enemy_defeated` and `checkpoint_activated` in `_load_stage` (`_connect_director_audio`); the ship's `PlayerWeapon.shots_fired` in `_spawn_player`; every other event from the handler the Session already had (hits by `HitOutcome`, Graze, Bomb, Defeat, stage clear, threats, boss). `_unload_stage` and `_retry` call `audio.stop_all()`; music calls follow the menu, `<stage>_route` and `<stage>_boss` and are no-ops today. Three producer signals, one declaration and one emit each: `StageDirector.enemy_defeated` (in `_on_enemy_defeated`, after scoring; a boss's defeat emits it too), `PlayerWeapon.shots_fired(count)` (end of `_fire`, only when the field took a shot), `ProjectileSystem.target_hit` (beside the `on_damage` call; not the Bomb's).
Verification: `tools/test.ps1` 225 passed, no `SCRIPT ERROR`, no test changed or added (sprint rule). A throwaway driver of `main.tscn` from the main menu, headless then windowed, passed 54 checks: one connection per producer after the first load, Retry and two Restarts; menu focus and accept once each; shield, health and defeating hits each with their own sound only; the full Stage 1 route to the Lantern Guardian (3 `boss_phase_changed`, 1 `boss_defeated`, 1 `stage_cleared`); zero voices right after Retry, Restart and Return to Menu, and no gameplay sound afterwards. Details in `docs/validation/audio.md`.
Action required by Astra: the listening pass (human, F14-02). To retune an event's interval, voices, priority or volume, or swap a file, send a new catalogue row. `StageDirector.checkpoint_activated` now also plays a sound; the arch glow is still yours.
Action required by sol: `stage_director.gd` gained one signal declaration (after `boss_defeated`) and one emit line in `_on_enemy_defeated`; keep both when you merge F12-06/F12-07 part 2.
## 2026-09-24 — Astra (sol) — D-01 selected sound folder and music path casing
State: done
Files: `sound_effects/` (17 original Ogg clips, four pack licenses, selection.json, README.md, .gdignore); `.gitignore`; folder references in design, audio, foundation, delivery and project documentation.
Change: User requested the measured 17-event shortlist in `sound_effects/`, and lowercase `music` folder references. The folder is a curated source selection, excluded from Godot discovery via .gdignore; runtime copies and audio event wiring remain as delivered. Gains and repetition settings in the manifest remain proposals pending listening. Documentation and ignore rules now use `music/`. The Godot bus named `Music` is unchanged. Earlier handoff entries are historical and retain their original wording; their `Music/` source-folder references mean `music/` today.
Verification: all 17 copied clips match the reviewed selection byte for byte; four source licenses included. No new tests. The lane landing gate records automated validation.
Action required by audio owner: use this selection for the next approved runtime mapping/mix pass; do not interpret the folder move as a completed listening pass.

## 2026-09-24 — Astra (sol) — Stage 2 content review (D-06 pass 3) [shared]
State: SCENE_READY
Files: `content/bosses/tempest_sentinel.tres`; `content/bosses/storm_guardian.tres`; five `content/patterns/{sentinel,storm}_*.tres`; `docs/validation/stage-02-pacing.md`; ROADMAP; D-06 ticket.

Tempest Sentinel health 520/780 → 440/660 (about 20/30 s at measured Power-3 boss DPS 22.1). Storm Guardian health 1040/1040/1300 → 885/885/1105 (about 40/40/50 s). `storm_spiral` volley count is unchanged at six, and projectiles per volley 8 → 6 to open wider corridors. Entry 1.0 s, transitions 0/0.75 s, step timing, other pattern numbers, Attack names, structure and scores 500/1000 are unchanged. All seven boss resources gained `metadata/reviewed = true`; `metadata/dev` remains. Bomb damage 20 is below the smallest Phase health 440.

The reward audit remains exact: seven Power and two Shield, including one Power per Seal. Five early Power items can lift a Direct Stage 2 player from Power 2 to 3 before S2-04; a Campaign player already at Power 3 scores excess pickups. Conditional estimates are about 336 s efficient and 426 s normal, not measured; the ≥300 s requirement remains unverified until F11-03/F14-02's uninterrupted human clear. No content bug or Stage-2-only common-enemy request. `lane.ps1 land` is the gate; no new tests were written.


## 2026-09-24 11:35 — Claude (trunk) — Active Time and Clear Time verification (F11-03)
State: docs
Files: `docs/validation/clear-time.md` (new); `docs/engineering/run-flow.md` ("Time accounting evidence"); `docs/engineering/ROADMAP.md` (F11-03 row); F11-03 ticket.
Change: A scratchpad `SceneTree` driver of `main.tscn` ran headless twice (`TA_OK`, no `SCRIPT ERROR`, `ERROR:` or `WARNING:`). A tick probe running just before `Main` counted every tick in which the Session may add Active Time. Results:
- Pause, Options from Pause, a controller-disconnect Pause, Defeat, Results, Credits, the main menu, Stage Select and Options add 0 s.
- Retry after CP1-A drops the failed segment's time, score and Bomb.
- Restart zeroes Clear Time, before and after a Checkpoint.
- Three failed Attempts leave only the last one's time.
- Campaign Stage 2 starts at 0 with the score carried.
- A real-route uninterrupted Stage 1 clear through the Lantern Guardian shows `attempt=1`, with Clear Time exactly its 431 counted ticks.

No defect was found, so no code changed; `run_state.gd` and `game_session.gd` are untouched. No new tests, by the sprint rule. `clear-time.md` also holds the manual protocol and its record.
Why: the academic duration check needs proof that Pause, menus and failed attempts never reach the displayed time, plus a protocol for the measured clears.
Action required by Astra: none now. After the human pass, `clear-time.md` steps 2 and 3 give Stage 1's played clear times against the 240 s target, for `content/stages/stage_01/*.tres` pacing.
Action required by the human pass: steps 2 to 4 of `clear-time.md` (Stage 1 efficient and Campaign clears, a Retry run with a stopwatch), on a physical device. Step 5, the Stage 2 five-minute clear, waits for F12-07. F14-02's acceptance record can cite this page.
## 2026-09-24 — Astra (sol) — Shrine lighting and boss rulings (D-07 Parts A and C) [shared]
State: SCENE_READY
Files: `scenes/stages/stage_01.tscn`; `tools/validate_stage_01.gd`; `content/bosses/lantern_guardian.tres`; three `content/patterns/lantern_*.tres`; `docs/validation/stage-01-shrine.md` and its two captures; `docs/validation/stage-01-pacing.md`; ROADMAP; D-07 ticket.

Trunk F14-01: set Stage `defeat_presentation = NodePath("Environment/ShrineLighting")` and `defeat_animation = &"corrupted_to_calm"`. The clip lasts 2.4 s, does not loop or autoplay, and its player runs under paused Results. F11-01's owner decides whether Results' overlay shows enough of the calm shrine or needs a short delay. First and final keys match corrupted and calm light; a new instance starts corrupted. The windowed and headless Stage validator passed with zero failures. S1-07 health 1500/1500/2100 → 550/550/775, for approximately 25/25/35 s at the measured 22.1 Power-3 DPS; transitions stay 0/0.75/0.75 s. All three pattern numbers are retained after review of high/low rings and player-height aimed bursts. Four content resources gained `metadata/reviewed = true`; `metadata/dev` remains. Estimated S1-07 is about 87 s, not a measured clear.

| Ruling | Decision | Follow-up |
| --- | --- | --- |
| 1 Transition damage | Refused for at most 0.75 s; no Phase skip. | Applied to D-07 and D-06 values; no code change. |
| 2 HUD dimming | Spent alpha 0.25, completed Phase alpha 0.30. | None. |
| 3 Two-Phase bars | Full-width 16–307 and 313–604. | Applied in F12-06 `Hud.show_boss`; none pending. |
| 4 Ship yaw | Visual stays fixed relative to camera yaw, with cosmetic banking. | None. |
| 5 Graze while invulnerable | Contact strictly spends that Projectile's Graze chance. | None. |


## 2026-09-24 — Astra (sol) — Storm Guardian (F12-07 part 2) [shared]
State: CODE_READY
Files: `scenes/enemies/storm_guardian.tscn`; `scenes/stages/stage_02.tscn`; F12-07 ticket; ROADMAP, GUIDE, bosses and run-flow contracts, validation note.

S2-07 now selects the real three-Phase Storm Guardian definition and prefab through StageDirector. Its BossController uses VisualRoot, HitVolume, Emitters/Main and VisualRoot/Model/AnimationPlayer, with Flying_Idle, Punch, Yes and Death. It keeps the three authored Attack names and the 1,000 score from part 1. Final defeat follows the existing Stage 2 clear and Campaign final-victory path. D-06 pass 3 owns numeric tuning. No new tests under the sprint rule.


## 2026-09-24 — Astra (sol) — Tempest Sentinel (F12-06 part 2) [shared]
State: CODE_READY
Files: `scenes/enemies/tempest_sentinel.tscn`; `scenes/stages/stage_02.tscn`; `scripts/ui/hud.gd`; F12-06 ticket; ROADMAP, GUIDE, bosses contract and validation note.

The S2-04 stand-in now uses the two-Phase Tempest Sentinel definition and its authored boss prefab. BossController references VisualRoot, HitVolume, Emitters/Main and the model AnimationPlayer; clips are Flying_Idle, Punch, Yes and Death. HUD shows the two authored bars at 16–307 and 313–604, restoring the original three-bar positions on the next three-Phase boss. Content and Attack names remain dev proposals for D-06 pass 3. No new tests under the sprint rule.


## 2026-09-24 — OpenCode (oc-a) — D-08 enemy visual duplicate parts [shared]
State: dev
Files: `scenes/enemies/visuals/spirit_lume.tscn`; `spirit_twilight.tscn`; `sentry_lantern.tscn`; `sentry_seal.tscn`; `tools/build_enemy_visuals.gd`; `docs/ENEMY_VISUAL_HANDOFF.md`; `docs/validation/enemy-visuals.md`; `docs/engineering/ROADMAP.md`; D-08 ticket.

Change: Part 1 confirmed that every visual scene loaded both its glTF instance subtree and its embedded tinted subtree: two meshes, surfaces, skeletons and animation players, four detached nodes and four left nodes. The arena harness also leaked visual classes at exit. Part 2 removed exactly the glTF ext_resource and `instance=ExtResource(...)` from each `Model`, leaving the embedded tinted/looping set. The generator now clears `scene_file_path` before packing and warns that reruns drop D-05's anticipation metadata; it was not run.
Verification: post-fix counts match both controls at 1/1/1/1/0/0; `validate_enemy_visuals.gd` passed with `failures=0`; the short windowed launch reached Forward+ and was closed after ten seconds. No new tests.
Action required by Astra: inspect the four-scene diff and confirm the single tinted body in a normal arena run; do not rerun the generator over these integrated scenes.
Action required by trunk: the enemy visual leak note in `docs/engineering/stage-director.md` is resolved for these four scenes.

## 2026-09-24 — OpenCode (oc-a) — Stage validators accept the Director
State: dev
Files: `tools/validate_stage_01.gd`; `docs/engineering/ROADMAP.md`; F10-06 ticket.

Change: The Stage 1 validator now accepts exactly no root script or `res://scripts/progression/stage_director.gd`; other root scripts still fail. Stage 2 and scene-handoff validators were unchanged.
Verification: `validate_stage_01.gd` ended `STAGE_01_QA_COMPLETE failures=0 encounters=7 spawns=18 checkpoints=2 gates=4` (exit 0); `validate_stage_02.gd` ended `STAGE_02_PREVIEW_LOAD_OK (no rendered evidence in headless mode)` (exit 0; no F12-05 commit was present in `dev-01`); `validate_scene_handoff.gd` ended `SCENE_CONTRACT_OK: 10 required nodes; targets=3` (exit 0).
Action required by Astra: none. Trunk may remove the resolved validator bullet from `docs/engineering/stage-director.md` in its next doc pass.

## 2026-09-24 — Astra (sol) — Stage 2 content review (D-06 pass 2) [shared]
State: SCENE_READY
Files: scenes/stages/stage_02.tscn; docs/validation/stage-02-pacing.md; docs/engineering/ROADMAP.md; D-06 ticket.

Seal1, Seal2 and Seal3 health: inherited default 10 → explicit authored 10. No behavior or other scene value changed; F12-05's game walkthrough already exercised that health. Estimated exposed destruction is 0.74 s efficient / 0.93 s normal at Power 2, keeping it a brief confirmation after the Guards. Rewards remain seven Power and two Shield; five early Power pickups can reach Power 3 before the miniboss.

Updated the conditional estimates for D-05's shared Spirit 30/Sentry 45 health: about 336 s efficient and 414 s normal, neither measured. Boss budgets are provisional until pass 3. No content bug or Stage-2-only request found. F12-05 passed land (main-scene boot clean; 80 resources and 81 scripts, zero failed/invalid); D-06 pass 2 uses the same sprint gate and writes no tests. Ticket stays todo for pass 3.


## 2026-09-24 — Astra (sol) — Stage 2 Director integration (F12-05) [shared]
State: CODE_READY
Files: scenes/stages/stage_02.tscn; scenes/dev/portal_light_resolved.tres; scripts/progression/stage_director.gd; scripts/progression/gate.gd; scripts/enemies/enemy_actor.gd; tests/scene/test_stage_02_contract.gd; module docs, GUIDE, validation, ROADMAP and ticket.

Stage 2 now has its Director, five Gates, CP2-A/CP2-B and three Seals. Scripts/exports only: geometry, metadata and authored monitoring preserved. Seal health remains default 10 for D-06 pass 2. Bosses remain dev Sentries for F12-06/F12-07. The green resolved portal-light material is a dev placeholder.

EnemyActor adds set_engaged and damaged; dormant Guards stay targetable/damageable but hold their attack/movement clocks. Director additions use private helpers and minimal call sites: setup/validation, guard callbacks, per-Seal rewards, light restoration and checkpoint entry fallback. Stage 1 keeps arch-only checkpoints. Gate optionally shows OpenVisual while open. Preserve authored Seal children, GuardLinks metadata, portal lights, marker and checkpoint paths.

No new tests. Minimally adjusted test_stage_02_spatial_contract's static-root assertion, intentionally obsolete now. Windowed menu entry and two accelerated full routes (Seal orders 123 and 312), checkpoint bypass entry and both Retry destinations were observed; details in docs/validation/stage-02-progression.md. Known enemy-visual exit leaks remain outside scope. Read-only code review found no critical/important issues. No Director merge conflict encountered during implementation; land performs the final sync and gate.


Append-only, newest entry first. One entry per change set that another agent must know about. Both agents write here. Never rewrite or delete an earlier entry; add a new one that supersedes it.

Entry format:

```
## YYYY-MM-DD HH:MM — <agent> — <short title>
State: <PLANNED | SCENE_READY | CODE_READY | INTEGRATED_VERIFIED | docs | dev>
Files: <paths touched>
Change: <what changed>
Why: <reason>
Action required by <other agent>: <what they must do, or "none">
```

---

## 2026-09-24 12:00 — Claude (plan) — Delivery at 18:00: F13-04 applies Astra's revised SFX list; export timeline
State: PLANNED
Files: `.scratch/audio/issues/04-apply-astras-revised-sfx-selection.md` (new), `docs/engineering/SPRINT.md`, `docs/engineering/ROADMAP.md`.
Change:
- **Sound.** The user chose Astra's revised selection (`sound_effects/`, 5 files swapped, new gains, intervals and voices, a global cap of 8). F13-04 in lane path applies it by about 13:30.
- **Export.** Trunk's F14-01 runs its swap step now, and exports once F13-04 has landed, at 15:30 at the latest.
- **Package.** oc-b's F14-02 part 2 lands by 16:30, and the human pass runs from 16:30 to 17:30.

Why: the delivery time is 18:00.

Action required by Astra: none; your revised list becomes the shipped mix.
## 2026-09-24 10:55 — Claude (plan) — Endgame routing: F11-03 to trunk, F14-01 start rule
State: PLANNED
Files: `docs/engineering/SPRINT.md` (trunk and path queues), `.scratch/run-flow/issues/03-active-and-clear-time-verification.md` (Lane), `docs/engineering/ROADMAP.md`.
Change:
- **Queues.** Trunk is idle before the export, so it takes F11-03 (the manual time protocol). Path keeps F13-03 (audio wiring) and F10-05 (Retry pickups).
- **Start rule.** F14-01 begins once F12-07, F13-03, F10-05 and D-07 have landed, so the delivered build contains them, or at the user's cutoff time, whichever comes first.

Why: two Opus lanes stay busy while sol finishes Stage 2, and the export ships the finished features.

Action required by Astra: none. Your queue stays F12-06 part 2, F12-07 part 2, D-07 Parts A and C, then D-06 pass 3.
## 2026-09-24 11:40 — Claude (trunk) — F11-02: Continuar into Campaign Stage 2, and Jogar novamente
State: CODE_READY
Files:
- Edited: `scripts/session/game_session.gd` (`_continue_campaign`, `_replay_stage`, `_begin_first_attempt`, two `match` arms).
- New: `docs/validation/run-flow-continue.png`.
- Docs: `docs/engineering/run-flow.md` ("Continuation and Direct Stage (F11-02)", Open issues), `docs/validation/run-flow.md` (F11-02 section), `docs/engineering/README.md` (the run-flow line), `docs/GUIDE.md` (the Section 6 `game_session.gd` row, the Section 10 rows "Main composition and session" and "Menus/options"), the ROADMAP F11-02 row and the ticket.

No scene file changed.

Change:
- **Continuar** after Campaign Stage 1 loads Stage 2. It carries the Power Level and the score, and restores 100 % Health, one Shield and two Bombs. Power Progress starts at 0.
- **Jogar novamente** after a Direct Stage starts that stage again as a new Direct Stage Run: Attempt 1, score 0, the stage's entry Power Level.
- Both buttons warn and do nothing anywhere else.
- **The Campaign's Stage 2 clear** shows the final victory (`Jornada concluída`) and ends the Run once.
- **Tests.** None added (sprint rule). A scratchpad driver of `main.tscn` checked every item, headless and windowed.

Why: F11-02; the Campaign now runs Stage 1 → Results → Stage 2 → final victory.
Action required by Astra: none for scenes. One design question for you or Braia: only the Power Level carries into Campaign Stage 2, not partial Power Progress (for example 3 of 5). Say if it should carry; the change is small but touches `RunState`.

## 2026-09-24 11:05 — Claude (trunk) — F11-01: Results, Defeat and Pause with real values
State: CODE_READY
Files:
- Edited: `scripts/session/game_session.gd` (`_on_stage_completed`, `_results_params`; the `run_ended` handler removed), `scripts/ui/menu_controller.gd` (`RESULTS_VALUE_PATHS` and the Results value writing), `tests/scene/test_game_session_flow.gd` (see below).
- New: `docs/engineering/run-flow.md`, `docs/validation/run-flow.md`, `docs/validation/run-flow-results.png`, `run-flow-defeat.png`.
- Docs: `docs/engineering/README.md` (one line), `docs/GUIDE.md` (the Section 6 `game_session.gd` and `menu_controller.gd` rows, the Section 7 "Stage completed" row, Section 14 "Runtime text and presentation"), the ROADMAP F11-01 row and the ticket.

No scene file changed.

Change:
- **A stage clear freezes under Results.** Results shows the real Clear Time (`M:SS`), score, Graze and bombs used, laid out for the Run Mode: Continuar after Campaign Stage 1, Jogar novamente after a Direct Stage, neither with `Jornada concluída` on the final victory. A final stage ends the Run with one victory. Every clear prints `STAGE_RESULT stage=… mode=… clear_time=… score=… graze=… bombs=… attempt=…` for F11-03 and F14-02.
- **Buttons.** Results' Menu principal and Créditos work (Back from Credits returns to Results, still paused). Defeat's two buttons and all of Pause's work. Back on Defeat and Results does nothing. Continuar and Jogar novamente warn until F11-02.
- **Tests.** None added (sprint rule). One existing test changed with the behavior: `test_game_session_flow.gd` `test_a_completed_stage_returns_to_the_menu_until_results_exist` is now `test_a_completed_stage_shows_results`. A scratchpad driver of `main.tscn` checked every item, headless and windowed.

Why: F11-01; Stage 1's clear (now the Lantern Guardian's defeat) ends on Results instead of the main menu.
Action required by Astra: `Layout/TimeValue`, `ScoreValue`, `GrazeValue` and `BombsValue` in `results.tscn` are load-bearing now: announce a rename. Time shows as `M:SS` with the seconds floored; say so if you prefer tenths. For D-07's shrine clip, `process_mode = ALWAYS` is now required: Results pauses the tree one frame after `boss_defeated`.

## 2026-09-24 10:30 — Claude (trunk) — F12-03 part 2: the Lantern Guardian fights in S1-07 [shared]
State: INTEGRATED_VERIFIED
Files:
- Edited: `scripts/progression/stage_director.gd` (`boss_definitions`, `defeat_presentation`, `defeat_animation`, the four `boss_*` signals, `_check_bosses`, `_spawn_boss`, `_on_boss_defeated`), `scripts/session/game_session.gd` (`ATTACK_CUE_SECONDS`, `_connect_boss_panel` and four `_on_boss_*` handlers, `hide_boss()` on Retry and Restart).
- **[shared] `scenes/stages/stage_01.tscn`:** the Stage node's StageDirector exports only, plus three ext_resources. The `lantern_guardian` Sentry stand-in is gone from `enemy_definitions`; `actor_scenes[&"lantern_guardian"]` → `scenes/enemies/lantern_guardian.tscn`; new `boss_definitions[&"lantern_guardian"]` → `content/bosses/lantern_guardian.tres`. `defeat_presentation` and `defeat_animation` stay unset. No geometry, marker or lighting change.
- **[shared] `scenes/enemies/lantern_guardian.tscn`:** `scripts/enemies/boss_controller.gd` attached to the `Enemy` root, with `node_paths` and `visual_root` → `VisualRoot`, `hit_volume` → `HitVolume`, `emitter` → `Emitters/Main`, `animation_player` → `VisualRoot/Model/AnimationPlayer`, and the clips `Flying_Idle`, `Punch`, `Yes`, `Death`. Nothing else changed.
- **[shared] `tools/validate_boss_scenes.gd`** (D-03's QA tool): `_check_lantern` now accepts `boss_controller.gd` on the Lantern root and still refuses any other script (`BOSS_SCENES_QA failures=0`). `_check_stage2` is unchanged, so F12-06 and F12-07 need the same one-line change when they attach the Stage 2 roots.
- New: `docs/validation/bosses-lantern-guardian.png`. Docs: `docs/validation/bosses.md` (the F12-03 section), `docs/engineering/bosses.md` ("Lantern Guardian (F12-03)"), `docs/engineering/stage-director.md` ("Boss branch (F12-03)", Exports rows, an Open issue), `docs/GUIDE.md` (Section 6 rows `game_session.gd`, `stage_director.gd`, `boss_controller.gd`; Section 10 "Lantern Guardian"), the ROADMAP F12-03 row and the ticket.

Change:
- **S1-07 has its boss.** Entering it behind CP1-B spawns the Guardião das Lanternas at `Wave1_Boss1` (0, 43, -520). The HUD shows its name, three Phase bars and each Attack's name for 3.0 s: Ritual das Lanternas, Fios de Luz, Dança do Crepúsculo. Each Phase's depletion clears hostile fire. The final Phase's defeat emits `boss_defeated(&"lantern_guardian")`, adds 1,000 and completes S1-07 exactly once; the ExitVolume changes nothing. Retry or Restart during the fight removes the boss and hides the panel.
- **Tests.** None added (sprint rule). A verifier drove the real game headless and windowed; a reviewer found no blocker, and its four minor points are fixed.

Why: F12-03 part 2 closes the ticket; Stage 1 now ends with its real boss.
Action required by Astra:
1. **Boss health is about 2.7× the pacing target.** Measured with the real weapon: 22.1 damage/s at Power Level 3 (17.1 at Power Level 2). Part 1's Phases of 1500 / 1500 / 2100 therefore last about 68 / 68 / 95 s, against STAGE_DESIGN's ~25 / 25 / 35 s; about 550 / 550 / 775 would fit (then about 32 / 32 / 45 s at Power Level 2). Values are yours: `content/bosses/lantern_guardian.tres` (D-07 Part C). Your 221 s Stage 1 estimate assumed an 85 s boss.
2. **Shrine lighting (D-07 Part A).** Author the corrupted-to-calm `AnimationPlayer` in `stage_01.tscn` with `process_mode = ALWAYS` (sprint note 4), and send its path and clip name; F14-01's swap step sets `defeat_presentation` and `defeat_animation`.
3. Boss-arena retreat containment is still open.
## 2026-09-24 09:45 — Claude (plan) — Delivery day: Retry pickups, validators, duplicate visuals; F13-03 and F3-04 part 2 to path
State: PLANNED
Files: `.scratch/stage-director/issues/05-retry-restores-checkpoint-pickups.md`, `06-stage-validators-accept-the-director.md` and `.scratch/design-sprint/issues/08-enemy-visuals-duplicate-parts.md` (new); `docs/engineering/SPRINT.md`, `docs/engineering/ROADMAP.md`; the Lane and Model lines of F13-03 and F3-04.
Change:
- **F10-05** carries Astra's Retry rule in lane path. The pickups that existed when the Checkpoint was activated come back on Retry: those collected before it stay collected, those available at it reappear, and those generated after it are removed and return through the replayed encounters' rewards.
- **F10-06** (oc-a) makes `tools/validate_stage_01.gd` accept the Stage's Director.
- **D-08** (oc-a) first confirms the duplicate model parts trunk reported in the four enemy visual scenes, and fixes them only if confirmed.
- **Queue moves.** To shorten trunk's serial chain, F13-03 and F3-04 part 2 move to path. `game_session.gd` and `main.tscn` are edited by two lanes today, under the sync-first, separate-functions, second-lander-merges rule.
- **Checkpoint names.** CP1-A and CP1-B already have their Portuguese names (Portal Selado, Entrada do Santuário); the report of ids on Defeat was stale.

Why: Astra's design answer, and delivery-day throughput.

Action required by Astra: review D-08's result when it lands; it edits your four visual scenes [shared].
## 2026-09-24 09:40 — Claude (path) — F3-04 part 2: camera settings reach every ship; F3-04 done
State: CODE_READY
Files: `scripts/session/game_session.gd` (trunk's file, by the 2026-09-24 exception in the path queue), `docs/engineering/settings.md`, `docs/validation/settings.md`, `docs/GUIDE.md` (the `game_session.gd` and `camera_rig.gd` rows), `docs/engineering/ROADMAP.md` (F3-04 row), `.scratch/settings/issues/04-settings-to-camera-wiring.md`.

Change:
- **Part 2 (it closes F3-04).** The Session applies the camera sensitivity and invert vertical through `CameraRig.apply_settings()` at every spawn, right after `setup`, and on every change of either value, even from Options over Pause.
- **Four additions, each in its own function.** `_connect_camera_settings()` (one call in `_ready`, one `Settings.changed` connection for the Session's life), `_apply_camera_settings()`, one call in `_spawn_player`, and `_on_setting_changed()`. Nothing else in `game_session.gd` changed.
- **Verified** headless by a throwaway script (the ticket's six cases, 16 checks), and by one short windowed run: 2.0 swings the view up, 0.2 barely moves it, and invert swings it down. Recorded in `docs/validation/settings.md` "Camera wiring". No new tests (the sprint rule), so `tests/scene/test_settings_camera_wiring.gd` was not created. No existing test changed.

Why: F3-04 part 2, moved from trunk to path on 2026-09-24.

Action required by trunk: when you land after this, keep the one-line `_connect_camera_settings()` call in `_ready`, the `_apply_camera_settings()` call after `_player.setup(_flight_volume)` in `_spawn_player`, and the three new functions after `_spawn_player`.
Action required by Astra: `CameraRig.sensitivity` and `invert_vertical` in `player_ship.tscn` are now overwritten by the player's settings at every spawn. Tune the orbit rate with `orbit_speed_degrees` instead.
Owed to a person: the physical keyboard and DualSense pass over Options and the camera orbit, and a real controller unplug in flight.

## 2026-09-23 23:36 — Claude (path) — F14-01 pre-flight: dev-01 exported and run outside the repository
State: docs
Files: `docs/HANDOFF_LOG.md` only (this entry). No code, scene, preset, ticket or ROADMAP edit; F14-01 stays `todo` for trunk.

Change:
- **Export.** `dev-01` at `921cbbd`, exported in the path worktree with `tools/godot.ps1 --headless --path . --export-release "Windows Desktop" build/Touhou-3D.exe`. It exited 0. `build/Touhou-3D.exe` is 125,878,832 bytes; the template is 109,268,480, so the embedded pack is about 16.6 MB. The 4.7.2 templates are in `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
- **Headless run** of a copy in a scratch folder outside the repository, `--headless --quit-after 300`: exit 0, no `ERROR:` or `WARNING:` line.
- **Windowed run.** Startup line `D3D12 12_0 - Forward+ - Using Device #0: AMD - AMD Radeon RX 9070 XT`, no fallback, V-Sync on, window 1280 × 720. `--print-fps` read:
  - 60 on the main menu, and 59 to 60 flying S1-01;
  - one-sample load hitches: 1 then 52 on the first Stage 1 load, 41 and 49 on Retry's reload, 51 and 22 on the Stage 2 load.
- **Walk.** Synthesized keyboard input, sent as scancodes to the game window:
  - Selecionar fase, then Floresta das Lanternas: the stage and the HUD load, and the ship flies and fires (player shots render).
  - Hostile fire took the ship to Defeat ("Tente outra vez", "Início da fase"), and Tentar novamente restarted the stage at 100 %.
  - Esc paused; Opções from Pause opened Options; Esc went back to Pause with Opções focused; Esc resumed.
  - Voltar ao menu; then Direct Stage 2 loads (Power 2, two Familiars), and back to the menu.
  - The build printed no `ERROR:`, `SCRIPT ERROR` or `WARNING:` line during the walk, and no setting changed.
- **Not done:** flying past `Gate_S1_02`, the busiest-wave and S1-07 FPS, and Sair. The walk stopped when the user took the desktop back, and the process was closed.

Findings for F14-01. None is an export-only failure of the game.
1. **A release export writes no console wrapper.** `export_presets.cfg` has `debug/export_console_wrapper=1` ("debug only"), so `--export-release` writes only `Touhou-3D.exe`, and the ticket's `build/Touhou-3D.console.exe` does not exist. Either set the key to `2` ("debug and release") in that trunk-only file, or capture the GUI exe's output with `cmd /c "Touhou-3D.exe --print-fps > run.log 2>&1"`, which works and is what this pass used.
2. **39 `ERROR: Attempting to parent and popup a dialog that already has a parent.`** (`scene/main/window.cpp:2297`) came from the first export after `sync`.
   - They appear while the editor converts every scene that instances the enemy visuals: `scenes/dev/sentry.tscn` and `spirit.tscn`, the four `scenes/enemies/visuals/*.tscn`, and 16 for `scenes/tests/enemy_variants_preview.tscn`.
   - That run also reimported the 15 new `docs/validation/*.png` and re-registered `Gate`, `Checkpoint` and `StageDirector`. A second export straight after it (verbose) printed none, and exited 0. The exported scenes load and play.
   - So F14-01 should import once before the recorded export (`tools/test.ps1`, or `tools/godot.ps1 --headless --path . --import`), or export twice and record the second, to meet "no `ERROR:` lines".
3. **`--script` does nothing in the release build.** It boots the main scene instead: neither a `-s` script at an absolute path that only calls `quit()`, nor the packed `res://tools/check_resources.gd`, ever ran. A driven walk of the build needs real or OS-level input, not a `SceneTree` driver.
4. **Two `WARNING: Image format RGB8 not supported by hardware, converting to RGBA8.`** print at boot, for `assets/models/enemies/Goleling_Atlas_Monsters.png` and `Hywirl_Atlas_Monsters.png` (the lossless atlases). A run from source prints the same two, so they are not export-only, and they are harmless.
5. **The pack carries non-game files.** `export_filter="all_resources"` packs 40 `tests/` scripts, 28 `tools/` scripts and 59 `docs/validation` screenshot entries. Nothing breaks. If F14-01 wants a smaller pack, `exclude_filter="tests/*, tools/*, docs/*"` drops them; `scenes/dev/` must stay, since Stage 1 spawns its dev prefabs.
6. **`user://` is shared.** The build's `user://` is `%APPDATA%\Godot\app_userdata\Touhou-3D`, the same folder source runs use, so an exported run reads the real `settings.cfg`.

Why: path's queue item 9, the F14-01 pre-flight (SPRINT "Lane queues"). Trunk's F14-01 can now start from these findings.
Action required by Astra: none. Item 4 is optional: reimport the two atlases if the warning matters.
## 2026-09-23 23:27 — Claude (trunk) — F10-03: Retry from Checkpoint and Restart flow
State: CODE_READY
Files:
- Edited: `scripts/session/game_session.gd` (`_spawn_player`, `_retry`, the Defeat param, `_flight_volume`), `scripts/progression/stage_director.gd` (`retry_from_checkpoint`, `get_respawn_transform`, `retry_location_name`).
- New: `docs/validation/stage-01-retry-defeat.png`, `stage-01-retry-respawn.png`.
- Docs: `docs/validation/stage-01-progression.md` ("Retry and Restart"), `docs/engineering/stage-director.md` ("Retry and Restart"), `docs/engineering/damage-pickups.md` (the Defeat and Retry lines), `docs/GUIDE.md` (the Section 6 `game_session.gd` and `stage_director.gd` rows, the Section 7 "Player defeated" row, a Section 8 note), the ROADMAP F10-03 row, and the ticket.

No scene file changed.

Change:
- **Retry resumes in place from the latest Checkpoint.** Every runtime enemy, Pickup and hostile Projectile of the failed Attempt goes, and queued Waves are cancelled. The Snapshot restores full resources, Power, score, Graze, bombs used and Clear Time. The Gates and PortalLinks are rebuilt, and a new ship with no Target Lock appears at the Checkpoint's `Respawn`, facing -Z.
- **Before any Checkpoint, Retry is Restart.** Restart still reloads the stage and discards every Checkpoint.
- **Defeat names the Checkpoint:** `Último checkpoint · CP1-A`, or `Início da fase` before any.
- **Tests.** None added (sprint rule). A verifier agent drove the game, including the windowed die-after-CP1-A → Retry pass; a reviewer agent found no defects.

Why: F10-03, the last Stage 1 flow ticket before the boss (F12-03).
Action required by Astra:
1. Give CP1-A and CP1-B Portuguese place names in `content/stages/stage_01/cp1_*.tres` `display_name` when you like. Defeat shows them as written.
2. **Design question (for you or Braia).** Retry removes every runtime Pickup, including rewards left uncollected before the Checkpoint (S1-02's five Power Pickups, S1-03's Shield Pickup). Their Encounters stay rewarded, so those Pickups never return. STAGE_DESIGN says to remove pickups "from the failed segment". If the earlier ones should come back, say so: the fix is small and inside the Director.
3. The CP1-B `Respawn` (0, 37, -454) touches S1-06's ExitVolume (Z -459..-455) by 0.05 on the first frame. It is harmless, because S1-06 is complete after the restore. Moving the marker 0.1 toward +Z would give a clean spawn.

Action required by trunk F11-01: `menu_controller.gd:144` calls the Defeat `checkpoint` param an id; it is the Checkpoint's `display_name`.
## 2026-09-23 23:23 — Astra (sol) — Stage 1 tuning and pacing (D-05) [shared]
State: SCENE_READY
Files: `content/stages/stage_01/*.tres`, `content/enemies/spirit.tres`, `content/enemies/sentry.tres`, `content/patterns/spirit_aimed_burst.tres`, `content/patterns/sentry_fan.tres`, four `scenes/enemies/visuals/{spirit_*,sentry_*}.tscn`, `docs/validation/stage-01-pacing.md`, `docs/validation/stage-01-anticipation.png`, the D-05 ticket, and the D-05 ROADMAP row plus one Received from Astra row. The dev enemy scenes were reviewed but not changed: their spheres still cover the visible bodies.
Change: Spirit health 20 → 30 and attack interval 1.5 → 1.4 s; Sentry health 30 → 45 and interval 2.0 → 1.8 s; Spirit spread 12 → 14° and Sentry spread 70 → 78°. CP1-A `CP1-A` → `Portal Selado`; CP1-B `CP1-B` → `Entrada do Santuário`. The 1.0 s second-Wave delays, Spirit/Sentry hit radii 1.0/0.9 at the root origin, movement and other pattern numbers stay as drafted. All 14 reviewed Resources gained `metadata/reviewed = true`; none lost `metadata/dev = true`. The four visual roots gained `metadata/anticipation_clip`: `Yes` for Spirits, `Punch` for Sentries. Both are 1.167 s source clips; about 1.17× playback would fit the one-second cue. The candidate mid-poses were rendered and inspected, and the existing visual validator reported zero failures.
Why: The common enemies were falling quickly at the measured weapon cadence; the modest health increase lets their aimed and fan patterns appear without turning the route into a forced wait. `docs/validation/stage-01-pacing.md` gives an **estimated** efficient clear of about 221 s against the 240 s target. No clear was measured, and its Lantern Guardian 85 s is provisional. Its separate five-minute fallback is a proposal for the user, not applied.
Action required by Claude (trunk): F10-01/F10-04 consume the content as is. F11-01 shows the new checkpoint names; F11-03 measures the actual Clear Time and F14-02 marks it unverified until measured. `EnemyActor` has no `anticipation_clip` export and still pulses scale, so a later trunk change must read or wire the chosen clips if the cast animation should replace that cue. No `PlayerShip/Weapon` export change is requested: keep the measured 25° lock assist and Bomb radius 10/damage 20; D-07 Part C keeps every boss Phase health above 20. D-06 pass 1 used provisional Spirit/Sentry health 20/30, so its Stage 2 estimate must be recomputed in pass 2 or 3. At the sprint checkpoint, the user decides whether to apply the Stage 1 five-minute fallback if Stage 2 slips.

## 2026-09-23 23:05 — Claude (trunk) — F10-02: Gate and Checkpoint adapters on Stage 1 [shared]
State: CODE_READY
Files:
- New: `scripts/progression/gate.gd` (`Gate`), `scripts/progression/checkpoint.gd` (`Checkpoint`), `docs/validation/stage-01-progression.md` with `stage-01-progression-gate.png` and `stage-01-progression-checkpoint.png`.
- Edited: `scripts/progression/stage_director.gd` (Gates, Checkpoints, PortalLinks, `_apply_progress`, `check_setup` additions).
- `scenes/stages/stage_01.tscn` **[shared]**: only two `ext_resource` lines, plus:
  - `gate.gd` on `Gates/Gate_S1_02..05`;
  - `checkpoint.gd` on `Checkpoints/CP1-A` and `CP1-B`, with `checkpoint_id` `&"CP1-A"` and `&"CP1-B"`;
  - on `Stage`, `guard_links`: `S1-04/Wave1_Sentry1..3` → `Environment/PortalLinks/GuardLink1..3`.

  No node, mesh, material, arch or `monitoring` flag changed.
- Docs: `docs/engineering/stage-director.md` ("Gate", "Checkpoint", "Progress application"), `docs/GUIDE.md` (Section 6 rows for `gate.gd`, `checkpoint.gd` and `stage_director.gd`, the Section 7 row "Checkpoint entered", the Section 10 rows "Stage 1 progression" and "Checkpoints/gates/seals"), the ROADMAP F10-02 row, and the ticket.

Change:
- **Stage 1 plays end to end with the dev enemies.** Each Gate clears hostile fire, then opens when its Encounter completes; closed, it stops the ship at every height and stops Projectiles.
- **Checkpoints.** CP1-A and CP1-B activate only after the Encounter before them. The first activation clears fire, refills (100 %, the Shield, 2 Bombs), commits the Attempt and records the Snapshot; a revisit does nothing. Each Checkpoint arms the next Encounter.
- **PortalLinks.** The S1-04 links hide as their guards die.
- **Tests.** None added (sprint rule). A verifier agent drove the game, including the whole route flown from the main menu in a window; the reviewer's one finding is fixed.

Why: F10-02; F10-03's Retry reuses `_apply_progress()` and the store.
Action required by Astra:
1. Keep `BarrierBody/Collision`, `ClosedVisual`, `Respawn` and `Environment/PortalLinks/GuardLink1..3`. `check_setup()` refuses the stage if one goes missing.
2. For a Checkpoint glow, react to `StageDirector.checkpoint_activated(checkpoint_id)`, for example with an `AnimationPlayer` on the arch, and tell Claude the node to connect.
3. The Gate and Checkpoint arch lintels are solid, and a ship can snag under one. Check that this is intended.
## 2026-09-24 01:30 — Claude (path) — F3-04 part 1: windowed pass for F3-02 and F3-03
State: docs
Files: New `docs/validation/settings.md`, `docs/validation/settings-1600x900.png` and `docs/validation/settings-fullscreen.png`. The ROADMAP F3-04 row is annotated. No code edits.
Change:
- **Part 1 of F3-04:** Options driven in a real window, in two processes on a temp settings file. The real `user://settings.cfg` was not touched.
- **Display.** Janela at 1600 × 900 and 1920 × 1080, Tela cheia at 2560 × 1440 and back, with the layout intact in both screenshots.
- **Volumes,** read back from `AudioServer`: Master −7.96 dB at 40, Music muted at 0, SFX −3.10 dB at 70.
- **A relaunch** kept every value and booted at 1600 × 900.
- **Prompts:** Automático hid the keyboard hint after a pad button and restored it after a key.
- **Pause:** an SFX change applied under Options from Pause, and a simulated unplug over the HUD paused.
- **Owed to a person:** the physical keyboard and DualSense pass, a real unplug in flight, and listening.
Why: F3-04 part 1 (path); part 2 (trunk) closes the ticket.
Action required by Claude (trunk): F3-04 part 2 adds the Session camera wiring. It records the camera items in `docs/validation/settings.md` ("Still to record"): a new ship gets the saved values, a live change reaches the rig, and 2.0 against 0.2 and invert show in flight. It also updates the `settings.md` Open issues line about the windowed display pass, which this part recorded.
Action required by Astra: none.

## 2026-09-24 01:46 UTC — Astra — Stage 1 night forest and both-stage rails
State: SCENE_READY
Files: scenes/stages/stage_01.tscn, scenes/stages/stage_02.tscn, assets/environment/stage_01/gate_veil.gdshader, Stage 1 and Stage 2 validation captures and handoffs, ROADMAP, local issue.
Change: Stage 1 has a navy night palette, moon, warm sparse lanterns, textured forest detail and low blue gate veils; both stages have visible side rails along every route terrace. Stage 1 rails sit on the bank tops. No runtime node names, markers, gate collision, collision layers, masks or script wiring changed.
Merge note: scenes/stages/stage_01.tscn overlapped with trunk F10-01 Stage Director attachment; the merge keeps both resource declarations and the Director script exports.
Why: User review requested a stronger Stage 1 night presentation, removal of the pink sky column, and readable out-of-bounds edges on both stages.
Action required by Claude: preserve Environment/BoundaryRails and the authored lighting/veil when attaching Stage Director and stage actors. The existing FlightBounds walls continue to provide physical containment; include them in the integrated flight pass. No wiring change is required for the rails.
## 2026-09-24 01:00 — Claude (path) — F3-03: input device mode and controller-disconnect pause
State: CODE_READY
Files: New `scripts/ui/input_device_state.gd`. Edited `scripts/ui/interface.gd` (the device tracking, the prompt push and the disconnect pause) and `scripts/ui/menu_controller.gd` (footer only: its own device tracking removed, `set_keyboard_prompts(shown)` added). Adjusted test: `tests/scene/test_menu_registry_contract.gd`. Docs: `docs/engineering/settings.md` ("Input device and disconnect"), `docs/engineering/menus-session.md` ("Footer"), `docs/GUIDE.md` (Section 6 `interface.gd` and `menu_controller.gd`, Section 7 "Pause requested"), and the ROADMAP F3-03 row.
Change:
- **One `InputDeviceState` in `Interface`** decides every menu's keyboard hint from Options' input device. Automático follows the last device used, Teclado always shows the hint, and Controle hides it while a pad is connected. The menus no longer track devices, so they cannot disagree.
- **A controller unplugged while the HUD is on top** injects the ordinary `pause` action, so the Session pauses and the keyboard drives Pause. Teclado mode skips this. Over Pause, Options, Defeat, Results or the menus nothing happens.
- **Adjusted test (SPRINT: an existing test broken by an intentional change):** `test_menu_registry_contract.gd::test_the_footer_hides_on_gamepad_input_and_returns_on_keyboard_input` is now `test_set_keyboard_prompts_shows_and_hides_the_footer`.
- **Checks.** No new tests. The scripted headless checks are recorded in `settings.md`, and `validate_menus.gd` still gives `MENUS_OK`.
Why: F3-03 (moved to path; PLANEJAMENTO Section 7).
Action required by Astra: `Layout/NavigationHint` stays load-bearing on the five full screens. No gamepad hint text or glyphs are planned.
Action required by Claude (trunk): F11-01 edits `menu_controller.gd` `_ready` and the registry test. Keep this ticket's `_ready` tail: the `_footer` lookup only, with no joypad connection. `game_session.gd` needed no edit. A physical DualSense unplug is owed to the human pass.

## 2026-09-23 22:40 — Claude (trunk) — F10-01: StageDirector attached to Stage 1 [shared]
State: CODE_READY
Files:
- New: `scripts/progression/stage_director.gd` (`StageDirector`), `docs/engineering/stage-director.md`, `docs/validation/stage-director.md` with `stage-director-s1-02.png` and `stage-director-rewards.png`.
- Edited: `scripts/session/game_session.gd` (Director pre-check, `setup`, `start_attempt`, stage clear, threats).
- `scenes/stages/stage_01.tscn` **[shared]**: only nine `ext_resource` lines at the top, and on the `Stage` root the script and its exports:
  - `stage_definition` = `content/stages/stage_01/stage_01.tres`;
  - `actor_scenes`: `spirit` → `scenes/dev/spirit.tscn`; `sentry` and `lantern_guardian` → `scenes/dev/sentry.tscn`;
  - `enemy_definitions`: `spirit` → `content/enemies/spirit.tres`; `sentry` and `lantern_guardian` → `content/enemies/sentry.tres`;
  - `power_pickup_scene` and `shield_pickup_scene` = the F7-03 dev prefabs.

  No node, marker, geometry or `monitoring` flag changed.
- `scripts/progression/encounter_machine.gd` (F8-02, lane oc-b), commit `be64081`: two parameters renamed, a compile fix with no behavior change.
- Docs: `docs/GUIDE.md` (the Section 6 `stage_director.gd` and `game_session.gd` rows, the Section 7 "Enemy defeated" and "Stage completed" rows, the Section 10 "Stage 1 progression" row), `docs/engineering/README.md`, the ROADMAP F10-01 row, and the ticket.

Change:
- **Stage 1's Encounters play.** Stage Entry begins S1-01. The Entry and Exit volumes are armed (deferred `body_entered`), and out-of-order entry and re-entry do nothing. Waves spawn at their markers under `RuntimeActors` and fire. Each defeat scores 100 once. S1-02 drops five Power Pickups at `RewardOrigin`, and S1-03 one Shield Pickup at `ShieldPickup`. Stage clear completes the stage.
- **Bad setup refuses the stage.** Bad content or a missing node is caught before the stage loads, and the menu stays.
- **Where the route stops.** Stage 1 still stops at the closed `Gate_S1_02` until F10-02.
- **EncounterMachine never compiled.** Its parameter `enemy_id` shadowed its static `enemy_id()`, which is a warning-as-error here, and nothing had loaded the class before today. Oc-b: no action; the fix is in.
- **Tests.** None added (sprint rule). A verifier agent drove the real game, headless and windowed; a reviewer agent's one finding, enemy definitions not validated up front, is fixed.

Why: F10-01, the first ticket of the Stage 1 route; F10-02, F10-03 and F12-03 build on it.
Action required by Astra:
1. `tools/validate_stage_01.gd:39` now fails its "Static stage unexpectedly contains runtime script" check, because Stage 1 has its Director by design. Update or drop that check.
2. Never rerun `tools/build_stage_01.py` over the wiring.
3. Keep the `Encounters/<ID>/{EntryVolume,ExitVolume,Spawns,RewardOrigin,ShieldPickup}` and `RuntimeActors` names. `check_setup()` refuses the stage if one goes missing.
4. `scenes/enemies/visuals/spirit_lume.tscn` and `sentry_lantern.tscn` declare `CharacterArmature`, `Skeleton3D`, the mesh and `AnimationPlayer` again as new typed nodes under the instanced glTF `Model`. Each enemy then holds duplicate children, leaks them at exit (`… RID allocations … leaked at exit`), and probably draws its model twice. Re-save them so those children are overrides with no `type=`.
## 2026-09-24 — OpenCode (oc-b) — F14-02 part 1b: acceptance draft

State: docs
Files: New `docs/validation/acceptance.md`.
Change:
- **Part 1b of F14-02** (SPRINT.md "Split tickets"). Drafts `docs/validation/acceptance.md`
  as two tables: all 18 acceptance checks of PLANEJAMENTO Section 12 (lines 300-317) and
  all 14 checks of STAGE_DESIGN "Acceptance checks for stage progression" (lines 147-160),
  32 rows in total.
- Every row gives the check text, its source file and line, the ticket(s) from
  `docs/engineering/ROADMAP.md` that deliver it, and the status `not yet verified`, as part 1b
  specifies. The header and summary sections are stubs for F14-02 part 2.
- No code and no tests; F14-02 stays `todo`.
Why: F14-02 part 1b (SPRINT.md oc-b queue row 9b); part 2 fills in the results after F14-01.
Action required by other agent: none. F14-02 part 2 (lane oc-b, after F14-01) fills in the
header, each row's status and evidence, the credits coverage and the summary.

## 2026-09-24 00:20 — Claude (path) — F3-02: Options bound to Settings, buses and window
State: CODE_READY
Files: New `scripts/ui/options_screen.gd`. Edited `scripts/ui/interface.gd` (`settings_path`, `get_settings()`, the Options binding, `restore_defaults` resolved). Docs: `docs/engineering/settings.md` ("Options binding"), `docs/engineering/menus-session.md` (the Interface contract and the Session actions row), `docs/GUIDE.md` (Section 6 `interface.gd`, Section 14 "State and verification"), and the ROADMAP F3-02 row.
Change:
- **`Interface`** owns the one `Settings`. It reads `settings_path` (default `user://settings.cfg`) once at boot; a bad file is a warning and the defaults are used. `get_settings()` exposes it.
- **A code-built `OptionsScreen` under the Options root** does the binding:
  - it fills the eight Section 14 widgets without signals, then connects them;
  - it applies Master, Music and SFX (0 mutes only that bus) and the window (Janela at the chosen resolution, stepped down to fit the screen; Tela cheia keeps the resolution for Janela);
  - it saves after each explicit change, and Defaults restores, refreshes and saves once.
- **Defaults** (`restore_defaults`) no longer reaches the Session.
- **Stored but not yet applied:** camera sensitivity, invert vertical and the input device.
- **Checks.** Tests: none (sprint rule). A scripted headless check of every behavior the ticket lists is recorded in `settings.md`.
Why: F3-02 (moved to path).
Action required by Astra: the eight widget paths, the item order of Janela/Tela cheia, the three resolutions and Automático/Teclado/Controle, and the slider ranges are load-bearing. A mismatch is reported at boot and leaves that field unbound. Values authored in `options.tscn` are now overwritten at boot by the saved values or the defaults.
Action required by Claude (trunk): F3-04 reads `interface.get_settings()` for `camera_sensitivity` and `invert_vertical`, listening to `Settings.changed` for live changes. `game_session.gd` needed no edit. The windowed display pass is owed to F3-04 part 1 (path).

## 2026-09-23 23:40 — Claude (path) — F6-04: Aim Assist follows the Target Lock under lock framing
State: CODE_READY
Files: `scripts/combat/player_weapon.gd` (the fire path and one new export), `docs/validation/enemies.md` (re-measurement; the F9-02 finding marked resolved), `docs/engineering/weapon-rendering.md` ("Aim Assist under a lock"), `docs/GUIDE.md` (Section 6 `player_weapon.gd` row), the ROADMAP F6-04 row.
Change:
- **The rule.** Under a Target Lock, the Aim Assist angle is measured from the camera, between the view and the lock's `HitVolume`. Each shot compares it with its cone widened by `lock_assist_degrees − main_assist_degrees`: main 25°, Familiars 25° at Power Level 2 and 35° at Power Level 3. Inside the cone the shot flies straight at the target. Unlocked fire is unchanged (no assist without a lock).
- **New export** `lock_assist_degrees` 25.0, a code default. `player_ship.tscn` is untouched.
- **Measured:** a locked Spirit at 10, 16, 30 and 50 units now falls in 2.02, 2.12, 2.35 and 2.68 s. Before, it never fell at 10 or 16. `CameraRig` and `Targeting` are unchanged.
- **Tests:** none (sprint rule).
Why: F6-04, from path's F9-02 finding (PLANEJAMENTO Section 4: Aim Assist toward the lock).
Action required by Astra: `lock_assist_degrees` (25°) is yours to tune (D-05 or D-07 Part C). Report the value to trunk for F14-01's swap step.
Action required by Claude (trunk): none now. F13-03 adds `shots_fired` to the same `_fire`, which is still the single fire path. `WeaponModel.assist_direction` is no longer called by the weapon; it stays in the core.
## 2026-09-24 02:00 — OpenCode (oc-a) — F9-03 part 1: SealRules core
State: CODE_READY
Files: `scripts/progression/seal_rules.gd`, `docs/engineering/enemies.md`
Change: Added the Node-free SealRules lifecycle core. It activates linked Guards once, counts each linked defeat once, exposes the Seal only after all Guards are defeated, ignores early damage including Bomb damage, and emits exactly-once progression signals. Capture and restore preserve state without emitting signals.
Why: F9-03 part 1 supplies the Stage 2 Seal progression contract for the adapter in part 2.
Action required by other agent: none; continue with F9-03 part 2.

## 2026-09-24 01:45 — Claude (plan) — land compiles every script; EncounterMachine fix landed early
State: dev
Files: `tools/check_resources.gd`, `tools/lane.ps1`, `docs/engineering/SPRINT.md`, `scripts/progression/encounter_machine.gd` (cherry-picked from trunk's `be64081`, byte-identical).
Change:
- **The fault.** F8-02's `encounter_machine.gd` never compiled: a parameter shadowed a function, which this project treats as an error. It passed `land` because no test or scene loaded it. Trunk found it in F10-01 and fixed it.
- **The early landing.** That exact fix is landed now, so no lane is blocked while trunk is still in F10-01. The change is identical, so trunk's own branch merges cleanly.
- **The gate.** `tools/check_resources.gd` now also compiles every `.gd` under `scripts/` and `tools/`: 53 scripts and 70 resources, clean.

Why: a core that nothing loads yet would otherwise break the first lane that uses it.

Action required by Astra: none.

## 2026-09-23 23:05 — Claude (path) — F12-02: BossController and dev boss prefab
State: CODE_READY
Files:
- New: `scripts/enemies/boss_controller.gd`, `scenes/dev/dev_boss.tscn`, `scenes/dev/dev_boss_definition.tres`, `docs/validation/bosses.md`, `docs/validation/bosses-dev-boss.png`.
- Edited: `scenes/dev/arena_harness.gd` and `.tscn` (export `spawn_dev_boss`, marker `EnemySpawns/DevBoss`, HUD boss-panel wiring, readout lines; additions in their own functions).
- Docs: `docs/engineering/bosses.md` (BossController contract, Setup for Astra), `docs/GUIDE.md` (Section 6 `boss_controller.gd`, Section 7 "Boss phase changed"), the ROADMAP F12-02 row.

Change:
- **`BossController`** on a boss's `Enemy` root. `spawn_setup(definition, enemy_id, encounter_id, rng, projectile_system, player, bounds) -> bool` works as for `EnemyActor`. Each physics tick at priority 0 it hovers the boss (placeholder bob), ticks the `BossMachine` from `Emitters/Main`, spawns its shots and registers its `HitVolume` sphere. It also:
  - clears every hostile Projectile when a Phase is depleted;
  - plays the optional clips `idle_clip`, `step_clip`, `phase_clip` (the sprint note) and `defeat_clip` only if `has_animation()` finds them, and otherwise warns once and skips them;
  - emits `boss_started`, `phase_changed`, `phase_health_changed`, `threat_reported` and `defeated` once, shaped for the HUD boss panel;
  - provides `get_score()`.
- **Dev boss:** "Guardião (dev)", three Phases of 40, a primitive sphere, hit radius 2.5. In the harness, `spawn_dev_boss` spawns it and wires the HUD as GUIDE Section 7 says.
- **Tests:** none added or changed (sprint rule). Scripted runs are in `docs/validation/bosses.md`.

Why: F12-02; F12-03, F12-06 and F12-07 attach this controller to Astra's boss scenes.
Action required by Claude (trunk): `content/bosses/lantern_guardian.tres` (F12-03 part 1) **does not load**. Line 14 references `SubResource("Attack_Ritual")` before it is declared, and Godot's parser refuses that. Reorder the sub-resources (steps, then attacks, then phases) before F12-03 part 2. To attach the controller to `lantern_guardian.tscn`, set `visual_root`, `hit_volume`, `emitter`, `animation_player` → `VisualRoot/Model/AnimationPlayer` and the clips `Flying_Idle`, `Punch`, `Yes`, `Death`. All four were checked at runtime.
Action required by Astra: none. Your boss trees already fit, with `HitVolume` placed at the hit center.
## 2026-09-24 01:30 — Claude (plan) — lantern_guardian.tres loads again; land now loads every resource [shared]
State: dev
Files: `content/bosses/lantern_guardian.tres` (sub-resources reordered, values unchanged), `tools/check_resources.gd` (new gate tool), `tools/lane.ps1`, `docs/engineering/SPRINT.md`.
Change:
- **The fault.** F12-03 part 1 landed `lantern_guardian.tres` with each Phase declared before the Attack and Steps it references. Godot's text parser rejects forward `SubResource` references ("Parse Error" at line 14), so the Boss Definition did not load. Path found it while checking F12-02.
- **The fix.** The blocks are now ordered so each comes after everything it references, with no value changed; the file loads and validates.
- **Why the gate missed it.** It never loaded `content/`: no content-validation test exists under the no-tests rule.
- **The new gate step.** `land` now also runs `tools/check_resources.gd`: every `.tres` and `.tscn` under `content/` and `scenes/` must load, and each Definition's `validate()` must pass. It checks 70 files, clean.

Why: trunk's F12-03 part 2 was blocked on this file, and a hand-written `.tres` can break the same way again.

Action required by Astra: when you hand-write or tune a `.tres` with sub-resources, declare each one after the ones it references. `land` now refuses the file otherwise.
## 2026-09-23 22:27 — OpenCode (oc-b) — F14-02 part 1 package script
State: CODE_READY
Files: `tools/package.ps1`, `docs/HANDOFF_LOG.md`
Change: Added the PowerShell 5.1-compatible package script for the first split part. It refuses a missing export with exit 2 and a dirty tree with exit 3, stages tracked project files while excluding agent directories, copies both exported executables, writes the Portuguese LEIA-ME, creates the dated zip, and includes extracted-copy import, test and executable boot verification plus `-SkipVerify`.
Why: F14-02 part 1 prepares the delivery tooling before trunk's F14-01 export is available; the final acceptance record and package run remain part 2.
Action required by trunk: none. For the next oc-b session (F14-02 part 2): sync after F14-01, run the script without `-SkipVerify`, record the package evidence and acceptance matrix, then close the ticket.

## 2026-09-23 22:20 — OpenCode (oc-b) — F3-01 Settings core and ConfigFile persistence
State: CODE_READY
Files: `scripts/settings/settings.gd`, `docs/engineering/settings.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md`, `.scratch/settings/issues/01-settings-core-and-configfile.md`, `docs/HANDOFF_LOG.md`
Change: Added the Node-free `Settings` Rules Core with GUIDE Section 14 defaults, typed getters, per-field sanitising and validation, idempotent `changed` signal emission, deep `capture`/`restore`, explicit ConfigFile load/save, corrupt-file fallback and static volume helpers. The new settings module contract documents the audio/display/controls file layout and invariants. No tests were written per the sprint rule.
Why: F3-01 supplies F3-02 with the validated settings state and persistence boundary without coupling the core to buses, windows, devices or camera behavior.
Action required by Astra: none. For path F3-02: construct `Settings`, call `load_file()` once at startup, apply the typed getters to widgets and call `save_file()` only after explicit user changes.

## 2026-09-24 01:00 — Claude (plan) — F6-04: Aim Assist under lock framing, queued in path
State: PLANNED
Files: `.scratch/weapon-rendering/issues/04-aim-assist-under-lock-framing.md` (new), `docs/engineering/SPRINT.md` (path row 7a), `docs/engineering/ROADMAP.md`.
Change: Path's F9-02 finding (locked shots miss enemies 10 to 16 units away once the lock framing blends in) becomes F6-04, in path after F12-02. It changes `PlayerWeapon`'s fire path so a Target Lock is aimed at against the lock itself, not the off-center framed view. The camera framing is untouched.
Why: Aim Assist toward the Target Lock is a PLANEJAMENTO Section 4 rule, and trunk is on the critical path.
Action required by Astra: tune `lock_assist_degrees` if F6-04 adds it, through D-05 or D-07 Part C.

## 2026-09-23 22:15 — Claude (path) — F9-02: EnemyActor and dev Spirit and Sentry prefabs [shared]
State: CODE_READY
Files:
- New: `scripts/enemies/enemy_actor.gd`, `scenes/dev/spirit.tscn`, `scenes/dev/sentry.tscn`, `docs/validation/enemies.md`, `docs/validation/enemies-arena.png`.
- New, Astra's values **[shared]**: `content/enemies/spirit.tres`, `content/enemies/sentry.tres`, `content/patterns/spirit_aimed_burst.tres`, `content/patterns/sentry_fan.tres` (all `metadata/dev = true`).
- Edited: `scenes/dev/arena_harness.gd` and `.tscn` (an `EnemySpawns` node with `Spirit` and `Sentry` markers; additions in their own functions).
- Docs: `docs/engineering/enemies.md` (EnemyActor contract, Setup for Astra), `docs/GUIDE.md` (Section 6 `enemy_actor.gd`, Section 7 "Enemy defeated", Section 10 "Common enemies and miniboss"), the ROADMAP F9-02 row.

Change:
- **`EnemyActor`** on the `Enemy` root: `spawn_setup(definition, enemy_id, encounter_id, rng, projectile_system, player, bounds)` after `add_child` under `RuntimeActors` (the Director's call in F10-01), then each physics tick at priority 0 it ticks the `EnemyModel`, spawns its hostile shots and registers its `HitVolume` sphere; `targetable`; a dev scale pulse over each Anticipation; `threat_reported(side)` when an attack starts off-screen; `defeated(enemy_id, encounter_id)` once, then `queue_free()`.
- **Dev prefabs** instance your `spirit_lume` and `sentry_lantern` as `VisualRoot`. The `HitVolume` sits at the root origin, where your visuals are centered (radius 1.0 and 0.9).
- **Arena harness:** a Spirit and a Sentry spawn in front of the ship with a seeded RNG; R respawns them; the readout shows their health, the defeats and the last off-screen side.
- **Tests:** none added or changed (sprint rule). Scripted runs in `docs/validation/enemies.md`.
- **Merge with trunk's F7-03:** conflicts in `scenes/dev/arena_harness.gd`, `scenes/dev/arena_harness.tscn` and `docs/GUIDE.md` (Section 6 rows) resolved on `lane/path`, keeping both sides: the harness spawns the Pickups and then the enemies, the readout shows both lines (its box grown to 440 px), and `EnemySpawns` is now a validated export like `pickup_root`.

Why: F9-02; the Director (F10-01) spawns through this API, and D-05 tunes these files.
Action required by Astra: D-05 may now tune `content/enemies/*.tres`, `content/patterns/*.tres` and the `HitVolume` radii (move the `HitVolume` node itself to re-center: its position is the aim point). Your final `scenes/enemies/spirit.tscn` and `sentry.tscn` can copy the dev tree one to one (enemies.md "Setup for Astra").
Action required by Claude (trunk): locked shots miss enemies 10 to 16 units away once the camera's lock framing blends in, by about 3.5 units, just outside the 10° main Aim Assist cone; from 30 units they hit. `PlayerWeapon` forward/cone against `CameraRig` lock framing (F6-03); see `docs/validation/enemies.md` "Finding for another lane". F10-01 can call `spawn_setup` as documented; score comes from `definition.score` on `defeated`.
## 2026-09-23 22:11 — OpenCode (oc-b) — F8-03 Snapshot and CheckpointStore
State: CODE_READY
Files: `scripts/progression/snapshot.gd`, `scripts/progression/checkpoint_store.gd`, `docs/engineering/progression-core.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md`, `.scratch/progression-core/issues/03-snapshot-capture-restore.md`, `docs/HANDOFF_LOG.md`
Change: Added the Checkpoint pair of STAGE_DESIGN's "Checkpoint contract": `Snapshot`, the immutable deep-copy value object of the `CombatState`, `RunState` and `EncounterMachine` captures (`capture_from`, `restore_into` with a fresh deep copy per core, `get_checkpoint_id` / `get_stage_id` / `get_resume_encounter_id`, `to_dict` / `from_dict`), and `CheckpointStore`, the Rules Core around it (`activate` asking `notify_checkpoint_entered` first and refusing while defeated or paused; refill, then `commit_checkpoint`, then the record, so the bombs-used statistic survives; `latest`, `latest_checkpoint_id`; `retry_into` restoring the latest Snapshot without a refill; `restart_into` as the core-level Restart proof F10 never calls; `reset`). Both contracts, the 4.H invariant rows and the Retry and Restart call sequence F10-03 follows are documented in `progression-core.md`. No tests were written per the sprint rule.
Why: F8-03 gives trunk's F10-02/F10-03 the Checkpoint rules: Defeat's Retry offer, the retry location and the Restart split.
Action required by Astra: none. For trunk (F10-02/F10-03): create the `CheckpointStore` in the Director's `setup()` (it survives Retry); call `store.activate(id, combat, run, encounters)` on a Checkpoint Area's entry; on Retry call `retry_into` and, when it returns false, Restart; never call `restart_into` — Restart keeps F2-04's full stage reload.

## 2026-09-24 00:30 — Claude (plan) — OpenCode runs on one shared meter: power models out, F3-02 and F3-03 to path
State: docs
Files: `docs/engineering/SPRINT.md` ("Model budgets" rewritten, oc-a, oc-b and path queues, Escalation, Overflow, Human steps, Shared files), `.scratch/settings/issues/02-*.md` and `03-*.md` (lane path), `.scratch/enemies/issues/03-seal-and-guard-rules.md` (part 2 on Luna), `docs/engineering/ROADMAP.md`.
Change:
- **The user's correction.** OpenCode has one usage meter shared by every model. A power-model request costs 10 to 20 times a Luna request and about 200 times a DeepSeek V4.1 Flash one.
- **Routing.** The remaining OpenCode tickets run on GPT 5.6 Luna, with V4.1 Flash as fallback. F9-03 part 2 moves from Qwen3.8 Max to Luna. F3-02 and F3-03 (planned on GLM-5.3) move to lane path, which has an Opus gap before its F3-04 part 1.
- **Escalation.** A stuck ticket now goes straight to rescue (Opus), not to Kimi K3.
- **Cost.** The rest of the OpenCode plan is about 22 % of one 5-hour window.

Why: on a shared meter, a single GLM-5.3 ticket would have spent most of a window.

Action required by Astra: none.

## 2026-09-23 21:54 — Claude (trunk) — F7-03: Pickup adapter and dev pickup prefabs
State: CODE_READY
Files:
- New: `scripts/combat/pickup.gd` (`Pickup`), `scenes/dev/power_pickup.tscn`, `scenes/dev/shield_pickup.tscn`, `docs/validation/pickups-arena.png`.
- Edited: `scenes/dev/arena_harness.gd` and `.tscn` (a `Pickups` node, the row spawn, the readout lines, dev key H).
- Docs: `docs/engineering/damage-pickups.md` ("Pickup contract"), `docs/validation/combat.md` ("Pickups"), `docs/GUIDE.md` (Section 6 `pickup.gd` row, Section 7 "Pickup accepted" row), the ROADMAP F7-03 row and "Requests to Astra" F7 row, and the ticket.

Change:
- **`Pickup`** is the Adapter on a Pickup root `Area3D`: accepted once on contact with the player body through `CombatState.collect_power_pickup()` or `collect_shield_pickup()`, then `accepted(pickup_id, kind, score_awarded)` and `queue_free()`. A Shield Pickup stays, unattracted, while the ship is shielded and is taken on the first tick after the Shield breaks. It drifts toward the player within `attraction_range` (6.0) at `attraction_speed` (14.0).
- **Dev prefabs** instance Astra's D-02 `power_pickup_visual.tscn` and `shield_pickup_visual.tscn` as `Visual` (no file of Astra's edited; no swap pending). Root: layer 0, mask 2, monitoring on, monitorable off, a 0.9 sphere.
- **Arena harness:** eleven Power Pickups in a row and one Shield Pickup; readout shows progress, Shield, Pickups taken and excess score; H breaks the Shield.
- **Tests.** None added (sprint rule). A throwaway script drove the harness: `PICKUPS_OK` headless and windowed.

Why: F7-03, which feeds F10-01's reward spawning.
Action required by Astra: none now. For final Pickup scenes keep the root contract in damage-pickups.md "Pickup contract", tune `attraction_range` and `attraction_speed` there, and send Claude the paths.
## 2026-09-23 22:00 — OpenCode (oc-a) — F12-03 part 1 Lantern Guardian content [shared]
State: dev
Files: `content/bosses/lantern_guardian.tres`, `content/patterns/lantern_ring.tres`, `content/patterns/lantern_aimed_burst.tres`, `content/patterns/lantern_paired_fan.tres`, and F12-03's ticket.
Change: Added the dev-flagged Lantern Guardian BossDefinition with three named Portuguese attack phases, health proposals of 1500/1500/2100, and authored ring, aimed-burst, and paired-fan patterns. Phase 1 alternates high/low rings and sparse aimed bursts; Phase 2 follows player height for charged aimed bursts and paired fans; Phase 3 combines rings, aimed bursts, and a reposition window.
Why: F12-03 part 1, content deliverables for the later Stage 1 Director integration.
Action required by Claude: Part 2 should reference these resources, preserve `kind = &"lantern_guardian"`, score 1000, the three attack names, and the dev placeholders until Astra tunes the values. No tests were added under the sprint rule.

## 2026-09-23 21:35 — Astra (sol) — Stage 2 content review (D-06 pass 1) [shared]
State: SCENE_READY
Files: `content/stages/stage_02/*.tres`, `docs/validation/stage-02-pacing.md`, `docs/engineering/ROADMAP.md`, `docs/HANDOFF_LOG.md`, and D-06's ticket.
Change: CP2-A `display_name` changed `CP2-A` → `Portão dos Selos`; CP2-B changed `CP2-B` → `Limiar do Cume`. All ten reviewed Stage 2 resources gained `metadata/reviewed = true`; `metadata/dev = true` remains. The S2-02 and S2-05 second-Wave delays remain 1.0 s. Reward audit confirms 20 common enemies, two bosses, seven Power and two Shield Pickups, including three per-Seal Power rewards. Direct Stage 2 reaches Power 3 before S2-04 if its first five Power items are collected. Conditional planning estimates are about 319 s efficient and 392 s normal; neither is measured. No content bug or Stage-2-only common-enemy request was found.
Why: D-06 pass 1 fixes the checkpoint names and supplies a transparent five-minute pacing budget before the Seal and boss values exist.
Action required by Claude: F12-05 loads the reviewed content with no structural change; F11-03 and F14-02 must treat the ≥300 s result as unverified until a measured uninterrupted clear. Astra keeps D-06 todo for pass 2 Seal health and pass 3 boss tuning.

## 2026-09-23 21:21 — Claude (trunk) — F7-02: Bomb clear, radius damage and bombs used [shared]
State: CODE_READY
Files:
- `scripts/session/game_session.gd`, `scripts/combat/projectile_system.gd` (`damage_targets_in_radius`), `scripts/combat/player_weapon.gd` (the "Bomb" exports and physics priority 50).
- `scenes/player/player_ship.tscn` **[shared]**: only `Weapon.bomb_visual_scene` = `scenes/dev/bomb_blast.tscn`.
- New: `scenes/dev/bomb_blast.gd` and `.tscn`, `docs/validation/combat-bomb.png`.
- Edited: `tools/validate_combat.gd` (checks 14 to 21).
- Docs: `docs/engineering/damage-pickups.md` ("Bomb"), `docs/engineering/weapon-rendering.md`, `docs/validation/combat.md`, `docs/GUIDE.md` (Section 6 rows for `player_weapon.gd`, `projectile_system.gd` and `game_session.gd`), and the ROADMAP F7-02 row.

Change:
- **What a Bomb press does.** It spends one Bomb, clears hostile fire within 10 units of the Core (awarding no Graze), counts in `bombs_used`, shows a translucent dev blast, and damages every registered enemy in range once for 20.
- **Where it is refused.** No Bomb under Pause, from the gamepad B that resumes Pause, with none left, or when defeated.
- **Weapon order.** `PlayerWeapon` now ticks after the actors, at physics priority 50. A Bomb sees this tick's enemies, and shots use this tick's yaw and lock.
- **Tests.** None added or changed (sprint rule). `validate_combat.gd` gives `COMBAT_OK`.

Why: F7-02.

Action required by Astra:
- **Tuning.** `PlayerShip/Weapon` has a "Bomb" group: `bomb_radius` (10.0), `bomb_damage` (20) and `bomb_visual_scene`, all yours to tune.
- **Swap pending: D-02.** Put the final blast inside a `BombBlast` root (`setup(radius)`, unit radius). It must keep later attacks readable.
- **Boss Phases.** Keep `bomb_damage` below the smallest boss Phase health.
## 2026-09-23 21:17 — OpenCode (oc-a) — F13-02 AudioController adapter
State: CODE_READY
Files: `scripts/audio/audio_controller.gd`, `docs/engineering/audio.md`, `docs/GUIDE.md` (Section 6 `audio_controller.gd` row), `docs/engineering/ROADMAP.md`, `.scratch/audio/issues/02-audio-controller-adapter.md`
Change: Added the AudioController adapter: limiter-gated SFX pool on `SFX`, crossfading music pair on `Music`, coalesced UI sounds from the Viewport and `Interface.action_requested` (accept outranks focus, one per frame), loud `_ready` validation, bad mapping entries reported and ignored. Not attached to any scene; F13-03 attaches it to `Main/Audio` and fills `event_streams` from D-01's files. No tests by the sprint rule; verified headless with a throwaway `tools/zz_audio_check.gd` (three events granted and logged, in-interval repeat refused, `missing_events` exact; deleted after the run). Headless audio runs on the Dummy driver, recorded in audio.md.
Why: F13-02; the playback half of the audio feature.
Action required by Astra: none now. After the D-01 listening pass, send Claude the event-to-file table and volume proposals; the `EVENT_RULES` intervals, caps and priorities are Claude's proposals for you to tune.

## 2026-09-23 21:09 — OpenCode (oc-b) — F12-04 Stage 2 content draft (dev) [shared]
State: dev
Files: `content/stages/stage_02/stage_02.tres`, `s2_01.tres` … `s2_07.tres`, `cp2_a.tres`, `cp2_b.tres`, `docs/engineering/progression-core.md`, `docs/engineering/ROADMAP.md`, `.scratch/bosses/issues/04-stage-02-content-draft.md`, `docs/HANDOFF_LOG.md`
Change: Transcribed STAGE_DESIGN's Stage 2 table into typed `.tres` Definitions that validate: seven Encounters in route order with the `next_id` chain, S2-01 with `requires_exit`, S2-03 as OBJECTIVES over `S2-03-Seal1..3` with its three ON_ENTRY guard waves, gates `Gate_S2_01` to `Gate_S2_05`, CP2-A guarding S2-04 and CP2-B guarding S2-07, 7 POWER and 2 SHIELD Pickups, and the new kinds `tempest_sentinel` and `storm_guardian`. Every file is flagged `metadata/dev = true`. The one-off headless scratch script (not committed) also cross-checked every marker, reward origin, gate and checkpoint against `scenes/stages/stage_02.tscn`, including the Seals' `seal_id` and `guard_spawn` metadata; no tests were written per the sprint rule.
Why: F12-05 loads `stage_02.tres`; Astra tunes the values in D-06 while the approved structure stays.
Action required by Astra: these files are yours. Free to change: the AFTER_PREVIOUS_WAVE delay (draft proposal 1.0 s) and the checkpoint `display_name`s (currently `"CP2-A"`/`"CP2-B"`). Must stay: the route order and completion conditions, the markers, 7 Power and 2 Shield Pickups, the five Gates and the resume points. Delete `metadata/dev` from a file once you have reviewed it.

## 2026-09-23 21:07 — Claude (trunk) — F6-03 part 2: PlayerWeapon, Familiars, target dummies; closes F6-03 [shared]
State: CODE_READY
Files:
- `scripts/combat/player_weapon.gd` (Astra's placeholder replaced by `PlayerWeapon`), `scripts/player/player_controller.gd`, `scripts/session/game_session.gd`.
- `scenes/player/player_ship.tscn` **[shared]**: only the `PlayerShip` `weapon` reference and the `Weapon` exports `muzzle`, `familiar_anchors`, `camera_rig`, `familiar_scene`; no transform, mesh, shape, layer or monitoring change.
- New: `scenes/dev/familiar.tscn`, `scenes/dev/target_dummy.gd` and `.tscn`, `docs/validation/weapon-rendering-familiars.png`.
- Edited: `scenes/dev/arena_harness.gd` and `.tscn`.
- Docs: `docs/engineering/weapon-rendering.md` ("WeaponModel", "PlayerWeapon contract", "TargetDummy"), `docs/validation/weapon-rendering.md`, `docs/GUIDE.md` (Section 5 Weapon line; Section 6 `player_weapon.gd` and `player_controller.gd` rows; Section 13 "Familiar anchors"), and the ROADMAP F6-03 row.

Change:
- **The ship shoots.** Holding `fire` spawns player Projectiles at the `WeaponModel` cadence (oc-a's part 1) from `Muzzle`, and from Power Level 2 also from both Familiar anchors, rotated by the camera yaw.
- **Aim Assist.** Shots aim at the view's center point at the lock's depth and are bent onto the locked `HitVolume` inside each shot's cone.
- **Familiars.** Two dev Familiars orbit the anchors from Power Level 2.
- **Bomb button.** It is tracked from events and fed to `CombatState.update_bomb_input()`: one press spends one Bomb.
- **Controls.** `PlayerController` gains the required `weapon` export, and `set_controls_enabled()` also turns fire off and on, so pause and Defeat stop firing.
- **Dev harness.** Three `TargetDummy`s count hits and flash; keys 1 to 3 set the Power Level.
- **Tests.** None were changed or added (sprint rule). A harness run gave `WEAPONCHECK_OK` headless and windowed.

Why: F6-03 part 2, which closes the ticket.

Action required by Astra:
- **Tuning.** Shot values, cadences and Aim Assist cones are Inspector exports on `PlayerShip/Weapon`, Claude's proposals.
- **Swap pending: D-02.** A final Familiar scene must have a `Node3D` root and no `CollisionObject3D` anywhere (the weapon refuses one that does).
- **HitVolume placement.** Keep each target's `HitVolume` centered on its visible body, because Aim Assist aims at it.
## 2026-09-23 21:05 — Astra (sol) — Combat visuals (D-02) [shared]
State: SCENE_READY
Files: `scenes/combat/visuals/*`, `assets/combat/*`, `assets/ui/menu_theme.tres`, `tools/validate_combat_visuals.gd`, `docs/validation/combat-visuals.md`, `docs/validation/combat-visuals.log`, `docs/validation/combat-visuals.png`, `docs/validation/menus-options-entry.png`, D-02's ticket, and the D-02 ROADMAP row.
Change: Player Projectile is a cyan unit octahedron (6 vertices); hostile Projectile is a coral unit sphere (54 vertices); the dev sphere uses 104 vertices. `familiar.tscn` is a cyan/gold star of radius 0.58 with looping `hover`; `power_pickup_visual.tscn` is a gold crystal of radius 0.78; `shield_pickup_visual.tscn` is a blue orb of radius 0.76; each Pickup loops `float`. `bomb_blast_visual.tscn` uses see-through cyan rings with a unit outer edge and a non-looping/autoplay `blast` clip of 0.4 s that hides them. All scenes have no script or collision. Offline QA passed headless and windowed; the gallery was inspected. The Options slider focus fill is gold, distinct from unfocused teal, and its focused screenshot was recaptured.
Why: Friendly shots, hostile patterns, Familiars and Pickups have distinct silhouettes while the Bomb shows its clear radius without hiding the next pattern.
Action required by Claude: Trunk F6-02 sets `Main/ProjectileRoot`'s `player_projectile_mesh` and `hostile_projectile_mesh` exports to the two resources; trunk F6-03 sets `PlayerShip/Weapon.familiar_scene` to `familiar.tscn`; trunk F7-02 instances `bomb_blast_visual.tscn` inside its Bomb wrapper, scales it by `bomb_radius`, and frees it after `blast`; path F7-03 instances the Power and Shield scenes as `Visual` under its existing `Pickup` roots. Full paths are in `docs/validation/combat-visuals.md`.
## 2026-09-23 20:56 — OpenCode (oc-b) — F8-04 Stage 1 content draft (dev) [shared]
State: dev
Files: `content/stages/stage_01/stage_01.tres`, `s1_01.tres` … `s1_07.tres`, `cp1_a.tres`, `cp1_b.tres`, `docs/engineering/progression-core.md`, `docs/engineering/ROADMAP.md`, `.scratch/progression-core/issues/04-stage-01-content-draft.md`, `docs/HANDOFF_LOG.md`
Change: Transcribed STAGE_DESIGN's Stage 1 table into typed `.tres` Definitions that validate: seven Encounters in route order with the `next_id` chain, completion conditions (S1-03 with `requires_exit`), waves whose markers match `scenes/stages/stage_01.tscn` exactly (17 common enemies plus `Wave1_Boss1`), gates `Gate_S1_02` to `Gate_S1_05`, CP1-A guarding S1-05 and CP1-B guarding S1-07, and rewards of 5 + 5 POWER at `RewardOrigin` plus one SHIELD at `ShieldPickup`. Every file is flagged `metadata/dev = true`. Created once with a headless scratch script that is not committed; no generator may ever overwrite Astra's tuning. No tests were written per the sprint rule.
Why: The Director (F10-01) loads `stage_01.tres`; Astra tunes the values while the approved structure stays.
Action required by Astra: these files are yours. Free to change: the AFTER_PREVIOUS_WAVE delay (draft proposal 1.0 s) and the checkpoint `display_name`s (currently `"CP1-A"`/`"CP1-B"`, matching MenuController's `Último checkpoint · <id>`; Portuguese place names welcome). Must stay: the route order and completion conditions, wave counts and markers, 5 + 5 Power Pickups, one Shield Pickup, the gates and the resume points. Delete `metadata/dev` from a file once you have reviewed it.

## 2026-09-23 20:56 — Claude (path) — F12-01 BossMachine core and boss Definitions
State: CODE_READY
Files:
- New: `scripts/definitions/boss_definition.gd`, `boss_phase_definition.gd`, `attack_definition.gd`, `attack_step_definition.gd`, `scripts/enemies/boss_machine.gd` (and their `.uid`), `docs/engineering/bosses.md`.
- Edited: `docs/engineering/README.md` (one line), `docs/engineering/ROADMAP.md` (the F12-01 row, and the F5-02 row now says ruling 5 is confirmed), `docs/engineering/projectile-field.md` (ruling 5 confirmed), `.scratch/bosses/issues/01-boss-machine-core.md` (Status, Outcome).

Change:
- **Definitions.** `BossDefinition` has 2 or 3 `BossPhaseDefinition`s. Each Phase has health, an `AttackDefinition` and `transition_seconds`, which is capped at 0.75 by `validate()` (D-07 ruling 1). An `AttackDefinition` is a Portuguese name, cycling `AttackStepDefinition`s and `reposition_seconds`. A step is a Pattern, its Anticipation, its height or `follow_player_height`, and `pause_after`.
- **`BossMachine`** runs, in order:
  - the entry window;
  - each step: `step_started`, then its Anticipation, then an aim and altitude sample at fire time, then the Pattern, then the pause;
  - the reposition window, then the steps again.
  - A hit is capped at the Phase's remaining health, and damage is refused only during the transition. A depleted Phase emits `phase_health_changed(i, 0.0)`, `hostile_clear_requested`, then `phase_changed(i + 1, name)`, or `defeated` exactly once for the last Phase.
- **No unit tests,** by the sprint rule. The five scripts pass `--check-only` with warnings as errors.

Why: F12-01 unblocks F12-02 (path) and F12-03 part 1 (oc-a).

Action required by Astra: when writing boss `.tres` content (D-07 Part C, D-06), keep each `transition_seconds` at or below 0.75, and keep every Attack's cycle above zero seconds; `validate()` enforces both. Attack names are Portuguese literals in the Definitions.

## 2026-09-23 20:32 — OpenCode (oc-a) — F6-03 part 1 WeaponModel
State: CODE_READY
Files: `scripts/combat/weapon_model.gd`, `.scratch/weapon-rendering/issues/03-weapon-model-and-player-weapon.md`
Change: Added the Node-free WeaponModel cadence, per-source cooldown, Power Level Familiar count and static Aim Assist direction rules. No tests were added per the sprint rule.
Why: This is F6-03's oc-a part 1; part 2 in trunk owns PlayerWeapon and scene integration.
Action required by Astra: None for part 1; shot values remain tuning proposals.
## 2026-09-23 20:43 — Astra (sol) — Stage 2 boss scenes (D-04) [shared]
State: SCENE_READY
Files: `scenes/enemies/tempest_sentinel.tscn`, `scenes/enemies/storm_guardian.tscn`, `assets/models/bosses/Dragon_Evolved.gltf` and copied atlas plus `.import` files, `tools/validate_boss_scenes.gd`, `docs/validation/boss-scenes.log`, `docs/validation/tempest-sentinel.png`, `docs/validation/storm-guardian.png`, `docs/ENEMY_VISUAL_HANDOFF.md`, `docs/ASSET_CREDITS.md`, `docs/engineering/ROADMAP.md`, and D-04's ticket.
Change: Both scenes have an identity `Enemy` Node3D root with no script; `VisualRoot/Model`, `HitVolume/Collision`, and `Emitters/Main`; no collision object under `VisualRoot`. HitVolume is layer 16, mask 0, and both monitoring flags off. `tempest_sentinel.tscn` uses Goleling at scale `(3.1, 3.1, 3.1)`, hit radius 2.5 at `(0, 6.9, 0)`, and emitter `(0, 7.1, -1.7)`. Its three storm rings spin through independent `VisualRoot/OrnamentPlayer` clip `storm_orbit` (loop/autoplay). `storm_guardian.tscn` uses Dragon_Evolved at scale `(5, 5, 5)`, hit radius 5.0 at `(0, 8.8, 0)`, and emitter `(0, 9.5, -3.5)`. Each model player is `VisualRoot/Model/AnimationPlayer`: idle `Flying_Idle` (loop/autoplay), step `Punch`, Phase gesture `Yes` (for later `phase_clip`), defeat `Death` (non-looping). The headless and windowed QA reported zero failures; S2-04 and S2-07 approach renders were inspected.
Why: F12-06 and F12-07 can integrate the approved Stage 2 boss art without changing encounter geometry or content values.
Action required by Claude: F12-06 attaches `boss_controller.gd` to the Tempest root, sets its exports, and points `stage_02.tscn`'s `actor_scenes[&"tempest_sentinel"]` at it. F12-07 does the same for Storm Guardian and `actor_scenes[&"storm_guardian"]`. Both roots currently have no script.
## 2026-09-23 20:35 — OpenCode (oc-b) — F8-02 EncounterMachine core
State: CODE_READY
Files: `scripts/progression/encounter_machine.gd`, `docs/engineering/progression-core.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md`, `.scratch/progression-core/issues/02-encounter-machine-core.md`, `docs/HANDOFF_LOG.md`
Change: Added the `EncounterMachine` Rules Core (ADR-0001): Encounter lifecycle with route-ordered entry behind activated Checkpoints, Wave scheduling with delays, idempotent completion emitting `gate_opened` → `rewards_requested` → `encounter_completed` → `stage_cleared`, Objective and Checkpoint flags, and `capture`/`restore`/`reset`. Documented its contract in `progression-core.md`. No tests were written per the sprint rule.
Why: F8-02 gives trunk's F10-01 the progression core it drives; the capture/restore slice feeds F8-03's CheckpointStore.
Action required by Astra: none. For trunk (F10-01): call `setup` in the Director's `setup()`, connect the six signals there, tick from `_physics_process` while the tree runs; CP1-B sits inside S1-06, so a Retry from CP1-B restores S1-06 as completed.
## 2026-09-23 23:10 — Claude (plan) — lane.ps1 handles Godot .uid and .import sidecars
State: docs
Files: `tools/lane.ps1`, `docs/engineering/SPRINT.md` ("Git worktrees", Conflicts); the missing `scripts/definitions/enemy_definition.gd.uid`, `scripts/enemies/enemy_model.gd.uid` and `tools/validate_boss_scenes.gd.uid`, committed by the new land step.
Change:
- **The fault.** Godot writes a random-uid sidecar the first time any worktree imports a new script or asset. Landings were blocked by untracked sidecars (oc-a on F6-03 part 1), and the next `sync` in trunk and oc-b would fail on untracked copies of files `dev-01` now tracks.
- **The fix.** `sync` and `land` delete a local sidecar that `dev-01` already tracks, commit one whose source is tracked, and resolve sidecar-only merge conflicts with `dev-01`'s copy. The three uids missing on `dev-01` are now tracked, using oc-a's and sol's copies.

Why: a tooling fault, not a lane's. No escalation was needed.

Action required by Astra: none. Your untracked `enemy_definition.gd.uid` and `enemy_model.gd.uid` are replaced by `dev-01`'s at your next sync. Your boss-model files are untouched.

## 2026-09-23 20:32 — Astra (sol) — Lantern Guardian scene (D-03) [shared]
State: SCENE_READY
Files: `scenes/enemies/lantern_guardian.tscn`, `assets/models/bosses/Ghost.gltf` and copied atlas plus `.import` files, `tools/validate_boss_scenes.gd`, `docs/validation/boss-scenes.log`, `docs/validation/lantern-guardian.png`, `docs/ENEMY_VISUAL_HANDOFF.md`, `docs/ASSET_CREDITS.md`, `docs/engineering/ROADMAP.md`, and D-03's ticket.
Change: `Enemy` is an identity Node3D with no script; `VisualRoot/Model` is the imported Ghost at scale `(2.6, 2.6, 2.6)`. Eight amber `VisualRoot/Lanterns/Lantern1..8` meshes orbit through `VisualRoot/LanternMotion` clip `orbit` (loop/autoplay). `HitVolume/Collision` is a sphere of radius 3.0, centered at `(0, 4.3, 0)` relative to Enemy, with layer 16, mask 0 and both monitoring flags off. `Emitters/Main` is `(0, 5, -1.5)`. The model player is `VisualRoot/Model/AnimationPlayer`: idle `Flying_Idle` (loop/autoplay), step `Punch`, Phase gesture `Yes` (recorded for later `phase_clip`), defeat `Death` (non-looping). The validator passed headless and windowed; the S1-07 dusk screenshot was inspected at 35 units.
Why: F12-03 can use the approved Stage 1 boss art without changing its gameplay model or markers.
Action required by Claude: trunk F12-03 attaches `boss_controller.gd` to Enemy; sets `visual_root`, `hit_volume`, `emitter`, `animation_player`, `idle_clip`, `step_clip`, and `defeat_clip`; and replaces the dev boss in `stage_01.tscn`'s `actor_scenes[&"lantern_guardian"]`. The root currently has no script. A future `phase_clip` may use `Yes`.


## 2026-09-23 20:29 — OpenCode (oc-a) — Generated script UIDs
State: docs
Files: `scripts/combat/pattern_emitter.gd.uid`, `scripts/definitions/pattern_definition.gd.uid`, `scripts/definitions/checkpoint_definition.gd.uid`, `scripts/definitions/encounter_definition.gd.uid`, `scripts/definitions/reward_definition.gd.uid`, `scripts/definitions/stage_definition.gd.uid`, `scripts/definitions/wave_definition.gd.uid`, `tools/validate_audio_selection.gd.uid`, `docs/HANDOFF_LOG.md`
Change: Tracked eight stable Godot script UIDs generated while importing scripts already integrated from F5-04, F8-01 and D-01; no source scripts were changed.
Why: Godot's import created these metadata files and the lane gate requires generated `.uid` files to be tracked beside their scripts.
Action required by the owning lanes: No source changes; these generated UIDs are now tracked.

## 2026-09-23 20:26 — OpenCode (oc-a) — F9-01 EnemyModel core
State: CODE_READY
Files: `scripts/definitions/enemy_definition.gd`, `scripts/enemies/enemy_model.gd`, `docs/engineering/enemies.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md`, `.scratch/enemies/issues/01-enemy-model-core.md`
Change: Added EnemyDefinition validation and the EnemyModel core for bounded movement, exactly-once defeat, Anticipation, sampled-aim PatternEmitter attacks and cooldowns. No tests were added per the sprint rule.
Why: F9-01 provides the reusable common Enemy rules core for F9-02's scene adapter.
Action required by Astra: Tune the proposed DRIFT/HOVER movement values against the authored Spirit and Sentry scenes when they are available.

## 2026-09-23 20:24 — OpenCode (oc-a) — AudioLimiter generated UID
State: docs
Files: `scripts/audio/audio_limiter.gd.uid`, `docs/HANDOFF_LOG.md`
Change: Committed the stable Godot script UID generated during the F13-01 land import.
Why: The lane gate requires generated `.uid` metadata to be tracked beside its script.
Action required by Astra: None.

## 2026-09-23 20:22 — OpenCode (oc-a) — F5-04 PatternDefinition and PatternEmitter
State: CODE_READY
Files: `scripts/definitions/pattern_definition.gd`, `scripts/combat/pattern_emitter.gd`, `docs/engineering/projectile-field.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md`, `.scratch/projectile-field/issues/04-pattern-emitter-core.md`
Change: Added typed pattern definitions and a Node-free emitter for timed hostile ring, fan, spiral, burst and sampled-aim volleys. Documented the public contract and STAGE_DESIGN mapping. No tests were added per the sprint rule.
Why: F5-04 makes shared pattern data and emission reusable by the enemy and boss cores.
Action required by Astra: Pattern field defaults are engineering proposals; authored `.tres` patterns remain with the content tickets.

## 2026-09-23 20:22 — Claude (trunk) — F7-01: hits, Graze and Defeat wired into GameSession [shared]
State: CODE_READY
Files:
- `scripts/session/game_session.gd`; `scripts/player/player_controller.gd` (on Astra's `scenes/player/player_ship.tscn`, which is unchanged).
- New: `tools/validate_combat.gd`, `docs/engineering/damage-pickups.md`, `docs/validation/combat.md`, `combat-hit-flicker.png` and `combat-defeat.png`.
- Docs: `docs/GUIDE.md` (Section 6 `game_session.gd` and `player_controller.gd` rows, Section 7 "Player defeated"), `docs/engineering/README.md`, and the ROADMAP F7-01 row.

Change:
- The ship can be hurt in the real game:
  - Core hits reach `CombatState.take_hit`.
  - A Graze adds 1 Graze and 10 score to `RunState`.
  - Invulnerability reaches the `ProjectileSystem` (no Graze during it), and `VisualRoot` blinks at 12 Hz while the Core stays lit.
  - Excess-Power score reaches `RunState`.
  - Defeat pauses the tree, Active Time, the controls and the core, under the Defeat overlay with `Início da fase`.
- `retry` restarts the stage until F10-03.
- No test changed. Per the sprint rule there is no new test file; `tools/validate_combat.gd` checks the 13 behaviours in the real main scene (`COMBAT_OK` headless and windowed).

Why: F7-01.

Action required by Astra:
- `PlayerShip` has a new Inspector export, `invulnerability_flicker_hz` (12.0, "Feedback" group), yours to tune.
- Keep `CoreVisual` under `DamageCore`, outside `VisualRoot`, or the Core would blink too.
- Defeat has no animation yet.
## 2026-09-23 20:21 — Astra (sol) — D-01 SFX selection and import [shared]
State: SCENE_READY
Files: `assets/audio/sfx/` (16 Ogg files and their `.import` settings), four `assets/licenses/kenney-*.txt` pack licenses, `docs/ASSET_CREDITS.md`, `scenes/ui/credits.tscn`, `docs/validation/audio-selection.md`, `docs/validation/menu-credits.png`, `tools/validate_audio_selection.gd`, and D-01's ticket.
Change: All 17 F13 events have a selected non-looping CC0 Kenney stream and proposed `volume_db` in [audio-selection.md](validation/audio-selection.md). The Credits screen now names the four packs. No music is shipped: the local Touhou-titled files lack documented redistribution permission. Godot import and 17-stream validation exited zero, the menu QA rendered the credit with zero failures, and the 16 copied streams match their originals byte for byte. No F13 event rule values are requested to change.
Why: F13 needs a concrete event-to-stream mapping and distributable credits. The menu credit names only packs used.
Action required by Claude: F13-03 copies the table's paths and `volume_db` values into `Main/Audio`. No music track table applies. Human listening approval is still needed before D-01 can be marked done; this agent cannot hear the selected files, so the ticket is blocked on that perceptual pass.

## 2026-09-23 20:18 — OpenCode (oc-b) — F8-01 progression Definitions
State: CODE_READY
Files: `scripts/definitions/encounter_definition.gd`, `wave_definition.gd`, `reward_definition.gd`, `checkpoint_definition.gd`, `stage_definition.gd`, `docs/engineering/progression-core.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md`, `.scratch/progression-core/issues/01-definition-schemas-and-content-validation.md`
Change: Added typed Resource schemas, local validation and Stage-level route/checkpoint validation, plus the module contract. No tests were written per the sprint rule.
Why: F8-01 provides the authored-data contract required by EncounterMachine and the later Stage 1 content draft.
Action required by Astra: Author content against the exported fields and validation rules in `docs/engineering/progression-core.md`; none for this ticket.
## 2026-09-23 20:17 — OpenCode (oc-a) — F13-01 AudioLimiter core
State: CODE_READY
Files: `scripts/audio/audio_limiter.gd`, `docs/engineering/audio.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md`, `.scratch/audio/issues/01-audio-limiter-core.md`
Change: Added the Node-free AudioLimiter core with event intervals, per-event/global caps, strict-priority oldest-voice stealing, monotonic ids, epsilon-based ticking and clear semantics. No tests were added per the sprint rule.
Why: F13-01 supplies the rules core used by F13-02's playback adapter.
Action required by Astra: None for this ticket; event rule values remain provisional until D-01's listening pass.

## 2026-09-23 20:13 — Astra (sol) — Rulings (D-07 Part B) [shared]
State: docs
Files: `docs/PLANEJAMENTO.md`, `scenes/ui/hud.tscn`, `.scratch/design-sprint/issues/07-shrine-lighting-and-boss-rulings.md`, `docs/engineering/ROADMAP.md`, `docs/HANDOFF_LOG.md`
Change: Five rulings below are recorded in PLANEJAMENTO Sections 4, 7 and 9. `Phase1` and `Phase2` carry authored two-Phase offset metadata, preserving their current three-Phase positions until Hud applies it. The D-07 ticket remains doing for Parts A and C.

| Ruling | Decision | Follow-up |
| --- | --- | --- |
| 1 Phase transition damage | Confirm no damage during the cue, bounded to 0.75 s so it does not pad the encounter. Excess damage cannot skip a Phase. | Path F12-01: keep `transition_seconds` at or below 0.75; no new code behavior requested. Sol D-07 Part C and D-06 apply the bound to values. |
| 2 HUD dimming | Confirm 0.25 alpha for spent Shield/Bomb and 0.30 for finished Phase. | None. |
| 3 two-Phase bar | Change to two equal segments across the full 620 px panel, with 16 px side margins and a 6 px center gap. | Trunk `Hud` follow-up: when `phase_count == 2`, read `two_phase_offset_left/right` metadata from Phase1 and Phase2 and apply those offsets; restore their authored offsets when three Phases show. No scheduled ticket owns this yet. |
| 4 ship yaw | Confirm the ship model does not yaw with the camera; the weapon and Familiars aim by camera yaw and visual banking stays cosmetic. | None. |
| 5 Graze under Invulnerability | Confirm strict spending: contact while invulnerable consumes that Projectile's one Graze opportunity. | None. |

Why: The existing boss cue, scoring and ship orientation remain readable and consistent with the source design; the two-Phase HUD capture showed unused panel width.
Action required by Claude: path observes the transition cap in F12-01; trunk applies the two-Phase HUD layout in a follow-up. Parts A and C remain with sol after F12-03.

## 2026-09-23 20:10 — Claude (trunk) — F6-02: ProjectileSystem on ProjectileRoot [shared]
State: CODE_READY
Files:
- New: `scripts/combat/projectile_system.gd`, `scenes/dev/dev_spray.gd`, `scenes/dev/projectile_player_mesh.tres` and `projectile_hostile_mesh.tres`, `docs/engineering/weapon-rendering.md`, `docs/engineering/spikes/projectile-rendering.md`, `docs/validation/weapon-rendering.md` and `weapon-rendering-spray.png`.
- Edited: `scenes/main.tscn` (script and meshes on `ProjectileRoot`; `Main.projectile_system`), `scripts/session/game_session.gd`, `scenes/dev/arena_harness.gd` and `.tscn`, `tests/scene/test_game_session_flow.gd` (the Return to Menu case, adjusted), `docs/GUIDE.md` (Section 5 `ProjectileRoot` line, Section 6 `game_session.gd` and `projectile_system.gd` rows), `docs/engineering/menus-session.md`, `docs/engineering/project.md`, `docs/engineering/README.md`, and the ROADMAP F6-02 row.

Change:
- The F5 field now runs in the game:
  - It ticks after the actors, with physics priority 100.
  - A layer-1, bodies-only ray kills Projectiles on scenery.
  - The ship's `DamageCore` and `GrazeVolume` spheres drive hits and Grazes (`player_hit` and `grazed` signals; nothing is fed to `CombatState` yet, that is F7-01).
  - Registered targets get `on_damage(damage)` callbacks.
  - Each faction is drawn by one `MultiMeshInstance3D`, capacity 2048.
- `GameSession.projectile_root` is renamed and retyped to `projectile_system: ProjectileSystem`. The Session sets it up on every stage load and calls `clear_all()` on unload, instead of freeing `ProjectileRoot`'s children.
- The arena harness sprays rings of hostile dev bullets.
- **Test adjusted, as the sprint rule allows:** `test_game_session_flow.gd::test_return_to_menu_unloads_everything_and_shows_the_main_menu` now spawns a Projectile and expects `count() == 0`, because `ProjectileRoot`'s children are the renderers.
- Measured with other lanes running: 3000 Projectiles at 1118 FPS, a 3.84 ms system physics step at 1280 × 720. No mitigation is needed.

Why: F6-02, with F6-01 folded in.

Action required by Astra:
- **Swap pending: D-02.** Deliver unit-radius Projectile meshes, one material per faction. Trunk points `Main/ProjectileRoot`'s two mesh exports at them.
- **Keep the ship's spheres as they are.** `DamageCore` and `GrazeVolume` stay `SphereShape3D` with monitoring off; their radii are the hit and Graze sizes.
- **Keep barriers on layer 1.** Closed Gate barriers and solid scenery stay `StaticBody3D` on layer 1.
- **D-07 Part B, a ruling to consider:** a bullet on a head-on path grazes a few ticks before it hits the Core, so every hit also scores a Graze. Should a hit cancel its own Graze?

## 2026-09-23 20:30 — Claude (path) — F5-03 ProjectileField clears and hit spheres
State: CODE_READY
Files:
- Edited: `scripts/combat/projectile_field.gd`, `docs/engineering/projectile-field.md`, `docs/engineering/README.md` (one line), `docs/engineering/ROADMAP.md` (F5-03 row), `.scratch/projectile-field/issues/03-bomb-phase-clears-and-hit-spheres.md` (Status, Outcome).

Change:
- `clear_hostile_in_radius(center, radius) -> int` is the Bomb; `clear_hostile_all() -> int` covers Gates, Checkpoints and boss Phases. Both remove HOSTILE Projectiles only, award and emit nothing, and from a listener take back a removed Projectile's pending `grazed`.
- `register_target(target_id, center, radius)` adds a hit sphere for the next tick only, keyed by `get_instance_id()`. `targets_in_radius(center, radius) -> PackedInt64Array` lists the registered spheres a blast reaches.
- PLAYER Projectiles are swept against the registered spheres and hit only the first target along their segment, reported as `enemy_hit(target_id, projectile_id, damage)` after the pass. The obstacle check still comes first.
- **No unit tests,** by the sprint rule. A reviewer found no defects.
- The projectile-field core chain (F5-01 to F5-03) is complete: F6-02 can wrap it, F7-01 and F7-02 can connect its signals and clears, and F9-02 can register spheres.

Why: F5-03 is the last Projectile Field core ticket before F6-02, the trunk critical path.

Action required by Astra: none (code only). Each enemy's hit sphere comes from its `HitVolume` shape, read by its adapter.

## 2026-09-23 22:50 — Claude (trunk) — F4-03: HUD boss panel, attack cue and threat API [shared]
State: CODE_READY
Files:
- `scripts/ui/hud.gd` (on the root of Astra's `scenes/ui/hud.tscn`, which is unchanged).
- New `scenes/dev/hud_harness.tscn` and `.gd`; new `docs/validation/combat-hud-boss-3.png` and `combat-hud-boss-2.png`.
- Docs: `docs/engineering/combat-hud.md`, `docs/validation/combat-hud.md`, `docs/GUIDE.md` Section 6 `hud.gd` row and Section 7 "Boss phase changed" row, ROADMAP F4-03 row.

Change:
- `Hud` gains `show_boss(display_name, phase_count)` (2 or 3 bars, else clamped), `set_phase_health(phase_index, ratio)` (dimmed at 0), `show_attack_cue(text, seconds)`, `hide_boss()`, and `show_threat(side, seconds)` (-1 left, +1 right, each on its own timer).
- Cue and threat timers stand still while the tree is paused. `unbind()` clears all of it, so a stage unload leaves nothing on screen.
- F10-01 (threats) and F12-03 (bosses) can now route to the HUD with no further HUD work.
- No new test file: the user's no-new-tests rule for the sprint (relayed 2026-09-23) replaced the ticket's tests with the self-checking harness run.

Why: F4-03.

Action required by Astra (D-07 Part B, optional):
- With two Phases, `Phase3` is hidden and the right third of `BossStatus` stays empty (`combat-hud-boss-2.png`). If that reads badly, author a two-Phase arrangement and say which node positions the code should switch between.
- Review `completed_phase_modulate` (alpha 0.3, an export on the HUD root). A spent Phase currently reads as an empty track.
- `BossStatus`, `BossName`, `Phase1`..`Phase3`, `AttackName`, `ThreatLeft` and `ThreatRight` are now load-bearing paths.
## 2026-09-23 20:05 — Claude (path) — F5-02 ProjectileField Core sweep and Graze rules
State: CODE_READY
Files:
- Edited: `scripts/combat/projectile_field.gd`, `docs/engineering/projectile-field.md`, `docs/engineering/README.md` (one line), `docs/engineering/ROADMAP.md` (F5-02 row), `.scratch/projectile-field/issues/02-core-hit-sweep-and-graze-rules.md` (Status, Outcome).

Change:
- `set_player(previous_center, center, core_radius, graze_radius, invulnerable)` and `clear_player()`, with signals `player_hit(projectile_id, damage)` and `grazed(projectile_id)`, buffered during the pass and emitted after it in slot order.
- The HOSTILE sweep uses the relative segment's closest distance. A hit removes the Projectile and never grazes. Graze happens at most once per life. Invulnerability passes Core contacts through and spends Graze on any contact (the strict reading). The first hit of a tick makes the rest of that tick invulnerable.
- `spawn` now also asserts a positive damage, because `CombatState.take_hit` asserts it.
- **No unit tests,** by the user's no-new-tests rule, which arrived mid-ticket. The ticket's "Tests required" list is not delivered. The existing 12 F5-01 tests pass against the extended core, and a reviewer found no defects.
- **Ruling 5 pending:** D-07 Part B had not landed. If Astra chooses the lenient reading, the Graze spend moves into the `grazed` branch of `tick`.

Why: F5-02 unblocks F5-03, and then F6-02 and F7-01, which wire these signals.

Action required by Astra: none (code only). D-07 Part B ruling 5 decides strict or lenient Graze under Invulnerability.
## 2026-09-23 22:30 — Claude (plan) — No new tests, ever: the user's rule for the sprint [shared]
State: docs
Files: `docs/engineering/SPRINT.md` ("Product decisions", workflow shapes, escalation, overflow, Claude guard, every kickoff prompt), `docs/engineering/CONVENTIONS.md` ("Tests", Definition of Done), `docs/engineering/ROADMAP.md` (F10-04, F11-03, Risk), `tools/lane.ps1` (a boot smoke and a wider error scan), `.scratch/stage-director/issues/04-stage-01-contract-smoke-test.md` (cut), `.scratch/run-flow/issues/03-active-and-clear-time-verification.md` (note), `CLAUDE.md`, `AGENTS.md` (shared).
Change:
- **The rule.** Nobody writes unit or scene tests or does TDD, in any lane. Every ticket's "Tests required" section and tdd kickoff are void.
- **The gate.** `tools/lane.ps1 land` still runs the existing suite (no token cost), and now also boots the main scene headless for 300 frames. A red run, `SCRIPT ERROR`, parse error or failed script load stops a landing, and so does any `ERROR:` line during the boot. Adapters are also checked by running the game.
- **Workflow shapes.** The 3-agent shape is now implementer, verifier (runs the game) and reviewer. Cores use implementer and reviewer.
- **Tickets.** F10-04, a test-only ticket, is cut; F11-03 keeps only its manual protocol.
- **Old tests.** If an old test fails only because a ticket intentionally changed that behavior, delete or minimally adjust that test and name it in the handoff.
- **Running lanes.** Trunk and path were told directly and have switched.

Why: The user's decision, to spend every lane's quota on the game itself.

Action required by Astra: none beyond the new sol kickoff in SPRINT.md. Your F tickets (F12-05 to F12-07) are code without tests, checked by `land` and a game run.

## 2026-09-23 22:10 — Claude (trunk) — F4-02: HUD bound to CombatState and Targeting [shared]
State: CODE_READY
Files:
- `scripts/ui/hud.gd`: Astra's placeholder replaced by `class_name Hud extends Control`, attached to the root of `scenes/ui/hud.tscn` (the scene itself is unchanged).
- `scripts/ui/interface.gd` (`get_hud() -> Hud`; a non-`Hud` root is refused), `scripts/session/game_session.gd` (one `CombatState`, `get_combat_state()`, start, pause, HUD bind and unbind).
- `scenes/dev/arena_harness.gd` and `.tscn`: new `HudLayer/HUD`, bound to a harness-owned `CombatState`.
- New `tests/scene/test_hud_contract.gd`; four cases in `tests/scene/test_game_session_flow.gd`.
- Docs: `docs/engineering/combat-hud.md` ("Hud contract"), new `docs/validation/combat-hud.md` and `combat-hud-marker.png`, `docs/GUIDE.md` Section 6 `hud.gd` row and Section 7 "Combat state changed" row, ROADMAP F4-02 row.

Change:
- The HUD renders the player panel from the Session's `CombatState` (Health bar and `"90%"`, Shield and Bomb icons lit or dim, Power Level, Power Progress) and centers `TargetMarker` on the locked target's projected `HitVolume`, hidden with no lock, a freed target or a target behind the camera. It calls no `CombatState` method but the getters.
- A Run from the main menu now shows real entry values: 100 %, Shield, two Bombs, Power Level 1, or 2 for a Direct Stage 2.

Why: F4-02. The HUD observes and never mutates (ENGINEERING_BRIEF 4.I); F4-03, F6-03 and F7 build on this binding.

Action required by Astra:
- None to integrate. Every GUIDE Section 15 path under `PlayerStatus`, and `TargetMarker`, is now load-bearing: renaming one needs a matching code change.
- D-07 Part B, optional: review `dim_modulate` (alpha 0.25, an export on the HUD root) and say if Power Level 3 should read differently than a full `PowerProgress` bar.
## 2026-09-23 19:40 — Claude (path) — F5-01 ProjectileField spawn, move and cull
State: CODE_READY
Files:
- New: `scripts/combat/projectile_spawn.gd`, `scripts/combat/projectile_field.gd` (and their `.uid`), `tests/unit/combat/test_projectile_field.gd`, `docs/engineering/projectile-field.md`.
- Edited: `docs/engineering/README.md` (one line), `docs/engineering/ROADMAP.md` (F5-01 row), `.scratch/projectile-field/issues/01-field-core-spawn-move-cull.md` (Status, Outcome).

Change:
- `ProjectileSpawn` is the request value; `ProjectileField` holds every Projectile in packed arrays and ticks them: lifetime, obstacle query, move, bounds, in ascending slot order.
- A full field refuses the new request and counts it; nothing is evicted.
- Ids are 64-bit ints (slot in the low 16 bits, a spawn serial above) and are never reused, even across `clear_all` and a new `setup`. Keep them in `int` or `PackedInt64Array`.
- The events rule for F5-02 and F5-03 is in the class comment and the module doc; no signal exists yet.

Why: F5-01 is the base of the projectile chain (F5-02, F5-03, F5-04, F6-02).

Action required by Astra: none (code only).

## 2026-09-23 21:00 — Claude (trunk) — Sprint re-routed: six lanes, per-ticket models [shared]
State: PLANNED
Files:
- `docs/engineering/SPRINT.md`, rewritten: lanes, queues with workflow shapes and models, model budgets, escalation, overflow, Claude usage, kickoff prompts, checkpoints.
- The `Lane:` and new `Model:` header lines of all 48 open tickets, plus split notes on F6-03, F9-03, F12-03, F3-04 and F14-02, and pass/order notes on D-06 and D-07.
- `docs/engineering/ROADMAP.md` (Lane column, Risk), `docs/engineering/CONVENTIONS.md`, `CLAUDE.md`, and `AGENTS.md` (shared).

Change:
- **Why the re-route.** OpenCode quotas are per model and per 5 hours, and GLM-5.3 allows only 220 requests, which cannot carry two lanes. The sprint is re-routed from a sizing of all 48 open tickets (about 6,230 mid-tier requests) and the public model evidence.
- **Lanes:**
  - `trunk` (Opus) keeps every Session and scene edit.
  - The new `path` lane (a second Opus session, stopped in its gaps) takes the critical-path cores and actor adapters: F5-01 to F5-03, F12-01, F9-02, F7-03, F12-02, F11-03.
  - `oc-a` and `oc-b` (OpenCode) replace `glm-a` and `glm-b`. Each ticket names its model, and the user switches it by hand: GPT 5.6 Luna as the workhorse; GLM-5.3 for F8-02, F3-02 and F3-03, each in a fresh window; Qwen3.8 Max for F13-02 and the Seal adapter; DeepSeek V4.1 Flash for content; Kimi K3 as the escalation reserve.
  - `rescue` (Opus, on demand) takes over stuck tickets.
  - `terra` (Codex Terra) and OpenRouter (GLM-5.2 or DeepSeek) are overflow with explicit switch rules.
- **Ticket moves.** F4-03 moved from sol to trunk, and F9-02 and F12-02 from sol to path.

Why: The critical path runs on Opus without hand-offs, the hardest OpenCode tickets get the strongest models within their quotas, and nothing waits on a spent quota.

Action required by Astra:
- Your queue is shorter and starts with D-07 Part B (the rulings), then D-01, D-03, D-04, D-02, D-06 pass 1, D-05, F12-05, D-06 pass 2, F12-06, F12-07, D-07 Parts A and C, and D-06 pass 3.
- Run `tools/lane.ps1 sync` first: your worktree is behind.
- D-05 has a timing rule (SPRINT.md "Shared files").
- `AGENTS.md` step 0 lists the new lanes.

## 2026-09-23 19:30 — Claude — Four-lane sprint: F3, F13 and Stage 2 reinstated; worktrees per lane [shared]
State: PLANNED
Files:
- New: `docs/engineering/SPRINT.md`; `tools/lane.ps1`; `.scratch/settings/{spec.md,issues/01..04}`; `.scratch/audio/{spec.md,issues/01..03}`; `.scratch/bosses/issues/04..07`; `.scratch/design-sprint/{spec.md,issues/01..07}`.
- Deleted: the F12-04 cut stub.
- Edited:
  - a `Lane:` line on every open ticket, and sprint notes in F6-02, F6-03, F7-02, F7-03, F12-01 to F12-03, F11-02, F11-03, F14-01 and F14-02;
  - F6-01 marked `cut` (folded into F6-02);
  - `.scratch/bosses/spec.md`, `.scratch/enemies/{spec.md,issues/03}`, and the settings, audio and bosses `00-plan.md`;
  - `docs/engineering/ROADMAP.md` (Lane column, new rows, Risk, "Requests to Astra") and `docs/engineering/CONVENTIONS.md` ("Git", "Sessions", "Shared-file protocol");
  - `.gitattributes` (union merge for this log and the engineering README), `CLAUDE.md`, and `AGENTS.md` (shared).

Change:
- **Scope.** The product decision reverses today's cuts in reduced but real form: Settings (F3-01 to F3-04), Audio (F13-01 to F13-03), and Stage 2 gameplay with its miniboss and final boss (F12-04 to F12-07, with F9-03 Seals).
- **Lanes.** The work runs in four lanes, each in its own git worktree on its own `lane/<name>` branch: `trunk` (Claude, Opus), `sol` (Astra, on GPT Sol), `glm-a` and `glm-b` (OpenCode with GLM 5.3).
  - Each lane lands ticket by ticket with `tools/lane.ps1 land` onto the integration branch that the primary tree has checked out (`dev-01`). The primary tree stays clean, and nobody works in it.
- **Your open requests to Astra** became seven design tickets, D-01 to D-07, in lane `sol`, each naming its consumer ticket and its exact node and clip contract. The lane also takes the adapter tickets F4-03, F9-02, F12-02 and F12-05 to F12-07.
- **Ownership during the sprint.** A ticket's Files section is its edit boundary, whoever runs it. SPRINT.md "Shared files" says which lane may touch the session, main, player and stage scenes.

Why: Two of the cuts each broke an assignment requirement (sound effects; a stage of at least five minutes, which is Stage 2). Four tools in parallel make the reinstated scope reachable before 2026-09-24.

Action required by Astra:
1. Open Codex in `C:\Users\Braia\Documents\touhou-3d-sol` (run `tools/lane.ps1 setup sol` if it is missing).
2. Paste the sol kickoff prompt from `docs/engineering/SPRINT.md`.
3. Work the sol queue: D-01, D-02, then D-07 Part B (the rulings, early), then F4-03, and onward.
4. Never edit `scenes/stages/stage_01.tscn` before F12-03 has landed.
5. `AGENTS.md` gained step 0 (the sprint); nothing else in it changed.

## 2026-09-23 16:00 — Claude — F4 to F14 tickets written; F3, F13 and F12-04 cut pending the user
State: PLANNED
Files: `.scratch/{combat-hud,projectile-field,weapon-rendering,damage-pickups,progression-core,enemies,stage-director,run-flow,bosses,delivery}/spec.md` (new) and their `issues/NN-*.md` tickets (31 `todo` plus the F12-04 `cut` stub, new); every F4 to F14 `issues/00-plan.md` (`Status: done` and an Outcome); `.scratch/settings/issues/00-plan.md` and `.scratch/audio/issues/00-plan.md` (`Status: cut`); `docs/engineering/ROADMAP.md` (the ticket rows, a `cut` status, "Order to 2026-09-24", Risk, "Requests to Astra"). No code, scene, content or GUIDE change.
Change: The per-feature planning sessions were collapsed into one pass. Each ticket names its exact files (Creates, Edits, Serialized at session end, Must not touch, Conflicts with) and carries a parallel-safe flag. Each `spec.md` lists under "Cross-feature contracts" the class, method and signal names the later features share. Those names were written against the real `CombatState` from F4-01. F3 Settings, F13 Audio and F12-04 (the Tempest Sentinel, the Storm Guardian and Stage 2 gameplay) are cut from the 2026-09-24 delivery until the user decides. Two of the cuts each break an assignment requirement: sound effects (F13), and the five-minute stage (planned for Stage 2, so F12-04). See the roadmap Risk section.
Why: The deadline is tomorrow; the Stage 1 loop comes first.
Action required by Astra: see the updated "Requests to Astra" rows F4-02, F6, F7, F8-04, F9, F10 and F12. The new requests are the tuning of Claude's proposed weapon, pattern, enemy and HUD values; Portuguese names for CP1-A and CP1-B; a Lantern Guardian scene with its clip names and the shrine-lighting clip; and a ruling on whether a boss takes damage during a Phase transition. The Stage 1 content, enemy and boss `.tres` files will be drafted by Claude and marked `dev` when those tickets run. Keep the load-bearing names in `stage_01.tscn` listed in the F10 row.

## 2026-09-23 15:10 — Claude — CombatState core (F4-01)
State: CODE_READY
Files: `scripts/combat/combat_state.gd` and `tests/unit/combat/test_combat_state.gd` (new), `docs/engineering/combat-hud.md` (new), `docs/engineering/README.md`, `docs/engineering/ROADMAP.md` (a new F4-01 row; F4-00 stays `todo` for `spec.md`, 02 and 03), `.scratch/combat-hud/issues/01-combat-state-core.md` (new, written from the 00-plan bullet).
Change: `CombatState` is the Node-free Rules Core for the player's combat resources in one life. It covers Health 0 to 100 (int percent, 10 per common hit) and a one-charge Shield that absorbs a hit of any size. Any accepted hit starts 1 s of Invulnerability, which rejects every later hit, including a second hit in the same tick. The player has two Bombs, spent only on the rising edge of the button: one press, one Bomb, and 2 s of Invulnerability. A press that began before a pause, a `start()` or a `restore()` never fires, so B pressed on the Pause menu never bombs on resume. Power Level runs 1 to 3 with 5 Power Pickups per level; at level 3 each extra pickup emits `score_awarded(50)`. A Shield Pickup is refused while shielded, so it stays in the world. `defeated` fires once per life. `refill()` is for a Checkpoint's first activation; `capture()` and `restore()` save the five resource values, and Retry clears defeat and Invulnerability. Hits, Bombs, pickups, refills and ticks are ignored while paused or defeated. Signals fire only on change. `take_hit` returns `REJECTED`, `ABSORBED`, `DAMAGED` or `DEFEATED`, so the Projectile Field can put a hit ahead of Graze. No scene, attached script or Astra-owned file changed. Verified: 26 tests (every ENGINEERING_BRIEF 4.C invariant has a named test), suite green at 198, no script errors. At the user's request, the core and the tests were written in parallel from one fixed API, and there was no mutation pass.
Why: F4-01. The HUD binding (F4-02), the damage, bomb and pickup flow (F7) and the Checkpoint Snapshot (F8-03) all read or drive these resources.
Action required by Astra: none. The tuning constants are PLANEJAMENTO Section 4's initial values; the F7 adapter will expose them if you want to tune them. The design readings are listed in `combat-hud.md` Open issues.

## 2026-09-23 14:12 — Claude — GameSession start, pause, restart, quit (F2-04) [shared]
State: CODE_READY
Files: `scripts/session/game_session.gd`, `scenes/main.tscn` (Claude's: new `player_scene`, `stage_scenes`, `stage_flight_bounds` on `Main`), `tests/scene/test_game_session_flow.gd` (new), `tools/validate_menus.gd`, `docs/validation/menus.md`, `docs/validation/menus-flight.png` (new) and `menus-pause-return.png` (re-captured), `docs/engineering/menus-session.md`, `project.md`, `README.md`, `ROADMAP.md` (the F2-04 row and a new "Requests to Astra" row), `.scratch/menus-session/issues/04-game-session-start-pause-quit.md`. Shared: `docs/GUIDE.md` (status line, Sections 5, 6, 7, 10, 14). None of your scenes changed: `stage_01.tscn`, `stage_02.tscn` and `player_ship.tscn` are only referenced from `Main`.
Change: The game plays from the main menu. Iniciar starts a Campaign on Stage 1 and a Stage Select card a Direct Stage 1 or 2: `GameSession` instances the stage under `WorldRoot`, spawns `PlayerShip` beside it at the stage's `PlayerStart`, keeps it inside the stage's Flight Volume (Stage 2's from your `FlightBounds/Limits` metadata, Stage 1's from `Main`: X -45..45, Y 0..75, Z -570..35, the inner faces of its walls), starts the Run and shows the HUD. Escape or Start over the HUD pauses the tree, Active Time and the ship's controls under Pause, which shows the Run's score and Graze; Continuar, Escape, B or Start resume; Opções from Pause keeps the game paused, and Start is ignored under it; Reiniciar fase reloads the stage and a new ship from the stage entry; Voltar ao menu unloads the stage, the ship and every projectile and ends the Run; Sair quits. A stage with no scene, no `PlayerStart` or no Flight Volume is refused with an error and the menu stays. Stage completion and victory return to the menu until F11 builds Results. Verified: 172 tests green (20 new flow tests), sixteen mutants each caught by assertion, `tools/validate_menus.gd` now playing the flow through the real Session on keyboard and gamepad events (`MENUS_OK` headless and windowed: the ship flies 11.80 units in one second and holds still while paused with the input held), a clean windowed boot of the real main scene, and Sair exiting with code 0. All input was synthetic; no pad was connected.
Why: F2-04, the last ticket of Feature F2. The menus requested actions nobody carried out, and nothing put the ship in a stage.
Action required by Astra: three things. (1) Every stage root must keep a `PlayerStart` `Node3D` and stay at the origin; a stage without `PlayerStart` is refused. (2) Optional: give Stage 1 the same `FlightBounds/Limits` marker Stage 2 has (`min` (-45, 0, -570), `max` (45, 75, 35)), so its scene is the single source of its flight interior; tell Claude and `Main`'s entry goes. (3) When a stage is added or its flight interior changes, send Claude the id and bounds: `Main` lists the stage scenes. Also note Stage 1 flies only up to the closed `Gate_S1_02` until F10 opens Gates. The physical keyboard and pad pass on the menus and the flight is still owed.

## 2026-09-23 13:30 — Claude — Interface and MenuController wiring (F2-02) [shared]
State: CODE_READY
Files: `scripts/ui/menu_controller.gd` (was the placeholder your eight menu roots attach), `scripts/ui/interface.gd` (new), `scripts/ui/screen_router.gd`, `scripts/session/game_session.gd`, `scenes/main.tscn`, `project.godot` (`[input]`: `ui_accept`, `ui_cancel`), `tests/scene/test_menu_registry_contract.gd` and `tests/scene/test_interface_contract.gd` (new), `tests/unit/ui/test_screen_router.gd`, `tests/unit/project/test_input_map.gd`, `tools/validate_menus.gd` (new), `docs/validation/menus.md` and five `menus-*.png` (new), `docs/engineering/menus-session.md`, `project.md`, `README.md`, `CONVENTIONS.md` ("Input actions"), `ROADMAP.md` (the F2-02 row and a new "Requests to Astra" row), `.scratch/menus-session/issues/02-interface-and-menu-controller.md`, `.scratch/menus-session/issues/04-game-session-start-pause-quit.md` (one added note). Shared: `docs/GUIDE.md` (status line, Sections 5, 6, 10, 14). None of your scenes, the theme or the HUD changed.
Change: The menus work. `MenuController` is now `class_name MenuController extends Control`, on the script your eight roots already attach: it knows its screen from the root name, connects every Section 14 button by path to `action_requested(action, payload)` (`start_campaign`, `open_stage_select`, `open_options`, `quit`, `start_direct_stage` with `{"stage": &"stage_01"}` or `&"stage_02"`, `back`, `open_controls`, `restore_defaults`, `open_credits`, `resume`, `restart_stage`, `return_to_menu`, `retry`, `continue_campaign`, `replay_stage`), focuses the first focusable control on entry and the remembered one on return, writes Pause's `Layout/Score`, Defeat's `Layout/RetryLocation` (`Início da fase` or `Último checkpoint · <id>`) and Results' mode (Continue, Replay or neither, `Jornada concluída` on final victory, a focus loop without the hidden buttons), and hides `Layout/NavigationHint` while a gamepad is in use. `Interface` on `Main/Interface` instances the eight menus and the HUD once (HUD first, so it draws under every menu), drives them through `ScreenRouter`, resolves Back — Back buttons and `ui_cancel` return to the caller, request `resume` on Pause, request `back_refused` on the main menu, Defeat and Results, and are left to the Session over gameplay — and passes every other action up. `GameSession` now opens the main menu with `interface.show_home(MAIN_MENU)`. Two defects found by a scripted keyboard and gamepad pass, fixed here: Godot 4.7 binds `ui_accept` and `ui_cancel` to keys only, so gamepad A and B did nothing in menus (A and B are now added in `project.godot`), and `ScreenRouter` handed a screen's old focus to a fresh entry of the same screen (it now emits hides before its stack changes). Verified: 153 tests green (15 + 11 new scene tests, one router regression, one input-map test), thirteen mutants each caught by assertion, and `tools/validate_menus.gd` printing `MENUS_OK` headless and windowed: arrows and the D-pad reach every control on every screen, and the keyboard and gamepad walks return to each caller with its focus. All input was synthetic; no pad was connected.
Why: F2-02. The menu scenes had no behavior; F2-04's Session needs action requests and a screen stack to start, pause and end a Run.
Action required by Astra: three things. (1) The Section 14 button paths, the root names and `Layout/Score`, `Layout/RetryLocation`, `Layout/Heading`, `Layout/NavigationHint` are now load-bearing: announce a rename here first, since `MenuController` needs the same change; tree order sets each screen's initial focus. (2) A focused slider is barely visible: Godot 4.7's `Slider` never draws `HSlider/styles/focus`, and `grabber_area_highlight` is the same `SliderFill` as `grabber_area`, so only a slightly brighter grabber marks it (`docs/validation/menus-options-entry.png`, and Options opens on the Geral slider). Please give `menu_theme.tres` a gold `HSlider/icons/grabber_highlight` or a distinct `grabber_area_highlight`. (3) Optional: Results with neither Continue nor Replay leaves an empty slot above Menu principal (`menus-results-final.png`). Also note gamepad B is now Back in menus and still `bomb` in play. The physical keyboard and pad pass on the menus is still owed.

## 2026-09-22 23:58 — Claude — RunState core (F2-03)
State: CODE_READY
Files: `scripts/session/run_state.gd` and `tests/unit/session/test_run_state.gd` (new), `docs/engineering/menus-session.md` (RunState sections), `docs/engineering/README.md`, `docs/engineering/ROADMAP.md` (the F2-03 row), `.scratch/menus-session/issues/03-run-state-core.md`, `.scratch/menus-session/issues/04-game-session-start-pause-quit.md` (one added note).
Change: `RunState` is the Node-free Rules Core that owns the Run. `start(mode, first_stage)` plays `[&"stage_01", &"stage_02"]` from `first_stage` in a Campaign and `[first_stage]` in a Direct Stage; `begin_attempt()` counts the Attempt, discards what the last one had not committed and unpauses; `tick_active(delta)` adds Active Time only in a stage and unpaused; `add_score`, `add_graze` and `note_bomb_used` feed the current Attempt; `commit_checkpoint()` folds it into the committed values, `rollback_attempt()` (Retry) returns to them, `restart_stage()` (Restart) returns to the stage-entry values; `clear_time()` is committed plus current Active Time; `complete_stage()`, `advance(power_level)` and `end_run(victory)` drive `stage_completed(result)`, `stage_started(stage)` and `run_ended(victory)`, each once per transition; `paused_changed` fires only on a change. Direct Stage 2 starts at Power Level 2, Stage 1 at 1, Campaign Stage 2 at the level passed to `advance()`. Score is carried into Campaign Stage 2; Clear Time, Graze and bombs used are per stage. Once a stage completes, nothing changes its result. `capture()` / `restore()` hold the committed values, the entry values and the stage position as a copied Dictionary, in both directions. No scene, no attached script and no Astra-owned file changed. Verified: 19 tests written test-first, suite green at 125, and twelve mutations each caught by a named assertion (none only by a runtime error, which the runner would have reported as PASS).
Why: F2-03. F2-04's `GameSession` needs the Run's lifecycle and time accounting in a testable core, and F8-03 and F10 build the Snapshot and Retry flow on its capture and rollback rules.
Action required by Astra: none. Two design readings are recorded in `menus-session.md` Open issues for review: Graze in Results is per stage, not a Run total, and replaying an isolated stage starts a new Run.

## 2026-09-22 23:53 — Claude — ScreenRouter core (F2-01)
State: CODE_READY
Files: `scripts/ui/screen_router.gd` and `tests/unit/ui/test_screen_router.gd` (new), `docs/engineering/menus-session.md` (new), `docs/engineering/README.md`, `docs/engineering/ROADMAP.md` (the F2-01 row), `.scratch/menus-session/issues/01-screen-router-core.md`, `.scratch/menus-session/issues/02-interface-and-menu-controller.md` (one added note).
Change: `ScreenRouter` is a Node-free Rules Core for menu navigation. Everything shown is one stack: a full screen (main menu, stage select, options, controls, credits, HUD) covers everything below it, an overlay (pause, defeat, results) leaves it visible. `home(id)` starts a new stack, `replace(id, params)` opens a full screen and `push(id, params)` an overlay over the current one, and `back()` removes the top entry: Options from the main menu returns to it, Options from Pause returns to Pause with the HUD under it and `has_overlay(PAUSE)` true throughout, Credits from Results returns to Results with its original params. `back()` returns false on a single screen and on Defeat or Results, which GUIDE Section 14 gives no Back row. Each transition emits `screen_hidden` for every screen that stops being visible, then `screen_shown(id, params)` for every one that becomes visible. Focus memory lives on the stack entry, so it survives while a screen waits for Back and is forgotten when it leaves: a Pause reopened after Resume starts on its initial button, not on "End run". No scene, no attached script and no Astra-owned file changed. Verified: 13 new tests written test-first, suite green, and five mutations each caught by a named test.
Why: F2-01, the first ticket of Feature F2. F2-02's `Interface` needs the navigation rules in a testable core so it only has to show, hide and focus.
Action required by Astra: none. The screen ids are code; which scene root maps to which id arrives with `MenuController` in F2-02.

## 2026-09-22 23:36 — Astra — F1 design decisions and generator retirement; flight tuning blocked [shared]
State: docs
Files: `docs/engineering/player-flight.md` (Open issues and retired-generator notice), `docs/engineering/ROADMAP.md`, `docs/GUIDE.md` Section 13, `.scratch/player-flight/issues/05-astra-design-pass.md`, `docs/HANDOFF_LOG.md`, `docs/validation/player-flight-design-tests.log`, both `assets/models/enemies/{Hywirl,Goleling}_Atlas_Monsters.png.import`, `tools/build_scene_handoff.py` moved unchanged to `docs/archive/build_scene_handoff.py.txt`, `docs/archive/README.md`.
Change: Recorded the requested F1 design decisions. (a) Accept the rectangular volume and open corners in the dev harness only; production stage boundaries still require presentation. (b) Choose proximity-driven ship transparency; a hull filling the view at 0.75 units is unacceptable for bullet readability. (c) Do not accept the measured 6.5-unit gate snap as final production presentation; keep collision-safe behavior until Claude can improve and revalidate the transition. (d) Keep left-to-right cycling with wrap as the design rule, with feel acceptance still pending. Solid stage trunks/substantial branches should occlude acquisition and Aim Assist using fitted layer-1 collision; this also deliberately blocks ship/camera, while decorative foliage should not. No collision was authored in this pass. Reaffirmed the Node3D / targetable / HitVolume contract with own volumes off layer 1. Retired the obsolete generator without executing it or changing its contents; scenes are authoritative. Chose the user's lossless alternative for both enemy atlases: `compress/mode=0`, `detect_3d/compress_to=0`; reimported successfully. No scene, Inspector value, node reference, collision setting, runtime script or test was edited. No request to change pinned speed 12.0, Focus 0.45, follow distance 8.5 or follow height 3.2.
Why: F1-05 is this session's single ticket. The live harness was opened and observed at the authored start (0, 6, 18), camera 9.08 / pitch -9 / roll 0, and later moving at speed 12 with bank. Computer Use then reported a physical Escape stop. The user authorized continuation on the secondary monitor; Godot was relaunched with `--screen 1`, but Computer Use still refused with the same stopped message. Thus the Inspector tuning and motion/physical-device acceptance are explicitly **blocked**, not signed off. The obstruction judgements use Claude's measurements and existing screenshots; no new gate or wall motion pass is claimed. All numeric proposals remain unchanged and listed in the module doc for resumption.
Validation: `tools/test.ps1 -Import` reimported the two atlases and passed 93/93, exit 0, with sandbox user-directory/cache diagnostics. Re-ran `tools/test.ps1` with normal user-directory access: **93 passed, 0 failed, exit 0**, evidence in `docs/validation/player-flight-design-tests.log`. Remaining ERROR/WARNING lines are intentional missing-reference/HitVolume negative tests followed by PASS. No test failures to report. `git diff --check` clean; integrated scenes/scripts/tests unchanged. The pre-existing untracked `.agents/` directory is excluded from this commit.
Action required by Claude: read the decisions in `player-flight.md` Open issues. Plan the proximity visual fade and investigate the gate transition without easing through geometry; coordinate fitted tree collision in a later scene pass. Preserve target prefab conventions and use the integrated scenes directly, never the archived generator. Astra still owes the numeric Inspector flight pass and motion acceptance once Computer Use resumes; a full human keyboard and DualSense pass is still unverified. F1-05 and its roadmap row remain blocked for that reason; F1-02 to F1-04 code completion is unchanged.

## 2026-09-22 23:26 — Claude — TargetSelector core and Targeting adapter (F1-04) [shared]
State: CODE_READY
Files: `scripts/player/target_selector.gd` (new), `scripts/player/targeting.gd` (was your placeholder), `scripts/player/player_controller.gd`, `scenes/dev/arena_harness.gd`, `tests/unit/player/test_target_selector.gd` and `tests/scene/test_targeting_contract.gd` (new), `tests/scene/test_player_ship_contract.gd`, `tools/validate_player_flight.gd`, `docs/engineering/player-flight.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md` (the F1-04 row and a new "Requests to Astra" row), `docs/validation/player-flight.md`, `docs/validation/player-flight-camera-lock.png` (re-captured) and `player-flight-targeting-occluded.png` (new), `.scratch/player-flight/issues/04-target-selector-and-targeting.md`. Astra-owned: `scenes/player/player_ship.tscn` (the `PlayerShip` root's references and the `Targeting` node only), `docs/GUIDE.md` (status line, Sections 6, 7, 10, 13).
Change: Target Lock works. `TargetSelector` is a Node-free Rules Core: a fresh lock takes the visible, in-range target nearest the screen center (distance breaks a tie); `next_target` steps to the next visible, in-range target to the right on screen, wrapping to the leftmost; a held lock is dropped only when its target disappears or leaves range, never for occlusion; `target_changed` fires once per change. `scripts/player/targeting.gd` is now `class_name Targeting extends Node`: every physics tick with a lock or a press it describes each `targetable` node to the core — screen position from the camera, distance from the ship, one occlusion ray from the camera to its `HitVolume` on layer 1 — reads `lock_target` (toggle) and `next_target` (switch), and emits `target_changed(target: Node3D)`, null on release; `get_current_target()` returns the lock. **In `player_ship.tscn`**: the root gained `"targeting"` in its `node_paths` marker and `targeting = NodePath("Targeting")` — `PlayerController` has a new required `targeting` export and connects `targeting.target_changed` to `camera_rig.set_lock_target` once in `_ready` — and the `Targeting` node gained `node_paths=PackedStringArray("camera")` with `camera = NodePath("../CameraRig/Camera3D")`. Nothing else in that file changed, and your `combat_arena.tscn` is untouched. The four selection exports stay at their defaults, so the file does not list them. The harness's F1-03 lock stand-in is gone; its readout now shows `lock <name> at <distance> of 60.0`. Two rules differ from the ticket as written, both found against the real camera: the switch order is left to right on screen instead of by angle around the center, and the 0.85 screen radius gates a fresh lock only — with it in the switch ring, locking High pushed Low to x -0.965 and cycling never reached it. Verified: 93 tests green (14 core, 10 scene contract), 11 mutations each caught by a named test, and `tools/validate_player_flight.gd` printing `FLIGHT_OK` headless and in a real window: from the open-air start `lock_target` picks Middle (worked by hand from your positions), `next_target` visits Middle → High → Low and wraps to Middle with the camera framing each, the release holds its heading, flying away releases the lock at 60.047 against 60.0, and a lock on Middle survives with the ship parked past the shrine gate, where the camera's line to Middle hits `BeamBody`. Every run was simulated input; no joypad was connected this time.
Why: F1-04, the last ticket of Feature F1. The camera could frame a lock but nothing chose one, lost one, or respected scenery.
Action required by Astra: four things. (1) Tune `max_distance` 60 and `max_screen_radius` 0.85 on `PlayerShip/Targeting` (under **Selection**) in the harness; both are proposals, and whether left-to-right switching reads well on `Tab`/`X` is your judgement. (2) Every future targetable prefab — enemies, bosses, anything lockable — must be a `Node3D` in the `targetable` group with a `HitVolume` child, with its own volumes off layer 1; a member without `HitVolume` is skipped with one warning. (3) Only layer-1 collision hides a target. The arena's trees, lanterns and peaks are meshes without collision, so they never hide one; stage trees that should block acquisition and Aim Assist need layer-1 collision. (4) `tools/build_scene_handoff.py` now also misses the `targeting` wiring on the root and on the `Targeting` node; reconcile before any rerun. The physical keyboard and pad pass is still owed for F1-02 to F1-04.

## 2026-09-22 15:10 — Claude — CameraRig follow, orbit, lock framing and obstruction (F1-03) [shared]
State: CODE_READY
Files: `scripts/player/camera_rig.gd` (was your placeholder), `scripts/player/player_controller.gd`, `scenes/dev/arena_harness.gd` and `scenes/dev/arena_harness.tscn`, `tests/scene/test_camera_rig_contract.gd` (new), `tests/scene/test_player_ship_contract.gd`, `tools/validate_player_flight.gd`, `docs/engineering/player-flight.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md` (the F1-03 row and two new "Requests to Astra" rows), `docs/validation/player-flight.md` and four new `player-flight-camera-*.png`, `.scratch/player-flight/issues/03-camera-rig.md`. Astra-owned: `scenes/player/player_ship.tscn` (the `CameraRig` node only), `docs/GUIDE.md` (Sections 6, 10, 13).
Change: `scripts/player/camera_rig.gd` is now `class_name CameraRig extends Node3D`. It sets `top_level` on itself in `_ready` and places itself every physics tick at the ship's position with a basis that is a pure yaw rotation, so the banking body cannot tilt the camera; the camera is placed at the authored offset rotated by that yaw and by a pitch, and its basis is rebuilt from the same two angles with an explicit zero roll. The `camera_*` actions orbit it at `orbit_speed_degrees`, the pitch is clamped to `pitch_limits_degrees`, `set_lock_target()` / `clear_lock_target()` fade a Target Lock framing in and out, and a ray from the ship to the desired camera position shortens the rig against scenery, immediately on the way in and eased on the way out. `apply_settings()` is there for F3. **The yaw lives in the `CameraRig` node's own `global_rotation.y`** — the rig reads it, modifies it and writes it back each tick — and `get_yaw()` publishes it; `PlayerController.camera_rig` is retyped from `Node3D` to `CameraRig` and `_camera_yaw()` now calls `get_yaw()`. **In `player_ship.tscn` only the `CameraRig` node changed**: it gained `node_paths=PackedStringArray("camera")`, `camera = NodePath("Camera3D")` and your camera offset as `follow_distance` 8.5 and `follow_height` 3.2. Your `Camera3D` node, its FOV, near, far and every other node in that file are untouched — but the rig now writes that camera's transform every frame, so the node's authored position and rotation are the documented rest pose rather than the live value. `scenes/dev/arena_harness.gd` grew a camera readout (yaw, pitch, roll, distance) and a dev stand-in for F1-04: `K`/`Y` locks the selected arena target, `Tab`/`X` cycles the three. Verified: 69 tests green, 22 of them the two scene contracts, plus `tools/validate_player_flight.gd` printing `FLIGHT_OK` over 24 new camera measurements in a real window — rest pose, orbit rate on both axes, both pitch limits, a camera-relative flight after a quarter turn, lock framing on all three arena targets with ship and target inside the field of view, the release holding its heading, shortening against the west wall, and the shrine gate pass — with the roll measured as exactly 0 in every one of them. Reproducible across runs; four new screenshots are in `docs/validation/`. Mutation-checked both ways: making `_camera_yaw()` return 0 fails only the new round-trip test, and running the obstruction ray on mask 0 fails only the shortening test.
Why: F1-03. The camera was still your static `Camera3D` and camera-relative movement had never been exercised with a turned rig, which is the failure the ticket called silent.
Action required by Astra: four things. (1) Tune the camera in `scenes/dev/arena_harness.tscn`. Everything on `PlayerShip/CameraRig` except `follow_distance` 8.5 and `follow_height` 3.2 is Claude's first guess: `default_pitch_degrees` -9 (the export form of your -0.16 rad), `pitch_limits_degrees` (-60, 35), `orbit_speed_degrees` 120, `position_damping` 10, `rotation_damping` 8, `lock_blend_speed` 4, `obstruction_margin` 0.4. Move the camera with those exports, not by dragging `Camera3D` — the rig overwrites its transform every frame. FOV, near and far are still read from your node. (2) Two feel judgements are yours: turned into a wall the camera collapses to 0.75 units from the ship and the hull fills the frame (`player-flight-camera-obstruction.png`) — a minimum distance, or the ship transparency PLANEJAMENTO Section 3 already mentions, would fix it; and the shortening under the shrine gate is a 6.5-unit change in a single frame (`player-flight-camera-gate.png`), which is the ray rule working as specified but may read as a pop. (3) `tools/build_scene_handoff.py` now also misses the `CameraRig` wiring, on top of the five `PlayerShip` lines F1-02 listed; without the `camera` reference the rig disables itself and the camera stops following. (4) The physical pass is still owed, on both flight and camera: this host has a DualSense pad that Godot recognises with a standard mapping, but no key or button has been pressed by a human — everything measured is simulated input.


## 2026-09-22 10:40 — Claude — PlayerController adapter and arena harness (F1-02) [shared]
State: CODE_READY
Files: `scripts/player/player_controller.gd`, `scenes/dev/arena_harness.tscn` and `scenes/dev/arena_harness.gd` (new), `tests/scene/test_player_ship_contract.gd` (new), `tools/validate_player_flight.gd` (new), `docs/engineering/player-flight.md`, `docs/engineering/README.md`, `docs/engineering/ROADMAP.md` (the F1-02 row and a new "Requests to Astra" row), `docs/validation/player-flight.md` and four `player-flight-*.png` (new), `.scratch/player-flight/issues/02-player-controller-adapter.md`. Astra-owned: `scenes/player/player_ship.tscn` (root node only), `docs/GUIDE.md` (header, Sections 3, 6, 10, 13).
Change: `scripts/player/player_controller.gd` was your placeholder and is now `class_name PlayerController extends CharacterBody3D`. It reads the input actions, asks `CameraRig` for its yaw, drives the `FlightModel` core, calls `move_and_slide()`, then clamps the position into the Flight Volume and updates the edge feedback; `_process` only eases `VisualRoot.rotation.z` toward the core's bank angle. Its owner injects the Flight Volume with `setup(bounds)` and controls it with `set_controls_enabled(enabled)` and `reset_to(transform)`; it reports `edge_proximity_changed(value)` and `focus_changed(active)`. **In `player_ship.tscn` only the root `PlayerShip` node changed**: `metadata/base_speed` and `metadata/focus_multiplier` are gone, replaced by the exports `base_speed` 12.0, `focus_multiplier` 0.45, `edge_margin` 4.0, `max_bank_angle_degrees` 25.0, `bank_smoothing` 8.0 and the four node references `visual_root`, `camera_rig`, `damage_core`, `graze_volume`; the node line gained `node_paths=PackedStringArray(...)`, without which Godot hands the script raw `NodePath` values and every reference reads as unset; and the body gained `motion_mode = 1` (floating, no gravity, layer 2, mask 1). Your geometry, materials, collision shapes, camera placement and every other node in that file are untouched. `scenes/dev/arena_harness.tscn` is Claude's dev scene: it instances your `combat_arena.tscn` unmodified, reads the `FlightBounds` metadata `min_corner`/`max_corner`, hands the volume to the controller, and draws a debug readout of position, speed and edge proximity. Verified: 57 tests green, ten of them the new scene contract test (body wiring, exports resolving, a pushed error plus disabled processing when a reference is missing, banking that moves `VisualRoot/EngineL` while `DamageCore`, `GrazeVolume` and `Muzzle` stay put, `reset_to`, disabled controls, `focus_changed`, and the injected volume clamping the ship); the clamp assertion was checked by mutation. `tools/validate_player_flight.gd` then flew the harness in a real window and measured 12.000 units per second on each of the six axes, 12.000 on a full three-axis diagonal against 20.78 unbounded, 5.400 under Focus, a stop at y 0.400 on the platform, y 0.000 on the clamped floor past the platform rim, x -38.000 against the west wall with the readout at 0.75, and a -24.5° roll strafing right. Four screenshots are in `docs/validation/`.
Why: F1-02. The ship had a scene and a movement core but nothing joining them; F1-03 and F1-04 need a flying ship to build a camera and targeting against.
Action required by Astra: three things. (1) Fly `scenes/dev/arena_harness.tscn` and tune `edge_margin`, `max_bank_angle_degrees` and `bank_smoothing` — they are Claude's proposals, and no design document fixes them. `base_speed` 12.0 and `focus_multiplier` 0.45 are pinned by the contract test, so say so before changing those two. (2) The rectangular Flight Volume's corners are open void past the circular platform, where the clamp holds the ship at y 0 over nothing with the feedback at 1.0 (`player-flight-clamp.png`); decide whether the volume should become a cylinder or the scenery should fill the corners. (3) `tools/build_scene_handoff.py` no longer reproduces the integrated `player_ship.tscn` — it still writes the two retired metadata entries and none of the exports, the `node_paths` marker or `motion_mode`. Reconcile those five lines before any rerun; it was left unchanged because this host has no Python to verify a rerun with. Also keep `DamageCore`, `GrazeVolume` and `Muzzle` outside `VisualRoot`, and tell Claude before renaming `VisualRoot`, `CameraRig`, `DamageCore` or `GrazeVolume`: each is a required reference and the ship refuses to move without it.

## 2026-09-22 00:15 — Claude — Gameplay roots stop while paused (F0-03 review fix) [shared]
State: CODE_READY
Files: `scenes/main.tscn`, `tests/scene/test_main_contract.gd`, `tests/run_tests.gd`, `docs/GUIDE.md` (Section 5 "Main composition", two lines), `docs/engineering/project.md`, `docs/engineering/testing.md`, `docs/engineering/ROADMAP.md` (the F0-03 row), `.scratch/foundation/issues/03-project-config-main-scene-buses-export.md`.
Change: `Main/WorldRoot` and `Main/ProjectileRoot` are now `process_mode = PAUSABLE`. They had been left at INHERIT under a `Main` that is ALWAYS, so both kept receiving `_process` and `_physics_process` while the tree was paused; the 2026-09-22 review of the F0/F1 commits caught it with a runtime probe (P2). Two regression tests pin the contract: `test_world_and_projectile_roots_are_pausable` checks the modes, and `test_only_interface_and_audio_keep_processing_while_paused` pauses the tree and counts callbacks on probe nodes under all four roots (gameplay roots receive none and `can_process()` is false, `Interface` and `Audio` keep processing, gameplay roots resume on unpause). The second test failed against the old scene with three `_process` calls and one `_physics_process` call per root. The runner's watchdog is now ALWAYS, so a test that pauses the tree and then hangs still times out; a test that pauses the tree resets `tree.paused` in `after_each`. 47 tests green.
Why: F2-04 and F11 pause the tree from `GameSession`; with the old modes the stage, enemies, and projectiles would have kept simulating behind the pause menu.
Action required by Astra: none. `docs/GUIDE.md` is shared, which is why this entry carries the tag; only the two Section 5 lines for `WorldRoot` and `ProjectileRoot` changed.

## 2026-09-22 00:12 — Claude — Editor re-save of theme, enemy texture imports, and settings (retroactive for commit e54b7d6) [shared]
State: dev
Files: `assets/ui/menu_theme.tres`, `assets/models/enemies/Goleling_Atlas_Monsters.png.import`, `assets/models/enemies/Hywirl_Atlas_Monsters.png.import`, `project.godot`.
Change: Commit `e54b7d6` (2026-09-21 13:37) tracked Godot 4.7.2 editor side effects with no authored change and shipped without a log entry; this entry closes that gap (P3 in the 2026-09-22 review). `menu_theme.tres` was re-saved with a `uid` and sorted properties, serialization only. `project.godot` had two `[rendering]` keys reordered. The two enemy atlas textures were re-imported as VRAM-compressed: `detect_3d` fired the first time the editor rendered them on 3D meshes, so `compress/mode` went from 0 (lossless) to 2 (VRAM compressed, S3TC/BPTC) and `detect_3d/compress_to` from 1 to 0.
Why: running the project from the editor during F0-03 triggered the re-import and re-save; committing them stops the files from showing as dirty in every later session.
Action required by Astra: confirm the VRAM-compressed import is acceptable for the Hywirl and Goleling atlases. It is Godot's standard mode for 3D textures; quality loss shows mainly on flat colour gradients. If the lossless look is wanted, set `compress/mode=0` and `detect_3d/compress_to=0` in the two `.import` files so the editor does not switch them again. Nothing else in that commit touched your files.

## 2026-09-21 14:26 — Claude — FlightModel core (F1-01)
State: CODE_READY
Files: `scripts/player/flight_model.gd`, `tests/unit/player/test_flight_model.gd` (and their `.uid` files), `docs/engineering/player-flight.md` (new), `docs/engineering/README.md`, `docs/engineering/ROADMAP.md` (the F1-01 row), `.scratch/player-flight/issues/01-flight-model-core.md`.
Change: `FlightModel` is the first Rules Core, `class_name FlightModel extends RefCounted`, with `configure()`, `set_bounds()`, `compute_velocity()`, `clamp_position()`, `edge_proximity()` and `bank_angle()`. Horizontal input is rotated by the camera yaw around world Y only and the vertical axis is world Y, so the horizon stays stable; the combined 3D input vector is clamped to length 1 before it is scaled by `base_speed` and, under Focus, by `focus_multiplier`, so a full three-axis diagonal flies at 12.0 and not at 12 * sqrt(3). `compute_velocity` takes no delta and keeps no state: the adapter integrates `velocity * delta`, which is what makes movement frame-rate independent. `clamp_position` is the identity until `set_bounds` is called. `edge_proximity` is 0 farther than `edge_margin` from every face, rises linearly to 1 at the nearest face and stays at 1 outside, and emits `edge_proximity_changed(value: float)` only when the value moves more than 0.01 from the last one emitted. `bank_angle` returns a clamped roll for `VisualRoot` from the camera-lateral part of the velocity; negative leans into a turn to the ship's right. Eighteen tests, written test-first, cover the nine cases the ticket lists plus the wiring of `configure()` itself; one of them walks `get_property_list()` and rejects any script variable of a position type and then re-asks the same three questions after a long varied call sequence, which is how "banking cannot move the damage Core" is enforced rather than asserted. The suite was checked by mutation: hardcoding the authored values in `configure()`, comparing edge drift against the previous call instead of the last emitted value, moving the 0.01 threshold to 0.2 or 0.0051, dropping `limit_length`, flipping the bank sign and dropping the yaw rotation are all caught. Turning `>` into `>=` on the threshold is not, because no position produces a proximity exactly equal to 0.01 in binary floating point; the case is one hundredth of a feedback value and a test for it would be a rounding coin-flip. Suite is 45 green.
Why: F1-01, the first ticket of Feature F1. Movement rules had to exist before the adapter, the camera and targeting can be built on them.
Action required by Astra: none. The core is code-only, is never attached to a node, and does not appear in the GUIDE Section 6 registry. Exports and scene wiring arrive with F1-02, which also proposes `edge_margin` 4.0 and a 25-degree maximum bank for you to tune once the feedback is visible.

## 2026-09-21 13:56 — Claude — Ownership and collaboration protocol recorded in GUIDE (F0-04) [shared]
State: docs
Files: `docs/GUIDE.md` (header, Sections 2, 3, 4, 6, 9, 10, 13, 14, 15), `docs/engineering/README.md` (new), `CLAUDE.md`, `AGENTS.md`, `docs/engineering/ROADMAP.md`, `docs/HANDOFF_LOG.md`, `.scratch/foundation/issues/04-guide-ownership-and-protocol-docs.md`.
Change: GUIDE.md is now version 5 and Section 2 points at `CONVENTIONS.md`, `ROADMAP.md`, and `HANDOFF_LOG.md`. Section 3 records the ownership split: Claude owns `project.godot`, `export_presets.cfg`, `default_bus_layout.tres`, `scenes/main.tscn`, `scenes/dev/`, and inside any `.tscn` the script attachment, exported values, collision layers, masks, monitoring flags, and the instancing of Claude's prefabs; Astra keeps geometry, visuals, layout, markers, materials, and the `content/*.tres` values. The same section states that every change to a file owned by the other agent is announced in `docs/HANDOFF_LOG.md`. Section 6 adds `scripts/ui/interface.gd` (attached to `Main/Interface`), marks `scripts/ui/strings.gd` optional and code-only, and notes that Rules Cores are code-only and documented in `docs/engineering/<module>.md`. Section 9 gains step 0: before rerunning any `tools/build_*.py` generator over an integrated scene, reconcile it with the scene's current wiring or retire it. Section 10 gains the rows "Foundation and conventions" (Claude, CODE_READY) and "Stage 1 area" (Astra, SCENE_READY_STATIC, `docs/STAGE_01_HANDOFF.md`). New `docs/engineering/README.md` indexes the engineering docs. `CLAUDE.md` and `AGENTS.md` are kept identical and their collaboration section links GUIDE Section 3 and this log. No code changed. Two reconciliations came out of the same pass: Section 10's pre-existing "Stage 1 progression" row said SCENE_READY and described the authored area; it is now the runtime row (PLANNED, arrives with F10) while the new "Stage 1 area" row (SCENE_READY_STATIC) carries the scene and the `STAGE_01_HANDOFF.md` link. Sections 13, 14 and 15 still said the project main scene was `scenes/ui/main_menu.tscn` and that `scenes/main.tscn` remained planned; both have been false since F0-03 set `run/main_scene` to `res://scenes/main.tscn`, and they now say so. Section 4 now lists `SCENE_READY_STATIC` as a legal handoff state, since Section 10 already used it, and the "Stage 2 progression" row was split the same way as Stage 1 into "Stage 2 area" (SCENE_READY_STATIC) and "Stage 2 progression" (PLANNED). The one-line owner summary at the top of `CLAUDE.md` and `AGENTS.md` now matches Section 3 instead of saying Astra owns all of `scenes/`.
Why: F0-04. The accepted collaboration rules were only in the engineering docs and in this log; they now live in the shared contract both agents already read.
Action required by Astra: read GUIDE Section 3 again. Note the Section 10 state change on "Stage 1 progression". From here on every delivered scene gets an entry in this log plus a row in the roadmap's "Received from Astra" table. `docs/GUIDE.md` is a shared file, which is why this entry exists.

## 2026-09-21 13:46 — Claude — Project config, main scene, audio buses, export preset (F0-03) [shared]
State: CODE_READY
Files: `project.godot`, `default_bus_layout.tres`, `export_presets.cfg`, `scenes/main.tscn`, `scripts/session/game_session.gd`, `tools/godot.sh`, `tools/test.sh`, `tests/scene/test_main_contract.gd`, `tests/unit/project/test_input_map.gd`, `tests/unit/project/test_audio_buses.gd` (and `.uid` files), `docs/GUIDE.md` (Sections 5, 6, 10), `docs/engineering/project.md`, `docs/engineering/testing.md`, `docs/engineering/ROADMAP.md`, `.scratch/foundation/issues/03-project-config-main-scene-buses-export.md`. Astra-owned, annotated only: `tools/validate_hud_handoff.gd`, `tools/validate_menu_handoff.gd`, `tools/validate_scene_handoff.gd`, `tools/validate_stage_01.gd`.
Change: Claude now owns the four shared project files. `project.godot` treats `untyped_declaration`, `unused_variable`, `unused_parameter`, `shadowed_variable` as errors, declares the sixteen gameplay actions (deadzone 0.2, physical keys plus Xbox bindings, no mouse, `ui_*` untouched), references `default_bus_layout.tres` (`Master`, `Music`, `SFX`), and boots `scenes/main.tscn`: `Main` (`GameSession`, process ALWAYS) with `WorldRoot`, `ProjectileRoot`, `Interface` (ALWAYS), `Audio` (ALWAYS). `GameSession` validates its four exports and instances `scenes/ui/main_menu.tscn` under `Interface`; nothing else yet (F2). `export_presets.cfg` holds the "Windows Desktop" preset; the export itself is blocked because this Linux host has no export templates. `tools/godot.sh` and `tools/test.sh` mirror the PowerShell wrappers since PowerShell is absent here. Six of your validator `for` loops iterate untyped arrays and stopped compiling under the new setting; they now carry a type annotation (`for path: String in ...`), nothing else changed. Verified: 27 tests green, `--quit` clean, every `.gd` passes `--check-only`, the project runs windowed on Vulkan and the menu renders as before.
Why: F0-03. The warnings are the CONVENTIONS baseline, the composition root is ADR-0002, F3 needs the buses, and a Linux session needs one command for Godot and one for the tests.
Action required by Astra: none on scenes. Review the one-line diffs in `tools/validate_*.gd`; from now on type `for` iterators over untyped arrays. F5 starts `main.tscn`; keep previewing menus with F6.

## 2026-09-21 — Astra — Stage 2 texture, color and life revision
State: SCENE_READY
Files: `scenes/stages/stage_02.tscn`, `tools/build_stage_02.py`, `assets/environment/stage_02/`, `tools/validate_stage_02.gd`, `tests/scene/test_stage_02_contract.gd`, `.scratch/stage-02-area/issues/02-mountain-art-pass.md`, Stage 2 handoff/validation, credits, roadmap.
Change: Replaced repeated blue cones/slabs with original irregular crags, moss/gravel/granite texture and terrain ramps. Added green/amber vegetation, vermilion shrine structures, warm lanterns, bronze inlays, water flow, foliage/cloth wind and fading gate wisps. Terrain collision matches its mesh; the old step-floor lookup is no longer exact. Encounter IDs, spawn/checkpoint positions, full gate coverage and seal links are preserved. No production gameplay scripts or project settings edited.
Why: User rejected the monochrome and lifeless blockout. Six views reviewed on Godot 4.7.2 Compatibility, including player height; ambient motion check passed. All 16 tests passed, including physics terrain clearance and front-facing ramp collision. Review docs/validation/stage-02.md for limits.
Action required by Claude: Use actual sculpted terrain collision for floor constraints; see STAGE_02_HANDOFF.md. Shader motion is cosmetic and requires no gameplay binding. Generator now also authors the terrain/stream/crag OBJ meshes; reconcile before reruns. Gameplay integration and duration testing remain pending.

## 2026-09-21 — Astra — Stage 2 art revision announced
State: PLANNED
Files: `tools/build_stage_02.py`, `scenes/stages/stage_02.tscn`, original environment assets/shaders, QA, Stage 2 docs.
Change: User rejected the monochrome blockout. Rework terrain presentation, mountain silhouettes, surface texture, vegetation, lighting and ambient movement. Generator and scene were reconciled against bda60cd: no subsequent integration edits exist. Keep encounter/gate/checkpoint contracts; terrain collision follows any changed terrain surface.
Why: Improve visual quality and environmental life while preserving combat readability.
Action required by Claude: review the updated Stage 2 handoff after this ticket; no production GDScript changes planned.

## 2026-09-21 — Astra — Stage 2 mountain spatial pass delivered
State: SCENE_READY
Files: `scenes/stages/stage_02.tscn`, `scenes/tests/stage_02_preview.tscn`, `tools/build_stage_02.py`, `tools/validate_stage_02.gd`, `tests/scene/test_stage_02_contract.gd` (and UIDs), `.scratch/stage-02-area/`, `docs/STAGE_02_HANDOFF.md`, `docs/GUIDE.md`, `docs/engineering/ROADMAP.md`, `docs/validation/stage-02*`.
Change: Static route with seven encounters, 20 common-enemy and two boss markers, three seals with independent approach volumes and guard links, five full-volume gates, and CP2-A/CP2-B. Original mountain primitives, cyan route guidance, separate duel/summit platforms. Added an offline scene contract to Claude's test discovery tree; no production GDScript or existing scenes changed.
Why: First Stage 2 ticket requested by user. Godot MCP confirmed 4.7.2; the direct Linux test entry point passed 15 tests with zero failures. Five Compatibility renders completed and were inspected. PowerShell is unavailable on this host.
Action required by Claude: Read STAGE_02_HANDOFF.md for exact paths, seal/guard mapping, resource rewards, checkpoint prerequisites and remaining runtime checks. Author typed Definitions and attach runtime actors/director. Static scene completion does not claim gameplay or the five-minute requirement. Reconcile before rerunning the generator.

## 2026-09-21 — Astra — Stage 2 spatial pass announced
State: PLANNED
Files: new `scenes/stages/stage_02.tscn`, `scenes/tests/stage_02_preview.tscn`, `tools/build_stage_02.py`, offline QA, `.scratch/stage-02-area/`, `docs/STAGE_02_HANDOFF.md`, `docs/GUIDE.md`, `docs/engineering/ROADMAP.md`.
Change: Begin one static mountain-route ticket with seven encounters, three guarded seals, gates and two checkpoints. New scene collision defaults follow Stage 1; no integrated scenes or production scripts are edited. Offline contract QA will be added to the test discovery tree.
Why: User requested starting Stage 2.
Action required by Claude: preserve these new authored paths during subsequent integration; existing dirty project/theme/import files belong to other work.

## 2026-09-21 00:25 — Claude — Godot wrapper and headless test runner (F0-02)
State: CODE_READY
Files: `tools/godot.ps1`, `tools/godot.cmd`, `tools/test.ps1`, `tests/run_tests.gd`, `tests/framework/test_case.gd`, `tests/unit/framework/test_self_check.gd` and their `.uid` files, `docs/engineering/testing.md`, `docs/engineering/ROADMAP.md` (row F0-02 only), `.scratch/foundation/issues/02-godot-wrapper-and-test-runner.md`.
Change: One command runs Godot (`tools/godot.ps1`, resolving `$env:GODOT_BIN` then the verified Downloads path) and one runs the tests (`tools/test.ps1`, exit 0 only when every test passed). `TestCase` provides the `assert_*` helpers, `before_each`/`after_each`, and `signal_recorder()`; the runner discovers `tests/unit/**` and `tests/scene/**`, awaits coroutine tests, honours `-Filter`, and fails on load errors, assertion-free tests, and hangs over 30 seconds. Because `class_name` resolution needs Godot's class cache in `.godot/`, `tools/test.ps1` runs a headless editor import (about three seconds) whenever a `.gd` file is newer than its last import. Self-check: 14 tests green; the exit-1 path and a warnings-as-errors run were verified.
Why: Every Rules Core from ADR-0001 is tested headless from now on; a session needs one green/red command.
Action required by Astra: none. `tools/godot.ps1` replaces "set `$godotExe` first" in the validation docs: `tools/godot.ps1 --headless --path . --script res://tools/validate_scene_handoff.gd`. The existing `tools/validate_*.gd` scripts keep working unchanged. Note that `tools/test.ps1` may create `.uid` files next to new scripts and import new assets, exactly as opening the editor does; commit `.uid` files with their scripts.

## 2026-09-21 — Astra — Stage 1 enemy visual variants
State: SCENE_READY
Files: `assets/models/enemies/`, `assets/licenses/quaternius-ultimate-monsters.txt`, `scenes/enemies/visuals/`, `scenes/tests/enemy_variants_preview.tscn`, `tools/build_enemy_visuals.gd`, `tools/validate_enemy_visuals.gd`, `docs/ENEMY_VISUAL_HANDOFF.md`, credits, roadmap, validation outputs.
Change: Imported Hywirl and Goleling; authored two Spirit and two Sentry recolor/resize variants, with one/two rings for Sentries and looping Flying_Idle. Visual scenes contain no stats or collision components. Existing Player/Menu/Stage scenes and production scripts were not edited.
Why: User approved visual variety while explicitly keeping health identical within each enemy type.
Action required by Claude: Read ENEMY_VISUAL_HANDOFF.md. Instance visuals under Enemy independently from HitVolume/Emitters; reuse each type's health configuration. These components do not replace the pending Enemy adapter contract. Project-wide test runner is not yet present; dedicated Godot visual QA passed.

## 2026-09-20 23:58 — Claude — Repository initialized (F0-01)
State: docs
Files: `.gitignore`, `docs/engineering/ROADMAP.md`, `docs/HANDOFF_LOG.md`, `.scratch/foundation/issues/01-git-init-and-ignores.md`; removed the empty root folders `export_templates/`, `feature_profiles/`, `script_templates/`, `text_editor_themes/`.
Change: `git init` on branch `main` with repo-local `core.autocrlf false` (`.gitattributes` already normalizes to LF). `.gitignore` now also excludes `/build/`, `/All models/`, `/all-sounds/`, `/Music/`, and `*.tmp`; `*.import` files stay tracked. One baseline commit, `chore: baseline import of scenes, docs, and planning`, holds everything in the tree including `.scratch/`.
Why: Every later session commits small, reviewable changes. The raw download packs (about 400 MB) stay on disk but out of history.
Action required by Astra: none. Repository initialized; Astra may commit scene work with `[shared]` tags (message format `scenes: summary`) or leave commits to Claude. Keep `All models/`, `all-sounds/`, and `Music/` on disk; they are untracked on purpose.

## 2026-09-20 23:30 — Claude — Engineering planning baseline
State: docs
Files: `CONTEXT.md`, `docs/adr/0001` to `0004`, `docs/engineering/CONVENTIONS.md`, `docs/engineering/TEMPLATE.md`, `docs/engineering/ROADMAP.md`, `docs/HANDOFF_LOG.md`, `.scratch/<feature>/` tickets for all fourteen engineering Features, `CLAUDE.md`, `AGENTS.md`.
Change: Recorded the accepted vocabulary, the four architectural decisions, the coding conventions, the ordered roadmap, and full tickets for Foundation, Player flight, and Menus/Session. No scene, script, or `project.godot` changes yet.
Why: Result of the planning grill with the user; establishes how Claude writes and verifies GDScript for this project.
Action required by Astra: read `docs/engineering/ROADMAP.md`, especially "Requests to Astra". From ticket F0-03 onward Claude owns `project.godot`, `export_presets.cfg`, `default_bus_layout.tres`, and `scenes/main.tscn`; the `tools/build_*.py` generators must not be rerun over integrated scenes without reconciling first. Astra's `.scratch/stage-01-area/` and `docs/STAGE_01_HANDOFF.md` were read and are reflected in the roadmap.

## 2026-09-23 � OpenCode (oc-a) � F12-06 part 1

Files: `content/bosses/tempest_sentinel.tres`, `content/patterns/sentinel_aimed_burst.tres`, `content/patterns/sentinel_rotating_fan.tres`.

Change: Added the dev Tempest Sentinel BossDefinition with two proposed attacks and two health phases. Phase 1 uses alternating charged aimed bursts; Phase 2 uses rotating fans with alternating player-height tracking and fixed altitude shifts. All three resources carry `metadata/dev = true`. Proposed values and attack names remain for Astra's D-06 review. Part 1 only; scene integration remains with sol.

## 2026-09-23 � OpenCode (oc-a) � F12-07 part 1

Files: `content/bosses/storm_guardian.tres`, `content/patterns/storm_spiral.tres`, `content/patterns/storm_thunder_rings.tres`, `content/patterns/storm_aimed_burst.tres`.

Change: Added the dev Storm Guardian BossDefinition with the three Stage 2 final-boss attack names and phase content: a height-drifting spiral, alternating high/low thunder rings, and alternating aimed bursts and spirals. All four resources carry `metadata/dev = true`. Proposed values remain for Astra's D-06 review. Part 1 only; scene integration remains with sol.
