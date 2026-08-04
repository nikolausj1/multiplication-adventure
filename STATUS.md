---
title: "STATUS - Math Tutor"
created: 2026-07-24
modified: 2026-08-03
version: 2.2
author: Claude Fable 5 (claude-fable-5)
tags:
---

# Math Tutor - Status

## Project

An iPad/iPhone SwiftUI app you built for your son Chase, called Multiplication Adventure, to master multiplication facts (0-11) before school starts Sept 8. It's a full game: a 7-world map, boss fights, daily "quests" with an adaptive fact ladder, a True/False Lightning Round, streaks, XP, a times-table reference, and a completion certificate. A sibling "Addition" app for Vinny is being ported in parallel by another agent, kept in sync via `PARITY.md`.

## Stage

Beta (1.0 build 2 resubmitted for App Store review 2026-07-31 after correcting the iPad screenshots; gameplay loop complete and in daily use on real devices)

## Health

🟡 At-risk - the app is submitted and all three devices run the same build, but the session-pacing engine (changed three times in 48 hours) still hasn't been validated by actual kid play, and that exact pacing is now frozen in the build under Apple review.

## Waiting on Me

- [ ] **Play-test the new pacing with Chase and Vinny** (~a few sessions) - check whether "~8 minutes, 30-50 answers" is the right feel
      - unblocks: knowing whether the pacing engine needs another retuning pass (and a 1.0.1 if so)
- [ ] **Try the new Lightning Round with the kids** (~10 min) - it ships OFF; enable via Parent Area gear -> Settings -> "Lightning Round unlocked" on their iPads
      - unblocks: deciding if it stays in the rotation as the mid-summer freshness drop
- [ ] **Review the world-1 boss video on device** (~5 min) - iPhone and dad's iPad Pro already have it (branch `boss-idle-videos`). Parent Area gear -> Developer/Testing -> Boss Gallery. Tap Defeat there: that path swaps to the still, and it is the one transition I could not tap-test myself
      - unblocks: deciding whether to render the other six bosses
- [ ] **Render the remaining six boss videos** (~your Kling time) - only after the above. Bigger subject (~1000-1200px tall, render 1920x1080) and >=40px margin all round; keep ProRes 4444 + alpha, 8s idle sway. Then `./scripts/make-boss-video.sh <master.mov> worldN`
      - unblocks: shipping animated bosses for the whole map
- [ ] **Watch for Apple's review verdict** (~passive) - approval auto-releases the app. NOTE: the first submission sat in "Waiting for Review" for six days with no reviewer action and no message from Apple; if this one stalls past ~5 days, contact App Review rather than assuming it is normal queueing
      - unblocks: the public App Store listing going live

## Next Up

1. Watch or ask Chase and Vinny about 2-3 real sessions under the new pacing; adjust the 8-minute constants if it feels off.
2. Respond to the App Store review outcome (auto-release on approval; fix-and-resubmit if rejected).
3. Enable the Lightning Round on the kids' devices and see if they like it.

## Ideas Shelf

- **Boss idle videos** - PILOT BUILT 2026-08-03 on branch `boss-idle-videos` (world 1 only, deployed to iPhone + dad's iPad Pro, not merged, not in any App Store build). Remaining: review on device, then render worlds 2-7 and run them through `scripts/make-boss-video.sh`.
- **Progress export/import** (S) - a Parent Area button to export the profile as JSON via the share sheet (and re-import); cheap insurance against device loss or a botched update.
- **Per-world ambience loops** (M) - background music per world, Kling prompts already drafted, volume-ducked under SFX with a parent toggle.
- **iPad portrait polish** (M) - the app now runs in portrait on iPad (universal update side effect) with heavy letterboxing; either lock it back to landscape or make portrait first-class.

## Biggest Risk

Apple review has the current pacing engine frozen in build 2 while the kids still haven't validated it - if play-testing says it needs another tuning pass, that becomes a 1.0.1 resubmission during launch week.

---

## Deferred

- "Made for Kids" category opt-in (Education + 4+ chosen instead, deliberately)
- A one-star-per-day cap on grinding (left open on purpose, helps catch-up days before Sept 8)
- Two cosmetic nits: certificate on-screen preview text is a bit crowded; streak-calendar caption slightly overlaps the grid
- iPhone Parent Area screenshot (cramped on 6.9" - polish before using it in the listing)

## App Store Readiness

- 2026-07-31: **1.0 (build 2) RESUBMITTED, state WAITING_FOR_REVIEW, auto-release on approval.** The 2026-07-25 submission sat six days untouched; pulled it (version briefly showed "Developer Rejected", which just means withdrawn by us) to replace the iPad screenshots, then resubmitted.
- Done: privacy policy live at https://nikolausj1.github.io/multiplication-adventure/privacy-policy.html (GitHub Pages).
- Done: public name "Multiplication Adventure" (ASC app 6787582433, record existed since Jul 4).
- Done: all metadata (subtitle, description, keywords, promo text, support URL, copyright), categories Education + Games (Family/Trivia - Apple's API no longer offers Games>Educational), age rating 4+, price Free, all 175 territories, App Privacy "Data Not Collected" published, review contact (phone reused from the ForeSome app record).
- Done: 9 screenshots uploaded (5 iPad 13", 4 iPhone 6.9": map, session, boss, Lightning Round). iPad set REPLACED 2026-07-31 with true landscape 2752x2064 captures - the originals were portrait 2064x2752 with black letterbox bars because the sim device was in portrait while the app is landscape-locked.
- Done: TestFlight - build 2 processed, internal "Family" group (apple@justinnikolaus.com invited), beta description + What to Test filled.
- Devices: iPhone and dad's iPad Pro on 1.0 (2) with the Lightning Round; Chase's iPad still on 83e7702 (functionally identical for him - Lightning ships gated OFF).

## Session Notes (2026-07-31)

- Answered Apple's new age-rating question `socialMediaAgeRestricted` (no social features); ASC had been nagging with a 2026-09-07 deadline.
- Screenshots cannot be edited while a version is "Waiting for Review" - fixing them costs the queue position.

## Session Notes (2026-07-25)

- PARITY items 18 and 19 confirmed genuinely ported to the Addition app (commits 824b247, 8f25200 verified in its repo).
- Lightning Round: fluent-facts-only, 20 statements, engine-isolated (no scheduler writes), flat 2 XP per correct, parent-gated OFF by default. Commit 5b5b919, pushed.
