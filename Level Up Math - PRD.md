---
title: "Level Up Math: Product Requirements Document"
created: 2026-05-31
modified: 2026-05-31
version: 1.0
author: Claude Opus 4.6 (claude-opus-4-6)
tags:
---

# Level Up Math

A focused iOS app that turns a nine-year-old's summer into automatic multiplication recall. One job, done exceptionally well: by the end of the summer he sees "8 x 7" and instantly knows "56," with no counting and no visible effort.

This document is the build spec. It assumes a single child (the developer's son), a local-only iPad app built in SwiftUI, a solid v1 in one to two weeks, and a possible path to the App Store later. Decisions already locked with the product owner are marked throughout.

---

## 1. Vision and Success Definition

Most children understand multiplication long before they can recall it fluently. They can work out that 8 x 7 = 56, but the working-out itself is the problem. Every fact that requires conscious calculation spends cognitive energy that should be going toward the actual math problem in front of them. The result is slower work, more frustration, and eroded confidence as math gets harder.

Level Up Math does not teach the concept of multiplication. It builds automatic recall of the facts. The entire product is engineered around manufacturing thousands of small retrieval events until each fact becomes instantaneous.

The definition of success is a single moment. It is the final week of summer, a parent asks "what is 8 times 7," and the child answers "56" with no pause, no finger counting, and no visible effort. A fact has not been memorized for a test. It has become automatic.

### Measurable success criteria

The product succeeds for this child if, by the end of summer:

- He can recall any fact from 0 x 0 through 12 x 12 correctly.
- His median response time on a recall prompt is under two seconds, trending toward one second on well-practiced facts. Research on automaticity places true direct retrieval at roughly 400 to 900 milliseconds, so under two seconds is the practical fluency bar and under one second is the stretch goal.
- He used the app on most days, in sessions of roughly ten to fifteen minutes, without it becoming a fight.
- The parent could tell at a glance, at any point, whether it was working.

The two north stars, in priority order, are real fluency gains and daily use. Every feature decision defers to those two.

---

## 2. Users

### Primary user: the child

A nine-year-old who understands multiplication conceptually but has no fluency yet. We are starting from the beginning to bank early wins and build confidence rather than starting from an assessment of where he is. Working assumptions about him:

- Easily distracted, short attention runway, will abandon anything that drags.
- Strongly motivated by games in the Minecraft and Roblox mold: building, leveling up, unlocking, collecting, visible progression.
- Responds to immediate feedback.
- Will focus for ten to fifteen minutes when genuinely engaged.
- Uses his own iPad, managed by the parent through Screen Time and Family Sharing.

### Secondary user: the parent

The parent's role is not to teach. It is to encourage consistency, watch progress, and supply real-world rewards. The parent needs visibility without management overhead. The parent dashboard exists to answer one question in under thirty seconds: is this working?

In this build the parent and child share the same iPad and the same view. The dashboard is transparent and not passcode-protected, by deliberate choice. The child sees exactly what the parent sees. This reinforces ownership of his own progress and removes any feeling of being monitored.

---

## 3. Product Philosophy

These principles override feature preferences whenever they conflict.

**Learning before entertainment.** Games, animation, XP, and ranks exist only to sustain practice. If a feature raises engagement but lowers learning effectiveness, it is cut. The goal is not that he loves the app. The goal is that he masters the facts.

**Consistency beats intensity.** Ten minutes daily beats an hour once a week. The product optimizes for sustainable daily return, not maximum time-in-app. He should end every session feeling successful, not drained.

**Effort before accuracy.** Early on, showing up matters more than being right. Reward structure leans heavily on effort and attempts at the start to kill resistance and build the habit, then shifts gradually toward mastery and speed as he progresses.

**No punishment.** Missing a day never destroys progress. A wrong answer is never a failure event. Mastery is permanent: a fact that lapses returns to review, never to zero. Streaks encourage return but their absence never guilts. The experience always pulls him back rather than punishing him for leaving.

**The app always knows what comes next.** He is never asked to choose what to study, what mode to use, or which table to drill. He opens the app and practices. All sequencing, difficulty, and review timing is decided by the system.

---

## 4. The Learning Engine

This is the core of the product and the part the original draft left unspecified. It rests on three well-established findings from learning science: spaced retrieval practice produces stronger and longer-lasting fluency than restudy or repetition, true automaticity means sub-two-second recall, and interleaving facts retains better than drilling one table in a block.

### 4.1 The fact universe

Facts run from 0 x 0 through 12 x 12. Because multiplication is commutative, 8 x 7 and 7 x 8 are the same underlying fact. The system tracks mastery on the 91 unique fact pairs (every pair where the first factor is less than or equal to the second), but presents prompts in both orders so he becomes fluent regardless of how a fact appears. Mastering 7 x 8 therefore also advances 8 x 7.

### 4.2 The three-stage mastery model

Every fact moves independently through three stages. A fact's stage is per-fact, not global, so at any moment he has some facts in early stages and others already mastered.

**Stage 1, Recognition.** Multiple choice. "7 x 8 = ?" with four options (56, 54, 63, 72). The goal is familiarity and building the mental connection, not recall. Distractors are chosen to be plausible (near-misses and common confusions), never random.

**Stage 2, Recall.** Open response. "7 x 8 = [ ]" answered on an on-screen number pad. This is the transition from recognition to memory. He must produce the answer with no options to lean on.

**Stage 3, Fluency.** Recall, but now speed is what matters. The objective is automaticity, not speed for its own sake. A fact is only truly mastered when it can be retrieved correctly and fast, repeatedly, on different days.

### 4.3 Promotion and mastery rules

- Recognition to Recall: two consecutive correct multiple-choice responses for that fact.
- Recall to Fluency: three correct open responses for that fact, not necessarily consecutive, with no recent error.
- Fluency to Mastered: three correct open responses under the fluency time threshold, spread across at least two different calendar days. The cross-day requirement is what prevents short-term cramming from being mistaken for durable mastery.

The fluency time threshold starts forgiving and tightens. Initial threshold is roughly three seconds; as his baseline speed improves the app tightens toward two seconds, and the stretch target for well-worn facts is under one second.

### 4.4 Spaced repetition scheduling

Each fact carries a strength level implemented as a Leitner-style box. Correct answers promote a fact to a longer interval; wrong answers demote it to a short one. Indicative intervals:

- Box 0: later this same session
- Box 1: next day
- Box 2: two days
- Box 3: four days
- Box 4: seven days
- Box 5 and beyond: treated as mastered, surfaced occasionally for maintenance

A fact is "due" when its interval has elapsed. Due facts are prioritized into sessions. A wrong answer on any fact drops it back several boxes and re-queues it soon, so weak facts naturally get more exposure without the child or parent having to manage anything.

### 4.5 Adaptive weak-area detection

The system continuously tracks, per fact: accuracy, average and recent response time, total exposures, error frequency, and number of lapses (times it fell back after being learned). It uses these to compute a per-fact priority. Facts that are slow, error-prone, or recently lapsed get more airtime; facts that are fast and reliable get less. Over the summer the practice mix becomes uniquely shaped to his specific weak spots, whether those turn out to be the 6s and 7s, the 8s, or the 12s. He spends his minutes where they pay off.

### 4.6 Interleaving

Within a session, facts from different tables are mixed rather than drilled in a single-table block, because interleaving improves retention. New facts are still introduced gradually (see curriculum below), but once introduced they are practiced interleaved with everything else due.

---

## 5. Curriculum and Sequencing

He starts at the very beginning. New tables are introduced in order of cognitive ease rather than numeric order, so easy wins come first and confidence compounds. A new table is only introduced once the earlier ones reach a mastery threshold (roughly 80 percent of their facts at Fluency or Mastered), so he is never flooded.

Introduction order:

1. x0 and x1 (rule-based, almost free)
2. x2 (doubles)
3. x10 (place-value pattern)
4. x5 (counting-by-fives pattern)
5. x11 (mirror pattern through 11 x 9, with 11 x 11 and 11 x 12 handled explicitly)
6. x3
7. x4
8. x9 (strong pattern, the digits of each answer sum to nine)
9. x6
10. x7
11. x8
12. x12

This front-loads the easiest two-thirds of the grid, so within the first week or two he has already "mastered" a large visible share of all facts, which is exactly the momentum the effort-before-accuracy principle is built to create.

---

## 6. The Session

He opens the app and is taken straight into a session. No menu, no mode select. A session targets roughly ten to fifteen minutes but is built from a target number of questions (around 20 to 30) rather than a clock, and he can stop at any time with full credit for what he did. Effort counts, so a short day is still a win.

A session has four movements:

1. **Warm-up.** Three to five already-mastered facts. Pure confidence and momentum.
2. **Core.** The bulk. Current learning-target facts in Recognition and Recall stages, interleaved.
3. **Review.** Spaced-due facts plus historically difficult ones, including short Fluency-stage bursts.
4. **Wrap.** A clear summary: what he practiced, XP earned, how close he is to the next rank or next table, and one encouraging line. He always leaves knowing he made progress.

The app never overwhelms with choice and always knows what comes next.

---

## 7. Progression: XP and Ranks

The motivational layer is leveling up, matched to his builder-and-leveler instincts.

**XP.** Earned on every answer. Early in his journey XP weights effort heavily: simply attempting and showing up earns well, so resistance stays low and the habit forms. As facts move into Fluency and Mastered, XP weighting shifts toward mastery and speed, with a bonus for fast correct answers. This is the effort-before-accuracy principle made concrete in the economy.

**Ranks.** A clear ladder, for example Novice, Apprentice, Builder, Skilled, Expert, Master, tied to cumulative facts mastered. Crossing a rank is a designed moment: a satisfying animation and sound, a clear "you leveled up" beat. Completing a whole table is its own celebrated milestone.

**Timing presentation, gentle to competitive.** At the start there is no visible timer. Response speed is measured silently to detect fluency, but he never sees a clock, so early practice stays pressure-free while he is building confidence. Once enough facts reach Fluency, the app unlocks an optional Speed Round mode with a visible timer and beat-your-best mechanics, and suggests turning it on. This matches the product owner's call: gentle first, competitive once he is ready.

No leaderboards and no competition against other people. Out of scope by decision.

---

## 8. Parent Dashboard

One screen, plain language, no jargon, readable in under thirty seconds, shared transparently with the child. It answers "is this working?"

It shows:

- **Practice cadence.** Days practiced this week and a simple streak, framed positively and never punitively.
- **Overall mastery.** A single percentage of all facts mastered, with a clear progress bar.
- **The mastery map.** A grid of the times tables, each fact color-coded by state: not started, learning, fluent, mastered. This is the at-a-glance picture of exactly where he is.
- **Accuracy and speed trend.** A simple line showing accuracy and median response time improving over time.
- **Trouble spots.** The handful of facts still giving him difficulty.
- **Earned rewards.** Milestones reached that are awaiting a real-world reward from the parent.

No complex analytics. No educational jargon. If a parent needs more than half a minute to understand it, it has failed.

---

## 9. Rewards

The app does not try to be the reward. Real-world rewards from family, an ice cream, a movie night, an outing, extra screen time, are stronger and keep motivation tied to family rather than digital currency.

By the product owner's decision, the model is: the app tracks mastery and defines the milestone moments, and when one is reached it surfaces a clear "earned" marker in the dashboard. The parent decides and delivers the real-world reward offline. There is no in-app currency and nothing to redeem in the app.

Milestone moments the app surfaces include: a table fully mastered, a rank-up, a multi-day practice streak, and overall mastery crossing 25, 50, 75, and 100 percent.

---

## 10. Completion

Unlike most educational apps, this one ends. When all facts through 12 x 12 are mastered, he reaches a genuine completion state. The app celebrates: a big completion animation and sound, the Master rank, a generated printable certificate, and a clear completion marker in the parent dashboard. Most importantly he can say, truthfully, "I know my multiplication tables." At that point the product has done its job.

---

## 11. Data Model

Local only, no account, no network. Implemented in SwiftData (or Core Data) on device.

- **Profile.** Single child in v1. Name, avatar, current rank, total XP, settings.
- **Fact.** The 91 unique pairs. Per fact: factors, current stage, Leitner box, due date, total attempts, total correct, recent response times, average response time, last-seen date, mastered date, lapse count.
- **Session.** Date, question count or duration, XP earned, accuracy, facts touched.
- **Milestone.** Type, earned date, whether the parent has fulfilled the real-world reward.
- **Settings.** Timing mode (gentle or speed), sound on or off.

All progress is permanent and cumulative. Nothing ever resets a mastered fact to zero.

---

## 12. Look, Feel, and Sound

Fun but clean, by decision. Bright and friendly enough to feel like a game, restrained enough not to feel like noisy junk. Satisfying sound effects on correct answers, level-ups, and milestones. No background music. Visual identity leans into the building-and-leveling theme with original art, not Minecraft or Roblox assets, since that keeps the door open to the App Store later. Number entry is a large, kid-friendly on-screen pad. Designed iPad-first.

No accessibility, reading-level, or handedness special requirements for this build, per the product owner.

---

## 13. Scope

### In scope for v1

Single child profile, the full 0 to 12 curriculum, the three-stage mastery model, spaced-repetition scheduling, adaptive weak-area detection, the four-movement session flow, XP and ranks with level-up moments, gentle-to-speed timing, the transparent parent dashboard, milestone tracking, the completion certificate, satisfying sound effects, fully local and offline.

### Out of scope for v1, candidates for later

Multiple child profiles, iCloud sync and a separate parent view on the parent's own phone, App Store packaging and privacy compliance work, notifications, expansion into division, addition, and subtraction, richer world-building art and animation, and any social or leaderboard features (leaderboards are explicitly excluded by decision).

---

## 14. Open Questions

These do not block the build but are worth resolving as it comes together:

- Exact rank names and the fact-count thresholds for each rank.
- The precise XP curve for the effort-to-mastery shift.
- Whether the Speed Round unlock is automatic, parent-toggled, or both.
- Final visual theme and avatar direction.
- Certificate design.

---

## 15. The One-Sentence Test

Everything in this document serves one sentence. In the final week of summer, the parent asks "what is 8 times 7," and without counting, without finger math, without a pause, the child says "56."
