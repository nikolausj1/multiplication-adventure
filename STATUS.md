---
title: "STATUS - Math Tutor"
created: 2026-07-24
modified: 2026-08-10
version: 3.0
author: Claude Opus 5 (claude-opus-5)
tags:
---

# Math Tutor - Status

## Project

An iPad/iPhone SwiftUI app you built for your son Chase, called Multiplication Adventure, to master multiplication facts (0-11) before school starts Sept 8. It's a full game: a 7-world map, boss fights with animated idle videos, daily "quests" with an adaptive fact ladder, a True/False Lightning Round, streaks, XP, a times-table reference, and a completion certificate. A sibling "Addition" app for Vinny is being ported in parallel by another agent, kept in sync via `PARITY.md`.

## Stage

Beta (1.0 build 5 resubmitted for App Store review 2026-08-10 after Apple rejected build 4; gameplay loop complete and in daily use on real devices)

## Health

🟡 At-risk - the app is back in review with the rejection cause fixed and verified, but this is the fourth trip through the queue and none of the three previous attempts reached a released state. The session-pacing engine still hasn't been validated by actual kid play, and that pacing is frozen in the build under review.

## Waiting on Me

- [ ] **Watch for Apple's verdict on 1.0 (5)** (~passive) - approval auto-releases. Apple DID review this app on 2026-08-08 (4 days after submit), so the queue does move; if this one stalls past ~5 days, contact App Review
      - unblocks: the public App Store listing going live
- [ ] **Play-test the pacing with Chase and Vinny** (~a few sessions) - check whether "~8 minutes, 30-50 answers" is the right feel, now that the iPhone map fix makes the map usable on a phone
      - unblocks: knowing whether the pacing engine needs another retuning pass (and a 1.0.1 if so)
- [ ] **Decide on the star-count cap** (~after one session of watching) - the 50-answer cap means a fast answerer can finish a star in ~4 minutes against an 8-minute target. Recommendation was to watch Chase play before changing anything
      - unblocks: whether the pacing constants need a 1.0.1
- [ ] **Try the Lightning Round with the kids** (~10 min) - it ships OFF; enable via Parent Area gear -> Settings -> "Lightning Round unlocked"
      - unblocks: deciding if it stays in the rotation as the mid-summer freshness drop
- [ ] **Update the developer address in Apple Developer** (~10 min, AFTER release) - the address on the ASC Business page is a former address. Deliberately deferred: changing it can trigger agreement re-acceptance and DSA trader re-verification, which you do not want mid-review. Also check whether the Digital Services Act trader record carries the same stale address, since that one is publicly displayed on EU listings
      - unblocks: accurate legal/trader details

## Next Up

1. Respond to the App Store review outcome for build 5 (auto-release on approval; fix-and-resubmit if rejected).
2. Watch or ask Chase and Vinny about 2-3 real sessions under the current pacing; adjust the 8-minute constants if it feels off.
3. Once released, fix the developer address and the DSA trader record together.

## Biggest Risk

Four submissions, zero releases. Each rejection or withdrawal costs the full queue position, so a small oversight (like the 404 that caused this one) turns into another multi-day round trip - and Sept 8 is four weeks out. The kids are unaffected either way since both run sideloaded builds.

## Ideas Shelf

- **Progress export/import** (S) - a Parent Area button to export the profile as JSON via the share sheet (and re-import); cheap insurance against device loss or a botched update.
- **Per-world ambience loops** (M) - background music per world, Kling prompts already drafted, volume-ducked under SFX with a parent toggle.
- **iPad portrait polish** (M) - the app now runs in portrait on iPad (universal update side effect) with heavy letterboxing; either lock it back to landscape or make portrait first-class.
- **Certificate and streak-calendar nits** (S) - certificate on-screen preview text is crowded; the streak-calendar caption slightly overlaps the grid.

---

## Deferred

- "Made for Kids" category opt-in (Education + 4+ chosen instead, deliberately - Guideline 5.1.4 makes the Kids Category a burden, not a benefit, here)
- A one-star-per-day cap on grinding (left open on purpose, helps catch-up days before Sept 8)
- iPhone Parent Area screenshot (cramped on 6.9" - polish before using it in the listing)
- Developer address change (see Waiting on Me - deliberately parked until after release)

## App Store Readiness

- 2026-08-10: **1.0 (build 5) RESUBMITTED, state WAITING_FOR_REVIEW, auto-release on approval.**
- 2026-08-08: **1.0 (build 4) REJECTED by Apple, Guideline 1.5 (Safety - Developer Information).** The Support URL in ASC returned a 404. Cause: `docs/support.html` was committed only to the `boss-idle-videos` branch, but GitHub Pages serves from `main//docs`, so the page was never published. The privacy policy was fine (it had been on `main` since July). Fixed by publishing the page to `main` (eefc27c) and verifying a live 200 before resubmitting. This also repaired the in-app Support link, which pointed at the same dead URL.
- Build 5 = build 4's source plus the iPhone map fix (7085ab7), which build 4 predated. Swapping builds was free because the rejection had already cost the queue position.
- Submission mechanics learned this round: after a rejection you must click **Update Review** on the version page first (item goes Rejected -> Ready for Review) before **Resubmit to App Review** becomes available. The API path `PATCH reviewSubmissions {submitted:true}` returns 409 "Version is not ready to be submitted yet" until that happens, and the version cannot be moved into a new submission (409 ITEM_PART_OF_ANOTHER_SUBMISSION) nor its item deleted (409 "Item was already submitted").
- Done: privacy policy AND support page both live and verified on GitHub Pages, both linked in-app from the Parent Area.
- Done: dev tools excluded from Release via `#if DEBUG` (Guideline 2.3.1(a)); verified absent with `strings -a` on the shipped binary.
- Done: parent gate is a two-digit multiplication problem (adult-level, regenerated per attempt).
- Done: metadata scrubbed for Guideline 5.1.4 (no "made for kids" phrasing, no `kids` keyword).
- Done: categories Education + Games (Family/Trivia), age rating 4+ with `socialMediaAgeRestricted` answered, price Free, 175 territories, App Privacy "Data Not Collected" published.
- Done: 9 screenshots (5 iPad 13" true-landscape 2752x2064, 4 iPhone 6.9").
- Account-level: Free and Paid Apps Agreements Active, bank account Active, W-9 Active, DSA/EU trader status Active for 27 countries. All verified 2026-08-07, nothing blocking.
- Devices: Chase's iPad runs an Ad Hoc build from 7085ab7 - functionally identical to build 5, which adds only the version-number bump. NOTE: that Ad Hoc build is labelled "build 4" but is a different binary from ASC's build 4; the bump to 5 ends that collision.

## Session Notes (2026-08-10)

- Diagnosed the rejection end to end via the ASC REST API rather than the web UI, which is far faster and more reliable than driving App Store Connect in a browser. Resolution Center messages are the one thing the API does NOT expose - those need the browser.
- Corrected an earlier wrong call: the multi-day wait before the rejection was NOT queue position. Apple reviewed on schedule; the app was sitting on a broken link that a single `curl` would have caught before submitting.

## Session Notes (2026-07-31)

- Screenshots cannot be edited while a version is "Waiting for Review" - fixing them costs the queue position.

---

## Lessons

- **Verify every externally-hosted URL is actually live before submitting to App Review.** A Support or Privacy URL that 404s is an automatic Guideline 1.5 rejection and costs a full review cycle. `curl -s -o /dev/null -w "%{http_code}" -L <url>` on each URL in the store listing takes seconds. Do it as the last step before submitting, every time.
- **GitHub Pages publishes from one specific branch.** A doc committed to a feature branch is not published, no matter how correct the file is. When a repo does feature-branch development but Pages serves `main//docs`, any page referenced by an external system (an app store listing, an email, a QR code) must be landed on the serving branch separately. `git ls-tree --name-only origin/<pages-branch> docs/` confirms what is actually published.
- **A `git worktree` on local disk is the clean way to commit to another branch** without disturbing a dirty working tree - and it sidesteps Dropbox entirely, which matters in this environment where Dropbox syncing build artifacts has repeatedly wedged git.
