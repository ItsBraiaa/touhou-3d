# F4 Combat state and HUD — spec

Status: ready-for-agent
Owner: Claude
Source: PLANEJAMENTO Section 4 (health, shield, invulnerability, bombs, power) and Section 7 "HUD"; ENGINEERING_BRIEF Sections 4.C, 4.I and 8; GUIDE Section 15 (HUD node paths) and Section 7 rows "Combat state changed", "Boss phase changed", "Target changed"; ADR-0001, ADR-0002.

## Goal

The player's combat resources live in one Node-free `CombatState` that the Session owns, and the combat HUD shows them without ever changing them: Health bar and percentage, the one Shield icon, two Bomb icons, the Power Level and its Power Progress, a target marker projected from the Target Lock, and, for bosses, a segmented Phase bar, a brief attack-name cue and left/right threat warnings. After F4 a Run started from the main menu shows live combat values on the HUD, and every later feature (hits in F7, bosses in F12, threats in F9/F10) only has to call the HUD API this feature exposes.

## Tickets

1. `01-combat-state-core.md` (parallel-safe) — **done** (2026-09-23, commit `combat: add CombatState core`; written from its 00-plan bullet and delivered before this spec).
2. `02-hud-binding-and-target-marker.md` — adapter; the Session creates the `CombatState`, starts it at each stage entry and pauses it; `Hud.bind()` renders it and the target marker.
3. `03-boss-panel-and-attack-cue-api.md` — adapter; `show_boss`, `set_phase_health`, `show_attack_cue`, `hide_boss`, `show_threat`, with a scripted dev harness.

02 and 03 edit `scripts/ui/hud.gd` and `tests/scene/test_hud_contract.gd` in sequence; neither is parallel-safe.

## Cross-feature contracts

The real `CombatState` (F4-01, `scripts/combat/combat_state.gd`, contract in `docs/engineering/combat-hud.md`) is the source of truth. Later tickets use exactly these names:

- `start(power_level: int, power_progress: int = 0)` at every stage entry (Start, Direct Stage, Restart, Campaign transition); the level comes from `RunState.starting_power_level()`.
- `take_hit(damage: int = HIT_DAMAGE) -> HitOutcome` with `enum HitOutcome { REJECTED, ABSORBED, DAMAGED, DEFEATED }`. The core itself starts `HIT_INVULNERABILITY` (1.0 s) after an accepted non-defeating hit and `BOMB_INVULNERABILITY` (2.0 s) after a Bomb; there is no `start_invulnerability()`.
- `update_bomb_input(held: bool) -> bool` once per physics tick: the rising edge while live with a charge spends one Bomb and emits `bomb_activated()`. There is no `use_bomb()`. `new()`, `start()`, `restore()` and `set_paused(true)` mark the button held, so a press begun before them never bombs.
- `collect_power_pickup() -> bool` (excess at Power Level 3 emits `score_awarded(points)`), `collect_shield_pickup() -> bool` (false while shielded: the Pickup stays), `refill()`, `tick(delta)`, `set_paused(paused)`, `capture() -> Dictionary` with keys `health`, `has_shield`, `bombs`, `power_level`, `power_progress`, and `restore(data)`.
- Getters `get_health`, `has_shield`, `get_bombs`, `get_power_level`, `get_power_progress`, `is_invulnerable`, `is_defeated`, `is_paused`.
- Signals, each only on a change: `health_changed(health: int)`, `shield_changed(shielded: bool)`, `bombs_changed(bombs: int)`, `power_changed(level: int, progress: int)`, `invulnerability_changed(invulnerable: bool)`; events `bomb_activated()`, `score_awarded(points: int)`, `defeated()` once per life.

Ownership (F4-02): `GameSession` holds **one** `CombatState` for its whole lifetime (a field initializer, like `_run_state`), calls `start()` at each stage entry and `set_paused()` from `_set_paused()`, and exposes `get_combat_state()`. Any Session connection to its signals (F7-01, F7-02, F7-03) is made once in `GameSession._ready`, never per stage. It survives stage swaps and ship re-instancing.

`Hud` (`scripts/ui/hud.gd`, `class_name Hud extends Control`, on the root of Astra's `scenes/ui/hud.tscn`, which is not edited): `Interface.get_hud() -> Hud` (F4-02).

- F4-02: `bind(combat_state: CombatState, targeting: Targeting, camera: Camera3D)` (idempotent: rebinding drops the previous connections first), `unbind()`. The Session binds after every ship load and unbinds on unload.
- F4-03: `show_boss(display_name: String, phase_count: int)` (2 or 3), `set_phase_health(phase_index: int, ratio: float)` (0-based, ratio 0..1), `show_attack_cue(text: String, seconds: float)`, `hide_boss()`, `show_threat(side: int, seconds: float)` (side -1 left, +1 right). Cue and threat timers do not count while the tree is paused.

Consumers: F7-01 connects `CombatState` to the Projectile Field; F10-01 routes the Director's `threat_reported(side)` to `show_threat`; F12-03 routes boss signals to `show_boss` / `set_phase_health` / `show_attack_cue` / `hide_boss`. The Tempest Sentinel's two-Phase layout stays supported although F12-04 is cut pending the user.

## Done when

- F4 tests pass, including every ENGINEERING_BRIEF Section 4.C invariant (F4-01) and a HUD test showing the HUD never changes `CombatState`.
- Starting a Run from the main menu shows 100 %, the Shield, two Bombs and Power Level 1 (2 for Direct Stage 2); locking a target in the dev arena harness shows the marker on it and hides it behind the camera.
- GUIDE Section 6 `scripts/ui/hud.gd` row is complete; `docs/engineering/combat-hud.md` covers `CombatState`, the HUD binding and the boss panel API.

## Out of scope

Anything that changes `CombatState` in play (hits, graze, bombs, pickups: F7), boss logic (F12), threat detection (F9, F10), invulnerability flicker (F7-01), score and Graze on the HUD (PLANEJAMENTO Section 7 keeps them on Pause and Results), audio feedback (F13, cut pending the user), and any edit to `scenes/ui/hud.tscn`.
