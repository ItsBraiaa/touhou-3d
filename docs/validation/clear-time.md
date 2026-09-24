# Active Time and Clear Time — F11-03

2026-09-24. This page has two parts:
- the time rules, checked through the real Session by a scripted headless pass;
- the manual protocol for the academic duration check, with its record.

Nothing on this page is a play-duration measurement yet. The Stage 1 and Stage 2 clear times need a person to play, so they are owed by the human pass (SPRINT.md "Human steps"). Contract: [engineering/run-flow.md "Time accounting evidence"](../engineering/run-flow.md#time-accounting-evidence).

## Rules under check

- **Active Time** counts only unpaused gameplay (CONVENTIONS "Time and randomness"). Pause, Options from Pause, Defeat, Results and the menus add nothing.
- **Clear Time** is the committed time through the last Checkpoint plus the current Attempt (STAGE_DESIGN "Time and score integrity"). A Retry rolls back the failed segment, a Restart zeroes it, and failed Attempts cannot inflate it (ENGINEERING_BRIEF 4.H).
- **Per stage.** Each stage of a Campaign accounts for its own Clear Time.
- **Uninterrupted clear.** A clear whose `STAGE_RESULT` line ends in `attempt=1`: no Retry and no Restart. Its Clear Time is its total Active Time.

## 1. Environment

| Item | Value |
| --- | --- |
| Host | This Windows 11 Pro machine (10.0.26200), the development PC |
| Date | 2026-09-24 |
| Engine | Godot 4.7.2.stable.official.ed1daf0bf, console binary, `--headless`, physics 60 Hz |
| Build | Source tree, not an exported build: `lane/trunk` at `dev-01` `f2acaf9`. `game_session.gd` md5 `2d8dea68…`, `run_state.gd` md5 `2bb9beb2…` |
| Input | Scripted only. `pause` and `ui_cancel` went through `Viewport.push_input`, menu buttons through their `pressed` signal, and the controller disconnect through `Input.joy_connection_changed`. The route used teleports and direct damage. No physical keyboard or gamepad was used, and a simulated event is not a physical pass (ENGINEERING_BRIEF Section 8). |

## 2. Driven pass: the time rules (scripted, headless)

A throwaway `SceneTree` script, kept in the session scratchpad and not in the repo, instanced `scenes/main.tscn` and drove the real Session.
- **The probe.** A node running just before `Main` in every physics step counted the ticks in which the Session may add Active Time: the tree running, the Run `IN_STAGE` and its pause flag clear. Clear Time was compared with that count, to float precision, and with the wall clock.
- **The route.** Stage 1 was flown by teleport through all seven Encounters, with direct damage to the Waves and to each of the Lantern Guardian's three Phases. The clear came from the Director's own `stage_cleared`.
- **Survival.** The script refilled the ship's `CombatState` at CP1-A, at CP1-B and before each Phase, so a scripted run never died by accident. The refill touches no `RunState` value.
- **Short checks.** Checks that only need a clear used `StageDirector.stage_cleared.emit()`, which reaches `complete_stage()` deferred, as a real clear does.

Two runs passed (`TA_OK`), the second after the Retry scenario gained a kill and a Bomb. Neither printed `SCRIPT ERROR`, `ERROR:` or `WARNING:`.

| Rule | Scenario | Measured |
| --- | --- | --- |
| Active Time counts unpaused play | 60 ticks in Direct Stage 1 | +1.0000 s, 60 counted ticks |
| Pause adds nothing | 60 ticks under Pause | +0.0000 s |
| Options from Pause adds nothing | 60 ticks under Options, 30 more after Back to Pause | +0.0000 s; then Continuar and 60 ticks give +1.0000 s |
| A controller disconnect pause adds nothing | `joy_connection_changed(0, false)` over the HUD opens Pause, then 60 ticks | +0.0000 s |
| Defeat adds nothing | 60 ticks under Defeat | +0.0000 s (Clear Time stays 2.1000 s) |
| Results adds nothing | 60 ticks under Results, then 60 under Credits from Results | +0.0000 s both; `TimeValue` unchanged |
| The menus add nothing | 60 ticks each on the main menu, Stage Select and Options, with the Run `RUN_ENDED` | 0 of 180 ticks counted; a new Direct Stage 1 starts at 0.0000 s |
| Restart zeroes Clear Time | Reiniciar fase at 1.0000 s, before any Checkpoint | 0.0000 s, attempt 2 |
| Restart discards the Checkpoint's time | Reiniciar fase at 2.2000 s, with 2.1000 s committed at CP1-A | 0.0000 s, committed 0.0000 s; a later Defeat offers `Início da fase` and its Retry gives 0.0000 s |
| Retry before a Checkpoint is Restart | Tentar novamente at 2.1000 s | 0.0000 s, attempt 2 |
| Retry rolls back the failed segment | Commit 2.0667 s at CP1-A. The failed segment: kill S1-05's first Wave, use a Bomb, 60 ticks, 60 paused, 60 more, die, 60 under Defeat | Clear Time 4.4833 → 2.0667 s (2.4167 s dropped). Score 1100 → 1400 → 1100 and bombs used 0 → 1 → 0 roll back too |
| Retry resumes from the committed time | 90 ticks after that Retry | 3.5667 s, the committed 2.0667 + 1.5000 s |
| Failed Attempts cannot inflate Clear Time | Three defeats before CP1-A (4.53 s of failed play), then 120 ticks and a clear | 2.0167 s, which is 121 ticks: the last Attempt plus the tick of the clear. `attempt=4` |
| Each Campaign stage has its own Clear Time | Campaign Stage 1 cleared at 1.5167 s with score 300, then Continuar | Stage 2 starts at 0.0000 s with score 300 carried, and reads 0.9833 s after 60 ticks |
| A Restart in Campaign Stage 2 goes to Stage 2's entry | Reiniciar fase, then 45 ticks and the clear | 0.0000 s with score 300 (the carried entry); final clear 0.7500 s |
| An uninterrupted clear's Clear Time is its total Active Time | Direct Stage 1 through the real route and the Lantern Guardian, no pause or death | `attempt=1`, 7.1833 s = 431 counted ticks exactly; the wall clock read 7.16 s |
| Results shows that time | The same clear | `TimeValue` `0:07`, the `M:SS` of 7.1833 s |
| Retry exclusion against a stopwatch | Direct Stage 1 with the failed segment above, then the real route and the boss | `attempt=2`. Results 8.5833 s (`0:08`) = the committed 2.0667 s + 391 ticks after the Retry. The wall clock from stage entry read 12.98 s; the 4.4 s gap is the failed segment, Pause and Defeat |

The `STAGE_RESULT` lines of the second run, in order:

```
STAGE_RESULT stage=stage_01 mode=DIRECT_STAGE clear_time=0.52 score=0 graze=0 bombs=0 attempt=2
STAGE_RESULT stage=stage_01 mode=CAMPAIGN clear_time=1.52 score=300 graze=0 bombs=0 attempt=1
STAGE_RESULT stage=stage_02 mode=CAMPAIGN clear_time=0.75 score=300 graze=0 bombs=0 attempt=2
STAGE_RESULT stage=stage_01 mode=DIRECT_STAGE clear_time=2.02 score=0 graze=0 bombs=0 attempt=4
STAGE_RESULT stage=stage_01 mode=DIRECT_STAGE clear_time=7.18 score=2700 graze=0 bombs=0 attempt=1
STAGE_RESULT stage=stage_01 mode=DIRECT_STAGE clear_time=8.58 score=2700 graze=0 bombs=0 attempt=2
```

The uninterrupted clear and the retried clear both end at score 2700: the failed segment's 300 points were not kept.

**The 7.18 s and 8.58 s are not play durations.** Teleports and instant kills skip the flight and the fights. They show only that Clear Time equals the counted ticks. The wall clock matched Active Time within 0.02 s while nothing was paused, because the game ran its 60 physics ticks per second. On a machine that falls below that rate, Active Time is simulated time and runs slower than a stopwatch.

**No defect found.** `run_state.gd` and `game_session.gd` are unchanged.

## 3. Manual protocol: the academic duration check

### Setup

1. Run from the source tree with the console binary, so the `STAGE_RESULT` lines stay in a log:
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot.ps1 --path . *> "$env:TEMP\clear-time-run.log"
   ```
   From the editor (F5), the lines show in the Output panel. From an exported build (F14-01), use `cmd /c "Touhou-3D.exe > %TEMP%\clear-time-run.log 2>&1"`.
2. Play on a physical keyboard or on the DualSense, and write down which one.
3. Start every measured run from the main menu. **Pause is allowed**: it adds no Active Time, as verified above.
   - **Reiniciar fase** makes the next clear `attempt=2`, so that run no longer counts as uninterrupted. Start again from the menu instead.
   - **Tentar novamente** does the same, and is used only in step 4.
4. For each run, record the Results `Tempo`, the `STAGE_RESULT` line, the starting Power, the bombs used, the Checkpoints retried, and a stopwatch time from the first frame of flight to Results (STAGE_DESIGN "Time and score integrity").

### Steps

2. **Stage 1, uninterrupted efficient clear.**
   - Start: Selecionar fase → Floresta das Lanternas, a Direct Stage at Power 1.
   - Play: no death; use Bombs freely; take every Power reward.
   - Pass: `attempt=1`, with the Results time compared with STAGE_DESIGN's target of about 240 s. D-05's estimate is about 221 s, not measured.
3. **Stage 1, normal clear with Campaign upgrades.**
   - Start: Iniciar (Campaign Stage 1, Power 1).
   - Play: normally, collecting the Power rewards on the route.
   - Record: the Power Level at Results, plus the step 2 record.
4. **Retry exclusion.**
   - Play Stage 1 past CP1-A (Portal Selado), die on purpose, and press Tentar novamente.
   - Clear the stage with the stopwatch running from stage entry to Results.
   - Pass: `attempt=2`, and the Results time falls short of the stopwatch by at least the failed segment plus the Defeat screen. The scripted pass above already shows this (12.98 s on the wall clock against 8.58 s in Results). The human run repeats it at play length.
5. **Stage 2, the five-minute requirement (PLANEJAMENTO Section 2).**
   - **Status: pending F12-07.** F12-06 and F12-07 part 2 have not landed, so Stage 2's miniboss and final boss are still the dev stand-ins, and a clear is not the real stage. F14-02's human pass measures it once they land.
   - Efficient clear: Selecionar fase → Montanha da Tempestade, a Direct Stage 2 at Power 2, uninterrupted, with Bombs and upgrades used well.
   - Normal clear: a Campaign run through Continuar, with Stage 1's Power carried.
   - Pass: the uninterrupted efficient clear reaches at least 300 s (STAGE_DESIGN "Acceptance checks for stage progression"). D-06's estimates are about 336 s efficient and 414 s normal, conditional and not measured.
   - Until then, the requirement is **unmet and unclaimed**. If the measured clear is short, the fix is encounter pacing (Astra's content values), never artificial waiting (ENGINEERING_BRIEF Section 8).

### Record

| Step | Date | Build | Device (physical?) | Mode, starting Power | Checkpoints retried | Bombs used | Results time | `STAGE_RESULT` line | Stopwatch | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2. Stage 1 efficient | — | — | — | Direct Stage 1, Power 1 | none | — | — | — | — | **not measured** (owed by the human pass) |
| 3. Stage 1 normal, Campaign | — | — | — | Campaign Stage 1, Power 1 | none | — | — | — | — | **not measured** (owed by the human pass) |
| 4. Retry exclusion | 2026-09-24 | source, headless | scripted, not physical | Direct Stage 1, Power 1 | CP1-A once | 1 in the failed segment, rolled back | 8.58 s (`0:08`) | `…clear_time=8.58 score=2700 graze=0 bombs=0 attempt=2` | 12.98 s (wall clock) | **rule verified, scripted**; the human run at play length is owed |
| 4. Retry exclusion | — | — | — | — | — | — | — | — | — | **not measured** (owed by the human pass) |
| 5. Stage 2 efficient | — | — | — | Direct Stage 2, Power 2 | none | — | — | — | — | **pending F12-07**, then F14-02's human pass |
| 5. Stage 2 normal, Campaign | — | — | — | Campaign Stage 2, Power carried | none | — | — | — | — | **pending F12-07**, then F14-02's human pass |

## For Astra

This page gives the measured Stage 1 clear times against the 240 s target, once the human pass fills steps 2 and 3. They inform the pacing values in `content/stages/stage_01/*.tres`. F12-03 noted the Lantern Guardian's Phase health at about 2.7× the pacing target (for D-07 Part C), so a played clear may run past D-05's 221 s estimate.
