# F14-01 Export and run outside the editor

Status: done

Outcome (2026-09-24, trunk):
- **Swap step.** Landed first as one `[shared]` commit (`83e5e2b`):
  - D-07's `defeat_presentation` and `defeat_animation` on Stage 1's `Stage`;
  - D-02's Projectile meshes on `Main/ProjectileRoot` and its Familiar on `PlayerShip/Weapon`;
  - the dev `BombBlast`, rebuilt around D-02's `bomb_blast_visual.tscn`.

  D-05 asked for no weapon or Bomb change.
- **Export.** From `dev-01` `8061d77`, after F13-04, with `tools/test.ps1` green (225). An `--import` came first, then `--export-release "Windows Desktop" build/Touhou-3D.exe`: exit 0, no `ERROR:` or `WARNING:`. `Touhou-3D.exe` is 129,258,616 bytes and `Touhou-3D.console.exe` 91,136.
- **Runs outside the repository.** Headless and windowed, D3D12 12_0 Forward+ on the RX 9070 XT, no fallback, 1280 × 720, V-Sync on and capped at 60.
  - The release build ignores `--script`. A scratch autoload loaded through an `override.cfg` beside the exe drove it with key events through its own input map. That walk passed every Deliverable 4 step, and Sair quit the game with exit 0.
  - FPS: S1-01 60; S1-02's Waves 59 to 60 (81 hostile); the Lantern Guardian 59 to 60 in all three Phases (106 hostile); the Storm Guardian 59 to 60 in all three (93 hostile). With V-Sync off the Storm Guardian never fell below 1,171.
  - The D-07 shrine clip plays under Results.
- **Export-only failures.** None. The one file fix: `export_presets.cfg` `debug/export_console_wrapper` 1 → 2, so the release export also writes the console exe the ticket names.
- **Also seen.** A quit-time audio leak (`ERROR: 2 resources still in use at exit`) on a trial build before F13-04. It is not export-only and did not recur on the final build; it is an open issue in `project.md`.
- **No tests** (sprint rule).
- **Not verified:**
  - a physical keyboard and gamepad on the build;
  - a boss fight flown by a person;
  - the presentation computer (the protocol is in `docs/validation/export.md`).
Type: integration
parallel-safe: no
Depends on: F11-03, F12-03; and the Godot 4.7.2 export templates, which the user installs (see Precondition)
Lane: trunk
Model: Claude Opus 5.5, solo

> **Sprint note:** before exporting, apply every pending swap as one `[shared]` commit. These are the lane-sol handoff entries marked "swap pending: D-0N", plus every value Astra asked trunk to set in a trunk-only file:
> - D-02 meshes, Familiar, pickup visuals and Bomb blast;
> - D-03 Lantern Guardian and D-04 boss scenes;
> - D-05 weapon and Bomb values in `player_ship.tscn`;
> - D-07 shrine exports on Stage 1's `Stage`.
>
> Measure the densest-boss FPS on the Storm Guardian if F12-07 has landed, otherwise on the Lantern Guardian.

## Goal

Export the Windows release build with the F0-03 preset "Windows Desktop" and run it outside the editor on this machine. Record the renderer, resolution and FPS, including the densest boss Encounter (S1-07, the Lantern Guardian), and any renderer fallback. Fix export-only failures. If the user can reach the presentation computer, give them the protocol to repeat there. This closes the F0-03 open issue "Windows export blocked".

## Precondition: export templates (check first, stop if absent)

1. Check that both of these exist:
   - `%APPDATA%\Godot\export_templates\4.7.2.stable\windows_release_x86_64.exe`
   - `%APPDATA%\Godot\export_templates\4.7.2.stable\windows_debug_x86_64.exe`

   On 2026-09-23 `C:\Users\Braia\AppData\Roaming\Godot\export_templates\` existed but was empty. F0-03 found none either, on its Linux host.
2. If either is missing, the session does not download or install anything; it neither fetches the templates nor opens the editor's downloader. It sets `Status: blocked` and records the blocker in an Outcome. It adds a ROADMAP row note and a handoff log entry. It then tells the user how to install them (about 1 GB), in one of two ways:
   - in the Godot 4.7.2 editor, open Editor > Manage Export Templates > Download and Install;
   - or download the official 4.7.2 `.tpz` from godotengine.org and use Install from File.

   Then it stops. This is the user's step; a session may not download files.

## Read first

- `docs/engineering/project.md`: `export_presets.cfg` has preset "Windows Desktop", `build/Touhou-3D.exe`, embedded PCK, x86_64, console wrapper on. Also its Open issues.
- `.scratch/foundation/issues/03-project-config-main-scene-buses-export.md`, the Outcome: the exact export command and the missing-template error.
- `docs/ENGINEERING_BRIEF.md` Section 3 and Section 8 "Manual and integration checks" ("Profile a dense final-boss encounter on the presentation computer. Initial target is 60 FPS, not a verified result. Record resolution and observed behavior before optimizing").
- `docs/PLANEJAMENTO.md` Section 12: the 60 FPS and "exported build runs outside the editor" items.
- `docs/engineering/testing.md` (running the suite) and `tools/godot.ps1` (argument forwarding).

## Files

- **Creates:** `docs/validation/export.md`. The build itself goes to `build/Touhou-3D.exe` and `build/Touhou-3D.console.exe`; it is git-ignored and never committed.
- **Edits:**
  - `export_presets.cfg`, only to fix an export-only failure, reporting the exact keys changed.
  - `project.godot`, only for an export-only setting, with the keys reported.
  - The owning Claude script, for the smallest fix of a failure that appears only in the exported build, with a regression test.
- **Serialized at session end:**
  - `docs/engineering/ROADMAP.md`: the F14-01 row.
  - `docs/HANDOFF_LOG.md`: one entry.
  - `docs/engineering/project.md`: a new "Export" section (command, output, environment, result), with the "Windows export blocked" open issue removed or updated.
  - `docs/GUIDE.md`: the Section 10 row "Foundation and conventions" (export evidence).
- **Must not touch:** every `scenes/**` file owned by Astra, `content/**`, `docs/ASSET_CREDITS.md`, and `%APPDATA%` beyond reading it. An Astra-owned file that needs a change for the export is a request in the handoff log, not an edit.
- **Conflicts with:** F14-02, which comes after and reuses the build.

## Deliverables

1. **Tests first.** `tools/test.ps1` is green, with no `SCRIPT ERROR`, on the commit being exported. Record the commit hash.
2. **Export.** Run `tools/godot.ps1 --headless --path . --export-release "Windows Desktop" build/Touhou-3D.exe`. It must exit 0 with no `ERROR:` lines. Record the size of both executables.
3. **Run outside the project.** Copy `build/` to a scratch folder outside the repository and run `Touhou-3D.console.exe --print-fps` from there, headless first where possible, then windowed. The main menu appears.
4. **Walk the build** on keyboard, with the gamepad too if one is connected:
   - Start Direct Stage 1 and fly past `Gate_S1_02` after S1-02.
   - Pause and resume, open Options from Pause, go Back.
   - Force a Defeat and Retry.
   - Return to the menu and Sair.
5. **Record** in `docs/validation/export.md`:
   - The renderer line Godot prints at startup: driver (Vulkan or D3D12), GPU, and any fallback message.
   - The window resolution, and the FPS readings from `--print-fps` in S1-01, in S1-02's busiest wave, and in S1-07. S1-07 needs someone to reach the boss: a human pass by the user, or "not measured" when there is none.
   - Every error or warning line the build prints.
6. **Fix export-only failures.** Typical causes are a resource loaded by a path string that the export did not include, or behavior that relied on an `assert` (stripped in release). Fix each with the smallest change in the file that owns it, and list it in the Outcome.
7. **Presentation computer.** Add a short protocol to `export.md`: copy `build/`, run the console exe with `--print-fps`, and record the same fields. Mark it "not verified" unless the user reports results.

## Tests required

No new automated test unless a fix needs a regression test. `tools/test.ps1` is green before and after. The export log and the run log are grepped for `ERROR` and `SCRIPT ERROR`.

## Out of scope

- The zip and the acceptance record (F14-02).
- Performance optimization. This ticket records measurements; it does not tune (ENGINEERING_BRIEF: "Record resolution and observed behavior before optimizing").
- Code signing, icons, a Linux preset.
- Installing the templates, which is the user's step.

## Definition of Done

- The precondition was met. Otherwise the ticket is `blocked`, with the user told how to install the templates.
- `tools/test.ps1` green; the export exits 0; the exported build boots outside the repository and plays Stage 1.
- `docs/validation/export.md` is complete, with S1-07 FPS measured or marked "not measured" and the reason.
- The `project.md` "Export" section, handoff log, `Status: done` with an Outcome, and the ROADMAP row are updated.
- One commit: `project: export the Windows build and record it`.

## Handoff notes for Astra

None, unless an Astra-owned asset fails in the export. That is reported with the path and the exact error.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/delivery/issues/01-export-and-run-outside-editor.md, then implement that ticket. Use /run to verify the exported build boots to the main menu and plays Stage 1 outside the editor. Finish with its Definition of Done and commit.
```
