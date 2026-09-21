# Handoff Log

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
