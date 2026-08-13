---
title: "STATUS - Math Tutor"
created: 2026-07-24
modified: 2026-08-13
version: 6.0
author: Claude Opus 5 (claude-opus-5)
tags:
---

# Math Tutor - Status

## Project

An iPad/iPhone SwiftUI app you built for your son Chase, called Multiplication Adventure, to master multiplication facts (0-11) before school starts Sept 8. It's a full game: a 7-world map, boss fights with animated idle videos, daily "quests" with an adaptive fact ladder, a True/False Lightning Round, streaks, XP, a times-table reference, a completion certificate, and (new, on branch) the Golden Guardians endgame. A sibling "Addition" app for Vinny is being ported in parallel by another agent, kept in sync via `PARITY.md`.

## Stage

Beta (1.0 build 6 REJECTED 2026-08-13 under Guideline 4.3(a) Design: Spam; reply sent to App Review the same day, awaiting response. The Golden Guardians endgame is complete and measured on branch `boss-idle-videos`, NOT in the rejected build.)

## Health

🔴 Blocked - Apple rejected build 6 as spam under 4.3(a), saying it shares a similar binary, metadata and/or concept with apps already on the Store. This is a harder class than the previous two rejections: it questions the app's right to exist on the Store rather than naming a fixable defect, and it puts the two-app plan (Addition free as a funnel, Multiplication paid) in doubt, because Apple's preferred 4.3 resolution is merging similar apps into one. The software itself is in good shape: nothing known-broken in the build, and the Golden Guardians endgame is fully measured on branch.

## Waiting on Me

- [ ] **Watch for App Review's reply on the 4.3(a) rejection** (~passive, 1-3 days typical) - the reply asks which apps build 6 was matched against, asserts originality, and discloses Addition Adventure by bundle ID. Do NOT resubmit while this thread is open; resubmitting an unchanged binary against a spam flag reads as ignoring them
      - unblocks: knowing whether the two apps can coexist, or whether they must merge into one app with selectable content
- [ ] **Decide the two-app question once Apple answers** (~a real decision, not a task) - three paths: explain and keep both; merge into one "Math Adventure" with an operation per player profile (Apple's preferred resolution, halves maintenance, kills the need for cross-promo); or retire Addition from the Store and keep it sideloaded for Vinny
      - unblocks: the pricing plan, which currently depends on two apps existing
- [ ] **Play the Golden Guardians endgame yourself** (~20 min on a simulator: `-demoGoldenEra`, then win/lose fights) (updated 2026-08-11)
      - unblocks: deciding whether it ships as 1.1 right after 1.0 releases, and whether the fight length (9-15 questions, one per fact) feels right
- [ ] **Grant the iPad simulator panel permission for MA-Verify-iPad, then rerun the retreat-screen tap-through** (~5 min) - the one Golden Guardians surface not verified on iPad (it IS verified on the tighter iPhone landscape layout; a permission prompt was declined/pending during the overnight run)
      - unblocks: closing the last verification gap
- [ ] **Play-test the pacing with Chase and Vinny** (~a few sessions) - check whether "~8 minutes, 30-50 answers" is the right feel
      - unblocks: knowing whether the pacing engine needs another retuning pass (and a 1.0.1 if so)
- [ ] **Decide on the star-count cap** (~after one session of watching) - watch Chase play before changing anything
      - unblocks: whether the pacing constants need a 1.0.1
- [ ] **Try the Lightning Round with the kids** (~10 min) - ships OFF; enable via Parent Area gear -> Settings
      - unblocks: deciding if it stays in the rotation
- [ ] **Update the developer address in Apple Developer** (~10 min, AFTER release) - deliberately deferred; see v4.0 notes
      - unblocks: accurate legal/trader details

## Next Up

1. Wait for App Review's reply on 4.3(a). Do not resubmit, do not upload a new build, do not edit metadata while the thread is open.
2. After 1.0 releases: decide the 1.1 plan for `boss-idle-videos` (Golden Guardians). The branch is 5 commits ahead, pushed, all measured; it needs your play-through and a version/build bump, nothing else known.
3. Watch Chase play 2-3 real sessions under the current pacing; adjust the 8-minute constants if it feels off.

## Biggest Risk

**The 4.3(a) spam flag is now the top risk, and it is different in kind from the previous ones.** The first two rejections named defects we could fix in an afternoon; this one questions whether the app belongs on the Store at all, and a second 4.3 flag on the same account (which submitting Addition Adventure would likely produce, since it is the same codebase) escalates toward Developer Program action. PARITY.md now carries a hold order for that app. Six submissions, zero releases. Secondary: the Golden Guardians endgame is machine-verified but has never been played by a human; the per-fight length and the fight-train-fight difficulty loop may need feel-tuning once Chase actually reaches the golden era (weeks away, so low urgency).

## Ideas Shelf

- **Progress export/import** (S) - a Parent Area button to export the profile as JSON via the share sheet (and re-import); cheap insurance against device loss.
- **Golden fight flourish** (S) - a guardian-specific gild animation or roar SFX when a world turns gold; currently it reuses the standard celebration.
- **Per-world ambience loops** (M) - background music per world, Kling prompts already drafted, volume-ducked under SFX with a parent toggle.
- **iPad portrait polish** (M) - the app runs in portrait on iPad with heavy letterboxing; either lock it back to landscape or make portrait first-class.

---

## Golden Guardians (built overnight 2026-08-11, branch `boss-idle-videos`, commits 4b876c9..aeb57e3)

Implements `docs/golden-guardians-spec.md` v3.1 in full. What shipped, in build order:

1. **Engine** (`Sources/Engine/GoldenFightBuilder.swift` + smoke-test coverage): a golden fight serves EVERY fact its world owns exactly once, each in a format its stage can answer (recognition -> MC untimed, recall -> open untimed, fluency/mastered -> open timed); never-introduced facts serve as MC. This closes the `stage >= .recall` hazard that would have made a world permanently unconquerable. Measured: 84 uniform + 2,100 randomized builds (23,100 questions), zero violations; recognition facts provably advance with `countsTime:false`; all 77 facts converge to mastered in 7 simulated daily rounds with the 2-day gate intact.
2. **The fight** (WP2): golden-era node taps go straight in; full-gauntlet HP (no early victory cutting facts); MC hits are normal hits (never crits, excluded from the speed baseline); >=85% gilds via `Profile.gildedWorldsMask` without touching `clearedWorlds`; soft fail = "the guardian escaped" retreat with a world-scoped untimed "TRAIN THE Ns" round. Measured: `-dumpGoldenSim` harness, 58/58 PASS on 12 runs total.
3. **Map transformation** (WP3, visually redesigned 2026-08-11 evening per your notes, commit 804a69e): the reveal flashes lightning twice, drains the whole scene to black and white, and slams in all seven guardians in full gold. Conquest restores the world's color to that node's circle (plus a star seal); when all seven fall, the entire map's color floods back before the certificate. Node labels are boss name + explicit challenge ("Storm Titan / x8 Challenge", flipping to "Conquered!" when beaten). Measured: pixel metric classifies 0/7 vs 3/7 vs 7/7 gilded correctly on both sims; 8/8 launch loop; pre-golden map byte-identical to pre-change build except an animation phase.
4. **Final beats** (WP4): seventh gild -> one-time "THE GUARDIANS SALUTE YOU!" takeover (8/8 launches) -> certificate gains a drawn gold seal (inside the ImageRenderer'd card) -> permanent quiet caption "Seven Worlds conquered · Adventure complete". Persistence verified across arg-less relaunch.
5. **Certificate + bar removal** (WP5): certificate awarded at map completion (no mastery precondition), retitled "CERTIFICATE OF VICTORY", reworded around conquering the Seven Worlds; sequence is takeover -> certificate -> map transform; `masterQuestBar`/`masterQuestBarSlim` deleted; WrapView and the trophy room's child-facing fact counts removed (sweep table in session log). Honest counts live only in the Parent Area.

**Phase-1 proof:** `-dumpQuestPlan -dumpSlow` re-run twice on the final build; all 20 per-session summary lines byte-identical to the pre-change baseline. Engine smoke test grew 59 -> 86 checks, all green.

**Verified by hand-driving the UI (iPhone landscape):** MC question shows 4 options and no timer; typed golden question shows keypad; losing (3/9 wrong) shows the retreat screen exactly per spec (no "So close!", no numbers, TRAIN THE 9s works and opens an untimed training round); winning gilds the node gold on the map.

**Not verified:** the retreat screen layout on iPad (simulator panel permission was declined/pending; the fight screen itself was captured fine on iPad via simctl), and confetti visibility on the gold win wrap (static screenshot timing). New debug hooks: `-demoGoldenEra`, `-gildWorlds <mask>`, `-autostartGolden`, `-goldenWorld <n>`, `-dumpGoldenSim`.

## Deferred

- "Made for Kids" category opt-in (Education + 4+ chosen instead, deliberately)
- A one-star-per-day cap on grinding (left open on purpose, helps catch-up days before Sept 8)
- iPhone Parent Area screenshot (cramped on 6.9" - polish before using it in the listing)
- Developer address change (see Waiting on Me - deliberately parked until after release)

## App Store Readiness

- 2026-08-13: **1.0 (build 6) REJECTED, Guideline 4.3(a) Design: Spam.** Reviewed on iPad Air 11-inch (M3). Apple's wording: the app "shares a similar binary, metadata, and/or concept as apps submitted to the App Store by other developers, with only minor differences". The phrase "by other developers" may be literal (the times-tables category is crowded, and the art is AI-generated, which shares a house style with many 2026 indie apps) or may be boilerplate masking the real trigger, which would be Addition Adventure: same source, same engine, same asset pipeline, submitted from this account weeks earlier. Replied the same day asking Apple which apps it was matched against, asserting originality (no purchased template, no shared code or assets with another developer, art and audio made for this app), listing the anti-spam signals (free, no ads, no IAP, no third-party SDKs, no accounts, no data collection, fully offline), disclosing Addition Adventure by name and bundle ID, and offering to consolidate if that is what resolves it. **Lesson: a proactive 4.3 explanation had been written into PARITY item 20 weeks earlier as a recommendation, and was deliberately left OUT of the build 6 reviewer notes on the reasoning that raising it might invite scrutiny. That reasoning was wrong: 4.3 matching is largely automated, so the reviewer sees the similarity either way, and the only thing the omission controlled was whether our explanation was there when they did.**
- 2026-08-10 (later): **1.0 (build 6) submitted, state WAITING_FOR_REVIEW, auto-release on approval.** Build 5 was pulled the same day, before Apple looked at it, because testing turned up a confirmed defect in it (see the answer-controls bug below). Build 6 = build 5 + that fix. The iPhone map screenshot in the listing was also replaced.
- 2026-08-08: **1.0 (build 4) REJECTED, Guideline 1.5** (Support URL 404 - page was only on the feature branch while GitHub Pages serves `main//docs`). Fixed on `main` (eefc27c), verified live 200 before resubmitting.
- Submission mechanics learned: after a rejection click **Update Review** on the version page first, then **Resubmit to App Review**; the API PATCH path 409s until then.
- Done: privacy policy AND support page live and verified; dev tools excluded from Release builds (verified with `strings`); parent gate; metadata scrubbed for 5.1.4; categories Education + Games, 4+, Free, 175 territories, "Data Not Collected"; 9 screenshots; agreements/bank/W-9/DSA all Active.
- Devices: **Chase's iPad is on 1.0 (6)** (Ad Hoc over USB-C). Launch with NO arguments on real devices: `-demo*` flags rewrite profile data.

## The "no way to answer" bug (root-caused 2026-08-10, commit 7400557)

Fixed and measured (5/6 failing before, 0/8 after, 0/8 on iPad). `assembleQuest`'s warm-up rebuilt review questions field-by-field, dropping `trueFalse`, so True/False questions fell through to MultipleChoiceView with nil options and rendered no controls. A safety net in QuestionContainer now degrades any option-less recognition question to the number pad.

## Session Notes (2026-08-11, evening iteration)

- Four on-device feedback changes landed (commits 624913d, 306818d): boss videos grade GOLD per-frame during golden fights (AVVideoComposition + Core Image, alpha preserved - unpremultiply before grading, premultiply after; regular fights untouched), the reveal is now a 4-strike lightning storm with screen shake, the DEBUG dev card opens without the math gate, and conquered nodes have three selectable treatments (-conqueredStyle 1|2|3: crown / sash / laurel; crown default pending your pick).
- Debug build with everything deployed to your iPad Pro and iPhone via devicectl. Chase's iPad untouched.

## Session Notes (2026-08-11, overnight)

- Golden Guardians built end to end by a lead session orchestrating five reviewed work packages; every package landed with its own measured verification before the next started (details in the Golden Guardians section above).
- One latent demo-state bug found and fixed along the way: `-demoMapDone`/`-demoGoldenEra` did not reset flags a previous demo launch had set on the same install, which could render the golden map behind the "YOU BEAT THE MAP!" takeover (an acceptance-2 violation that would also have confused real testing).
- The WP5 digit sweep found one pre-existing child-facing fact fraction outside the spec's list: the trophy room's "N of 77 / facts I know" tile. Replaced with a guardians-defeated tile.

---

## Lessons

- **Verify every externally-hosted URL is actually live before submitting to App Review.** `curl -s -o /dev/null -w "%{http_code}" -L <url>` on each listing URL takes seconds. Do it every time. (promoted to Build Guide v8.0, 2026-08-12)
- **GitHub Pages publishes from one specific branch.** A doc on a feature branch is not published. `git ls-tree --name-only origin/<pages-branch> docs/` confirms what is actually live. (promoted to Build Guide v8.0, 2026-08-12)
- **A `git worktree` on local disk is the clean way to commit to another branch** without disturbing a dirty tree, and it sidesteps Dropbox. (promoted to Build Guide v8.0, 2026-08-12)
- **For an intermittent UI bug, build a pixel detector and loop the launch - do not "fix" it from a plausible-looking code read.** A failure RATE (5/6 -> 0/8) turns "seems fixed" into evidence, and forcing the suspected condition with a debug flag makes the flake deterministic. (promoted to Build Guide v8.0, 2026-08-12)
- **Beware field-by-field struct copies.** Rebuilding a value type to change one field silently drops every field added later. (promoted to Build Guide v8.0, 2026-08-12)
- **An in-memory, launch-arg-gated sim harness that drives the real view model is the cheapest app-layer regression rig.** (2026-08-11) Pattern: `QuestPlanDump`/`GoldenSimDump` - in-memory SwiftData store, injectable clock, drive `vm.answer(...)` in a loop, print PASS/FAIL counts, `exit(0/1)`. It verifies the full service -> builder -> view-model pipeline headlessly, loops for a rate, and doubles as the fixture for later features. Costs one file; catches wiring bugs no engine test can see. (promoted to Build Guide v8.0, 2026-08-12)
- **When an unseeded simulation must prove "nothing changed", diff its stable summary lines, not its full output.** (2026-08-11) Run the baseline twice FIRST to learn which lines are run-invariant (here: per-session summary lines), then compare only those against the post-change run. A full-text diff of unseeded output proves nothing; a summary-line diff is byte-exact evidence. (promoted to Build Guide v8.0, 2026-08-12)
- **MCP simulator tap-driving needs a per-device user permission grant; plan overnight verification around it.** (2026-08-11) `simctl io screenshot`/`launch` work without it, but tap injection does not, and a declined/pending prompt in a non-interactive session permanently blocks that device for the night. Front-load tap-driven checks onto an already-granted device and verify the riskiest (compact) layout there. (promoted to Build Guide v8.0, 2026-08-12)
