# Getting Multiplication Adventure onto iPads — submission runbook

Two phases. **Phase 1 = TestFlight** (get it to cousins/friends fast).
**Phase 2 = public App Store** (permanent, searchable). Do Phase 1 first; Phase 2
reuses everything from Phase 1 plus screenshots and a fuller review.

The app is already in good shape: paid developer account (team `6A4J2GTB6F`),
offline / no-data-collection, privacy manifest shipped, `1.0 (1)`, iPad-only,
encryption-exempt flag set. Metadata drafts are in
[METADATA.md](METADATA.md); the privacy policy to host is
[../privacy-policy.html](../privacy-policy.html).

---

## One-time prep (do these once, before Phase 1)

### A. Host the privacy policy → get a URL

You need a public URL for the policy. Easiest free option, since the repo is
already public on GitHub:

1. `docs/privacy-policy.html` is already in the repo. Push it (it will be after
   I commit this batch).
2. On GitHub: repo **Settings → Pages → Build from a branch → `main` / `/docs`**
   → Save.
3. After a minute the policy is live at:
   `https://nikolausj1.github.io/multiplication-adventure/privacy-policy.html`
4. Open it to confirm, and use that URL wherever a Privacy Policy URL is asked.

(If you'd rather not use GitHub Pages, any host works — even a Notion page set to
public. It just needs to load.)

### B. Decide the public app name

Pick from [METADATA.md](METADATA.md) (first choice: **Multiplication
Adventure**). You'll type it when creating the app record; App Store Connect
tells you instantly if it's taken. Have a backup ready.

---

## Phase 1 — TestFlight

### 1. Create the app record

1. Sign in to [App Store Connect](https://appstoreconnect.apple.com) → **Apps → +
   → New App**.
2. Platform **iOS**; Name **[your chosen name]**; Primary language **English
   (U.S.)**; Bundle ID **`com.levelup.adventure`** (pick it from the dropdown —
   if it's not there, it's auto-registered on first upload, or add it at
   developer.apple.com → Identifiers); SKU: anything unique, e.g.
   `multiplication-adventure-01`.

### 2. Upload the build from Xcode

The Ad Hoc export we've used for your son's iPad is *not* the same as an App Store
upload. Use Xcode's Organizer:

1. Open `LevelUpMath.xcodeproj` in Xcode.
2. Set the run destination to **Any iOS Device (arm64)** (top bar).
3. **Product → Archive.** (If Archive is greyed out, the destination is still a
   simulator — switch it.)
4. When the Organizer opens: select the archive → **Distribute App → App Store
   Connect → Upload** → keep the defaults (automatic signing, symbols on) →
   Upload.
5. Wait ~5–15 min. The build appears in App Store Connect under **TestFlight**
   with status "Processing," then "Ready to Submit."

> Version/build: this batch is `1.0 (1)`. Every *new* upload needs a higher build
> number — bump `CURRENT_PROJECT_VERSION` in `project.yml` (1 → 2 → …) and run
> `xcodegen generate` before re-archiving. I can do that bump each time.

### 3. Fill the tiny bit of TestFlight info

Under **TestFlight** tab:
- **Test Information** (left sidebar): paste the Beta App Description, feedback
  email, and the Privacy Policy URL from [METADATA.md](METADATA.md).
- Because the app collects no data, there's no extra compliance to fill.
- Export compliance: it will ask about encryption — answer **No** (the
  `ITSAppUsesNonExemptEncryption = NO` flag we ship means it usually won't even
  ask).

### 4. Add testers

Two ways:
- **Individual emails:** TestFlight → **Internal Testing** (people on your dev
  account, up to 100, no beta review needed) or **External Testing** (anyone, up
  to 10,000). For cousins/friends use **External**: create a group, add their
  emails.
- **Public link:** in the External group, enable **Public Link** — you get a URL
  you can text to the parents. They open it on the iPad, install **TestFlight**
  from the App Store, and tap Install.

### 5. Beta review (external only)

External testing needs a one-time **Beta App Review** (much lighter than full
review — usually < 24h). Submit the build for beta review; once approved, invites
work and the public link goes live. Internal testers can install immediately with
no review.

**That's it for Phase 1.** Push updates by bumping the build number, re-archiving,
and uploading — testers get them automatically. Builds expire after 90 days;
re-upload to refresh.

---

## Phase 2 — public App Store

Everything above carries over. Add:

### 1. Screenshots (required)

App Store requires **13-inch iPad** screenshots (2064×2752 portrait or 2752×2064
landscape). I've prepared a set in `docs/appstore/screenshots/` — upload them
under the app version → **iPad 13-inch** slot (they also cover the smaller iPad
sizes automatically). 1 minimum, up to 10; the order you set is the order shown.

### 2. Version metadata

From [METADATA.md](METADATA.md): Subtitle, Promotional text, Description,
Keywords, Support URL, Marketing URL (optional), Copyright.

### 3. Categories & rating

- Primary **Education**, Secondary **Games**.
- **Age rating:** open the questionnaire and answer **None / No** to everything
  (no violence, no mature content, no gambling, no unrestricted web, no ads). The
  result is **4+**.
- **Made for Kids:** leave **off** for v1 (Education + 4+ is fully appropriate and
  skips the stricter Kids-category review). You can opt in later if you want the
  Kids category placement.

### 4. App Privacy

Data collection → **"Data Not Collected."** Check the one box, done. (Matches the
shipped `PrivacyInfo.xcprivacy`.)

### 5. Submit for review

Attach the build, set **"Automatically release"** (or manual), and **Submit for
Review.** Full review is typically 1–3 days. If anything bounces, the reviewer
tells you exactly what; common ones for a kids app are the privacy policy URL not
loading (make sure Pages is live) and screenshots not matching the app (ours do).

---

## Things reviewers might ask (and our answers)

| Question | Answer |
|---|---|
| Does it collect data? | No — fully offline, nothing leaves the device. |
| Login required? | No accounts, no login. |
| In-app purchases? | None. |
| Third-party content rights? | Art is original / AI-generated (rights held); audio is Kenney CC0 (license file shipped in `Sources/App/Resources/Audio/`). |
| Ads / analytics? | None. |
| Made for Kids? | Age-appropriate (4+), listed under Education. |

## What I can keep doing for you

- Bump the build number and re-archive-ready the project before each upload.
- Regenerate/adjust screenshots.
- Tweak any metadata copy.
- Everything except the steps that need your Apple ID login (creating the record,
  clicking Upload/Submit, adding testers) — those are yours.
