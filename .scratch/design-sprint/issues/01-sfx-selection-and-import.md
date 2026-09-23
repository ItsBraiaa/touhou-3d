# D-01 SFX selection and import

Status: todo
Type: design
Owner: Astra (GPT Sol)
Lane: sol
Depends on: none

## Goal

Choose one sound for each of the 17 events in the F13 catalogue from the four local Kenney packs in `all-sounds/`. Copy the selection into `assets/audio/sfx/` with correct import settings, record the licenses and credits, and decide on music under the Touhou fan-content guidelines: ship none unless a permitted track is identified, and record the decision either way. Hand Claude the event-to-file table that F13-03 enters in `Main/Audio`. This is the "selection/mix" half of GUIDE Section 10 "Audio integration", and the assignment's "sound effects" requirement (PLANEJAMENTO Section 2).

## Read first

- `.scratch/audio/spec.md` "Event catalogue": the 17 ids, what each sound means, and the proposed interval, voices and priority
- `docs/PLANEJAMENTO.md`:
  - Section 9: the minimum audio events, the four Kenney packs (all CC0, with their source links), "Record filename, creator, source link, license, and modifications", "Select music through listening", and "Music references" with the guidelines paragraph.
  - Section 3: off-screen threats need audio warnings. Section 7: Graze gets "subtle light and sound feedback".
- `docs/STAGE_DESIGN.md` "Checkpoint contract": arches with "a brief glow and sound"
- `docs/ASSET_CREDITS.md` (the entry format) and `assets/licenses/` (the naming, `kenney-space-kit.txt`)
- `docs/GUIDE.md` Section 3 (preserve `all-sounds/` and `Music/`; runtime assets are selected copies), Section 5 (buses `Master`, `Music`, `SFX`) and Section 14 (extend credits only for integrated assets; never rerun `build_menu_handoff.py` over integrated menus)

## Files

- **Creates:**
  - `assets/audio/sfx/<pack>/<original file name>` and the `.import` next to each file, with `<pack>` one of `interface`, `digital`, `scifi`, `impact`.
  - `assets/licenses/kenney-interface-sounds.txt`, `kenney-digital-audio.txt`, `kenney-sci-fi-sounds.txt`, `kenney-impact-sounds.txt`: each pack's supplied license, copied only for packs with a selected file.
  - `tools/validate_audio_selection.gd` and `docs/validation/audio-selection.md`.
- **Edits:** `docs/ASSET_CREDITS.md` (new "Sound effects" and "Music" sections), `scenes/ui/credits.tscn` (one "EFEITOS SONOROS" entry in the existing style: `Kenney · <packs used> · CC0`), `docs/HANDOFF_LOG.md`.
- **Must not touch:** `all-sounds/**` and `Music/**` (originals), `scenes/main.tscn` (Claude sets the mapping in F13-03), `scripts/**`, `tests/**`, `project.godot`, `default_bus_layout.tres`, every other menu scene, and `tools/build_menu_handoff.py` (do not rerun it).

## Deliverable contract

Consumed by F13-03 (`.scratch/audio/issues/03-audio-event-wiring.md`) and read by F13-02's `missing_events()` check.

- **One row per event id**, exactly these 17: `ui_focus`, `ui_accept`, `player_shot`, `enemy_hit`, `graze`, `shield_broken`, `player_hit`, `bomb_used`, `player_defeated`, `pickup_power`, `pickup_shield`, `enemy_defeated`, `checkpoint_activated`, `threat_warning`, `boss_phase_changed`, `boss_defeated`, `stage_cleared`. A file may serve two events; list it on both rows.
- **Table** in `docs/validation/audio-selection.md`: `| Event | File (res://) | Length (s) | volume_db | Why it fits |`. `volume_db` is your mix proposal, 0.0 when none is needed. Claude copies it into `event_volume_db`.
- **Files.** Copy the originals byte for byte, keeping the name Kenney gave them and the format the pack ships. If you trim or convert one, give it a `_trim` suffix and record the change in the credits.
- **Import.** Every sound effect is non-looping: Ogg Vorbis `loop=false`, WAV loop mode Disabled. The limiter counts a voice for the stream's length, so a loop would hold a voice until it is stolen.
- **Length guide** (proposal):
  - UI: 0.3 s or less.
  - `player_shot`, `enemy_hit`, `graze` and `pickup_power`: 0.4 s or less, soft, because they repeat. `graze` is the subtlest.
  - `stage_cleared`, `player_defeated` and `boss_defeated`: 3 s or less.
  - Everything else: 1.5 s or less. `threat_warning` must cut through combat.
- **Pack hints** (PLANEJAMENTO Section 9; you decide): menus from Interface Sounds, shots from Digital Audio, energy (Bomb, Shield, Checkpoint, warnings, boss Phase) from Sci-fi Sounds, and impacts and defeats from Impact Sounds.
- **Credits.**
  - `docs/ASSET_CREDITS.md` "Sound effects": creator Kenney, each pack used with its source link from PLANEJAMENTO Section 9, CC0, the license copy's path, the runtime folder, and the changes (none, or per file).
  - `credits.tscn` names only the packs actually used.
- **Music decision**, recorded in `docs/ASSET_CREDITS.md` "Music" and in the handoff entry:
  - The five files in `Music/` carry *Touhou 10* composition titles. PLANEJAMENTO calls those compositions references, "not verified audio files ready to redistribute".
  - Unless a file's source and permission are documented, do not copy it. The expected outcome is "No music ships in this delivery", with the reason.
  - Do not download anything in this ticket: a new track is the user's call.
  - If a permitted track is identified, copy it to `assets/audio/music/` with loop on and credit it with the attribution its license requires. Then give Claude a table over the ids `menu`, `stage_01_route`, `stage_01_boss`, `stage_02_route` and `stage_02_boss`; one track may serve several ids.

## Acceptance

- `tools/godot.ps1 --headless --path . --import` exits 0.
- `tools/godot.ps1 --headless --path . --script res://tools/validate_audio_selection.gd` loads every table path as an `AudioStream` and prints its length and loop flag. It exits non-zero on a missing file, a length of 0, a looping sound effect or an id outside the 17. The tool must compile under the four warnings-as-errors (type `for` iterators).
- `tools/test.ps1` green, with no `SCRIPT ERROR`. The menu contract tests cover `credits.tscn`'s load-bearing paths.
- A listening pass in the editor, one "why it fits" line per row.
- The credits screen re-rendered with `tools/validate_menu_handoff.gd`, windowed, into `docs/validation/menu-credits.png`.
- Every pack with a selected file has its license in `assets/licenses/`.

## Handoff to Claude

Add a `docs/HANDOFF_LOG.md` entry, newest first. It names D-01, points at the table in `docs/validation/audio-selection.md`, lists the license files and the `credits.tscn` change, and states the music decision (with the track table if any). It also lists any event whose rule values you want changed after listening. F13-03 consumes it. Set this ticket to `Status: done` with an `## Outcome`.

## Kickoff prompt

```
Read AGENTS.md, docs/engineering/SPRINT.md (lane sol), docs/GUIDE.md Sections 3 and 5 and .scratch/design-sprint/issues/01-sfx-selection-and-import.md, then deliver it in your worktree, log it in docs/HANDOFF_LOG.md, commit, and run tools/lane.ps1 land.
```
