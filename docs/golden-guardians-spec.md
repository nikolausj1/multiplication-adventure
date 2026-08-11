---
title: "Golden Guardians - the post-map mastery mechanic"
created: 2026-08-10
modified: 2026-08-11
version: 3.0
author: Claude Opus 5 (claude-opus-5)
tags:
---

# Golden Guardians

The single mechanic that carries the game past the map. Replaces the Master Quest
progress bar and rules out the alternatives considered alongside it (trophy hall,
mastery-tinted times table, any child-facing fact counter).

## The shape of the whole game

Four phases. Only phases 3 and 4 are new work.

### Phase 1: the unbeaten map (no changes)

Nodes are worlds. A world's boss is unknown until that world is beaten. Beating
a world reveals the next. Stars, quests, streaks and XP all behave exactly as
they do today. Nothing in this phase changes, and nothing hints at what follows.

### Phase 2: the map is beaten. Celebrate hard, pay everything out.

This is the moment he has been able to see since day one, and it gets the full
reward with nothing held back:

- The existing "YOU BEAT THE MAP!" takeover.
- Confetti and the tier 4 celebration.
- **The certificate is awarded here.** Not at 77 of 77.

This is the single most important decision in the spec. Version 1 gated the
certificate on full mastery, which meant beating the game left the trophy locked.
That is a false summit and it is exactly the "really?! again?!" feeling to avoid.
A reward that arrives late is a reward withheld.

The certificate's wording changes accordingly: it certifies conquering the Seven
Worlds, which is what he actually did. The honest fact count stays in the Parent
Area.

### Phase 3: after the celebration, the surprise

Once the celebration is dismissed, the map transforms. **The guardians return in
golden form and replace the world images on the nodes.** The map he has looked at
for weeks becomes a visibly different map, built entirely from art the app
already owns.

This ordering is the whole trick. A surprise after the reward is a gift. The same
surprise before the reward is a chore. Version 2 of this spec had the golden
guardians visible from early on specifically to avoid a surprise, which would
have quietly spent the biggest moment in the app for nothing.

What the transformed map shows:

- Each node is now its guardian, tinted gold, on the world's palette.
- Each node is labelled with the tables it owns, for example "Sky Citadel - the
  8s". **These labels appear only now.** Before this point quests draw from the
  global fact ladder, so a table label on a world would be false. Post-transform
  practice is world-scoped, so the label becomes true exactly when it appears,
  and the relabelling reinforces that the map has changed.

| World | Tables | Facts | Guardian |
|---|---|---|---|
| Highland Trail | 0, 1, 2, 10 | 10 | Granite Giant |
| Shipwreck Cove | 5, 11 | 10 | Tidal Kraken |
| Jungle Temple | 3, 4 | 15 | Jade Jaguar |
| Desert Canyon | 9 | 9 | Sandstorm Scorpion |
| Frozen Summit | 6 | 10 | FrostFang Dragon |
| Volcano Depths | 7 | 11 | Magma Fist |
| Sky Citadel | 8 | 12 | Storm Titan |

### Phase 4: all seven golden guardians beaten

Three beats, all reusing existing assets:

1. **The guardians assemble.** A takeover showing all seven, golden, defeated but
   standing. They were guardians, not villains: they were testing him, and now
   they salute him. One screen, no new art.
2. **The certificate gains its gold seal.** He already owns it and it is probably
   on the fridge. Upgrading something he possesses beats granting a new thing.
3. **The map stays permanently gold.** He sees it at every launch.

**Then the app is finished, and it says so.** Nothing nags afterwards. Daily
quests remain available for upkeep, silent and optional. No new tier, no streak
ultimatum. "You are done, and here is the proof" is a legitimate ending, and the
fact that this app can say it is part of why it will be trusted.

## Entry: fighting versus practising

Tapping a golden node goes **straight into the boss fight**. No menu, no
long-press, no second icon. The exciting thing should not have a chooser in front
of it.

Practice is surfaced by **losing**, not by the map. When the guardian escapes, the
retreat screen offers "Train the 8s first": a normal, untimed, world-scoped quest
on that world's tables. Practice therefore appears exactly when it is needed and
never clutters the map, and the difficulty ramp teaches itself:

    fight -> struggle -> train -> fight again

That loop is the mastery mechanic. It never has to be explained to him.

## What "conquered" means

**Beating the fight**, not reaching an invisible mastery flag. A guardian that
stays un-gold after he beat it is its own small betrayal.

This is legitimate rather than a cop-out because of a lucky fit in the numbers:
the worlds hold 9 to 15 facts each, and a boss fight is already 10 to 16
questions. **A golden fight serves that world's entire fact set, once.** Passing
means answering essentially every fact in the table, fast, in one sitting, under
pressure. That is a stronger proof of fluency than the ladder's cross-day
bookkeeping.

Mastery becomes the side effect rather than the goal. Seven gold guardians is the
visible completion: countable at a glance, no numbers anywhere.

## The three engine facts that constrain this

1. **Boss fights already promote facts.** `service.record(...)` runs before the
   `bossWorldIndex == nil` branch, which only gates XP and streak flourishes.
2. **Boss fights are already the mastery instrument.** Mastery needs FAST
   corrects (`fluencyGoal = 3`, `fluencyDaysGoal = 2`); boss questions are
   already `format: .fluency, timed: true`, weakest-first. Nothing new is being
   invented, only scoped and re-skinned.
3. **The current boss pool cannot see low facts.** `buildBossSession` filters
   `$0.introduced && $0.stage >= .recall`. A fact at `.recognition` is invisible
   to every boss fight, forever. **Fixing this is mandatory**, or a world can
   never be conquered. Golden fights serve such facts in their correct format
   (multiple choice, untimed, normal hit only, never a critical, excluded from
   the speed baseline, mirroring how `trueFalse` is treated as `verifyOnly`).
   They advance up the ladder and become fluency-eligible next time.

## Soft fail

The guardian escapes; he is never defeated. Per-answer promotions are recorded
regardless of outcome, so progress is inherently kept and only the presentation
changes. No failure screen, no "So close!". The 85% bar governs whether the world
turns gold, never whether the session counted.

## Explicitly not built

- Trophy hall or browsable guardian museum
- Mastery colouring on the times table chart
- Any child-facing "X of 77" (the Master Quest bar is removed)
- Per-world fact counts shown to the child
- A second certificate

## Acceptance criteria

1. Beating the map awards the certificate immediately, with no mastery
   precondition.
2. The golden map is revealed only after the completion celebration is dismissed,
   never before or during.
3. A golden fight serves every fact its world owns, and no fact can be
   permanently unreachable. Specifically, a fact at `.recognition` must be
   servable and must advance.
4. Losing a golden fight never reduces progress and never shows a failure state.
5. No screen visible to the child displays a fraction, percentage or fact count
   at any point.
6. Nothing in phase 1 changes in any way.
7. Golden fights write to the scheduler through the existing `record(...)` path.
   No new promotion rules are introduced.

## Verification plan

The day gate makes this impossible to validate by hand in one sitting, so the
engine harness carries the load:

- Extend `Tests/EngineSmokeTest.swift` with a simulation that seeds "map beaten,
  N facts unmastered", runs simulated golden fights against a synthetic clock
  advancing one day per round, and asserts every world becomes conquerable and no
  fact is ever unreachable.
- Re-run the 10 day pacing simulation (`-dumpQuestPlan -dumpSlow`) to prove
  phase 1 is untouched.
- On device, check the transformation, the gold tint and the soft fail on **both**
  iPhone landscape and iPad. Every recent presentation bug in this app has been
  compact-height specific, and the iPhone map is the tightest layout in the
  product.

## Estimated cost

Two to three days. The bulk is the world-scoped, mixed-format session builder and
its engine test. The gold tint, the node transformation, the table labels and the
three final beats are comparatively small because they reuse existing art.
