---
title: "STATUS - Math Tutor"
created: 2026-07-24
modified: 2026-08-10
version: 4.0
author: Claude Opus 5 (claude-opus-5)
tags:
---

# Math Tutor - Status

## Project

An iPad/iPhone SwiftUI app you built for your son Chase, called Multiplication Adventure, to master multiplication facts (0-11) before school starts Sept 8. It's a full game: a 7-world map, boss fights with animated idle videos, daily "quests" with an adaptive fact ladder, a True/False Lightning Round, streaks, XP, a times-table reference, and a completion certificate. A sibling "Addition" app for Vinny is being ported in parallel by another agent, kept in sync via `PARITY.md`.

## Stage

Beta (1.0 build 6 submitted for App Store review 2026-08-10, carrying the fix for the long-standing "no way to answer" bug; gameplay loop complete and in daily use on real devices)

## Health

🟢 On-track - the "sometimes there's no keyboard" bug that had survived two wrong fixes is now root-caused, fixed and measured (5/6 failing before, 0/8 after, plus 0/8 on iPad), the Guideline 1.5 rejection cause is fixed and verified live, and the store screenshot that showed the old cramped map has been replaced. Build 6 is in review with nothing known-broken in it.

## Waiting on Me

- [ ] **Watch for Apple's verdict on 1.0 (6)** (~passive) - approval auto-releases. Apple DID review this app on 2026-08-08 (4 days after submit), so the queue does move; if this one stalls past ~5 days, contact App Review
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

Five submissions, zero releases. Each rejection or withdrawal costs the full queue position, so a small oversight turns into another multi-day round trip - and Sept 8 is four weeks out. Mitigating factor: the two things that caused the last two round trips (a 404 Support URL, a broken build) are both now verified rather than assumed.

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

- 2026-08-10 (later): **1.0 (build 6) SUBMITTED, state WAITING_FOR_REVIEW, auto-release on approval.** Build 5 was pulled the same day, before Apple looked at it, because testing turned up a confirmed defect in it (see the answer-controls bug below). Build 6 = build 5 + that fix. The iPhone map screenshot in the listing was also replaced: the old one predated `7085ab7` and showed the cramped layout with "1 STAR TO THE BOSS" clipped mid-word. New capture is 2868x1320 from the fixed build.
- 2026-08-10: **1.0 (build 5) resubmitted, then WITHDRAWN by us the same day** (never reviewed).
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
- Devices: **Chase's iPad is on 1.0 (6)** as of 2026-08-10 (Ad Hoc, installed over USB-C, install + launch both verified) - the same binary that is in App Store review, so he has the answer-controls fix. Wireless `devicectl` kept dropping the iPad to "unavailable"; the cable was the fix. Launch it with NO arguments on real devices: `-demo*` flags rewrite profile data.

## The "no way to answer" bug (root-caused 2026-08-10, commit 7400557)

The long-running intermittent bug where a question appeared with no keypad, no
entry field and no buttons is fixed, and this time the cause is proven rather
than inferred. It was never a keyboard or safe-area problem: both earlier
attempts (`fdad010` ignoresSafeArea, `27de971` fullScreenCover → overlay) fixed
look-alike symptoms and left it intact.

`assembleQuest`'s WARM-UP block rebuilt each review question field-by-field to
relabel its `movement`, copying prompt/format/options/timed but silently
dropping `trueFalse` and `shownValue`. True/False questions are built with
`format == .recognition, options == nil` and rely on that flag to reach
TrueFalseView; stripped of it they fell through to MultipleChoiceView, whose
`ForEach(options ?? [])` renders the prompt and nothing else. Warm-up is the
first three questions of a quest, hence "it breaks the moment a session opens",
and reopening (a fresh plan with a new seed) appeared to fix it.

Measured on iPhone 16 Pro Max by sampling screenshots for answer controls:
before, 2/10 normal launches and 5/6 with `-forceTrueFalse` failed; after, 0/8
normal, 0/8 forced, and 0/8 on iPad. Answering was also confirmed to work
end-to-end (streak increments), not merely to render. A safety net in
QuestionContainer now degrades any option-less recognition question to the
number pad, so a planner slip can never strand a child again.

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
- **For an intermittent UI bug, build a pixel detector and loop the launch - do not "fix" it from a plausible-looking code read.** This bug survived two confident fixes because both were reasoned from symptoms that resembled a known cause. What actually cracked it: a launch-arg repro (`-autostartSession`), a one-line image metric that separates good from broken by 100x (fraction of saturated key-coloured pixels in the control region), and a shell loop of ~10 launches producing a failure RATE. A rate turns "seems fixed" into 5/6 → 0/8, and it also lets you *disprove* a hypothesis cheaply - forcing the suspected condition produced a visibly different failure, which killed the leading theory in one build.
- **When a debug flag exists that forces the rare branch, use it to make the flake deterministic** (`-forceTrueFalse` took the failure rate from ~20% to ~83%). Proving the rate moves when you force the suspected input is what separates a real diagnosis from a guess.
- **Beware field-by-field struct copies.** Rebuilding a value type to change one field silently drops every field added later - the compiler cannot help, because the omitted fields have defaults. Prefer mutating a copy, and when a copy must strip behaviour, normalise every field that depended on it.
