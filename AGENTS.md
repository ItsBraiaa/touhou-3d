# Touhou 3D

Godot 4.7.2 third-person 3D bullet hell (working title Guardiã dos Ventos). Two agents work here: Astra (Codex) is Lead Game Designer and owns scene geometry, art, layout, markers, materials, and content values; Claude is Lead Code Engineer and owns GDScript, tests, project configuration, `scenes/main.tscn`, `scenes/dev/`, and the wiring inside any scene (script attachment, exported values, collision layers and masks, monitoring flags, instancing of Claude's prefabs). GUIDE Section 3 is the full split. Engineering docs and code identifiers are in English; player-facing UI is in Portuguese.

## Start here

0. **Sprint to 2026-09-24:** lanes `trunk` and `path` (Claude Opus; `rescue` on demand), `oc-a` and `oc-b` (OpenCode, model chosen per ticket by its `Model:` line), `sol` (Astra on GPT Sol) and, optionally, `terra` (Codex Terra). Each lane has its own git worktree and `lane/<name>` branch. Never work in the primary tree. Read [docs/engineering/SPRINT.md](docs/engineering/SPRINT.md) first; it gives your lane's queue, the worktree loop (`tools/lane.ps1 sync`, `status`, `land`) and your kickoff prompt. Claude skill names in kickoff prompts (`/mattpocock-skills:tdd`, `/run`) are Claude-only; follow their intent (test-first; verify headless).
1. [docs/engineering/ROADMAP.md](docs/engineering/ROADMAP.md): what is done, what is next, what Astra still owes. Pick one ticket.
2. [docs/engineering/CONVENTIONS.md](docs/engineering/CONVENTIONS.md): how code is written, tested, committed, and handed off.
3. [docs/engineering/README.md](docs/engineering/README.md): index of the engineering docs — conventions, roadmap, ticket template, testing, and one line per module doc.
4. [CONTEXT.md](CONTEXT.md) for vocabulary and [docs/adr/](docs/adr/) for the four architectural decisions.
5. [docs/GUIDE.md](docs/GUIDE.md) for scene and script contracts, then the gameplay sources [docs/PLANEJAMENTO.md](docs/PLANEJAMENTO.md) and [docs/STAGE_DESIGN.md](docs/STAGE_DESIGN.md).

One ticket per session. A session ends with tests green, the ticket marked done or blocked, the roadmap row updated, a handoff log entry, and one commit of its own files.

## Collaboration protocol

Ownership and edit rights are in [GUIDE.md Section 3](docs/GUIDE.md#3-file-ownership) and [CONVENTIONS.md "Shared-file protocol"](docs/engineering/CONVENTIONS.md#shared-file-protocol). Every change to a file owned by the other agent is announced in [docs/HANDOFF_LOG.md](docs/HANDOFF_LOG.md), newest first, never rewriting earlier entries. Never rerun a `tools/build_*.py` generator over an integrated scene without reconciling first.

## Agent skills

### Issue tracker

Issues and specs live as local markdown files under `.scratch/<feature-slug>/` (no git remote). See [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md).

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`, recorded as a `Status:` line in each issue file. See [docs/agents/triage-labels.md](docs/agents/triage-labels.md).

### Domain docs

Single-context: one `CONTEXT.md` at the repo root plus ADRs in [docs/adr/](docs/adr/). See [docs/agents/domain.md](docs/agents/domain.md).
