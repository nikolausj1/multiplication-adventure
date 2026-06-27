---
title: "Multiplication Adventure — Consolidated Spec"
created: 2026-06-24
supersedes: "Level Up Math - PRD.md"
status: living document
---

# Multiplication Adventure

A focused iPad app that turns a nine-year-old's summer into automatic multiplication
recall. One job, done exceptionally well: by the end of summer he sees "8 × 7" and
instantly knows "56," with no counting and no visible effort.

This document consolidates the original PRD **plus every decision made in the design
sessions since** (engine details, visual/motion, the Adventure re-theme, and
multi-profile/parent controls). Where the original PRD and a later decision conflict,
**the later decision wins and is marked**.

**Legend:** ✅ Built & verified · 🔜 Planned (next build) · 🔁 Changed from original PRD

---

## 1. Vision & Success

Most children understand multiplication long before they can recall it fluently. Working
it out spends cognitive energy that should go to the actual problem. This app does not
teach the concept — it manufactures thousands of small retrieval events until each fact
is instantaneous.

**Success** = the final week of summer, a parent asks "what is 8 times 7," and the child
answers "56" with no pause. Measurable:
- Recall any fact 0×0–12×12 correctly.
- Median response time under 2s, trending toward 1s on well-practiced facts.
- Used on most days, ~10–15 min sessions, without becoming a fight.
- A parent can tell at a glance whether it's working.

Two north stars, in order: **real fluency gains**, then **daily use**.

---

## 2. Users 🔁

**Original PRD:** single child profile; multiple profiles out of scope.
**Now (decided 2026-06-24):** **full multiple profiles are in scope.**

- **Primary user — the child:** 9-year-old, conceptually fluent but no recall yet.
  Easily distracted, motivated by building/leveling/unlocking (Minecraft/Roblox mold),
  responds to immediate feedback, ~10–15 min attention when engaged.
- **Secondary user — the parent:** encourages consistency, watches progress, supplies
  real-world rewards. Needs to answer "is this working?" in under 30 seconds.

🔜 **Multiple profiles:** each profile (son, parent, siblings) owns **independent**
progress — its own 91 facts, sessions, milestones, XP, streak, settings, and world-map
position. The app persists an **active profile** and opens straight into it (zero choice
for the kid, §3). Switching happens only in the parent area. First launch auto-creates one
renameable profile. Cap ~6 profiles.

---

## 3. Product Philosophy (overrides feature preferences)

- **Learning before entertainment.** If a feature raises engagement but lowers learning, it's cut.
- **Consistency beats intensity.** Optimize for sustainable daily return, not time-in-app.
- **Effort before accuracy.** Early on, showing up matters more than being right; reward leans on effort first, then shifts to mastery/speed.
- **No punishment.** Missing a day never destroys progress. A wrong answer is never a failure event. Mastery is permanent — a lapsed fact returns to review, never to zero.
- **The app always knows what comes next.** The child never chooses what to study, what mode, or which table. He opens the app and practices.

---

## 4. The Learning Engine ✅

Pure-Foundation, unit-tested (**41 checks passing**), bridged to SwiftData. Rests on
spaced retrieval, automaticity (sub-2s), and interleaving.

### 4.1 Fact universe ✅
Facts 0×0–12×12. Commutative, so **91 unique pairs** (first factor ≤ second); prompts
shown in both orders. Mastering 7×8 also advances 8×7.

### 4.2 Three-stage mastery model ✅ — stage = question *format*
Each fact moves independently through:
- **Recognition** — multiple choice, four plausible distractors (near-misses, never random).
- **Recall** — open response on a number pad.
- **Fluency** — open response where speed matters.
- **Mastered** — durable; surfaced only for maintenance.

### 4.3 Promotion & mastery rules ✅
- Recognition → Recall: **2 consecutive** correct MC.
- Recall → Fluency: **3 correct** open responses (resets on error → "no recent error").
- Fluency → Mastered: **3 fast-correct** open responses across **≥2 calendar days** (the
  cross-day rule prevents cramming from faking durability).
- Fluency threshold starts ~3s and tightens toward 2s (1s stretch), tracked from his recent fluency-stage times.

### 4.4 Spaced repetition ✅ — Leitner box = *timing*
Boxes 0→5+: later-this-session, 1d, 2d, 4d, 7d, 14d, maintenance. Correct promotes a box;
**wrong drops ~2 boxes and re-queues the fact later in the same session.** Stage and box
are separate systems: **stage decides format, box decides when due** (the resolved gap).

### 4.5 Adaptive weak-area detection ✅
Per fact: accuracy, recent response time, exposures, errors, lapses → a priority score.
Slow/error-prone/overdue/lapsed facts get more airtime; fast/reliable ones get less.

### 4.6 Interleaving ✅
Within a session, facts from different tables are mixed (no same-table back-to-back where avoidable).

### Resolved engine decisions (were open/ambiguous) ✅
- **Stage × Leitner:** one scheduler — stage = format, box = timing; a correct answer advances both.
- **Wrong answer:** neutral-soft reveal, no retry, demote ~2 boxes, re-queue ~4 slots later.
- **Open-response input:** explicit Enter (✓ key); **response time = question-shown → Enter**.
- **Trend data:** per-session **median RT + accuracy** stored on each session record.

---

## 5. Curriculum & Sequencing ✅ (→ becomes the world map, §11)

Starts at the beginning. Tables introduced in order of **cognitive ease**, not numeric
order. A fact unlocks once both its factors' tables are introduced. New tables introduced
gradually; a fact is interleaved with everything else once introduced.

**Introduction order:** ×0,×1 → ×2 → ×10 → ×5 → ×11 → ×3 → ×4 → ×9 → ×6 → ×7 → ×8 → ×12.

---

## 6. The Session ✅

Opens straight into a session — no menu. ~20–30 questions (~10–15 min), stoppable anytime
with full credit. Four movements:
1. **Warm-up** — a few already-mastered facts (confidence). Cold-start falls back gracefully.
2. **Core** — current learning-target facts (Recognition/Recall), interleaved.
3. **Review** — spaced-due + historically difficult facts, including short Fluency bursts.
4. **Wrap** — summary: practiced count, accuracy, XP, progress toward next milestone, one encouraging line.

---

## 7. Progression 🔁 — XP stays; ranks retire in favor of the world map

- **XP** ✅ — earned every answer. Early weighting favors **effort** (attempting pays well);
  as overall mastery rises, weighting shifts to **correctness + speed**. This is the only
  place the effort→mastery curve lives.
- 🔁 **Ranks retired.** The original Novice→Master ladder is replaced by the **7-world
  adventure map** (§11) as the progression spine.
- **Timing presentation** ✅ — no visible timer early (speed measured silently). A **Speed
  Round** (visible **count-up + beat-your-best**, never a countdown) unlocks once enough
  facts reach Fluency.
- No leaderboards, no competing against others (by decision).

### Celebration taxonomy ✅ (calm loop, lavish milestones)
Intensity = rarity × effort, kept separate from the XP curve (two dials).
- **T0** in-loop feedback (not a celebration) · **T1** light (mastered fact, daily streak, wrap, speed PB)
- **T2** medium (table complete, streak thresholds 3/7/14/30 · 🔜 world cleared moves to T3)
- **T3** major (25/50/75%) · **T4** finale (100%)
- **Coincident milestones merge into one** celebration at the highest tier.

---

## 8. Parent Area & Dashboard 🔁

**Dashboard** ✅ (one screen, plain language, <30s, **transparent/shared** per original §2):
- Practice cadence (days this week + streak, positive framing).
- Overall mastery % + progress bar.
- **Mastery map** — 13×13 grid, each fact colour-coded by state with an always-on stage
  badge (1–3) and a star when mastered (colour + shape, not colour alone).
- Accuracy & speed **trend** over time.
- Trouble spots (handful of difficult facts).
- Earned rewards (milestones awaiting a real-world reward; parent marks "Given").

🔜 **Parent area** (new): entered via a **gear icon on the map**. Holds the transparent
dashboard **plus a gated Manage section**:
- Add / switch / rename / delete profile; **reset progress**; per-profile settings (sound, speed-round).
- **Parent gate** on destructive actions only: a **2-digit × 2-digit multiplication
  challenge** (a young child can't pass it; viewing stays open per §2).
- **Reset** = wipe a profile to brand-new (re-seed its 91 facts). **Delete** = remove a
  profile (can't delete the last; deleting the active one switches to another). Both gated + confirm.

---

## 9. Rewards ✅

The app isn't the reward. It tracks mastery, defines milestone moments, and surfaces an
"earned" marker; the **parent delivers the real-world reward offline**. No in-app currency.
Milestones: a table/world cleared, a multi-day streak, overall 25/50/75/100%.

---

## 10. Completion ✅/🔜

The app **ends**. 🔜 Reaching and clearing the final world is the adventure climax; the
**"I know my multiplication tables" certificate** + completion finale land at **100% true
mastery** (a victory lap that may arrive just after the last world).

---

## 11. Adventure Re-theme 🔜 (the next build)

A journey across **7 themed environments** on a map. This is a presentation +
progression-framing layer over the tested engine, plus a few contained engine-adjacent changes.

### 11.1 Worlds
Linear map, one stop per world. Front-loaded easy; hard tables get their own world:

| World | Tables |
|---|---|
| W1 | ×0 · ×1 · ×2 |
| W2 | ×10 · ×5 |
| W3 | ×11 · ×3 |
| W4 | ×4 · ×9 |
| W5 | ×6 |
| W6 | ×7 · ×8 |
| W7 | ×12 |

The **map is the home/hub.** Landscape-locked. World identity is **data-driven**
(`WorldCatalog`: name, tables, asset keys, palette); names start as generic placeholders.

### 11.2 Progression
- A world **focuses new learning** on its own tables (new-fact introduction scoped to the
  current world), but **sessions are cumulative** — the engine interleaves spaced review of
  all earlier worlds, which is how earlier worlds reach true mastery while he advances.
- **Cleared = every fact in the world reaches Fluency** (reachable, avoids a multi-day tail
  wall). Certificate at 100% true mastery (§10).
- Next world unlocks on clear. Locked worlds shown **fogged "???"**; the reveal **reuses
  the next world's background** (zoom/fog-lift, a T3 "world cleared" celebration).
- **Cleared worlds are revisitable** for optional focused review (main flow stays on the current node).

### 11.3 Art manifest (you generate ahead; app runs on placeholders first)

> Full world ideas, copy-paste **ChatGPT image prompts**, and the **audio asset list** live
> in the companion doc: **`Multiplication Adventure - Assets.md`**.

| Asset | Scope | Size / format | Notes |
|---|---|---|---|
| Environment background | per world ×7 | 2732×2048 JPG | Full-bleed; content sits behind a scrim so it can be busy. |
| Map-node thumbnail | per world ×7 | ~512² PNG | The environment as a badge; shown once unlocked. |
| Button skin | per world ×7 | ~600×220 PNG, 9-slice | ONE resizable frame per world for all buttons; pressed state derived in-app. |
| Map background | shared | 2732×2048 JPG | **Neutral, non-spoiling** (must not reveal future environments). |
| Locked-node art | shared | ~512² PNG | Fog/"?" marker. |
| App icon + launch | shared | 1024² | The rename. |

**Legibility:** an **app-applied scrim/card** sits behind all interactive content, so art
can be anything and contrast is guaranteed. The session screen wears the current world's
background (behind the scrim). Current map position is a **UI-drawn pulsing marker** (no
character sprite in v1).

### 11.4 Engine-adjacent changes for the re-theme
- Scope new-fact introduction to the current world.
- Retire the rank-up celebration; add a **"world cleared"** milestone (T3).
- Keep all engine tests green; add new world-progress tests.

---

## 12. Look, Feel & Sound ✅ (token layer ready for the art swap)

Fun but clean. Everything routes through a single **theme/token layer**
(`Theme.swift`) so per-world art/palette is a token swap, not a rewrite.
- **Type:** SF Rounded, heavy; the numeral is the hero.
- **Motion:** calm in-loop (≤200ms snappy springs), lavish at milestones; **Reduced Motion honored**.
- **Number pad:** calculator layout (7-8-9 top), large keys.
- **Sound:** ~6–8 curated, App-Store-cleared clips, each tied 1:1 to a motion event; no
  background music. (Currently haptics wired; audio is a stubbed fast-follow.)
- **Avatar:** static SF Symbol per profile in v1; cosmetic unlocks are a fast-follow.

### Kids-UX / iPad HIG hardening ✅
Reduced-Motion support, ≥44pt tap targets, button depth + press feedback, accessibility
labels on icon-only controls.

---

## 13. Data Model

Local-only, no account, no network. SwiftData on device.
- ✅ **Fact** — the 91 pairs: factors, stage, Leitner box, due date, attempts/correct,
  recent times, average time, last-seen/error/mastered dates, lapse count, per-stage progress.
- ✅ **SessionRecord** — date, question/correct counts, XP, median RT, facts touched (backs the trend).
- ✅ **MilestoneRecord** — label, detail, tier, earned date, fulfilled flag.
- ✅ **Profile** — name, avatar, XP, streak bookkeeping, settings.
- 🔜 **Per-profile refactor:** `Profile` becomes the parent entity owning Fact / SessionRecord /
  MilestoneRecord and world-map position; an active-profile pointer is persisted.

All progress is permanent and cumulative; nothing resets a mastered fact to zero (except an
explicit, gated parent **Reset**).

---

## 14. Scope

**Built (v1 engine + app):** the full engine, three-stage model, SRS, adaptive priority,
four-movement session, XP, transparent dashboard with mastery map + trend, milestone tiers,
neutral-soft feedback, kids-UX hardening. Runs on iPad simulator (home / session / dashboard verified).

**Next build (this spec's 🔜 items):** per-profile data layer → world engine → rename +
landscape → map home + per-world theming + placeholder art slots → parent area with gate.

**Still deferred / fast-follow:** custom/generated art + avatar cosmetic unlocks, sound
pack, completion certificate art, App Store packaging, notifications, other operations
(division/addition), iCloud sync.

---

## 15. Build & Verify (for engineers)

- Project source of truth: `project.yml` (XcodeGen); `.xcodeproj` is gitignored —
  `xcodegen generate`.
- Build: `xcodebuild -project … -scheme … -sdk iphonesimulator -destination 'id=<iPad sim>' build`.
- Engine tests (no Xcode): `cp Tests/EngineSmokeTest.swift /tmp/main.swift && swiftc -O Sources/Engine/*.swift /tmp/main.swift -o /tmp/t && /tmp/t`.
- `Sources/Engine/` is pure Foundation (testable standalone); `Sources/App/` is SwiftData + SwiftUI.

---

## 16. The One-Sentence Test

In the final week of summer, the parent asks "what is 8 times 7," and without counting,
without finger math, without a pause, the child says "56."
