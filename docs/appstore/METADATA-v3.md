---
title: "App Store metadata v3 - the 4.3(a) differentiation pass"
created: 2026-08-24
modified: 2026-08-24
version: 1.0
author: Claude Opus 5 (claude-opus-5)
tags:
---

# Metadata v3

Written to answer the Guideline 4.3(a) Design: Spam rejection of 1.0 (6) on
2026-08-13. Apple said the app "shares a similar binary, metadata, and/or
concept as apps submitted to the App Store by other developers, with only minor
differences," and did not answer the follow-up asking which apps it was matched
against (11 days of silence as of 2026-08-24).

The strategy is to make the next submission demonstrably NOT a repackaged
template, in the three places that actually carry weight: the binary, the
reviewer notes, and the screenshots. Metadata copy is a smaller lever and is
tuned rather than rewritten.

## Unchanged, deliberately

- **App name: Multiplication Adventure.** Justin's call. It is in the DNA of the
  app, 4.3(a) is about binary/assets/concept rather than titles, and descriptive
  names are common among legitimate apps.
- **Keywords.** They are invisible to users, they exist for discovery, and no
  reviewer judges spam by the keyword field. Changing them would cost
  findability for no defensive benefit.
- **The description body.** It is already specific and personal: named worlds,
  named guardians, real mechanics. No template ships that copy. Only additions
  below.

## Subtitle (30 char limit)

Current: `Master the times tables` (23) - a category description, not a product.

Recommended: `Seven worlds, seven guardians` (29)

Alternatives: `A boss fight for every table` (28), `Seven worlds, one boss each` (27)

Rationale: names a structure specific to this app. A repackaged quiz template
cannot honestly say it.

## Promotional text (170 char limit)

Current (110): `Learn the times tables the fun way. Explore seven worlds, battle guardians, earn stars, and master every fact.`

Recommended (155):

    Seven worlds, seven guardians, all 77 times-table facts.
    No ads, no purchases, no tracking, works offline. Built by one parent
    for his own kids.

Rationale: "the fun way" is the single most template-sounding phrase in the
listing. Provenance ("built by one parent") is the strongest anti-spam signal
available and it is true.

## Description: two additions, nothing removed

1. Add near the top, after the opening line:

       It was built by one parent, at home, for his own two children, and
       every world, guardian, and sound in it was made for this app.

2. Add as a closing section:

       AND THEN IT ENDS
       There is no endless streak to protect and no reason to keep playing
       once the tables are learned. When every fact is mastered the journey
       finishes, the certificate prints, and the app says so.

Rationale: provenance and a finishable design are both rare and both true. The
second is also the sharpest marketing line available, independent of 4.3.

## Screenshots: swap one

Current order: map, session, boss, Lightning Round.

The session shot (a question plus a number pad) is the single most generic image
in the set and looks like every math app. Replace it with the Certificate of
Mastery, or with the golden map if build 7 ships Golden Guardians.

Keep the map first. It is the most distinctive image and the install sheet only
shows the first three.

## Reviewer notes (4000 char limit) - the main lever

This is the only place to talk directly to the human deciding. The previous
submission's notes said nothing about originality or the sibling app; that
explanation existed only in a Resolution Center thread that was never read.

    ORIGINALITY AND THE 4.3 REJECTION OF BUILD 6

    This submission responds to the Guideline 4.3(a) rejection of build 6 on
    August 13. I replied in Resolution Center that day asking which apps my
    submission was matched against and did not receive a response, so I have
    made the app and its listing more clearly distinct and am resubmitting.

    This app is original work. I wrote every line of it myself. It is not
    built on a purchased or third-party template, it does not use a
    commercial app generator, and it shares no source code or assets with any
    other developer's app. There is no third-party SDK of any kind in the
    binary. The engine, the curriculum, the game design, the artwork, the
    sound effects and the copy were all produced specifically for this app.

    Provenance: I built this at home for my own two children, so that my son
    would know his times tables before starting the school year. That is the
    entire reason it exists. It is free, and it has no advertising, no in-app
    purchases, no subscription, no accounts, no sign-in, no analytics and no
    data collection of any kind. It works fully offline. There is no
    monetization surface in the app at all, which I hope is relevant, since
    spam submissions are generally monetization plays.

    The artwork, sound and copy were created specifically for this app.
    Nothing in it is stock, purchased, or reused from another app, and none
    of it appears anywhere else.

    DISCLOSURE OF MY OTHER APP

    I have a second app record on this account, Addition Adventure
    (com.levelup.addsub). It is also entirely my own work and it shares an
    engine with this app because I wrote both. They teach different arithmetic
    for different ages: that one covers addition and subtraction for my
    younger son, this one covers the multiplication tables 0 to 11 for my
    older son. The curriculum, artwork, world names, boss characters and
    progression all differ. Addition Adventure has never been released, is not
    on the App Store, and is not in review. I am holding it back specifically
    because of this rejection.

    If the concern is that these two should be one app, I am willing to
    consolidate them into a single app with selectable content and withdraw
    the other record entirely. I would rather do that than leave a spam flag
    unresolved. Please tell me if that is the required resolution.

    WHAT IS DISTINCT ABOUT THIS APP

    - Seven worlds, each with its own named guardian, its own palette and
      its own animated boss encounter.
    - An adaptive per-fact mastery ladder (recognition, recall, fluency,
      mastered) with a speed threshold that adjusts to the individual child,
      so fluency means fast recall rather than a correct guess.
    - A designed ending. When all 77 facts are mastered the app finishes and
      prints a certificate. It does not try to retain the child afterwards.

    HOW TO SEE IT QUICKLY

    World 1 is available immediately and shows the complete loop. Create a
    player through the short onboarding, tap World 1, and answer a few
    questions. From the map, "Times Table" opens the reference chart. The gear
    icon opens the Parent Area behind a two-digit multiplication gate (for
    example 16 x 18), which is deliberately beyond the 0-11 tables the app
    teaches.

    Thank you for reading. I am happy to make any change that resolves this.

## On disclosing how the artwork was made

Deliberately NOT in the notes. There is no Apple rule requiring disclosure of
generated assets: no guideline, no App Store Connect field, no policy. The
AI-transparency regimes that exist target AI features users interact with, and
this app has none at runtime.

An earlier draft volunteered it, on the theory that if Apple matched on visual
style then explaining the style would be exculpatory. That was a guess about an
unknown trigger, and it opens a line of questioning that is not currently open.

Guideline 4.3(a) is about duplication and repackaging. The claim that answers it
is that the assets exist in no other app, which is true and is stated plainly
without reference to tooling.

Hold the fuller explanation in reserve. If Apple names visually similar apps or
asks about the art directly, answer completely at that point: it becomes
relevant, and a straight answer is then the strongest move.

**What was never optional** was removing the "hand-painted" claim from the
description and support page. Not disclosing a method is fine. Asserting a false
one, in a submission whose entire defence is the developer's credibility, is not.

## The biggest lever is not on this page

Build 6 predates the Golden Guardians endgame, which is complete and measured on
branch `boss-idle-videos`: a map that transforms after completion, seven golden
boss rematches, a world-scoped mastery loop and a final salute. Shipping that as
build 7 makes "only minor differences from other apps" a materially weaker
claim, because no repackaged template has it.

Justin should play it first. Shipping unplayed content into a review where the
app is already flagged is a bad trade.
