---
title: "Level Up Math: Development Plan"
created: 2026-05-31
modified: 2026-05-31
version: 1.0
author: Claude Opus 4.6 (claude-opus-4-6)
tags:
---

# Level Up Math: Development Plan

This is the build companion to the PRD. It covers the technology choices, the order we build in, how we get something onto your son's iPad fast and then harden it into a solid v1, how we verify it actually works, and exactly how I help at each step.

The target is a solid, genuinely usable v1 on his iPad within one to two weeks. You test what I build. The strategy is to get a rough but real version into his hands within the first few days so the summer clock starts, then layer in the engine and polish while he is already using it.

---

## 1. Technology Choices

- **Language and UI:** Swift with SwiftUI. Native, fast to build, and the right fit for an iPad-first app.
- **Persistence:** SwiftData (Apple's modern local data layer) for the profile, facts, sessions, and milestones. Fully on-device, no account, no network.
- **Minimum iOS:** iOS 17 or later, which his iPad will support and which SwiftData requires.
- **Sound:** lightweight bundled sound effects played through the system audio APIs. No music.
- **Build and install:** Xcode on your Mac, deployed to his iPad over a cable or via TestFlight. TestFlight is the cleaner path once we have an Apple Developer account, because it lets you push updates to his iPad through the summer without plugging in.

What we are deliberately not using: no backend, no third-party game engine, no analytics SDKs, no ad or in-app-purchase frameworks. Everything stays local and simple, which is faster to build, safe for a child, and still leaves a clean path to the App Store later.

### What you will need on your side

- A Mac with a recent version of Xcode installed.
- His iPad and a cable, at least for the first install.
- An Apple ID. A paid Apple Developer account (99 dollars a year) is needed for TestFlight and eventually the App Store, but is not required just to run the app on his iPad during early testing. We can start without it.

---

## 2. Build Order and Milestones

Seven milestones, sequenced so there is always a working app and each step adds something testable. Rough day estimates assume focused iteration; we move at whatever pace fits.

### Milestone 0: Project skeleton (day 1)

A running SwiftUI app that launches on his iPad, with the data model defined (Profile, Fact, Session, Milestone) and the 91 facts seeded. Nothing pretty yet. The point is a green light: it builds, it runs, it stores data.

### Milestone 1: Playable core loop (days 1 to 2)

The single most important slice. A session that shows multiple-choice and open-response questions, accepts answers on a number pad, gives immediate right-or-wrong feedback, and records the result. Even with placeholder visuals, this is the rough-but-real build you can hand him so the summer starts. He can practice from here forward.

### Milestone 2: The learning engine (days 2 to 4)

The brain from PRD section 4. Three-stage progression per fact, the promotion and mastery rules, Leitner spaced-repetition scheduling, response-time capture, and adaptive weak-area weighting. After this, the app is genuinely teaching rather than just quizzing, and what he practices is driven by what he actually needs.

### Milestone 3: Session structure and curriculum (days 4 to 5)

The four-movement session (warm-up, core, review, wrap), the start-at-the-beginning curriculum with tables introduced in ease order, interleaving, and the gating that holds back a new table until the prior ones are mostly mastered.

### Milestone 4: Progression and feel (days 5 to 7)

XP with the effort-to-mastery shift, ranks and level-up moments, satisfying sound effects, the gentle-by-default timing with the Speed Round unlock, and the wrap screen. This is where it starts to feel like a game he wants to return to.

### Milestone 5: Parent dashboard and rewards (days 7 to 9)

The transparent one-screen dashboard: cadence, overall mastery percentage, the color-coded mastery map, accuracy and speed trend, trouble spots, and the earned-rewards list. Plus milestone detection feeding it.

### Milestone 6: Completion and polish (days 9 to 12)

The completion state, generated certificate, Master rank celebration, visual cleanup, edge-case handling, and a verification pass. This is the line between "working" and "solid v1."

You get a build to put in front of him at Milestone 1 and a meaningfully better one at the end of each milestone after that.

---

## 3. How We Verify It Actually Works

Fluency software is easy to get subtly wrong in ways that look fine on screen, so verification is built into the plan rather than bolted on at the end.

- **Engine unit tests.** The scheduling and mastery logic is pure rules, so I write automated tests for it: does a wrong answer demote correctly, does a fact need cross-day reps to reach Mastered, does the weak-area weighting actually favor slow and error-prone facts, do due dates advance correctly. This is the highest-risk code and it gets the most coverage.
- **Simulated learner.** Before your son ever sees Milestone 2, I run a simulated child through hundreds of sessions in code to confirm facts progress sensibly, nothing gets stuck, and the curriculum gates open at the right time. This catches pacing bugs that would otherwise take weeks of real use to surface.
- **Your hands-on testing.** At each milestone you run the real build and we fix what feels wrong. You are the product owner and the feel test.
- **His real use.** Once he is on it, his actual data is the truth. The dashboard doubles as our instrument: if mastery is not climbing or a table is stalling, we see it and adjust the engine.

---

## 4. How I Help at Each Step

Concretely, here is what I do versus what you do.

I write the Swift and SwiftUI code, the data model, and the learning engine, and I deliver it as real files you can open in Xcode. I write the automated tests and run the simulated-learner checks. When something breaks, you paste me the Xcode error or describe the behavior and I diagnose and fix it. I keep the PRD and this plan updated as decisions firm up, following your project standards. I can generate the certificate design, draft the sound and visual direction, and produce any supporting assets we can make without a designer.

You install Xcode, run the builds on his iPad, test the feel, make the calls on the open questions in PRD section 14, and observe how he actually responds so we can tune. When we hit the Apple Developer account and TestFlight step, I walk you through it.

A normal working loop looks like this: I hand you a milestone build with notes on what to try, you run it and tell me what works and what does not, I revise, repeat. We do not move to the next milestone until the current one feels right to you.

---

## 5. Immediate Next Steps

1. You confirm Xcode is installed and his iPad is available, and decide whether to start cabled or set up a developer account for TestFlight now.
2. You resolve the few open questions from PRD section 14 that affect early build, especially rank names and thresholds, though I can start with sensible defaults and we tune later.
3. I scaffold Milestone 0 and Milestone 1 so there is a playable build to react to.

Say the word and I will start generating the project.
