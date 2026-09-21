# Stage Progression Specification

Date: 2026-09-20. Language: English. Player-facing labels remain Portuguese.

## Status and relationship to the game design

The user approved the hybrid structure: progression challenges in Stage 1, one miniboss in Stage 2, an intermediate checkpoint in each stage, and a checkpoint before each final boss. [PLANEJAMENTO.md](PLANEJAMENTO.md) defines the shared game mechanics. This document defines stage progression and checkpoint details.

Full resource restoration on first checkpoint activation and retry is approved. Encounter counts, timings, and reward placement remain concrete defaults for playtesting, not measured results. Preserve the approved structure and checkpoint behavior when tuning them.

## Shared encounter rules

- A route progresses from entrance to destination through connected 3D combat volumes. The player controls forward movement and can orbit targets inside each volume.
- Use two common enemy types: **Spirit**, a moving enemy that fires aimed bursts; **Sentry**, a floating enemy that fires spaced fans.
- Enemies visibly appear before shooting. Initial anticipation time: 1 second. Aimed attacks sample the player's position before firing rather than tracking perfectly throughout the burst.
- Combat gates open when their listed enemies/objectives are defeated. Traversal segments finish when the player enters the exit volume. Timings are targets, never automatic completion triggers.
- Gates, rings, barriers, and seals have readable world-space visuals. Closed gates glow with hostile energy; cleared gates open visibly and reveal the next destination. No written objective list or tutorial interruptions.
- Gate barriers span the full allowed flight volume, including vertical routes. They cannot be bypassed by flying above or below the scenery.
- Required enemies remain inside reachable bounds. An enemy accidentally leaving the volume is repositioned to a valid spawn location, not left blocking completion forever.
- Completed encounters stay completed until the player explicitly restarts the stage or restores an earlier checkpoint. Re-entering a trigger does not spawn another wave or award another reward.
- Reward bundles contain the exact number of individual power pickups listed below. Pickups are optional; progression never requires collecting them. A player who misses upgrades must still be able to win at lower power.
- Bombs damage objective targets and enemies normally. They do not skip progression flags or reveal an objective before its guards have been cleared.
- Clear remaining hostile bullets when a combat gate opens, before a checkpoint activates, and between boss phases. Do not grant graze for cleared bullets.

## Stage 1 — Floresta das Lanternas

### Intended experience

Introduce the ship, readable aimed fire, vertical movement, and power growth through play. Increase complexity from a single threat type to mixed waves, then test those skills against a three-phase guardian. No miniboss in this stage.

Target uninterrupted active duration: **240 seconds / 4 minutes**. Individual segments can vary; measure the complete stage after tuning.

| ID | Segment | Target | Entry → player action → completion | Reward / checkpoint |
| --- | --- | --- | --- | --- |
| S1-01 | Forest approach | 15 s | Stage starts → fly through an open lane toward lanterns at different heights → enter the first clearing | No enemies; safe space to move |
| S1-02 | Spirit clearing | 30 s | Enter clearing → defeat two waves of three Spirits, second wave starting after the first is defeated → all six defeated | Final wave drops 5 power items; collecting all raises power 1 to 2 |
| S1-03 | Lantern ascent | 25 s | Enter rising passage → ascend around tree crowns and destroy two Sentries at different heights → both defeated and player reaches upper exit | One shield pickup beside the upper exit |
| S1-04 | Sealed portal | 35 s | Approach portal → defeat three Sentries linked visibly to the barrier, in any order → all three defeated opens the gate | Cross the gate to activate CP1-A |
| S1-05 | Shrine approach | 40 s | Leave CP1-A → defeat two mixed waves, each with two Spirits and one Sentry → all six defeated | Final wave drops 5 power items; all Stage 1 power items collected yields level 3 |
| S1-06 | Sanctuary entrance | 10 s | Follow the now-open path → enter the safe sanctuary arch | Activate CP1-B; continue across a separate arena threshold |
| S1-07 | Lantern Guardian | 85 s | Enter arena → defeat all three boss phases → final health segment depleted | Boss score, stage results, and campaign continuation or isolated-stage replay |

### Spatial layout and readability

The entrance is broad and unobstructed. Lantern chains guide the player upward, while trees create depth references without narrow precision tunnels. The portal challenge requires changing angle and altitude, not finding hidden keys. Link each Sentry to the portal with a visible energy beam; destroying a Sentry removes its beam.

The shrine approach combines previously introduced enemies instead of introducing another enemy type. Keep the active wave ahead or beside the player when it appears; off-screen threats require the shared warning behavior.

### Final boss sequence

Use a fully navigable aerial clearing with a shrine below for spatial reference. Three health segments, approximately 25/25/35 seconds under the initial damage balance.

1. **Ritual das Lanternas:** emit expanding rings at alternating heights with broad angular gaps. Between rings, rotate the next gap. The player can orbit through gaps or change altitude. Include a sparse aimed burst between ring emissions so remaining at one height is not a universal safe solution.
2. **Fios de Luz:** briefly charge, aim at the player's sampled position, then fire a short burst. Alternate this with paired fans at the player's approximate altitude. The player should move after the aim cue and use focus for fine correction.
3. **Dança do Crepúsculo:** alternate a ring sequence and aimed bursts, followed by a short repositioning window. Increase coordination requirements rather than doubling all bullet counts.

Defeat clears hostile fire and changes the shrine's lighting from corrupted to calm. Use a short visual resolution and results screen; no mandatory story dialogue.

## Stage 2 — Montanha da Tempestade

### Intended experience

Combine known mechanics with stronger vertical demands and a mid-route duel. The seals offer local freedom of order within a linear journey. The miniboss introduces rotating patterns used again by the final boss.

Target uninterrupted active duration: **360 seconds / 6 minutes**. The academic minimum is **300 seconds of active gameplay for this stage alone**. Reserve enough real encounter content to meet that minimum during efficient play; do not enforce it with forced waiting.

| ID | Segment | Target | Entry → player action → completion | Reward / checkpoint |
| --- | --- | --- | --- | --- |
| S2-01 | Mountain ascent | 25 s | Stage starts → climb between rock formations and defeat two Spirits → enter the first ledge volume | No power reward |
| S2-02 | Crossfire ledges | 35 s | Enter ledges → defeat two waves, each with two Spirits and one Sentry, at staggered heights → both waves cleared | 2 power items after final wave; one shield pickup near exit |
| S2-03 | Three storm seals | 65 s | Enter basin → clear guards and destroy each of three seals in any order → all seals destroyed opens the upper gate | Each seal drops 1 power item; crossing the gate activates CP2-A |
| S2-04 | Tempest Sentinel miniboss | 50 s | Leave CP2-A and cross duel threshold → defeat both miniboss phases → miniboss defeated opens exit | 500 score and one shield pickup |
| S2-05 | Final ascent | 45 s | Leave duel arena → defeat two mixed waves, each with two Spirits and one Sentry, while changing altitude → all enemies defeated opens summit route | 2 power items from final wave |
| S2-06 | Summit threshold | 10 s | Fly to summit arch → enter safe threshold volume | Activate CP2-B; boss starts beyond a separate arena trigger |
| S2-07 | Storm Guardian | 130 s | Enter summit arena → defeat all three phases → final health segment depleted | Boss score and victory results |

### Three-seal progression challenge

Place seals at low, middle, and high positions around a central basin. All three positions are visible from the entrance. Each seal has two linked Sentry guards. Only the selected/approached seal's guards engage initially; activate its group once when the player enters its approach volume or shoots a guard. The player may retreat and activate another group, accepting extra pressure.

The seal is visibly shielded while either linked guard lives. Its shield disappears when both die. The exposed seal becomes a stationary target that aim assist can select; destroy it with ordinary fire or bomb damage. Set its health low enough that breaking it is a brief confirmation after the combat challenge.

Each broken seal changes one of three large portal lights. Opening the third light releases the gate. No keys, inventory, text instructions, random objective placement, or respawning guards.

Direct Stage 2 starts at power 2. Collecting the two ledge pickups and three seal pickups reaches power 3 before the miniboss. Campaign players already at power 3 receive excess-pickup score under the shared rules.

### Miniboss — Sentinela da Tempestade

Reuse the common Sentry model with a larger silhouette, distinct color, and rotating visible parts. This is one additional encounter, not a third fully animated final-boss asset.

- Two health segments and one brief phase transition. Initial phase targets: 20 and 30 seconds.
- Phase 1: alternating aimed bursts with explicit charge flashes.
- Phase 2: rotating fans with broad gaps and occasional altitude shifts. This previews the final boss's spiral motion at lower density.
- Free movement around the enemy remains available. Track the player's general altitude when preparing the next pattern rather than leaving a permanent safe ceiling.
- Phase changes clear hostile fire. Defeat opens the exit and awards its reward once.
- No additional checkpoint after the miniboss. Death during the final ascent restores CP2-A and repeats the miniboss; reaching CP2-B removes that repetition from later retries.

### Final boss sequence

Use a large volume between peaks with visible clouds below and mountain faces as depth references. Initial phase targets: 40/40/50 seconds.

1. **Espiral da Tempestade:** rotating streams form moving gaps. Gradually move the emission height so the player combines orbiting with ascent/descent. Keep safe corridors wide enough for focused movement.
2. **Círculos do Trovão:** show a brief ring-shaped cue at the next attack height, then emit expanding rings. Alternate high and low threats rather than filling the whole volume simultaneously.
3. **Olho da Tormenta:** alternate aimed bursts and spirals, then leave a short repositioning window. Combine learned patterns with bounded density; avoid simultaneous patterns whose individually safe gaps contradict each other.

The boss's defeat clears bullets, reduces storm intensity, and reveals the sky. Finish the two-stage story arc with visual feedback, results, and credits access.

## Checkpoint contract

### Activation and restore defaults

Checkpoints are safe arches with a brief glow and sound. Activate automatically once after the preceding encounter is complete and the player enters the arch. The next combat trigger is separate so activation occurs before new attacks begin.

**Approved rule:** both first activation and retry restore 100% health, one shield, and two bombs. This makes a checkpoint a visible rest point and avoids rewarding deliberate death for a refill. Revisiting an already activated checkpoint during the same attempt does not refill resources again.

Snapshot the current power level and partial power progress, score, graze count, successful-path active time, bombs-used statistic, stage identifier, next encounter, and completed encounter/objective flags. Refill resources before recording the checkpoint state. Ammo refill does not erase the bombs-used statistic.

On Retry, restore the snapshot and remove all transient enemies, bullets, pickups, damage timers, target locks, and queued spawns from the failed segment. Reconstruct only encounters at or after the saved resume point. Completed rewards and objectives remain resolved. Respawn facing the next destination with no incoming projectiles.

| Checkpoint | Activation location | Retry starts at | Previous content remains complete |
| --- | --- | --- | --- |
| Stage 1 entry | Stage load | S1-01 | None |
| CP1-A | Beyond the cleared sealed portal | S1-05 | S1-01 through S1-04 |
| CP1-B | Sanctuary entrance | S1-07 arena approach | Stage 1 route |
| Stage 2 entry | Stage load | S2-01 | None |
| CP2-A | Beyond the three-seal gate | S2-04 arena approach | S2-01 through S2-03, including seal order/state |
| CP2-B | Summit threshold | S2-07 arena approach | Stage 2 route and miniboss |

Retry always uses the latest activated checkpoint. Restart Stage explicitly discards checkpoint progress and restores the stage-entry snapshot. Return to Menu ends the run. Checkpoints remain session-only.

### Time and score integrity

Successful-path time equals committed time through the last checkpoint plus active time since that checkpoint. Retrying rolls back the failed segment's time and statistics. Pauses, menus, and failed attempts do not inflate the displayed completion time. Keep a separate uninterrupted-clear measurement for the academic duration check.

For each stage-clear test, record whether checkpoints were retried, starting power, bombs used, and measured active duration. Validate Stage 2 with no deaths and strong play before claiming the five-minute requirement is satisfied.

## Agent implementation contract

Represent each segment with a stable ID, entry condition, spawn configuration, completion condition, one-time rewards, gate state, and checkpoint reference. Encounter progress is owned by the stage director; enemy death reports an event rather than directly loading another stage.

Use explicit states: inactive → active → completed. Checkpoint restore rebuilds these states from the snapshot. Gate opening and reward spawning must be idempotent: duplicate callbacks cannot award or spawn twice.

Implement and validate the shared encounter/checkpoint behavior in a simple arena before decorating the two routes. Keep the complete player action and exit condition visible in the segment definition so another agent can implement a segment without inventing missing progression logic.

## Acceptance checks for stage progression

- [ ] Stage 1 progresses through all seven segments and contains no miniboss.
- [ ] Stage 2 progresses through all seven segments and includes one two-phase miniboss.
- [ ] Every required enemy and seal is reachable with keyboard and gamepad controls.
- [ ] All six seal orders can open the Stage 2 gate; revisiting a seal cannot reset it or duplicate a reward.
- [ ] Flying over/under a locked gate cannot skip the required encounter.
- [ ] A bomb kill of the last guard/enemy advances the encounter exactly once.
- [ ] Dying before and after each checkpoint restores the correct segment and resources.
- [ ] Death after the miniboss but before CP2-B restores CP2-A; death at the final boss restores CP2-B.
- [ ] Power progress, score, graze, bombs-used statistics, and successful-path time restore without farming failed attempts.
- [ ] Entering a checkpoint twice cannot repeatedly refill resources.
- [ ] Restart Stage and isolated stage selection use the correct stage-entry values.
- [ ] Every route is readable without tutorial boxes or written objective lists.
- [ ] Stage 2 uninterrupted efficient clear reaches at least five active minutes through actual gameplay.
- [ ] Boss patterns remain avoidable from different heights and do not permit a permanent risk-free perch.
