# App Store Connect — copy-paste metadata

Everything below is ready to paste into App Store Connect. Character limits are
Apple's; drafts here respect them. Anything in **[brackets]** is a decision or a
value only you can supply.

---

## App name (max 30 chars) — PICK ONE

Apple requires the public name to be unique across the store, so have backups.
"Multiplication" alone is too generic to reserve; these keep the theme:

1. **Multiplication Adventure** (26) — first choice, matches the home-screen brand
2. **Multiplication Quest** (21)
3. **Times Table Adventure** (22)
4. **Times Table Quest: Math** (24)
5. **Multiply Quest** (15)

> The home-screen label (`Multiplication`) is independent of this and can stay as
> is. If your first choice is taken, App Store Connect tells you immediately when
> you type it into the app record.

## Subtitle (max 30 chars)

> Master the times tables

Alternates: `Times tables, one quest at a time` is too long; `A times-tables quest` (20).

## Promotional text (max 170 chars) — editable anytime without a new build

> Learn the times tables the fun way. Explore seven worlds, battle guardians,
> earn stars, and become a multiplication master. No ads, no tracking, made for kids.

## Keywords (max 100 chars, comma-separated, no spaces after commas)

> multiplication,times tables,math,maths,kids,3rd grade,4th grade,facts,fluency,arithmetic,learning,game

(99 chars. Don't repeat the app-name words here — Apple already indexes those.)

## Description (max 4000 chars)

```
Multiplication Adventure turns learning the times tables into a real adventure.

Your child journeys across seven hand-painted worlds — from Highland Trail to the
Storm Titan's peak — mastering one multiplication fact at a time. Every world ends
in a boss battle against its guardian, and every correct answer lands a hit.

The app adapts to your child. Facts they know fly by; facts they're still learning
come back more often, first as multiple choice, then fill-in-the-blank, then from
memory — so they build real fluency, not just lucky guesses. Fast, confident
answers earn speed bonuses and streaks; a wrong answer just means a little more
practice, never a penalty.

WHAT'S INSIDE
• All the times tables from 0 to 11 — 77 facts in total
• Seven worlds with a boss guardian in each
• A star quest system that paces practice into short, winnable sessions
• Speed bonuses, answer streaks, and celebration moments that make progress feel great
• A Times Table reference chart to look up any answer
• A Certificate of Mastery to earn — and print — once every fact is mastered
• Multiple player profiles, so siblings and friends each keep their own progress

BUILT FOR KIDS AND PARENTS
• No ads. No in-app purchases. No sign-in.
• No tracking and no data collection — the app is completely offline and every
  bit of progress stays on the device.
• A simple parent area (behind a gate) shows exactly which facts your child has
  mastered and which ones need work.

Made by a dad for his own kids, and now for yours. Perfect for 2nd, 3rd, and 4th
graders building multiplication fluency — or anyone who wants the times tables to
finally stick.
```

## What's New (release notes for v1.0)

```
The very first release. Seven worlds, 77 facts, and a certificate waiting at the end. Have fun!
```

---

## TestFlight (Beta) fields

### Beta App Description (shown to testers)

```
Multiplication Adventure — a times-tables game for kids. Explore seven worlds,
battle the guardian in each, and master every fact from 0 to 11. Fully offline,
no ads, no accounts. Thanks for testing!
```

### What to Test (per build)

```
Please try:
• Create a player, pick an avatar, and play a session in the first world.
• Answer some questions right and some wrong — the number pad should always appear.
• Check the Times Table button (top of the map) and the parent area (gear icon).
• Let a second child create their own profile and confirm progress stays separate.

Tell me anything confusing, anything that looks broken, and whether the difficulty
feels right for your kid's grade.
```

### Test information (contact)

- Feedback email: **[your email]**
- Marketing URL: (optional) your GitHub repo or leave blank
- Privacy Policy URL: **[hosted privacy-policy.html URL — see SUBMISSION.md]**

---

## App information (set once)

| Field | Value |
|---|---|
| Bundle ID | `com.levelup.adventure` |
| Primary category | **Education** |
| Secondary category | **Games** (subcategory: Educational) |
| Age rating | **4+** (see SUBMISSION.md for the questionnaire answers — all "None") |
| Price | **Free** |
| Made for Kids category | **Optional — recommend NO for v1.** Listing under Education with a 4+ rating avoids the stricter Kids-category review while still being fully appropriate. You can opt in later. |
| Support URL | **[required — can be the GitHub repo URL or a simple page]** |
| Marketing URL | Optional |
| Privacy Policy URL | **[hosted privacy-policy.html URL]** |
| Copyright | `2026 Justin Nikolaus` |
| Availability | **[all countries, or just your own to start]** |
| Content rights | Contains no third-party content (art is your own/AI-generated, audio is Kenney CC0) |

## Data collection (App Privacy section) — the easy part

Answer Apple's App Privacy questionnaire with:

> **"Data Not Collected"** — check the single box that says the app collects no data.

Nothing else to fill in. This matches the `PrivacyInfo.xcprivacy` shipped in the app.
