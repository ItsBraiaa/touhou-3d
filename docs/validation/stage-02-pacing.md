# Stage 2 pacing review — D-06 pass 1

2026-09-23. This is a **planning estimate, not a measured clear**. F12-04's Stage 2 content is present and structurally reviewed, but F9-02's Spirit/Sentry definitions, F12-05's Director and Seals, F12-06/F12-07's boss content, and F11-01's Results flow have not all landed. The academic claim of at least 300 active seconds remains **not verified** until an uninterrupted strong-play run is measured.

## Content and reward audit

The seven Encounter files preserve F12-04's approved order, completion conditions, Wave markers and kinds, gates, objectives, and checkpoint resume points. They contain 20 common enemies and two boss markers. S2-02 has two Power and one Shield; S2-03 has one Power reward under each Seal; S2-04 has one Shield; S2-05 has two Power. That is exactly seven Power and two Shield Pickups, with no reward in S2-01, S2-06 or S2-07. S2-03's rewards point to `Seals/SealN/RewardOrigin`, so F12-05 can deliver each when its Seal breaks. No content mismatch was found.

A Direct Stage 2 starts at Power Level 2. If the player collects both S2-02 Power items and all three Seal rewards, the five pickups reach Power Level 3 before S2-04. S2-05's two then award excess-pickup score. A Campaign player already at Power 3 treats all seven as excess. Pickups are optional, so neither the upgrade nor this timing is guaranteed in a playthrough.

CP2-A is now `Portão dos Selos` (was `CP2-A`), and CP2-B is `Limiar do Cume` (was `CP2-B`). The 1.0 s second-Wave delays in S2-02 and S2-05 stay unchanged: they separate sequential combat rather than create a long wait. Every Stage 2 `.tres` reviewed here has `metadata/reviewed = true`; `metadata/dev = true` remains until runtime verification.

## Estimate and assumptions

`base_speed` is 12 units/s. The straight Z spans total 658 units, or 54.8 s at that speed before climbs, lateral Seal visits, alignment, combat movement or dodging. The floor and Seal heights (43, 65, 86) make the straight-line figure a lower bound. The encounter target column is STAGE_DESIGN's 25/35/65/50/45/10/130 s, totaling 360 s.

Provisional common-enemy health is 20 per Spirit and 30 per Sentry, following F9-02's proposal of about 2 and 3 seconds of Power 1 fire at the current 10 main shots/s. Provisional Seal health is 10. These are **assumptions**, not the later authored values. Current weapon exports yield at most 18 shots/s at Power 2 (10 main + two Familiars at 4 each) and 23.3 at Power 3 (10 + two at 6.67); each deals 1 damage. For the efficient estimate, 75% hits give about 13.5 and 17.5 effective damage/s. For normal play, 60% hits give about 10.8 and 14.0. Boss Phase durations use the STAGE_DESIGN targets (20/30 and 40/40/50 s) pending F12-06/F12-07 health; normal-play boss times scale by 75/60. Transitions use D-07's 0.75 s cap per Phase change, never invulnerability padding.

| Segment | Target | Z span / straight flight | Efficient working estimate | Normal working estimate | Main time sources |
| --- | ---: | ---: | ---: | ---: | --- |
| S2-01 | 25 s | 111 / 9.3 s | 19 s | 22 s | 40 assumed Spirit health, first Anticipation, climb. |
| S2-02 | 35 s | 93 / 7.8 s | 29 s | 35 s | 140 assumed enemy health, 1 s Wave delay, two Anticipations, height changes. |
| S2-03 | 65 s | 123 / 10.3 s | 42 s | 53 s | 180 guard health, three brief Seals, lateral approaches and climb; efficient case uses two Bombs on guards before CP2-A. |
| S2-04 | 50 s | 70 / 5.8 s | 54 s | 68 s | 20 + 30 s provisional boss combat, one transition; CP2-A refills two Bombs. |
| S2-05 | 45 s | 108 / 9.0 s | 28 s | 33 s | 140 assumed enemy health, 1 s Wave delay, two Anticipations, ascent. |
| S2-06 | 10 s | 28 / 2.3 s | 7 s | 8 s | Safe climb and arch alignment; no mandatory wait. |
| S2-07 | 130 s | 125 / 10.4 s | 140 s | 173 s | 40 + 40 + 50 s provisional boss combat, two transitions; CP2-B refills two Bombs. |
| **Total** | **360 s** | **658 / 54.8 s** | **about 319 s** | **about 392 s** | Both figures are conditional estimates. |

The efficient budget includes about 45 s of route detours, climbing, aim alignment and dodging above straight flight; normal play adds about 15 s. It assumes six Bombs are used across the stage's entry and two checkpoint refills, with 20 damage each, and normal play uses three. It counts the two 1 s Wave delays and Anticipation, and subtracts only damage time Bombs plausibly save. The estimate sits about 19 s above the 300 s floor, a thin margin. Final boss health and measured hit rates can easily change it.

No measured Results Clear Time, Retry count or Bomb count is available. F11-03 and the human pass must record a Direct Stage 2 clear with no deaths, starting Power 2, the Bombs used, and whether the player retried a checkpoint. If the efficient measured clear falls below 300 s, D-06 pass 3 should first tune boss Phase health and attack patterns; increasing the 1 s Wave delays into forced waits would violate STAGE_DESIGN.

## Pass 2 — explicit Seal health (2026-09-24)

Each of Encounters/S2-03/Seals/Seal1..3 now explicitly exports health = 10 (inherited default 10 → authored 10). This preserves the value observed in F12-05's two Seal-order walkthroughs. At the pass-1 Power 2 assumptions of 13.5 effective DPS / 10.8 normal DPS, an exposed Seal takes about 0.74 / 0.93 seconds of fire; at Power 3 it is shorter. Guard removal remains the challenge and the Seal remains a brief confirmation. Bomb damage can destroy an exposed Seal, never a shielded one. No other Stage 2 scene property changed.

D-05 has since landed shared Spirit health 30 and Sentry health 45, superseding pass 1's 20/30 assumptions. Keeping every other provisional budget unchanged, the incremental health adds 20/13.5 s in S2-01, 70/13.5 in S2-02, 90/13.5 in S2-03 and 70/17.5 in S2-05: about 17.3 s efficient. Normal uses 10.8/14.0 DPS and adds about 21.7 s. The revised conditional totals are therefore **about 336 s efficient and 414 s normal**, still estimates, still dependent on pass 3's actual boss health/attack review. The historical pass-1 table above is retained with its original assumptions. No measured five-minute claim is made.

Reward structure remains seven Power and two Shield pickups; the two ledge Power plus three Seal Power items permit Power 3 before S2-04. F12-05's walkthrough observed precisely those five early Power ids. Boss tuning and the uninterrupted strong-play measurement remain pending. Gate: tools/lane.ps1 land; no new tests or content structure changes.

## Pass 3 — integrated bosses and reviewed values (2026-09-24)

F12-06 and F12-07 have replaced both Sentry stand-ins. The measured locked Power-3 boss hit rate from `docs/validation/bosses.md` is 22.1 damage/s at about 38 units. Phase health now follows the Stage 2 target durations at that rate:

| Boss | Phase health before → after | Phase duration at 22.1/s | Other change |
| --- | --- | --- | --- |
| Tempest Sentinel | 520/780 → 440/660 | 19.9/29.9 s | Charged aim and rotating fan numbers retained. |
| Storm Guardian | 1040/1040/1300 → 885/885/1105 | 40.0/40.0/50.0 s | Spiral volley 8 → 6 projectiles for wider corridors. |

Both Definitions and all five boss patterns carry `metadata/reviewed = true` alongside `metadata/dev = true`. Named Attacks, 500/1000 score, 1.0 s entries, and 0/0.75 s transitions stay as drafted. The 20-damage Bomb is below the smallest 440-health Phase. Sentinel aim alternates high and low; fans alternate following the player's height with a fixed high shift. Storm spirals climb and descend, rings alternate high and low with a 72° gap, and the final Attack schedules aim and spiral steps in sequence. These values are readable proposals until a full play pass checks actual safe corridors.

The pass-2 route estimate remains **about 336 s efficient** when the boss can sustain the observed locked hit rate. The provisional 50 s and 130 s boss budgets in the historical table are now represented by actual health rather than assumptions. A normal route with about 75% of that boss hit rate raises its boss time by roughly 60 s against the efficient route; combining it with the pass-2 common-enemy and traversal assumptions gives **about 426 s normal**. Both totals include the two 1 s Wave delays, 10-health Seals, short Phase transitions, and Bomb savings. They are estimates, not Results Clear Times.

The exact rewards remain seven Power and two Shield. A Direct Stage 2 player starting at Power 2 can collect five Power before the miniboss and reach Power 3; a Campaign player already at Power 3 gets excess-pickup score. No uninterrupted strong-play Stage 2 clear was measured. The ≥300 active-second acceptance line remains **not verified** and belongs to the F11-03/F14-02 human protocol. No content structure bug or Stage-2-only common-enemy request was found.
