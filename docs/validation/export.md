# Windows export, run outside the editor — F14-01

2026-09-24. The release build of `dev-01` `8061d77` (every sprint ticket through F13-04, plus F14-01's swap step), exported with the preset "Windows Desktop" and run from a folder outside the repository on the development PC. It boots, plays both stages and quits cleanly. It printed no `ERROR:`, `SCRIPT ERROR` or `WARNING:` line in any run. Contract: [engineering/project.md "Export"](../engineering/project.md#export).

## 1. Build

| Item | Value |
| --- | --- |
| Commit | `dev-01` `8061d77`, with this ticket's `export_presets.cfg` change (`debug/export_console_wrapper` 1 → 2). `tools/test.ps1` on it: `TESTS_PASSED 225`, `TESTS_FAILED 0`, no `SCRIPT ERROR` |
| Import | `tools/godot.ps1 --headless --path . --import` once first, so the export does not reimport (path's pre-flight saw 39 editor-dialog `ERROR:` lines on an export straight after a sync) |
| Export | `tools/godot.ps1 --headless --path . --export-release "Windows Desktop" build/Touhou-3D.exe`: exit 0 in 5 s, no `ERROR:` or `WARNING:` line |
| Output | `build/Touhou-3D.exe` 129,258,616 bytes (the 109,268,480-byte template plus the embedded pack, about 20 MB); `build/Touhou-3D.console.exe` 91,136 bytes, the console wrapper, which now ships with the release export too. Both are git-ignored |
| Templates | `%APPDATA%\Godot\export_templates\4.7.2.stable\`, installed by the user on 2026-09-23 |

## 2. Environment

| Item | Value |
| --- | --- |
| Host | The development PC: Windows 11 Pro 10.0.26200, AMD Radeon RX 9070 XT |
| Renderer | `D3D12 12_0 - Forward+ - Using Device #0: AMD - AMD Radeon RX 9070 XT`. No fallback message, in every windowed run |
| V-Sync | `Requested V-Sync mode: Enabled - FPS will likely be capped to the monitor refresh rate.` Godot reports a 120 Hz screen, yet V-Sync capped every run at 60 FPS. The cause (a driver frame cap or the display) was not investigated |
| Window | 1280 × 720, windowed (mode 0), viewport 1280 × 720. These come from the real `user://settings.cfg` (`window_mode=0`, `resolution=Vector2i(1280, 720)`), which the build shares with source runs; no setting was changed |
| `user://` | `%APPDATA%\Godot\app_userdata\Touhou-3D` |

## 3. Runs

Every run used a copy of `build/` in a scratch folder outside the repository, started as `Touhou-3D.console.exe --print-fps`.

1. **Headless boot**, `--headless --quit-after 300`: exit 0; output only the engine banner.
2. **Windowed boot**, `--print-fps --quit-after 600`: the main menu at 60 FPS (one 59), and the renderer lines above.
3. **Driven runs.** The release build ignores `--script` (path's pre-flight, and a debug export does too). So a scratch autoload, kept in the session scratchpad and not in the repo, was loaded through an `override.cfg` beside the exe (`[autoload] F14Drive="*<absolute path>.gd"`). Godot documents that file for exported projects, and it worked. The autoload waits for `Main`, then drives the real Session:
   - **Walk**, windowed and headless.
     - Key events went through `Input.parse_input_event`, so the build's own input map read them: ↓, Enter, W, J and Esc.
     - A route segment it did not measure was cleared by direct damage, as in F11-03.
     - A Defeat was forced through `CombatState`.
   - **Boss benches**, windowed.
     - Direct Stage, with the route before the boss cleared by direct damage.
     - The ship waits at the boss Encounter's entry volume, Target Locked, firing (`fire` held).
     - It is kept alive by `CombatState.refill()` and `ProjectileSystem.set_player_invulnerable(true)` every frame.
     - Each Phase runs 15 s, sampled once a second, then ends by direct damage.

   The window kept focus in every sample. Driven input is not a physical pass (ENGINEERING_BRIEF Section 8).

## 4. Walk (keyboard events, windowed; repeated headless)

| Step | Result |
| --- | --- |
| Boot | Main menu, focus on Iniciar |
| ↓ to Selecionar fase, Enter | Stage Select, focus on Floresta das Lanternas |
| Enter | Direct Stage 1 loads (`stage_01.tscn`) with the HUD |
| W and J held 5 s in S1-01 | The ship flew z 20 → −40; up to 11 player shots live |
| S1-02, its Waves left firing for 8 s, then cleared | Completed |
| From z −118, W for 3 s | Flew past `Gate_S1_02` (z −140) to z −154 |
| Esc | Pause, focus on Continuar |
| ↓ to Opções, Enter | Options over Pause |
| Esc, Esc | Back to Pause with Opções focused, then resumed |
| Forced Defeat | Defeat, focus on Tentar novamente |
| Enter | Play resumes at 100 Health |
| Esc, ↓ to Voltar ao menu, Enter | Main menu |
| ↓ to Sair, Enter | The game quit itself, exit code 0 |

`WALK_OK`, 0 failures, in both runs. No Checkpoint had been reached, so Tentar novamente restarted Stage 1 from its start.

## 5. FPS readings (release build, 1280 × 720, V-Sync on)

`min` is the lowest one-second sample. "Hostile" and "player" are the peak live Projectile counts from `ProjectileSystem.count`. "Worst frame" is the longest single frame in the window.

| Where | Min | Mean | Samples | Peak hostile | Peak player | Worst frame |
| --- | --- | --- | --- | --- | --- | --- |
| Main menu (`--print-fps`) | 59 | 59.9 | 8 | 0 | 0 | — |
| S1-01, flying and firing | 60 | 60.0 | 5 | 0 | 11 | 17.9 ms |
| S1-02, its Waves firing | 59 | 59.9 | 8 | 81 | 12 | 16.7 ms |
| S1-07 Lantern Guardian, Phase 1 | 59 | 59.9 | 15 | 106 | 9 | 26.3 ms |
| S1-07 Phase 2 | 59 | 59.9 | 15 | 38 | 9 | 27.3 ms |
| S1-07 Phase 3 | 59 | 59.9 | 15 | 106 | 9 | 28.0 ms |
| S2-07 Storm Guardian, Phase 1 | 59 | 59.9 | 15 | 43 | 3 | 27.9 ms |
| S2-07 Phase 2 | 59 | 59.9 | 15 | 93 | 3 | 30.6 ms |
| S2-07 Phase 3 | 59 | 59.9 | 15 | 72 | 3 | 31.2 ms |

**Headroom, with V-Sync off** (the same Storm Guardian bench, with V-Sync turned off by the autoload through `DisplayServer.window_set_vsync_mode`): the lowest one-second sample was 1192 FPS in Phase 1, 1171 in Phase 2 (at 54 hostile) and 1247 in Phase 3. The means were 1264, 1214 and 1275, and the worst frame 8.3 ms.

Reading: the 60 FPS target (PLANEJAMENTO Section 12) holds on this PC in both stages' boss fights, with large headroom. The worst frames of 26 to 31 ms are single-frame hitches, and a one-second sample never fell below 59. By Projectile count the densest fight is the Lantern Guardian (106 hostile), not the Storm Guardian (93). On the presentation computer, this is **not verified** (Section 7).

An earlier trial build without F13-04, windowed, gave the same picture: Storm Guardian samples of 56 to 59 in Phase 1 (a 67.8 ms hitch as the boss spawned), then 58 and 59.

## 6. What the build printed

- Export: no `ERROR:` or `WARNING:` line.
- Every run of the final build: the engine banner, the two renderer and V-Sync lines, `Project FPS` lines, and the Session's `STAGE_RESULT` lines. No `ERROR:`, `SCRIPT ERROR` or `WARNING:`. Path's pre-flight saw two `Image format RGB8 not supported` warnings for the enemy atlases; they no longer appear.
- On the trial build before F13-04, a headless walk printed, after Sair, `WARNING: 6 ObjectDB instances were leaked at exit` and `ERROR: 2 resources still in use at exit`. The verbose run named them: two `AudioStreamPlaybackOggVorbis` of `assets/audio/sfx/interface/confirmation_001.ogg`, the `ui_accept` sound, still playing when Sair quit the game in the same frame. It is a quit-time race: the sound was still playing when the tree was torn down. Two walks of the final build print nothing at exit, after F13-04 retuned the limiter (the `ui_accept` interval went from 0.05 to 0.15 s). It is not export-only, only the console exe shows it, and it was left as it is (an open issue in `project.md`).
- The shrine: after the Lantern Guardian's last Phase, `Environment/ShrineLighting` was playing `corrupted_to_calm` under Results (the D-07 swap).

## 7. Not verified

- **A physical keyboard and gamepad on the build.** The walk used key events injected in-process; the human pass owes this (SPRINT "Human steps").
- **FPS in a boss fight flown by a person.** The benches parked the ship at the entry volume and kept it alive, so the fight's density is the boss's own pattern output, not a person's dodging.
- **The presentation computer**, below.

## Presentation computer protocol

Not verified: nobody has run it yet.

1. Copy `Touhou-3D.exe` and `Touhou-3D.console.exe` from `build/` to any folder on that computer. Nothing else is needed: the pack is embedded.
2. Open a Command Prompt there and run `Touhou-3D.console.exe --print-fps > run.log 2>&1`. The console exe writes the engine's output, which the GUI exe does not.
3. Play:
   - Selecionar fase, then Floresta das Lanternas, through S1-02 and, if possible, the Lantern Guardian;
   - then Montanha da Tempestade to the Storm Guardian;
   - quit with Sair.
4. From `run.log`, record:
   - the startup line (`D3D12 …` or `Vulkan …`, the GPU, and any fallback message);
   - the V-Sync line;
   - the window resolution, shown under Opções > Resolução;
   - the lowest `Project FPS` value in S1-01, in S1-02, and in each boss fight;
   - every `ERROR:` or `WARNING:` line.
5. Add the results as a new section on this page. If the build will not start, run `Touhou-3D.console.exe --rendering-driver vulkan` once, and record which driver works.

## Package — F14-02 part 2

`tools/package.ps1` stages every tracked file into `Touhou-3D/project/`, adds the two
executables under `Touhou-3D/game/` and a Portuguese `LEIA-ME.txt`, writes
`build/package/Touhou-3D-<yyyyMMdd>.zip`, then extracts the zip to `build/package/verify/`
and checks the copy independently. The zip is git-ignored and never committed.

- **Re-export.** F14-02 part 2 reran F14-01's command from the synced tree
  (`tools/test.ps1` → `--import` → `--export-release "Windows Desktop" build/Touhou-3D.exe`):
  exit 0, no `ERROR:` or `WARNING:` line, `Touhou-3D.exe` 129,258,616 bytes and
  `Touhou-3D.console.exe` 91,136 bytes — byte-identical to the F14-01 build above. The
  build/ folder must exist first: a fresh worktree needs `New-Item -ItemType Directory build`,
  or the export fails with "the export path does not exist".
- **Command:** `powershell -NoProfile -ExecutionPolicy Bypass -File tools\package.ps1`.
- **Refusals, run once each:** a missing executable exits 2
  (`package: executable 'build\no_such_exe.exe' is missing; run F14-01's export first.`); a
  dirty tree exits 3 (`package: working tree is dirty: tools/package.ps1`).
- **Fix in this ticket.** The part-1 script archived `build/package/Touhou-3D/*`, so the zip
  held `project/`, `game/` and `LEIA-ME.txt` at its root, and the `--import` check on
  `verify/Touhou-3D/project` failed with `Invalid project path specified`. It now archives the
  `Touhou-3D` folder itself, so the zip has the documented `Touhou-3D/` root. No gameplay,
  scene or content file changed.
- **Second fix.** Part 1 captured the child processes' output with `2>&1` while
  `$ErrorActionPreference` was `Stop`, so godot.ps1's `Using Godot:` line on stderr aborted the
  verify step. The capture now scopes the preference to `Continue`, so a child's stderr is
  read, not thrown.
- **Output** (clean tree at this ticket's package commit, `8ee9217`):

  ```
  PACKAGE_ARCHIVE 79756718 bytes, 743 staged files: C:\Users\Braia\Documents\touhou-3d-oc-b\build\package\Touhou-3D-20260924.zip
  PACKAGE_OK
  ```

  The three checks on the extracted copy passed: the project `--import` exited 0; the extracted
  `tests/run_tests.gd` exited 0 with `TESTS_PASSED 225`, `TESTS_FAILED 0` and no `SCRIPT ERROR`;
  and `game/Touhou-3D.console.exe --headless --quit-after 300` exited 0 with only the engine
  banner, no `ERROR:` line. `PACKAGE_OK`, exit 0. This record's own commit changes this page,
  so the final repackage after it differs by a few hundred bytes; `PACKAGE_OK` and the
  743-file count are stable.
