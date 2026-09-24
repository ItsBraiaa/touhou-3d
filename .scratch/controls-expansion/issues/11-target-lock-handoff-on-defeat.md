# F16-11 target-lock-handoff-on-defeat

Status: done
Type: adapter
Owner: Claude
Lane: path
Depends on: F16-04, F16-09
Parallel-safe: yes (targeting and selector only)

## Request (the user, 2026-09-24)

Automatic Target Lock handoff when the currently locked enemy or boss dies:
- a surviving visible, in-range target is chosen by the existing rules, and the normal target change is emitted, so the camera, HUD and weapon follow;
- with no eligible target, the lock clears and `CameraRig.request_recenter()` runs;
- an unrelated death never steals the lock, and a manual unlock never reacquires;
- actors leave `targetable` before their defeat signal, while their Death clip plays;
- range loss and other lock changes are unchanged.

Follow-up decision from the user: skip the recenter while a boss's Death clip plays.

## Design

- `TargetSelector.select_successor(candidates)`: visible and in range, nearest the screen center, nearer distance on a tie, no screen radius.
- `Targeting` watches only the locked target's `defeated` signal (reconnected on every lock change), records the id, and hands off on the next physics tick that finds the lock invalid, unless a manual press counts that tick.
- No successor: release plus `lock_lost_to_defeat`, which `PlayerController` connects to `CameraRig.request_recenter`. The signal is not emitted when the defeated lock is a `BossController` still in the tree (its Death clip is playing).

## Files

`scripts/player/target_selector.gd`, `scripts/player/targeting.gd`, `scripts/player/player_controller.gd` (one connection); `docs/engineering/player-flight.md` (Targeting contract), `docs/validation/controls-expansion.md` (new F16-11 section), `docs/engineering/ROADMAP.md`, `docs/HANDOFF_LOG.md`.

## Verification (no tests)

Headless in-game driver of `main.tscn` outside the repo: see `docs/validation/controls-expansion.md`, "Target Lock handoff (F16-11, path)". `tools/lane.ps1 land` is the gate.

## Outcome

Done 2026-09-24 by lane path (implementation by a workflow agent, boss rule, docs and landing by the orchestrator). Every requested case passed in the headless game run, and all three bosses keep their Death clip in view. PLANEJAMENTO's Target Lock sentence still says a lock ends on death; the rule change is announced to Astra in the handoff entry instead of editing her text. The physical play check is owed to the user's pass.
