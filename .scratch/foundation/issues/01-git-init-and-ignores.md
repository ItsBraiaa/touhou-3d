# F0-01 Git init and ignores

Status: done
Type: docs
parallel-safe: no
Depends on: nothing

## Goal

Turn the folder into a git repository with a clean baseline commit, ignoring generated caches and the raw asset download packs, so every later session can commit small, reviewable changes.

## Read first

- `docs/engineering/CONVENTIONS.md`, sections "Git" and "Shared-file protocol"
- `docs/GUIDE.md` Section 3 (file ownership) and Section 13 "Tools and integration boundaries" (the `.gdignore` folders)

## Facts already established

- No `.git` exists. Global git identity is configured (`Braia`, personal email); do not change it.
- `.gitignore` currently contains `.godot/` and `/android/`. `.gitattributes` sets `* text=auto eol=lf`.
- Raw packs: `All models/` (334 MB), `all-sounds/` (9.6 MB), `Music/` (58 MB); each has a `.gdignore`. `assets/` holds the selected runtime copies.
- Four empty stray editor-data folders at the root: `export_templates/`, `feature_profiles/`, `script_templates/`, `text_editor_themes/`.

## Deliverables

- `.gitignore` with: `.godot/`, `/android/`, `/build/`, `/All models/`, `/all-sounds/`, `/Music/`, `*.tmp`. Keep `*.import` files tracked (Godot convention).
- The four empty stray folders removed.
- `git init` on branch `main`, `git config core.autocrlf false` for this repo (the attributes file already normalizes to LF).
- One baseline commit: `chore: baseline import of scenes, docs, and planning` containing everything currently in the tree, including `.scratch/`.

## Steps

1. Verify the stray folders are empty before removing them. If any is not empty, stop and record it in this ticket instead of deleting.
2. Update `.gitignore`. Run `git status --short | head` after `git init` and confirm none of the ignored folders appear.
3. Commit. Confirm with `git log --oneline` and `git count-objects -vH` that the repository is small (well under 100 MB).

## Tests required

None (no code). Verification is the `git status` and size checks above.

## Out of scope

Remote, branches, hooks, LFS.

## Definition of Done

- Baseline commit exists on `main`; ignored folders are absent from `git status`.
- Roadmap row F0-01 set to `done`; handoff log entry added ("repository initialized; Astra may commit scene work with `[shared]` tags or leave commits to Claude").
- This ticket `Status: done`.

## Handoff notes for Astra

The repository now exists. Scene work can be committed directly (message format `scenes: summary`). Raw packs are untracked on purpose; keep them on disk.

## Kickoff prompt

```
Read CLAUDE.md, docs/engineering/ROADMAP.md and .scratch/foundation/issues/01-git-init-and-ignores.md, then implement that ticket. Finish with its Definition of Done.
```
