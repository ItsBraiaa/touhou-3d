# Sprint to 2026-09-24: lanes, worktrees and model routing

Planned 2026-09-23 by Claude acting as product owner, engineer and game-design architect, and re-routed the same evening. The re-route used a sizing of all 48 open tickets (about 6,230 mid-tier agent requests), public evidence on the OpenCode models, and the per-model OpenCode quotas. This page supersedes the cut decisions in [ROADMAP.md](ROADMAP.md) of the same day. Every lane session reads it before its ticket; tickets and their `Depends on` lines stay authoritative.

## Product decisions

- **Reinstated, reduced but real.** These are back in scope:
  - F3 Settings (four tickets);
  - F13 Audio (three tickets plus D-01);
  - Stage 2 gameplay (F12-04 to F12-07, with F9-03 Seals).

  Two of the cuts broke assignment requirements (PLANEJAMENTO Section 2): sound effects, and a stage of at least five minutes, which is Stage 2.
- **F6-01 is folded into F6-02.** MultiMesh is the default renderer, and F6-02 carries the benchmark.
- **Astra's design work runs in lane `sol`,** as D-01 to D-07 in `.scratch/design-sprint/`.
- **Routing by difficulty.** Opus takes the serialized Session path and the hardest Godot integration. OpenCode takes cores, content and standalone adapters, with the model chosen per ticket (a `Model:` line in its header; the user switches it by hand). Power models take the hardest OpenCode tickets. Flash models take the mechanical ones.
- **Scope changes are still the user's call.** The fallback order in "Checkpoints" is a proposal the user confirms at the checkpoint.
- **This page supersedes older "cut" wording.** Tickets written before the sprint may still say F3, F13 or F12-04 is "cut". Treat every such line as "reinstated, done by the ticket named here". An acceptance item is never "not verified (cut)" unless the user cuts it; a ticket that has not landed by delivery is "not verified (not landed)".
- **Header lines win over body text.** Lane names in ticket bodies and specs are historical: `glm-a`, `glm-b`, or a lane the ticket later left. A ticket's `Lane:` and `Model:` header lines and this page's queues are authoritative.
- **Late asset swaps.** A consumer ticket never waits for a D asset:
  - It uses the D asset if it is already on the integration branch, and otherwise ships its dev placeholder and logs "swap pending: D-0N".
  - F14-01 starts by applying every pending swap, and every value Astra asks trunk to set in a trunk-only file (D-05's weapon and Bomb values in `player_ship.tscn`, D-07's shrine exports on Stage 1), as one `[shared]` commit.
- **Split tickets.** F6-03, F9-03, F12-03, F3-04, F14-02, D-06 and D-07 run in parts across lanes or windows. Each part commits with `(<ID> part N)` in its message and writes a handoff entry saying "part N". Only the final part sets `Status: done`. Check a part with `git log dev-01 --oneline --grep "<ID> part N"`. A part's own dependencies are the ones in the queue tables below, not the ticket's full `Depends on` line.

## Lanes

| Lane | Tool | Worktree (`C:\Users\Braia\Documents\`) | Branch | Role |
| --- | --- | --- | --- | --- |
| `trunk` | Claude Code, Opus 5.5, ultracode | `touhou-3d-trunk` | `lane/trunk` | The Session lane: the **only** lane that edits `scripts/session/game_session.gd`, `scenes/main.tscn`, `scenes/player/player_ship.tscn`, `project.godot`, `export_presets.cfg` and the script wiring in `scenes/stages/stage_01.tscn`. Sets the pace. Runs the whole sprint. |
| `path` | Claude Code, Opus 5.5, ultracode | `touhou-3d-path` | `lane/path` | Critical-path and hard Godot work that touches none of trunk's files: the projectile-field chain, the boss core, the first real actors, Pickups, the boss adapter, the windowed F3 pass, an export pre-flight and F11-03. **Stopped during its gaps**; a stopped session costs nothing. |
| `rescue` | Claude Code, Opus 5.5 | none of its own | the stuck lane's | Started only on demand: it takes over an OpenCode ticket that a power model could not finish, or resolves a `stage_director.gd` merge for sol. Opens in the stuck lane's worktree after that session stops, and closes when the ticket lands. |
| `oc-a` | OpenCode desktop | `touhou-3d-oc-a` | `lane/oc-a` | Cores and standalone adapters: audio limiter and controller, pattern emitter, enemy model, WeaponModel core, Stage 1 contract test, lantern boss content, Seals. |
| `oc-b` | OpenCode desktop | `touhou-3d-oc-b` | `lane/oc-b` | Definitions, EncounterMachine, content drafts, Snapshot, Settings, packaging. |
| `sol` | Codex, GPT Sol, as Astra | `touhou-3d-sol` | `lane/sol` | Every D ticket, plus the Stage 2 scene work F12-05 to F12-07. |
| `terra` (optional) | Codex, Terra | `touhou-3d-terra` | `lane/terra` | Overflow for easy tickets only (see "Overflow"). Not created until needed. |

Inside any ticket, its **Files** section is the boundary. If a ticket seems to need a file outside it, the session stops and says so in its Outcome.

## Git worktrees: one agent, one worktree, one branch

No two agents ever share a working tree or a branch.

0. **How to call the scripts.** This machine's PowerShell execution policy is the Windows default (Restricted), so a bare `tools\lane.ps1` fails. Call every script as `powershell -NoProfile -ExecutionPolicy Bypass -File tools\lane.ps1 <command> <args>`, and the same for `tools\test.ps1`. Everywhere this page writes `tools/lane.ps1 <command>`, it means that form.
1. **The primary tree is only a landing target.** `C:\Users\Braia\Documents\touhou-3d` keeps the integration branch `dev-01` checked out and clean. No agent opens a session, edits or commits there. Only `tools/lane.ps1 land` moves it, by fast-forward.
2. **Create a lane once.** Run `tools/lane.ps1 setup <lane>`. It creates `touhou-3d-<lane>` on `lane/<lane>` from `dev-01`. Open that lane's tool in that folder and nowhere else, and never check out another lane's branch. The first `tools/test.ps1` in a new worktree imports the project (about a minute).
3. **Every ticket follows the same loop:**
   1. `tools/lane.ps1 sync`
   2. `tools/lane.ps1 status <ticket path>`
   3. Implement and test.
   4. Commit on your lane branch.
   5. `tools/lane.ps1 land`, which merges `dev-01` in, runs the tests (a red run or any `SCRIPT ERROR` stops it), and fast-forwards the primary tree. It retries if another lane landed first.
4. **Conflicts.**
   - `docs/HANDOFF_LOG.md` and `docs/engineering/README.md` merge with the union driver: add entries, never reorder.
   - Any other conflict is resolved in your lane branch, never in the primary tree, and the file is named in your handoff entry.
5. **No pushes, no rebases, no amends.** The user pushes when they choose.

## Shared files

| File | Who edits it | Rule |
| --- | --- | --- |
| `scripts/progression/stage_director.gd` | trunk F10-01, F10-02, F10-03, F12-03 part 2, F13-03; sol F12-05, F12-06, F12-07 | Unordered pairs: F12-03 with F12-05, and F13-03 with F12-06 and F12-07. Sync right before starting, put every addition in its own private function with a one-line call site, and the second lander merges both. If sol hits a conflict inside one function, it stops and `rescue` resolves it on `lane/sol`. |
| `tests/scene/test_stage_director.gd` | trunk F12-03; sol F12-05 | Each edits only its named functions; the second lander keeps both. |
| `tests/scene/test_game_session_flow.gd`, `test_game_session_combat.gd`, F10 and F11 scene tests | trunk | Sol F12-05 may change only a case that breaks because Stage 2 now has a Director, and names it in its handoff. Trunk syncs before F11-01 and keeps the change. |
| `scripts/ui/menu_controller.gd`, `tests/scene/test_menu_registry_contract.gd` | oc-b F3-03; trunk F11-01 | Whichever starts second syncs first and keeps the other's hunks. They overlap only at the tail of `_ready`. |
| `scripts/ui/interface.gd` | trunk F4-02, then oc-b F3-02, then F3-03 | Ordered by dependencies. |
| `scenes/dev/arena_harness.gd` and `.tscn` | trunk F6-02, F6-03; path F9-02, F7-03, F12-02 | Serialized: path starts F9-02 only after trunk's F6-03 (part 2) has landed. No other ticket edits the harness. |
| `docs/engineering/stage-director.md` | oc-a F10-04; trunk F10-01, F12-03; sol F12-05 | F10-04 lands before F10-01 starts, or puts its notes in its handoff entry. F12-03 and F12-05 each write only their own section. |
| `docs/engineering/damage-pickups.md`, `docs/validation/combat.md` | trunk F7-02; path F7-03 | Each appends its own headed section; the second lander keeps both. |
| `docs/engineering/weapon-rendering.md` | trunk F6-02 creates it | Oc-a's F6-03 part 1 must not create it: its contract goes in doc comments and the handoff entry, and trunk's part 2 writes the section. |
| `content/bosses/lantern_guardian.tres`, `content/patterns/lantern_*.tres` | oc-a F12-03 part 1 creates them | Trunk's part 2 only references them. Sol's D-07 Part C tunes values after F12-03 has landed. |
| `scenes/enemies/lantern_guardian.tscn` | sol D-03 creates it (no root script); trunk F12-03 part 2 attaches `boss_controller.gd` `[shared]` | Sol stops editing it after T0 + 15 h; later fixes are handoff requests. |
| `scenes/dev/spirit.tscn`, `sentry.tscn`, `content/enemies/*.tres`, their pattern `.tres` | path F9-02 creates them; sol D-05 tunes them | D-05 starts after F9-02 and F6-03 land, and lands before trunk starts F10-01 (about T0 + 9 h); otherwise it waits until F10-01 lands. |
| `content/stages/stage_01/*.tres` | oc-b F8-04 creates them; sol D-05 tunes them | Same D-05 timing rule. |
| `scenes/stages/stage_01.tscn` | trunk (F10-01, F10-02, F12-03, F14-01's swap step) | Sol's D-07 Part A edits it only after F12-03 has landed, and never touches the Stage script or its exports. |
| `scenes/stages/stage_02.tscn` | sol F12-05 attaches the scripts | Only sol. |
| `docs/GUIDE.md`, `docs/engineering/ROADMAP.md` | everyone | Each lane edits only its own rows. D tickets also add one "Received from Astra" row. An adjacent-row conflict keeps both texts. |
| `user://` | shared by all worktrees (keyed by project name) | Tests that write there use a per-process file name, for example `"user://test_settings_%d.cfg" % OS.get_process_id()`. Only the real game writes `settings.cfg`. |
| `build/` | per worktree (ignored) | Path's pre-flight, trunk's F14-01 and oc-b's F14-02 each export in their own worktree. F14-02 re-exports with the command F14-01 recorded in `docs/engineering/project.md`. |

Handoff entry headers name the lane: `— Claude (trunk) —`, `— Claude (path) —`, `— Claude (rescue for oc-a) —`, `— OpenCode (oc-a) —`, `— Astra (sol) —`, `— Codex Terra (terra) —`.

## Lane queues

Run top to bottom. When the next ticket's dependencies are not done, take the first later ticket in your own queue whose dependencies are. If none is ready, read ahead and check again in ten minutes. Never write code against an interface that has not landed. If the rest of your queue waits on another lane for more than an hour, stop and report.

**Workflow shapes for the Opus lanes** (at most 3 agents per workflow):
- **3 agents:** an implementer; a test-writer who writes the ticket's listed tests from the spec, in parallel and in separate files; and a reviewer who checks correctness, conventions and the Files boundary once the tests are green. The implementer fixes what the reviewer confirms.
- **2 agents:** an implementer and a reviewer.
- **Solo:** one agent that self-reviews against the Definition of Done.

### trunk (Opus, whole sprint)

| # | Ticket | Shape | Depends on |
| --- | --- | --- | --- |
| 1 | F4-02 hud-binding-and-target-marker | solo | done |
| 2 | F4-03 boss-panel-and-attack-cue-api (fills the wait for F5-03) | solo | F4-02 |
| 3 | F6-02 projectile-system-adapter, with the folded F6-01 benchmark | 3 agents | F5-03 |
| 4 | F6-03 part 2: PlayerWeapon, `player_ship.tscn` `[shared]`, harness; closes the ticket | 2 agents | F6-02, F4-02, F6-03 part 1 (oc-a) |
| 5 | F7-01 hit-to-combat-state-and-defeat | 3 agents | F6-02, F4-02 |
| 6 | F7-02 bomb-clear-and-invulnerability | 2 agents | F7-01, F6-03 |
| 7 | F10-01 stage-director-adapter | 3 agents | F8-02, F8-04, F9-02, F7-03, F4-03 |
| 8 | F10-02 gate-and-checkpoint-adapters | 3 agents | F10-01, F8-03, F7-02 |
| 9 | F10-03 retry-restart-flow | 3 agents | F10-02, F7-01 |
| 10 | F12-03 part 2: Director boss branch, Session wiring, `stage_01.tscn` exports, integration test; closes the ticket. Runs straight after F10-03 so Stage 2 unblocks about 2.7 h sooner | 3 agents | F12-02, F10-03, F12-03 part 1 (oc-a) |
| 11 | F11-01 defeat-results-retry-restart-screens | solo | F10-03 |
| 12 | F11-02 campaign-continuation-and-direct-stage | solo | F11-01 |
| 13 | F13-03 audio-event-wiring | 2 agents | F13-02, F12-03, F7-03, D-01 |
| 14 | F3-04 part 2: the Session additions; closes the ticket | solo | F10-03, F3-02, F3-04 part 1 (path) |
| 15 | F14-01 export-and-run-outside-editor, starting with the swap step | solo | F11-03, F12-03 |

Slip rule: if F11-02 has not landed by T0 + 19.5 h, run F14-01 straight after F11-03 (before F13-03 and F3-04), and F14-02 re-exports at the end.

### path (Opus, stopped during gaps)

| # | Ticket | Shape | Depends on |
| --- | --- | --- | --- |
| 1 | F5-01 field-core-spawn-move-cull | solo | done |
| 2 | F5-02 core-hit-sweep-and-graze-rules | 3 agents | F5-01. It waits at most until T0 + 1 h for sol's D-07 Part B (ruling 5), then pins the current reading and logs "ruling 5 pending" |
| 3 | F5-03 bomb-phase-clears-and-hit-spheres | 3 agents | F5-02 |
| 4 | F12-01 boss-machine-core | solo | F5-04 |
| 5 | F9-02 dev-prefabs-and-enemy-actor | 2 agents | F9-01, F6-02, and trunk's F6-03 part 2 (arena harness). It reads the ProjectileSystem priority that F6-02 actually landed. |
| 6 | F7-03 pickup-adapter-and-rewards | solo | F7-01 |
| 7 | F12-02 boss-controller-adapter | solo | F12-01, F9-02, F4-03 |
| 8 | F3-04 part 1: the windowed F3 pass for F3-02 and F3-03, `docs/validation/settings.md` and screenshots | solo | F3-02, F3-03 |
| 9 | F14-01 pre-flight: export `dev-01` in this worktree, run it, and record export-only errors in a handoff entry (no other file edits) | solo | F10-02 |
| 10 | F11-03 active-and-clear-time-verification. It never edits `game_session.gd`; a Session defect goes to trunk as a blocker. | solo | F11-02 |

Expected gaps (stop the session): about T0 + 4.0 to 5.9 h, T0 + 10.7 to 12.4 h, and T0 + 13.2 to 19.5 h.

### oc-a (OpenCode; model per ticket)

| # | Ticket | Model (fallback) | Depends on |
| --- | --- | --- | --- |
| 1 | F13-01 audio-limiter-core (also the smoke test for Luna on Go) | GPT 5.6 Luna (DeepSeek V4.1 Flash) | done |
| 2 | F5-04 pattern-emitter-core | GPT 5.6 Luna (DeepSeek V4.1 Flash) | F5-01 |
| 3 | F9-01 enemy-model-core | GPT 5.6 Luna (DeepSeek V4.1 Flash) | F5-04 |
| 4 | F6-03 part 1: the WeaponModel core only (no scene) | GPT 5.6 Luna (DeepSeek V4.1 Flash) | F4-01 only |
| 5 | F13-02 audio-controller-adapter (not attached). Run a 5-request check of Qwen3.8 Max first | **Qwen3.8 Max** (GPT 5.6 Luna) | F13-01 |
| 6 | F10-04 stage-01-contract-smoke-test (lands before trunk starts F10-01) | GPT 5.6 Luna (DeepSeek V4.1 Flash) | F8-04 |
| 7 | F12-03 part 1: `lantern_guardian.tres`, three lantern patterns, the content unit test | GPT 5.6 Luna (DeepSeek V4.1 Flash) | F12-01, F5-04, F6-03 part 1 |
| 8 | F9-03 part 1: the SealRules core | GPT 5.6 Luna (DeepSeek V4.1 Flash) | F9-02 |
| 9 | F9-03 part 2: the Seal adapter; closes the ticket. Starts after Qwen3.8 Max's window has reset (about T0 + 8.4 h) | **Qwen3.8 Max** (Kimi K3) | F9-03 part 1 |

### oc-b (OpenCode; model per ticket)

| # | Ticket | Model (fallback) | Depends on |
| --- | --- | --- | --- |
| 1 | F8-01 definition-schemas-and-content-validation | GPT 5.6 Luna (DeepSeek V4.1 Flash) | done |
| 2 | F8-02 encounter-machine-core | **GLM-5.3** (GPT 5.6 Luna) | F8-01 |
| 3 | F8-04 stage-01-content-draft (also the smoke test for V4.1 Flash) | DeepSeek V4.1 Flash (GLM-5.3-Flash) | F8-01 |
| 4 | F12-04 stage-02-content-draft. If F9-01 has not landed yet, do F8-03 first | DeepSeek V4.1 Flash (GPT 5.6 Luna) | F8-01, F9-01 |
| 5 | F8-03 snapshot-capture-restore | GPT 5.6 Luna (DeepSeek V4.1 Flash) | F8-02, F4-01 |
| 6 | F3-01 settings-core-and-configfile | GPT 5.6 Luna (DeepSeek V4.1 Flash) | done |
| 7 | F3-02 options-screen-binding. Starts after GLM-5.3's first window resets (about T0 + 5.9 h) | **GLM-5.3** (GPT 5.6 Luna) | F3-01, F4-02 |
| 8 | F14-02 part 1: `tools/package.ps1` only | GPT 5.6 Luna (DeepSeek V4.1 Flash) | none |
| 9 | F3-03 input-device-mode-and-controller-disconnect. Starts after GLM-5.3's second reset (about T0 + 10.9 h) | **GLM-5.3** (GPT 5.6 Luna) | F3-02 |
| 10 | F14-02 part 2: re-export after sync, package, acceptance record; closes the ticket | DeepSeek V4.1 Flash (GLM-5.3-Flash) | F14-01 |

### sol (Codex, GPT Sol as Astra)

| # | Ticket | Depends on |
| --- | --- | --- |
| 1 | D-07 Part B: the written rulings, first, by about T0 + 0.8 h (rulings 1 and 5 pin F12-01 and F5-02) | none |
| 2 | D-01 sfx-selection-and-import | none |
| 3 | D-03 lantern-guardian-scene | none |
| 4 | D-04 stage-2-boss-scenes | none |
| 5 | D-02 combat-visuals (with the focused-slider fix) | none |
| 6 | D-06 pass 1: the values review and the 300 s estimate | F12-04 |
| 7 | D-05 stage-1-tuning-and-pacing (see its timing rule in "Shared files") | F8-04, F9-02, F6-03 |
| 8 | F12-05 stage-02-director-integration | F10-03, F9-03, F12-04 |
| 9 | D-06 pass 2: the Seal health exports | F12-05 |
| 10 | F12-06 tempest-sentinel-miniboss | F12-05, F12-02, F12-03, D-04 |
| 11 | F12-07 storm-guardian | F12-06, D-04 |
| 12 | D-07 Parts A and C: the shrine clip and the lantern values; closes the ticket | F12-03 |
| 13 | D-06 pass 3: the boss values; closes the ticket | F12-07 |

Sol idles from about T0 + 8.7 h to T0 + 15.2 h, waiting for F10-03. It reads ahead for F12-05 or stops.

Ticket files: `.scratch/<feature>/issues/NN-slug.md`, found by ID with `tools/lane.ps1 status <ID>`. Folders: F3 `settings`, F4 `combat-hud`, F5 `projectile-field`, F6 `weapon-rendering`, F7 `damage-pickups`, F8 `progression-core`, F9 `enemies`, F10 `stage-director`, F11 `run-flow`, F12 `bosses`, F13 `audio`, F14 `delivery`, D `design-sprint`.

## Model budgets (OpenCode, requests per 5 h per model)

The 5-hour windows roll from each model's first use. The weekly cap is about 2.5 full windows per model. Before a power-model ticket, check the meter; if the remaining quota is below the estimate plus 15 %, use the ticket's fallback.

| Model | Quota / 5 h | Planned use | Note |
| --- | --- | --- | --- |
| GLM-5.3 | 220 | W1 F8-02 (~120); W2 F3-02 (~160); W3 F3-03 (~150) | Each window keeps 60 to 100 spare for one short escalation. Weekly 430 of about 550. |
| Qwen3.8 Max | 160 | W1 F13-02 (~130); W2 F9-03 part 2 (~70) | 30 spare in W1 does not cover a retry: a red F13-02 escalates to Kimi K3. |
| Kimi K3 | 110 | Escalation reserve only | At most 100 per window, one session at a time. |
| Grok 4.7 | 169 | Unused unless the user opts in | Second escalation reserve (xAI keeps data 30 days). |
| Qwen3.7 Max | 170 | Unused | Mixed tool-calling reports on OpenCode Go. |
| GPT 5.6 Luna | 2050 | W1 about 670 across both sessions; W2 about 180 | The shared workhorse. Two sessions at once stay well inside the quota. |
| DeepSeek V4.1 Flash | 26000 (4× promo until Sep 27) | About 240 in total, plus fix-up retries | Sometimes ends a turn empty after a tool call: reply "continue" (not a failure). |
| GLM-5.3-Flash | 6320 | Fallback only | Not prompt-cached on Go; count it at a fraction of its quota. |

Excluded by default: Muse Spark 1.2 and 1.3 Contributor (train on prompts) and Space Bunny Free (unknown provider). They are opt-in only.

**Model switches are manual.** Before each ticket, the OpenCode session reads the ticket's `Model:` line. If it names a different model from the one selected, the session stops and asks the user to switch. There are about ten switch points between T0 and T0 + 11 h.
- **Overnight fallback:** if the user is away, run the remaining oc-a and oc-b tickets on GPT 5.6 Luna with no switches, and hold only F3-02 and F3-03 for GLM-5.3. F3 has slack until about T0 + 21.5 h.

## Escalation

1. **When an OpenCode ticket is stuck.** A workhorse or flash model is red twice on the same failing test, or twice hits a tool-call error that poisons the session. The lane then stops and writes the failing test, the error and its hypothesis into the ticket's Outcome.
2. **Kimi K3 comes next.** The user switches that session to Kimi K3 for at most 100 requests, to debug and fix only (no rewrite), one session per window.
3. **The ticket goes to `rescue` instead when:**
   - Kimi K3 is spent or busy with the other lane;
   - Kimi K3 also fails twice;
   - the ticket already runs on a power model and has failed twice;
   - its needed-by time is under 2 h: F8-02 by T0 + 9.1 h, F10-04 by T0 + 9.1 h, F8-03 by T0 + 11.4 h, F9-03 by T0 + 15.2 h, and F14-02 part 2 at the end.
4. **Handover to rescue.**
   1. The user stops the OpenCode session.
   2. The user opens Claude Code Opus 5.5 in that lane's worktree with the rescue prompt below.
   3. When rescue lands the ticket, the lane resumes.
5. **Other rules.**
   - A power-model ticket's fix-up after a written diagnosis may drop to DeepSeek V4.1 Flash to save quota; a second red on the same test escalates.
   - Opus lanes never escalate to cheaper models. A stuck trunk or path ticket adds a diagnosing reviewer within its 3-agent cap.
   - A Session defect found by path's F11-03 becomes trunk's next ticket.
   - Sol keeps its tickets; rescue only resolves its `stage_director.gd` merge.

## Overflow

Both overflows are optional, and neither is expected under this plan (Luna's quota is not tight).

**Codex Terra (lane `terra`).** Start it with `tools/lane.ps1 setup terra` only if an OpenCode lane has been blocked for more than an hour, by quota or a model outage, while one of these easy tickets is ready: **F8-04, F10-04, F13-01, F3-01**.
- Tell the owning lane to skip that ticket.
- Terra never takes a D ticket, anything sol owns, or any file outside those tickets.

**OpenRouter (GLM-5.2 or DeepSeek, pay per token; set a spend cap on the key).** Plug the key into OpenCode and select it as that ticket's model when either:
- the planned model and its fallback both show more than 90 % of the 5-hour window spent, and the next reset is more than an hour away; or
- a model's weekly meter passes 80 %.

Run easy tickets in batches of two or three in one session. Switch back as soon as the OpenCode window resets. The candidates:
- F8-04, F12-04 and F12-03 part 1 (content);
- F10-04 (read-only contract test);
- F14-02 parts 1 and 2;
- F13-01;
- the fix-up retry of any OpenCode ticket whose first red run has a written diagnosis naming the fix;
- the ROADMAP row, handoff entry and module-doc tail of any OpenCode ticket whose code is already green.

Never send OpenRouter a strong-coder, complexity-4 or 5, or critical-path ticket.

## Claude usage

At most three Opus sessions, each running workflows of at most 3 agents:
1. `trunk` runs the whole sprint.
2. `path` runs only while it has a ready ticket.
3. `rescue` runs only on demand and closes when its ticket lands.

**Expected spend.** In mid-tier-request units (a 3-agent ticket costs about 2.5× and a 2-agent ticket about 1.6×): trunk about 4,100, path about 1,300, rescue at most 300. Trunk peaks in windows W3 and W4, at about 1,100 each.

**Guard.** If the Claude meter passes 75 % of a window with more than 1.5 h left in it, cut in this order:
1. The test-writers (3 agents become 2).
2. The reviewers on tickets of complexity 4 or lower.

Never drop the reviewer on F10-01, F10-02, F10-03 or F12-03. Path pauses before trunk ever does, because trunk sets the pace. Mid-coder and content work never runs on Opus (F4-03 is the exception: it fills trunk's otherwise idle wait).

## Kickoff prompts

Paste one into a fresh session of the right tool, opened in the lane's worktree. A lane session chains tickets, committing and landing after each one. After four tickets, or when the context is heavy, start a fresh session with the same prompt. Every prompt assumes scripts are called as `powershell -NoProfile -ExecutionPolicy Bypass -File tools\<script>.ps1 <args>`.

**trunk: Claude Code desktop, Opus 5.5, ultracode on,** in `touhou-3d-trunk`:

```
You are lane trunk of docs/engineering/SPRINT.md. Read CLAUDE.md, docs/engineering/SPRINT.md and docs/engineering/ROADMAP.md once. Work the trunk queue in order, one ticket at a time: tools/lane.ps1 sync; tools/lane.ps1 status <ticket path> (for a part, check the part dependencies in SPRINT's table, using git log dev-01 --oneline --grep "<ID> part N"); implement it with the workflow shape the trunk table gives (3 agents: implementer, test-writer, reviewer; 2 agents: implementer, reviewer; solo: self-review against the Definition of Done), applying the Claude usage guard; finish its Definition of Done; commit on lane/trunk; tools/lane.ps1 land. Then the next ticket. Stop after four tickets and report what landed. Run every tools script as powershell -NoProfile -ExecutionPolicy Bypass -File tools\<script>.ps1 <args>.
```

**path: Claude Code desktop, Opus 5.5, ultracode on,** in `touhou-3d-path`:

```
You are lane path of docs/engineering/SPRINT.md. Read CLAUDE.md, docs/engineering/SPRINT.md and docs/engineering/ROADMAP.md once. Work the path queue in order with the workflow shape its table gives, one ticket at a time: tools/lane.ps1 sync; tools/lane.ps1 status <ticket path> (for a part, use SPRINT's part dependencies); implement; finish its Definition of Done; commit on lane/path; tools/lane.ps1 land. Never edit a trunk-only file (SPRINT "Lanes"). When your next ticket is not ready and none later is, stop the session and report which dependency you are waiting for; the user restarts you with this prompt. Stop after four tickets and report what landed. Run every tools script as powershell -NoProfile -ExecutionPolicy Bypass -File tools\<script>.ps1 <args>.
```

**rescue: Claude Code desktop, Opus 5.5,** opened in the stuck lane's worktree after that lane's session is stopped:

```
You are rescue for lane <lane> of docs/engineering/SPRINT.md. Read CLAUDE.md and the "Escalation" section of docs/engineering/SPRINT.md, then finish <ticket path> starting from the failing test and the diagnosis in its Outcome, solo, without rewriting what already works. Finish its Definition of Done, commit on lane/<lane> with the handoff header "— Claude (rescue for <lane>) —", run tools/lane.ps1 land, and stop. Run every tools script as powershell -NoProfile -ExecutionPolicy Bypass -File tools\<script>.ps1 <args>.
```

**oc-a and oc-b: OpenCode desktop,** one session per lane, in `touhou-3d-oc-a` or `touhou-3d-oc-b`:

```
You are lane oc-a of docs/engineering/SPRINT.md (use oc-b for the other session). Read AGENTS.md, docs/engineering/SPRINT.md and docs/engineering/CONVENTIONS.md once. SPRINT.md supersedes every "cut pending the user" line in the tickets. Work your lane's queue from SPRINT, one ticket at a time. Before each ticket, read its Model line in SPRINT's table: if it names a different model from the one you are running, stop and ask the user to switch models, then continue. For each ticket: tools/lane.ps1 sync; tools/lane.ps1 status <ticket path> (for a part, SPRINT's part dependencies apply, and you do only that part; commit it with "(<ID> part N)" in the message and leave the ticket todo unless it is the last part); read only the ticket's "Read first" list; write the tests first, then the code, with strict static typing (warnings are errors); run tools/test.ps1 until green with no SCRIPT ERROR; finish its Definition of Done; commit on your lane branch with the ticket's commit message; tools/lane.ps1 land. If the same test fails twice after fixes, stop, write the failing test, error and hypothesis into the ticket's Outcome, and ask the user to escalate (SPRINT "Escalation"). Skill names in a ticket's kickoff (/mattpocock-skills:tdd, /run) are Claude-only: follow their intent. Stop after four tickets and report what landed. Run every tools script as powershell -NoProfile -ExecutionPolicy Bypass -File tools\<script>.ps1 <args>.
```

**sol: Codex, GPT Sol,** in `touhou-3d-sol`:

```
You are Astra, lane sol of docs/engineering/SPRINT.md. Run tools/lane.ps1 sync first. Read AGENTS.md, docs/engineering/SPRINT.md, docs/engineering/CONVENTIONS.md and docs/GUIDE.md Sections 3 and 5 once. SPRINT.md supersedes every "cut pending the user" line in the tickets. Work the sol queue in SPRINT's order, one item at a time, starting with D-07 Part B: tools/lane.ps1 sync; tools/lane.ps1 status <ticket path> (for a part or pass, SPRINT's dependencies apply; commit it with "(<ID> part N)" or "(<ID> pass N)" and leave the ticket todo unless it is the last); deliver it inside its Files boundary (D tickets are design deliverables; F tickets are code: test-first, strict static typing, tools/test.ps1 green with no SCRIPT ERROR); finish its Definition of Done or Handoff section; commit on lane/sol; tools/lane.ps1 land. If a stage_director.gd merge conflicts inside one function, stop and ask the user for the rescue session. Stop after four items and report what landed. Run every tools script as powershell -NoProfile -ExecutionPolicy Bypass -File tools\<script>.ps1 <args>.
```

**terra: Codex, Terra (optional),** in `touhou-3d-terra` after `tools/lane.ps1 setup terra`:

```
You are lane terra of docs/engineering/SPRINT.md. Take only the ticket(s) the user names, from F8-04, F10-04, F13-01 and F3-01. Read AGENTS.md, docs/engineering/SPRINT.md and docs/engineering/CONVENTIONS.md once. For each: tools/lane.ps1 sync; tools/lane.ps1 status <ticket path>; tests first, then code; tools/test.ps1 green with no SCRIPT ERROR; its Definition of Done; commit on lane/terra; tools/lane.ps1 land. Never touch a D ticket or any file outside the ticket. Run every tools script as powershell -NoProfile -ExecutionPolicy Bypass -File tools\<script>.ps1 <args>.
```

## Checkpoints (T0 = the lanes start; planned for about 21:00 on 2026-09-23)

**At T0 (about 15 minutes of setup).** The lanes are ready: `trunk`, `path`, `oc-a`, `oc-b` and `sol` worktrees exist, `sol` runs `tools/lane.ps1 sync` first, and each new worktree's first test run imports the project.

| When | Landed by then | What works |
| --- | --- | --- |
| T0 + 1 h | D-07 Part B, F5-01, F13-01, F8-01 | Rulings pinned before F5-02 and F12-01; field spawn, move and cull; Luna smoke-tested |
| T0 + 3 h | F4-02, F4-03, F5-02, F5-03, F5-04, F9-01, F8-02, F8-04, D-01, D-03 | Full projectile-field core and PatternEmitter; HUD bound with marker, boss panel and cues; schemas, EncounterMachine and Stage 1 content; SFX imported; Lantern Guardian scene |
| T0 + 6 h | F12-01, F6-03 part 1, F13-02, F10-04, F12-04, F8-03, F3-01, F6-02, F12-03 part 1, D-04, D-02, D-06 pass 1 | MultiMesh Projectiles with the benchmark recorded; boss, audio and Snapshot cores; Stage 2 and lantern content |
| T0 + 9.5 h | F6-03, F7-01, F7-02, F9-02, F7-03, F3-02, F14-02 part 1, F9-03 part 1, D-05 | The ship fires; hostile fire damages it; Defeat; Bomb; Spirits and Sentries fight in the arena; Pickups; Options apply and persist; Stage 1 tuned |
| T0 + 13.5 h | F10-01, F10-02, F12-02, F9-03, F3-03, F3-04 part 1, F14-01 pre-flight | The Stage 1 route with Encounters, Waves, rewards, Gates, Checkpoints and PortalLinks; boss adapter; controller disconnect pause; a first exported build smoke-tested |
| T0 + 17.5 h | F10-03, F12-03, F12-05, D-06 pass 2 | Stage 1 end to end with Retry, Restart and the Lantern Guardian; the Stage 2 route live |
| T0 + 21 h | F11-01, F11-02, F11-03, F12-06, F12-07 | Results, Defeat, Campaign continuation, Direct Stage; Stage 2 with its miniboss and Storm Guardian; time accounting verified |
| T0 + 23.5 h | F13-03, F3-04, D-07, D-06, F14-01 | Sound effects; camera settings; shrine lighting; the exported build with every swap applied |
| Last (about T0 + 24 h) | F14-02 | Package and acceptance record |

**If a checkpoint slips by more than an hour,** the proposed cut order is below. The user confirms each step.
1. Music (keep SFX).
2. F3-03's prompt icons (keep the disconnect pause).
3. The Storm Guardian's final art (fight the dev boss).
4. Stage 2 entirely (F12-05 to F12-07), with D-05's Stage 1 pacing raised to five minutes.

## Human steps

- **Export templates.** Installed on 2026-09-23 (`%APPDATA%\Godot\export_templates\4.7.2.stable`).
- **OpenCode model switches.** Switch models when a lane asks (about ten times before T0 + 11 h), or use the overnight fallback.
- **Checkpoints.** Run `tools/lane.ps1 status <IDs>` from any lane folder, with the IDs of the checkpoint row.
- **The human pass, reserved for about T0 + 21 to 24 h.**
  - D-01's listening pass.
  - F11-03's clear-time runs and the Stage 2 five-minute measurement.
  - The S1-07 FPS reading.
  - The physical keyboard, DualSense and unplug passes.
- **Publishing.** Push and open pull requests when you choose; the lanes never push.

## Defaults taken (change any by telling Claude)

- T0 is about 21:00 on 2026-09-23, and delivery is the end of 2026-09-24.
- GPT 5.6 Luna is the OpenCode workhorse. If GPT 6 Luna is on your plan (about 4,230 per 5 h in the OpenCode Go docs), it may replace 5.6 Luna in every row.
- Grok 4.7, the Contributor models and Space Bunny Free are unused.
- Codex Terra is available as the optional overflow lane.
