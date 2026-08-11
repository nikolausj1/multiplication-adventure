---
title: "Golden Guardians - the post-map mastery mechanic"
created: 2026-08-10
modified: 2026-08-10
version: 1.0
author: Claude Opus 5 (claude-opus-5)
tags:
---

# Golden Guardians

The single mechanic for everything after the map is beaten. Replaces the Master
Quest progress bar and rules out the alternatives that were considered alongside
it (trophy hall, mastery-tinted times table, any child-facing fact counter).

## Why this shape

Beating the Storm Titan is the emotional peak of the game. The risk with any
post-map content is that it reads as "you thought you were done, you were not",
which is a punch in the gut for a seven-year-old. Golden Guardians avoids that
because nothing is ever presented as unfinished. There is no counter at zero, no
checklist, no percentage. There is only a guardian that has started to stir, and
a shinier version of a fight he already enjoyed.

The mechanic is also close to free, because **the boss fight is already the exact
instrument that produces mastery**. From `PromotionEngine`:

```swift
case .fluency:
    if FluencyThreshold.isFast(responseTime, threshold: fluencyThreshold) {
        f.fluencyFastCount += 1
        f.fluencyFastDays.insert(DayStamp.of(now))
    }
    if f.fluencyFastCount >= fluencyGoal && f.fluencyFastDays.count >= fluencyDaysGoal {
        advance(&f, to: .mastered)
    }
```

Mastery requires FAST correct answers. Boss questions are already built
`format: .fluency, timed: true`, drawn from the weakest facts first. A boss fight
is a timed fluency test wearing a costume. Boss answers already run through the
full promotion path: `service.record(...)` is called before the
`bossWorldIndex == nil` branch, which only gates XP and streak flourishes.

## The three engine facts that shape the design

1. **Mastery is day-gated.** `fluencyGoal = 3`, `fluencyDaysGoal = 2`. Three fast
   corrects across at least two distinct calendar days. No single session can
   master anything. This is deliberate anti-cramming and the design leans into
   it: the endgame is a short ritual across a few days, not one long grind.
2. **The current boss pool cannot see low facts.** `buildBossSession` filters
   `$0.introduced && $0.stage >= .recall`. A fact still at `.recognition` is
   invisible to every boss fight, forever. Left unfixed, a child could stall at
   74 of 77 with no reachable path. Fixing this is mandatory, not optional.
3. **Worlds already own tables.** `WorldCatalog.slots` plus
   `WorldCatalog.facts(inWorld:)` give a per-world fact set with no new
   modelling:

   | World | Tables | Facts | Guardian |
   |---|---|---|---|
   | Highland Trail | 0, 1, 2, 10 | 10 | Granite Giant |
   | Shipwreck Cove | 5, 11 | 10 | Tidal Kraken |
   | Jungle Temple | 3, 4 | 15 | Jade Jaguar |
   | Desert Canyon | 9 | 9 | Sandstorm Scorpion |
   | Frozen Summit | 6 | 10 | FrostFang Dragon |
   | Volcano Depths | 7 | 11 | Magma Fist |
   | Sky Citadel | 8 | 12 | Storm Titan |

## Behaviour

### Availability

Golden Guardians unlock when every world is cleared
(`clearedSet.count == WorldCatalog.count`). Before that, nothing changes anywhere
in the app.

A world offers a golden rematch when it is cleared AND at least one of its own
facts is not yet `.mastered`. When every fact a world owns is mastered, that
world is **gilded**, permanently.

### The stirring hint

This replaces every counter. A world with unmastered facts shows its guardian
stirring: a slow, low-amplitude pulse on the node plus a faint ember or aura in
the world's palette colour. The world with the FEWEST unmastered facts stirs most
strongly, so the nearest goal draws the eye without ever stating a number.

Gilded worlds stop stirring and gain a gold ring, distinct from the existing
green "boss beaten" check. The two states are independent and both are true
achievements: the check means the guardian fell, the ring means the tables are
known.

No text, no fraction, no percentage is shown to the child at any point.

### The golden fight

Entered by tapping a stirring world's node. Differences from the normal boss:

- **World-scoped.** Questions come from `WorldCatalog.facts(inWorld:)` for that
  world only, unmastered facts first, topped up with that world's mastered facts
  if the pool is short. This is what makes "I need to work on my eights, that is
  Sky Citadel" true. The normal boss stays globally scoped and is unchanged.
- **Format follows the fact, which closes the straggler hole.**
  - `.stage >= .recall` serves as `.fluency`, timed. Counts toward mastery, can
    land a critical hit.
  - `.stage == .recognition` serves as `.recognition`, multiple choice, untimed.
    Advances the ladder so the fact becomes fluency-eligible on the next
    rematch. Lands a normal hit only, never a critical, and does not feed the
    speed baseline. This mirrors how `trueFalse` is already handled as
    `verifyOnly` in `PromotionEngine`.
- **Appearance.** The guardian's idle video is tinted gold and carries a
  particle layer. No new video renders are required.
- **Soft fail.** The guardian escapes rather than defeating the player. Per
  answer promotions are already recorded regardless of the outcome, so progress
  is inherently kept. Only the presentation changes: no failure screen, no
  "So close!", just the guardian retreating and an invitation to come back. The
  85% pass bar still controls whether the world gilds, not whether the session
  counted.

### Gilding

When the last of a world's facts reaches `.mastered`, mid-fight:

- The guardian's defeat plays in full gold.
- A tier 3 milestone fires (`MilestoneEngine` already supports tiers), naming the
  tables: "The eights are yours."
- The node gains its permanent gold ring and stops stirring.

When all seven are gilded, the existing tier 4 completion milestone fires and the
certificate gains its gold seal (see the decision below).

## Decisions required before implementation

1. **When is the certificate earned?** Today it is gated on 77 of 77, which means
   beating the map leaves the trophy locked. That is the false summit this whole
   design exists to avoid. **Recommendation: award the certificate at map
   completion**, and have the gold seal added to it when all seven worlds gild.
   One artifact, upgraded, rather than a reward withheld.
2. **Does the Master Quest bar survive?** **Recommendation: remove it.** It is the
   child-facing counter this mechanic is designed to replace, and leaving both
   means the stirring hint competes with a number.
3. **Is the normal per-world rematch (non-golden) still wanted?** Not required by
   this spec. Gilded worlds could still offer a plain rematch for fun.

## Explicitly not built

- Trophy hall / guardian museum
- Mastery colouring on the times table chart
- Any child-facing "X of 77"
- Per-world fact counts shown to the child
- A second certificate

## Acceptance criteria

1. From a profile with all seven worlds cleared and any distribution of
   unmastered facts, playing only golden rematches on two or more distinct days
   reaches 77 of 77. No normal quests required.
2. No fact can be permanently unreachable. Specifically, a fact at
   `.recognition` must be servable by a golden fight and must advance.
3. No screen visible to the child displays a fraction, percentage or fact count
   at any point in the post-map phase.
4. Losing a golden fight never reduces progress and never shows a failure state.
5. Nothing in the pre-map experience changes in any way.
6. Golden fights write to the scheduler through the existing `record(...)` path.
   No new promotion rules are introduced.

## Verification plan

The engine harness can prove criterion 1 headlessly, which matters because the
day gate makes manual testing slow:

- Extend `Tests/EngineSmokeTest.swift` with a simulation that seeds a profile at
  "map beaten, N facts unmastered", then runs simulated golden rematches with a
  synthetic clock advancing one day per round, asserting convergence to 77 of 77
  within a small number of days and asserting no fact is ever unreachable.
- Run the existing 10 day pacing simulation (`-dumpQuestPlan -dumpSlow`) to
  confirm pre-map behaviour is untouched.
- On device, confirm the stirring hint, the gold tint and the soft fail read
  correctly on both iPhone landscape and iPad, since every recent presentation
  bug in this app has been compact-height specific.

## Estimated cost

Roughly two to three days. The bulk is the world-scoped, mixed-format session
builder. The tint, the stirring hint and the gilded node state are small. The
engine test is worth the extra half day because the day gate makes the mechanic
impossible to validate by hand in one sitting.
