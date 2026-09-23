# Sprint to 2026-09-24: four lanes, four worktrees

Planned 2026-09-23 by Claude acting as product owner, engineer and game-design architect. It supersedes the cut decisions in [ROADMAP.md](ROADMAP.md) of the same day. Every lane session reads this page before its ticket; tickets and their `Depends on` lines stay authoritative.

## Product decisions

- **Reinstated, reduced but real.** These are back in scope:
  - F3 Settings (four tickets);
  - F13 Audio (three tickets plus D-01);
  - Stage 2 gameplay (F12-04 to F12-07, with F9-03 Seals promoted).

  Two of the cuts broke assignment requirements (PLANEJAMENTO Section 2): sound effects, and a stage of at least five minutes, which is Stage 2.
- **F6-01 is folded into F6-02.** MultiMesh is the default renderer, and F6-02 carries the benchmark. With four lanes running, no FPS measurement is ever "alone".
- **Astra's design work runs in lane `sol`.** The seven D tickets in `.scratch/design-sprint/` turn every open "Request to Astra" into a deliverable with a consumer ticket.
- **Scope changes are still the user's call.** The fallback order in "Checkpoints" below is a proposal the user confirms at the checkpoint.
- **This page supersedes older "cut" wording.** Tickets written before the sprint may still say F3, F13 or F12-04 is "cut", in their Out of scope, Handoff or acceptance lines. Treat every such line as "reinstated, done by the ticket named in this page". An acceptance item is never "not verified (cut)" unless the user cuts it at a checkpoint; a ticket that has not landed by delivery is "not verified (not landed)".
- **Late asset swaps.** A consumer ticket never waits for a D asset:
  - It uses the D asset if it is already on the integration branch, and otherwise ships its dev placeholder and says so in its handoff entry ("swap pending: D-0N").
  - F14-01 starts by applying every pending swap, and every value Astra asks trunk to set in a trunk-only file (D-05's weapon and Bomb values in `player_ship.tscn`, D-07's shrine exports on Stage 1), as one `[shared]` commit.

## Lanes

| Lane | Tool | Worktree | Branch | Owns |
| --- | --- | --- | --- | --- |
| `trunk` | Claude Code, Opus 5.5, ultracode | `C:\Users\Braia\Documents\touhou-3d-trunk` | `lane/trunk` | Every edit to `scripts/session/game_session.gd`, `scenes/main.tscn`, `scenes/player/player_ship.tscn`, `project.godot`, `export_presets.cfg`, and the script wiring inside `scenes/stages/stage_01.tscn` |
| `sol` | Codex, GPT Sol, as Astra | `C:\Users\Braia\Documents\touhou-3d-sol` | `lane/sol` | The D tickets (Astra's scenes, art, audio assets, content tuning), `scenes/stages/stage_02.tscn` wiring (F12-05), the actor and boss adapter tickets in its queue |
| `glm-a` | OpenCode, GLM 5.3, session A | `C:\Users\Braia\Documents\touhou-3d-glm-a` | `lane/glm-a` | Projectile, pattern, enemy, boss and audio cores; the audio adapter (standalone); Seals; contract and time tests |
| `glm-b` | OpenCode, GLM 5.3, session B | `C:\Users\Braia\Documents\touhou-3d-glm-b` | `lane/glm-b` | Definitions, EncounterMachine, Snapshot, content drafts, Settings, Pickups, packaging |

Inside any ticket, its **Files** section is the boundary. If a ticket seems to need a file outside it, it stops and says so in its Outcome; it does not edit the file.

## Git worktrees: one agent, one worktree, one branch

No two agents ever share a working tree or a branch. That is what keeps them from breaking each other's builds and test runs.

1. **The primary tree is only a landing target.** `C:\Users\Braia\Documents\touhou-3d` keeps the integration branch checked out (`dev-01` today; `tools/lane.ps1` reads whatever branch is checked out there). It stays clean: no agent opens a session, edits or commits there during the sprint. Only `tools/lane.ps1 land` moves it, and only by fast-forward.
2. **Create a lane once.** From any tree, run `tools/lane.ps1 setup <lane>`. It creates `C:\Users\Braia\Documents\touhou-3d-<lane>` on branch `lane/<lane>`, from the integration branch. Open that lane's tool in that folder and nowhere else. Never check out another lane's branch.
3. **First test run.** A new worktree has no `.godot/` cache, so the first `tools/test.ps1` imports the project (about a minute).
4. **Every ticket follows the same loop:**
   1. `tools/lane.ps1 sync` merges the latest integration branch into your lane.
   2. `tools/lane.ps1 status <ticket path>` shows each dependency's Status as landed. Start only when all are `done`.
   3. Implement and test, then commit on your lane branch (message rules in [CONVENTIONS.md](CONVENTIONS.md) "Git").
   4. `tools/lane.ps1 land` merges the integration branch in again, runs `tools/test.ps1` (a red run or any `SCRIPT ERROR` line stops it), then fast-forwards the primary tree to your branch. If another lane landed first, it retries.
5. **Conflicts.**
   - `docs/HANDOFF_LOG.md` and `docs/engineering/README.md` merge with the union driver (`.gitattributes`), so two lanes adding entries never conflict. The newest-first order may interleave; do not reorder earlier entries.
   - Any other conflict means two lanes touched one file. Resolve it in your lane branch, never in the primary tree, and name the file in your handoff entry so the plan gets fixed.
6. **No pushes, no rebases, no amends.** The user pushes and opens pull requests when they choose.

## Shared files

- **`docs/engineering/ROADMAP.md`:** a lane edits only its own ticket rows.
- **`docs/GUIDE.md` Section 6:** only the rows for the scripts your ticket touches.
- **`docs/HANDOFF_LOG.md`:** one entry per ticket, newest first, headed with your lane (`— Claude (trunk) —`, `— Astra (sol) —`, `— GLM (glm-a) —`).
- **`scenes/stages/stage_01.tscn`:** trunk wires it in F10-01, F10-02 and F12-03. Astra's D-07 shrine-lighting clip waits until F12-03 has landed.
- **`scenes/stages/stage_02.tscn`:** only F12-05 attaches scripts to it.
- **Other scenes:** Astra's other deliverables are new sub-scenes (`scenes/enemies/*.tscn`, `scenes/combat/visuals/*.tscn`) that Claude's prefabs instance, not edits of integrated scenes.
- **Files two lanes edit without a dependency between them.** For each pair, run `tools/lane.ps1 sync` right before starting and keep your additions in separate functions with one-line call sites. Whoever lands second merges both.

  | File | Tickets |
  | --- | --- |
  | `scripts/progression/stage_director.gd` | trunk F10-01 to F10-03, F12-03, F13-03; sol F12-05 |
  | `scripts/ui/menu_controller.gd` and `tests/scene/test_menu_registry_contract.gd` | glm-b F3-03; trunk F11-01 |
  | `scripts/enemies/enemy_actor.gd` | sol F9-02, F12-05 (same lane, ordered) |
  | `tests/scene/test_stage_02_contract.gd` (Astra's) | sol F12-05 changes one assertion and logs it |

  `scripts/ui/interface.gd` is ordered by dependencies (F4-02, then F3-02, then F3-03).
- **`user://` is shared by all four worktrees,** because Godot keys it by project name. A test that writes under `user://` uses a per-process file name, for example `"user://test_settings_%d.cfg" % OS.get_process_id()`. Nothing but the real game writes `user://settings.cfg`.
- **D tickets** update their own ROADMAP row and add one "Received from Astra" row.

## Lane queues

Run top to bottom. When the next ticket's dependencies are not done, take the first later ticket in your own queue whose dependencies are. If none is ready, read ahead (the next ticket and its sources) and check again in ten minutes. Never write code against an interface that has not landed. If the rest of your queue waits on another lane for more than an hour, stop the session and report which ticket is blocked, so the user can close it or reassign work instead of paying for idle polling.

**trunk** (the critical path):

| # | Ticket | Depends on |
| --- | --- | --- |
| 1 | F5-01 field-core-spawn-move-cull | F0-02 |
| 2 | F4-02 hud-binding-and-target-marker | F4-01, F2-04 |
| 3 | F6-02 projectile-system-adapter (with the F6-01 benchmark) | F5-03 |
| 4 | F6-03 weapon-model-and-player-weapon | F6-02, F4-01, F4-02 |
| 5 | F7-01 hit-to-combat-state-and-defeat | F6-02, F4-02 |
| 6 | F7-02 bomb-clear-and-invulnerability | F7-01, F6-03 |
| 7 | F10-01 stage-director-adapter | F8-02, F8-04, F9-02, F7-03, F4-03 |
| 8 | F10-02 gate-and-checkpoint-adapters | F10-01, F8-03, F7-02 |
| 9 | F10-03 retry-restart-flow | F10-02, F7-01 |
| 10 | F3-04 settings-to-camera-wiring | F10-03, F3-02 |
| 11 | F11-01 defeat-results-retry-restart-screens | F10-03 |
| 12 | F11-02 campaign-continuation-and-direct-stage | F11-01 |
| 13 | F12-03 lantern-guardian-in-s1-07 | F12-02, F10-03 |
| 14 | F13-03 audio-event-wiring | F13-02, F12-03, F7-03, D-01 |
| 15 | F14-01 export-and-run-outside-editor | F11-03, F12-03, export templates |

**glm-a:**

| # | Ticket | Depends on |
| --- | --- | --- |
| 1 | F5-02 core-hit-sweep-and-graze-rules | F5-01 |
| 2 | F5-03 bomb-phase-clears-and-hit-spheres | F5-02 |
| 3 | F5-04 pattern-emitter-core | F5-01 |
| 4 | F9-01 enemy-model-core | F5-04 |
| 5 | F12-01 boss-machine-core | F5-04 |
| 6 | F13-01 audio-limiter-core | F0-02 |
| 7 | F13-02 audio-controller-adapter (not attached) | F13-01 |
| 8 | F9-03 seal-and-guard-rules | F9-02 |
| 9 | F10-04 stage-01-contract-smoke-test | F8-04 |
| 10 | F11-03 active-and-clear-time-verification | F11-02 |

**glm-b:**

| # | Ticket | Depends on |
| --- | --- | --- |
| 1 | F8-01 definition-schemas-and-content-validation | F0-02 |
| 2 | F8-02 encounter-machine-core | F8-01 |
| 3 | F8-04 stage-01-content-draft | F8-01 |
| 4 | F8-03 snapshot-capture-restore | F8-02, F4-01 |
| 5 | F12-04 stage-02-content-draft (early, to unblock F12-05) | F8-01, F9-01 |
| 6 | F3-01 settings-core-and-configfile | F0-02 |
| 7 | F3-02 options-screen-binding | F3-01, F4-02 |
| 8 | F3-03 input-device-mode-and-controller-disconnect | F3-02 |
| 9 | F7-03 pickup-adapter-and-rewards | F7-01 |
| 10 | F14-02 package-and-acceptance-record | F14-01 |

**sol** (Astra):

| # | Ticket | Depends on |
| --- | --- | --- |
| 1 | D-01 sfx-selection-and-import | none |
| 2 | D-02 combat-visuals | none |
| 2b | D-07 Part B only: the written rulings, as their own commit and land (the ticket stays `doing` until Parts A and C). Early because F5-02 and F12-01 pin readings those rulings may change | none |
| 3 | F4-03 boss-panel-and-attack-cue-api | F4-02 |
| 4 | D-03 lantern-guardian-scene | none |
| 5 | F9-02 dev-prefabs-and-enemy-actor | F9-01, F6-02 |
| 6 | F12-02 boss-controller-adapter | F12-01, F9-02, F4-03 |
| 7 | D-04 stage-2-boss-scenes | none |
| 8 | D-05 stage-1-tuning-and-pacing | F8-04 |
| 9 | F12-05 stage-02-director-integration | F10-03, F9-03, F12-04 |
| 10 | F12-06 tempest-sentinel-miniboss | F12-05, F12-02, F12-03, D-04 |
| 11 | F12-07 storm-guardian | F12-06, D-04 |
| 12 | D-06 stage-2-content-review | F12-04 |
| 13 | D-07 shrine-lighting-and-boss-rulings | F12-03 |

Ticket files: `.scratch/<feature>/issues/NN-slug.md`, found by ID with `tools/lane.ps1 status <ID>`. Folders: F3 `settings`, F4 `combat-hud`, F5 `projectile-field`, F6 `weapon-rendering`, F7 `damage-pickups`, F8 `progression-core`, F9 `enemies`, F10 `stage-director`, F11 `run-flow`, F12 `bosses`, F13 `audio`, F14 `delivery`, D `design-sprint`.

## Kickoff prompts

Paste one into a fresh session of the right tool, opened in the lane's worktree. A lane session chains tickets: it commits and lands after every ticket and moves to the next. Start a fresh session with the same prompt after four tickets or when the context is heavy.

**trunk: Claude Code desktop, Opus 5.5, ultracode on,** opened in `touhou-3d-trunk`:

```
You are lane trunk of docs/engineering/SPRINT.md. If this folder is not a worktree yet, run tools/lane.ps1 setup trunk from C:\Users\Braia\Documents\touhou-3d and reopen here. Read CLAUDE.md, docs/engineering/SPRINT.md and docs/engineering/ROADMAP.md. Then work your queue in order, one ticket at a time: tools/lane.ps1 sync; tools/lane.ps1 status <ticket path>; implement the ticket with a workflow (one implementer, then parallel adversarial reviewers for correctness, conventions and the ticket's Files boundary; fix what they confirm); finish its Definition of Done; commit on lane/trunk; tools/lane.ps1 land. Then the next ticket. Stop after four tickets and report what landed.
```

**sol: Codex, GPT Sol,** opened in `touhou-3d-sol`:

```
You are Astra, lane sol of docs/engineering/SPRINT.md. If this folder is not a worktree yet, run tools/lane.ps1 setup sol from C:\Users\Braia\Documents\touhou-3d and reopen here. Read AGENTS.md, docs/engineering/SPRINT.md, docs/engineering/CONVENTIONS.md and docs/GUIDE.md Sections 3 and 5. Work your queue in order, one ticket at a time: tools/lane.ps1 sync; tools/lane.ps1 status <ticket path>; deliver the ticket inside its Files boundary (D tickets are design deliverables; F tickets are code: test-first, strict static typing, tools/test.ps1 green with no SCRIPT ERROR); finish its Definition of Done or Handoff section; commit on lane/sol; tools/lane.ps1 land. Then the next ticket. Stop after four tickets and report what landed.
```

**glm-a and glm-b: OpenCode, GLM 5.3,** one session per lane, opened in `touhou-3d-glm-a` or `touhou-3d-glm-b`:

```
You are lane glm-a of docs/engineering/SPRINT.md (use glm-b for the other session). If this folder is not a worktree yet, run tools/lane.ps1 setup glm-a from C:\Users\Braia\Documents\touhou-3d and reopen here. Read AGENTS.md, docs/engineering/SPRINT.md and docs/engineering/CONVENTIONS.md. Work your queue in order, one ticket at a time: tools/lane.ps1 sync; tools/lane.ps1 status <ticket path>; read only the ticket's "Read first" list; write the tests first, then the code, with strict static typing (warnings are errors); run tools/test.ps1 until green with no SCRIPT ERROR; finish the ticket's Definition of Done; commit on lane/glm-a with the ticket's commit message; tools/lane.ps1 land. Then the next ticket. Skill names in a ticket's kickoff prompt (/mattpocock-skills:tdd, /run) are Claude-only: follow their intent (test-first; verify headless). Stop after four tickets and report what landed.
```

## Checkpoints (T0 = the four lanes start)

| When | Landed by then | What works |
| --- | --- | --- |
| T0 + 3 h | F5-01 to F5-03, F4-02, F8-01, F8-02, D-01 | Field core; HUD bound |
| T0 + 7 h | F6-02, F6-03, F7-01, F5-04, F9-01, F9-02, F8-03, F8-04, F3-01, F3-02, F13-01, F4-03 | Shooting and damage in the arena; Options apply |
| T0 + 12 h | F7-02, F7-03, F10-01 to F10-03, F12-01, F12-02, F13-02, F9-03 | Stage 1 playable with checkpoints and Retry |
| T0 + 16 h | F11-01, F11-02, F12-03, F13-03, F3-03, F3-04, F12-04, F12-05 | Stage 1 complete with sound; Stage 2 route live |
| T0 + 19 h | F12-06, F12-07, F11-03, F14-01, D-05 to D-07 | Both stages; export |
| Last | F14-02 and the human pass | Package and acceptance record |

If a checkpoint slips by more than an hour, this is the proposed cut order. The user confirms each step.
1. Music (keep SFX).
2. F3-03's prompt icons (keep the disconnect pause).
3. The Storm Guardian's final art (fight the dev boss).
4. Stage 2 entirely (F12-05 to F12-07), with D-05's Stage 1 pacing raised to five minutes.

## Human steps

- **Export templates.** Install the Godot 4.7.2 export templates (editor: Editor → Manage Export Templates, about 1 GB) before F14-01; `%APPDATA%\Godot\export_templates\` is empty today.
- **Playtest.** A person plays the physical keyboard and DualSense pass and the clear-time measurement from F11-03's protocol.
- **Publishing.** Push and open pull requests when you choose; the lanes never push.

## Token and time efficiency

- One session per lane runs up to four tickets. The start-up reading (CLAUDE.md or AGENTS.md, this page, CONVENTIONS) happens once per session, not once per ticket.
- Read only a ticket's "Read first" list and the code it names. Each spec's "Cross-feature contracts" already pins the names shared across lanes.
- Tests stay headless. Only F6-02's benchmark, F14-01 and the human pass run windowed.
- The trunk lane spends its extra budget on review, not on reading: an implementer plus parallel reviewers per ticket, because every other lane waits on trunk.
