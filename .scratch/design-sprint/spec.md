# Design sprint (Astra, lane sol) — spec

Status: ready-for-agent
Owner: Astra (GPT Sol, Codex), lane `sol`
Source: `docs/engineering/SPRINT.md` (lane sol queue, "Shared files"); `docs/engineering/ROADMAP.md` "Requests to Astra"; `docs/GUIDE.md` Sections 3 and 5; `docs/PLANEJAMENTO.md` Sections 2, 4, 9; `docs/STAGE_DESIGN.md`.

## Goal

Every open "Request to Astra" that the 2026-09-24 delivery needs becomes one D ticket with a named consumer ticket, an exact file contract and a mechanical acceptance check. Astra's deliverables are new files (sub-scenes, meshes, audio imports, content values, rulings) that Claude's code already expects, so no lane waits on a conversation. The D tickets are interleaved with lane sol's code tickets in `SPRINT.md` order.

## Tickets, in lane sol order

| # | Queue item | Depends on | Delivers | Consumed by |
| --- | --- | --- | --- | --- |
| 1 | **D-01** `01-sfx-selection-and-import.md` | none | One Kenney sound per F13 catalogue event, copied to `assets/audio/sfx/`, licenses and credits, and the music decision (written separately; the ticket holds the event table) | F13-03 (trunk enters the table in `Main/Audio`), F14-02 (credits) |
| 2 | **D-02** `02-combat-visuals.md` | none | Final Projectile meshes, Familiar, Power and Shield Pickup visuals, Bomb blast, under `scenes/combat/visuals/` | F6-02, F6-03, F7-02 (trunk), F7-03 (glm-b) |
| 3 | F4-03 boss-panel-and-attack-cue-api | F4-02 | code | |
| 4 | **D-03** `03-lantern-guardian-scene.md` | none | `scenes/enemies/lantern_guardian.tscn` with the GUIDE Section 5 tree and real clip names, no gameplay value (written separately) | F12-03 (trunk attaches `boss_controller.gd` with F12-02's clip exports and swaps `actor_scenes`) |
| 5 | F9-02 dev-prefabs-and-enemy-actor | F9-01, F6-02 | code | |
| 6 | F12-02 boss-controller-adapter | F12-01, F9-02, F4-03 | code | |
| 7 | **D-04** `04-stage-2-boss-scenes.md` | none | Tempest Sentinel and Storm Guardian scenes (written separately) | F12-06, F12-07 (lane sol) |
| 8 | **D-05** `05-stage-1-tuning-and-pacing.md` | F8-04 | Stage 1 content, dev enemy and pattern values, HitVolume radii, CP1-A/CP1-B names, Anticipation clip, pacing table and the five-minute fallback note | F10-01 (loads it), F11-01 (Defeat text), F11-03 (expected time), F14-02; SPRINT cut step 4 |
| 9–11 | F12-05, F12-06, F12-07 | see SPRINT | code | |
| 12 | **D-06** `06-stage-2-content-review.md` | F12-04 | Stage 2 content tuned toward 300–360 s, reward and Power 3 check | F12-05 (loads it), F11-03, F14-02 |
| 13 | **D-07** `07-shrine-lighting-and-boss-rulings.md` | F12-03 | Shrine-lighting clip in Stage 1, five written rulings | F12-03's Director exports (trunk sets them), F4-02/F4-03, F12-01, F5-02, F1-02/F6-03 |

D-07 Part B (the rulings) needs nothing from F12-03; see that ticket for early delivery.

## Rules every D ticket follows

- **The ticket's Files section is the edit boundary** (SPRINT "Lanes"). A D ticket never edits `scripts/`, `tests/`, `project.godot`, `scenes/main.tscn` or `scenes/player/player_ship.tscn` (trunk only), nor `scenes/dev/` except the values D-05 names. `scenes/stages/stage_01.tscn` is edited only by D-07, after F12-03 has landed. `scenes/stages/stage_02.tscn` script wiring is F12-05's alone; the one D edit there is D-06's three Seal `health` values, after F12-05.
- **New sub-scenes, not edits.** Visual deliverables are new files under `scenes/combat/visuals/` or `scenes/enemies/`, instanced by Claude's prefabs or pointed at by Claude's exports.
- **Values on trunk-only files are proposed, not edited.** `PlayerShip/Weapon` exports (shot, Familiar and Bomb values), `Main` exports and `StageDirector` exports are written as "old → proposed" lines in the handoff entry for trunk to apply.
- **Content stays valid.** `validate()` stays empty and `tools/test.ps1` stays green. A red test that pins a value you changed wins: revert that value and log the one you wanted. Keep `metadata/dev = true` wherever a `test_every_file_is_flagged_dev` exists (F8-04, F12-03, possibly F12-04); add `metadata/reviewed = true` instead, which no test reads.
- **Any `.gd` you write** (a `tools/validate_*.gd`) compiles with `untyped_declaration`, `unused_variable`, `unused_parameter` and `shadowed_variable` as errors (ROADMAP "Requests to Astra", F0-03 row).
- **Evidence** goes in `docs/validation/`, headless first, then windowed (a windowed capture can hang; the headless run proves the scene loads).
- **Never rerun a `tools/build_*.py` or `build_enemy_visuals.gd` generator** over an integrated scene.
- **Session end:** one `docs/HANDOFF_LOG.md` entry headed `— Astra (sol) —`, naming each consumer ticket; in `docs/engineering/ROADMAP.md` only your D row and one "Received from Astra" row; commit `design: <summary>` (`[shared]` when a Claude-owned file is touched); `tools/lane.ps1 land`.

## Cross-lane contracts

- **Late-swap rule (D-02, D-03, D-04, D-07).** A consumer ticket that starts after the D ticket has landed uses the final file directly. When the consumer landed first, the swap is a Claude-side one-line change made by the first ticket of the owning lane that starts after the D ticket lands, recorded in its Outcome: trunk for `main.tscn`, `player_ship.tscn`, `stage_01.tscn` exports and `scenes/dev/bomb_blast.*`; trunk also for `scenes/dev/power_pickup.tscn` and `shield_pickup.tscn` once F7-03 has landed.
- **D-02 paths:** `scenes/combat/visuals/projectile_player_mesh.tres`, `projectile_hostile_mesh.tres`, `familiar.tscn`, `power_pickup_visual.tscn`, `shield_pickup_visual.tscn`, `bomb_blast_visual.tscn` (clip `blast`). Root contracts are in D-02.
- **D-07 shrine clip:** `AnimationPlayer` at `Environment/ShrineLighting` relative to `Stage`, clip `corrupted_to_calm`, feeding F12-03's `defeat_presentation` and `defeat_animation`.
- **Rulings** are one sentence each in the relevant PLANEJAMENTO section plus a table in the D-07 handoff entry. Engineering Open issues are closed by the consuming lane, not by Astra.

## Requests to Astra: coverage

| ROADMAP row | Covered by |
| --- | --- |
| F4-02 (HUD dimming 0.25 and 0.3, two-Phase bar layout) | D-07 Part B |
| F6 (Projectile presets, Familiar; weapon and F5-04 pattern tuning; F1 ship-turn call) | D-02; weapon values as proposals in D-05; D-07 Part B |
| F7 (Pickup visuals, Bomb blast; Bomb radius and damage) | D-02; Bomb numbers as proposals in D-05 |
| F8-04 (Stage 1 content, CP1-A and CP1-B names) | D-05 |
| F9 (dev enemy and pattern tuning, HitVolume radii, Anticipation clip; Tempest Sentinel) | D-05; D-04 |
| F12 (Lantern Guardian scene and clips; shrine clip; transition ruling; Lantern Guardian tuning; Stage 2 bosses) | D-03; D-07 Parts A, B, C; D-04 |
| F13 (event-to-sound selection, music decision) | D-01 |
| F2-02 (visible focused slider in `menu_theme.tres`; Results layout) | **not covered** |
| F10 (boss-arena retreat containment, checkpoint glow on `checkpoint_activated`) | **not covered** |
| F1-02 to F1-05 (Inspector flight tuning; human keyboard and DualSense pass) | **not covered** (human step in SPRINT) |
| F2-04 (optional `FlightBounds/Limits` in Stage 1) | **not covered** (optional) |

## Done when

- D-01 to D-07 are `done` with an Outcome, each landed on the integration branch with its consumer named in the log.
- Every consumer ticket's Outcome, or a late swap, points at the final file instead of a `scenes/dev/` placeholder, or records why it could not.
- `docs/validation/stage-01-pacing.md` and `stage-02-pacing.md` exist, and the five-minute claim is made only from a measured clear (STAGE_DESIGN "Time and score integrity").

## Out of scope

Code of any kind; the human physical-device pass; music selection beyond what D-01 decides; retreat containment and checkpoint glow (not covered above); a second Stage 1 art pass.
