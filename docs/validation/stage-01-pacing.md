# Stage 1 pacing review — D-05

2026-09-23. **Estimate, not a measured clear.** F10-03, F11-01 and F12-03 have not landed, so the complete Retry, Results and Lantern Guardian route cannot supply a Clear Time yet. The design target is about 240 active seconds. No five-minute claim is made for Stage 1.

## Reviewed values and route

The ten Stage 1 resources retain their approved structure: seven Encounters, 17 common enemies, one boss, two five-item Power rewards, one Shield, four Gates, and CP1-A/CP1-B resume points. The second Wave delays in S1-02 and S1-05 stay at 1.0 s; they separate two sequential groups without creating a long idle interval. Every reviewed Stage 1, enemy and pattern Resource carries `metadata/reviewed = true` beside its existing `metadata/dev = true`.

| Value | Before | Reviewed |
| --- | ---: | ---: |
| Spirit health | 20 | 30 |
| Sentry health | 30 | 45 |
| Spirit attack interval | 1.5 s | 1.4 s |
| Sentry attack interval | 2.0 s | 1.8 s |
| Spirit aimed-burst spread | 12° | 14° |
| Sentry fan spread | 70° | 78° |
| CP1-A display name | `CP1-A` | `Portal Selado` |
| CP1-B display name | `CP1-B` | `Entrada do Santuário` |

Movement values and the remaining pattern numbers stay as drafted. Spirit and Sentry `HitVolume` spheres remain radius 1.0 and 0.9 at the visual roots' origins; the arena capture in `docs/validation/enemies.md` shows that these centers cover the bodies. Widening them would enlarge hits beyond the visible silhouettes. Layer, mask and monitoring flags remain unchanged.

`EnemyActor` has no `anticipation_clip` export and still uses its scale pulse. The visual scenes now record the candidate clips as root metadata: `Yes` for both Spirit variants and `Punch` for both Sentry variants. Each source clip is 1.167 s; playback speed about 1.17 would fit the existing 1.0 s Anticipation. The mid-pose gallery in [stage-01-anticipation.png](stage-01-anticipation.png) was rendered from the four variants and inspected: Spirit reaches forward, while Sentry opens its wings and arms, which read as a windup rather than contact at the preview distance. These clips are **not played in combat yet**; that is an `EnemyActor` follow-up for trunk. Godot's existing visual validator reported `ENEMY_VISUAL_QA failures=0` after the metadata change.

## Conditional time estimate

Straight Z travel totals 519 units, or 43.3 s at `base_speed` 12. Combat estimates assume sustained Target Lock, 75% useful hits, 8.5 damage/s at Power 1 from the measured 30-unit Spirit run, about 13.5 at Power 2 and 17.5 at Power 3 from the current 10 main shots/s plus Familiar cadence. They include target acquisition, climb/alignment, the initial Anticipation, and the 1 s second-Wave delays. Multiple enemies can fire concurrently; their health is still cleared by the one player weapon. Bomb use can lower these figures. S1-07 uses STAGE_DESIGN's provisional 25/25/35 s because the Lantern Guardian content is not integrated.

| Segment | Target | Z span / straight travel | Combat basis | Estimated active time |
| --- | ---: | ---: | --- | ---: |
| S1-01 approach | 15 s | 77 / 6.4 s | Safe flight and lane alignment | 9 s |
| S1-02 Spirit clearing | 30 s | 77 / 6.4 s | 6 × 30 health ÷ 8.5 DPS ≈ 21 s; two cues, Wave delay and aiming | 35 s |
| S1-03 lantern ascent | 25 s | 77 / 6.4 s | 2 × 45 ÷ 13.5 ≈ 7 s; climb and height changes | 24 s |
| S1-04 sealed portal | 35 s | 82 / 6.8 s | 3 × 45 ÷ 13.5 = 10 s; three heights and gate alignment | 29 s |
| S1-05 shrine approach | 40 s | 82 / 6.8 s | (4 × 30 + 2 × 45) ÷ 13.5 ≈ 16 s; two cues and Wave delay | 31 s |
| S1-06 sanctuary entrance | 10 s | 27 / 2.3 s | Safe arch alignment | 6 s |
| S1-07 Lantern Guardian | 85 s | 97 / 8.1 s | Reviewed health 550/550/775 ÷ measured 22.1 Power-3 DPS = 24.9/24.9/35.1 s, plus 1.5 s transitions; approach partly overlaps | about 87 s |
| **Stage 1** | **240 s** | **519 / 43.3 s** | **Conditional estimate; no Results capture** | **about 221 s** |

Power 1 applies through S1-02. Taking its five Power items makes S1-03 through S1-05 Power 2; taking S1-05's five makes S1-06 and S1-07 Power 3. These are collection assumptions, not guaranteed upgrades. A normal run with less accurate fire, more maneuvering and fewer Bomb hits could take about 260–280 s. The efficient estimate is roughly 19 s under the 240 s design target. S1-07 now uses the observed locked-shot ceiling; misses and dodges lengthen it. It remains an estimate, not a Results Clear Time. Bomb damage 20 is below the smallest Phase health 550.

## Five-minute fallback proposal — not applied

If Stage 2 slips and the user chooses the sprint's Stage 1 fallback, this estimate needs roughly 79 more active seconds. The levers below are ordered by implementation cost; none is part of D-05's committed values.

| Lever | Approximate gain | Cost in feel and scope |
| --- | ---: | --- |
| Raise common health from 30/45 to about 38/57 | 14–16 s | Longer fights, more repetitive shots; also lengthens Stage 2 because the definitions are shared. Shorter attack intervals increase pressure but provide no reliable duration, so they are not counted. |
| Raise Lantern Guardian Phase health enough for roughly 40–45 s more combat | 40–45 s | Risks repetitive patterns; D-07 Part C must keep all three Phases readable and Bomb damage below the smallest Phase health. |
| Add one three-Enemy Wave to both S1-02 and S1-05 | 22–26 s | New markers, content and Director contract work after F12-03; changes the approved encounter structure and needs the user's scope decision. |
| Increase the second-Wave `delay` | 0 s accepted | Idle padding would violate the no-forced-wait rule; a delay can only serve a short readable spawn separation. |

The first three gains sum to roughly 76–87 s, which could reach 300 s on this model. They are not evidence that a real clear reaches five minutes. F11-03 and the human pass must measure an uninterrupted strong-play clear, record starting Power, Bombs used and checkpoint retries, and revise the estimate from actual Results time.
