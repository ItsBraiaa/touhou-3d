# Touhou 3D (Guardiã dos Ventos)

A third-person 3D bullet hell in Godot 4 with two stages, built as an academic delivery. This glossary fixes the words used in code identifiers, engineering docs, tickets, and tests. Player-facing text is Portuguese and is not covered here.

## Language

### Run and progression

**Run**:
One playthrough from a menu start until results or a return to the main menu.
_Avoid_: session (as a player concept), playthrough, game

**Run Mode**:
The way a Run was started: **Campaign** (Stage 1 then Stage 2) or **Direct Stage** (one stage chosen from the menu, with its own entry resources).
_Avoid_: isolated stage, stage select mode, solo stage

**Stage**:
One complete route with its Encounters, Checkpoints, and final Boss. There are exactly two.
_Avoid_: level, map, world

**Encounter**:
A route unit with a stable ID (`S1-01` to `S2-07`), an entry condition, a completion condition, one-time rewards, and optional Gate and Checkpoint references. Its lifecycle is inactive, active, completed.
_Avoid_: segment, sector, combat volume, section, area (as a unit)

**Wave**:
A group of Enemies spawned together inside an Encounter, with an activation rule.
_Avoid_: spawn group, batch

**Gate**:
An openable barrier spanning the full flight volume that opens when its Encounter completes.
_Avoid_: portal, barrier, door, wall

**Seal**:
A guarded, destroyable objective in Stage 2. It is shielded while any linked Guard lives.
_Avoid_: objective (when the Seal itself is meant), crystal, key

**Objective**:
A named progression flag an Encounter can require, such as a destroyed Seal.
_Avoid_: quest, goal, mission

**Checkpoint**:
A safe arch that activates once per Attempt and records a Snapshot. Stage Entry behaves like an implicit Checkpoint.
_Avoid_: save point, respawn point

**Attempt**:
Play from a spawn until defeat or Stage completion. Retry and Restart each begin a new Attempt.
_Avoid_: life, try, death

**Retry**:
The player action that begins a new Attempt from the latest activated Checkpoint's Snapshot.
_Avoid_: continue, respawn

**Restart**:
The player action that begins a new Attempt from the Stage Entry Snapshot, discarding Checkpoints.
_Avoid_: reset, replay (as an in-run action)

**Snapshot**:
An immutable copy of run state recorded at Stage Entry or a Checkpoint: resume Encounter, resources, Power, score, Graze count, times, completed Encounters, and Objectives.
_Avoid_: save, save game, state dump

**Restore**:
Applying a Snapshot: rebuilding Encounter states, resources, and statistics, and removing everything from the failed Attempt.
_Avoid_: load, rollback, reload

**Active Time**:
Uninterrupted gameplay time inside an Attempt. Pauses and menus do not count.
_Avoid_: play time, elapsed time

**Clear Time**:
The displayed result: committed Active Time through the last Checkpoint plus the current Attempt's Active Time.
_Avoid_: successful-path time, completion time, total time

**Stage Director**:
The owner of Encounter progression, Waves, Objectives, Gates, Checkpoints, and Snapshots for the loaded Stage.
_Avoid_: level manager, game manager, controller (for this role)

**Session**:
The technical owner of the Run: Run Mode, stage transitions, results, pause, and Stage Entry state. Not a player-facing word.
_Avoid_: game state, global state

### Combat

**Health**:
The player's survivable damage budget, expressed as a percentage from 0 to 100.
_Avoid_: HP, hit points, life

**Shield**:
A one-charge protection that absorbs one complete hit and does not stack or regenerate.
_Avoid_: armor, barrier, extra life

**Invulnerability**:
The brief window after damage or a Bomb during which hits are rejected and no Graze is awarded.
_Avoid_: i-frames, immunity, grace period

**Bomb**:
A consumable charge that clears hostile Projectiles in a radius around the player and grants Invulnerability.
_Avoid_: special, super, spell card, ultimate

**Core**:
The small sphere at the ship's center that is the player's only damage volume.
_Avoid_: hitbox, hurtbox, hit point

**Graze Volume**:
The sphere slightly larger than the Core used to award Graze.
_Avoid_: graze box, proximity hitbox

**Graze**:
A score event awarded at most once per hostile Projectile that enters the Graze Volume without hitting the Core.
_Avoid_: near miss, scratch, dodge bonus

**Projectile**:
A bullet owned by the player or an enemy, simulated by the Projectile Field with a position, velocity, lifetime, and owner.
_Avoid_: bullet (in identifiers), shot (for the entity), danmaku

**Projectile Field**:
The single system that owns all Projectile state, movement, collision, Graze, and cleanup.
_Avoid_: bullet manager, projectile pool, bullet system

**Pattern**:
A parameterized Projectile emission shape: ring, fan, spiral, or burst.
_Avoid_: attack (for the shape), spell, barrage

**Attack**:
A named Boss behavior for one Phase, composed of Patterns and movement, with a Portuguese display name.
_Avoid_: spell card, move, ability

**Emitter**:
A named marker on an enemy from which a Pattern originates.
_Avoid_: muzzle (for enemies), spawn point (for projectiles), gun

### Player

**Power Level**:
The player's shot configuration tier, 1 to 3.
_Avoid_: power (alone, in identifiers), upgrade level, weapon level

**Power Progress**:
The count of Power Pickups collected toward the next Power Level.
_Avoid_: partial power, power fraction, experience

**Pickup**:
A collectible that attracts to the player at short range: **Power Pickup** or **Shield Pickup**.
_Avoid_: item, drop, collectible, loot

**Familiar**:
A small orbiting companion granted at Power Level 2 that adds shots and has no collision.
_Avoid_: option, drone, satellite, pet

**Focus**:
Holding the focus input to move slowly and make the Core more visible.
_Avoid_: slow mode, precision mode, walk

**Target Lock**:
The explicitly selected enemy that the camera frames and Aim Assist uses. Cleared by switch, release, death, or range.
_Avoid_: lock-on, focus target

**Aim Assist**:
Correction of player shots toward the Target Lock, respecting scenery occlusion.
_Avoid_: homing, auto-aim, tracking

**Flight Volume**:
The bounded 3D space the player may occupy in an Encounter, communicated by scenery and feedback.
_Avoid_: playable area, arena (for the whole stage)

### Enemies

**Enemy**:
A non-Boss hostile of one of two **Enemy Types**: **Spirit** (moving, aimed bursts) or **Sentry** (floating, spaced fans).
_Avoid_: common enemy, mob, minion, actor

**Guard**:
A Sentry linked to a Seal. The Seal is shielded while any of its Guards lives.
_Avoid_: guardian (reserved for boss names), protector

**Boss**:
A hostile with Phases and named Attacks. The Lantern Guardian and Storm Guardian have three Phases; the Tempest Sentinel has two.
_Avoid_: miniboss (as a separate concept), final boss (in identifiers)

**Phase**:
One health bar segment of a Boss with its own Attack. Depleting it clears hostile Projectiles and starts the next Phase.
_Avoid_: segment, health segment, stage (of a boss), form

**Anticipation**:
The visible cue an Enemy or Boss shows before firing.
_Avoid_: telegraph, wind-up, charge (as a noun)

### Content and structure

**Definition**:
A typed Resource authored in the Inspector that describes content: Encounter, Wave, Pattern, Attack, Boss, reward bundle.
_Avoid_: config, data file, template, blueprint

**Rules Core**:
A Node-free class holding gameplay rules, ticked explicitly and tested directly.
_Avoid_: model, logic class, service, core (alone, which means the damage Core)

**Adapter**:
A scene-attached script that reads input or scene state, drives a Rules Core, and renders its results.
_Avoid_: controller (generic), manager, wrapper
