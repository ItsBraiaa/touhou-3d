# F12-04 Tempest Sentinel and Storm Guardian

Status: cut (pending the user, 2026-09-23)
Type: integration
parallel-safe: no
Depends on: F12-03, F9-03, and a decision by the user to un-cut Stage 2 gameplay

## Intended scope

This ticket also carries all Stage 2 gameplay integration:

- The two-Phase **Sentinela da Tempestade** miniboss (S2-04): it reuses the Sentry visual larger, with rotating parts (MODEL_SELECTION). Phase 1 is aimed bursts with charge flashes; Phase 2 is rotating fans with altitude shifts. 500 score and a Shield Pickup once. It opens the exit, and there is no checkpoint after it.
- The three-Phase **Guardião da Tempestade** (S2-07): Espiral da Tempestade, Círculos do Trovão, Olho da Tormenta; victory results on defeat.
- The Stage 2 Director: Stage 2 content S2-01 to S2-07 with CP2-A and CP2-B, the three Seals (F9-03) with Guard passivity, portal lights and per-seal rewards, and the Gates `Gate_S2_01..05`. Also the five-minute efficient-clear measurement (STAGE_DESIGN acceptance).

## Why it is cut

The deadline is 2026-09-24, and every scheduled ticket before it (F4 to F12-03, F14) already fills the remaining sessions. Stage 2 is SCENE_READY_STATIC only: no Stage 2 content exists, and neither the Tempest Sentinel scene nor `storm_guardian.tscn` exists (ROADMAP "Requests to Astra", F12). The planning pass marked it cut rather than scheduling placeholders for Stage 2 geometry. Scope changes are the user's call (ROADMAP "Risk").

## Consequences while cut

- Campaign final victory needs a Stage 2 completion that is unreachable, so F11-02 drives `RunState` directly for that path and records the gap.
- F9-03 (Seals) has no scheduled consumer.
- F4-03's two-Phase HUD layout is supported but not exercised by a real boss. The academic "Stage 2 at least 300 s of active gameplay" check cannot be claimed; F14-02 marks it "not verified (cut)".

## What un-cuts it

1. The user decides to schedule Stage 2 gameplay.
2. Astra delivers Stage 2 gameplay markers as authored (`docs/STAGE_02_HANDOFF.md` is ready), plus `scenes/enemies/tempest_sentinel.tscn` and `scenes/enemies/storm_guardian.tscn` with the GUIDE Section 5 tree and actual clip names.
3. A planning pass then splits this stub into real tickets (Stage 2 content draft, Stage 2 Director integration with Seals, Sentinel, Storm Guardian, duration measurement) in the house format.

## Kickoff prompt

None while cut.
